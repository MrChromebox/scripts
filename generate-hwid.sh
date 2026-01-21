#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --board BOARD" >&2
}

board=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)
      board=${2:-}
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [ -z "$board" ]; then
  usage
  exit 1
fi

board=$(printf '%s' "$board" | tr '[:lower:]' '[:upper:]')
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
data_file="$script_dir/database/cros-hwid.json"

node_bin=""
if command -v node >/dev/null 2>&1; then
  node_bin="node"
elif command -v nodejs >/dev/null 2>&1; then
  node_bin="nodejs"
else
  echo "Error: node (or nodejs) is required to run this script." >&2
  exit 1
fi

"$node_bin" - <<'NODE' "$data_file" "$board"
const fs = require("fs");
const file = process.argv[2];
const board = process.argv[3];
if (!file || !board) {
  console.error("Usage: generate-hwid.sh --board BOARD");
  process.exit(1);
}
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const devices = data.devices || {};

function randInt(n) {
  return Math.floor(Math.random() * n);
}

function pick(arr) {
  return arr[randInt(arr.length)];
}

function parseGroups(hwid) {
  if (!hwid) return [];
  const parts = String(hwid).split(" ");
  if (parts.length < 2) return [];
  return parts.slice(1).join(" ").split("-").filter(Boolean);
}

function flattenEntries(map) {
  const all = [];
  for (const entries of Object.values(map)) {
    if (!Array.isArray(entries)) continue;
    for (const entry of entries) {
      if (entry && entry.hwid) all.push(entry);
    }
  }
  return all;
}

function charPattern(group) {
  let hexOnly = true;
  const pattern = [];
  for (const ch of group) {
    if (ch >= "0" && ch <= "9") {
      pattern.push("D");
    } else if (ch >= "A" && ch <= "Z") {
      pattern.push("A");
    } else {
      pattern.push("X");
    }
    if (!((ch >= "0" && ch <= "9") || (ch >= "A" && ch <= "F"))) {
      hexOnly = false;
    }
  }
  return { pattern: pattern.join(""), hexOnly };
}

function genChar(type, hexOnly) {
  if (type === "D") {
    return String(randInt(10));
  }
  if (type === "A") {
    const letters = hexOnly ? "ABCDEF" : "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    return letters[randInt(letters.length)];
  }
  const pool = hexOnly
    ? "0123456789ABCDEF"
    : "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  return pool[randInt(pool.length)];
}

function genGroupFromTemplate(group) {
  const { pattern, hexOnly } = charPattern(group);
  if (!pattern) return "";
  let out = "";
  for (const t of pattern) {
    out += genChar(t, hexOnly);
  }
  return out;
}

const entries = devices[board];
let pool = entries;
if (!Array.isArray(pool) || pool.length === 0) {
  console.error("Board unsupported, trying random");
  pool = flattenEntries(devices);
}

let groups = [];
if (pool.length > 0) {
  const template = pick(pool);
  groups = parseGroups(template.hwid);
}

const groupCount = groups.length || 4;
const prefixLen = Math.min(2, groupCount);
const outGroups = [];

for (let i = 0; i < groupCount; i++) {
  if (i < prefixLen && groups[i]) {
    outGroups.push(groups[i]);
    continue;
  }
  const templateGroup = groups[i] || "A0Z";
  outGroups.push(genGroupFromTemplate(templateGroup));
}

console.log(`${board} ${outGroups.join("-")}`);
NODE
