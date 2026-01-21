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

py_bin=""
if command -v python3 >/dev/null 2>&1; then
  py_bin="python3"
elif command -v python >/dev/null 2>&1; then
  py_bin="python"
else
  echo "Error: python3 (or python) is required to run this script." >&2
  exit 1
fi

"$py_bin" - "$data_file" "$board" <<'PY'
import json
import random
import sys

if len(sys.argv) < 3:
    print("Usage: generate-hwid.sh --board BOARD", file=sys.stderr)
    sys.exit(1)

db_file = sys.argv[1]
board = sys.argv[2]

with open(db_file, "r", encoding="utf-8") as fh:
    data = json.load(fh)

devices = data.get("devices", {})

def parse_groups(hwid):
    if not hwid:
        return []
    parts = str(hwid).split(" ")
    if len(parts) < 2:
        return []
    return [g for g in "-".join(parts[1:]).split("-") if g]

def flatten_entries(device_map):
    all_entries = []
    for entries in device_map.values():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if isinstance(entry, dict) and entry.get("hwid"):
                all_entries.append(entry)
    return all_entries

def char_pattern(group):
    hex_only = True
    pattern = []
    for ch in group:
        if "0" <= ch <= "9":
            pattern.append("D")
        elif "A" <= ch <= "Z":
            pattern.append("A")
        else:
            pattern.append("X")
        if not (("0" <= ch <= "9") or ("A" <= ch <= "F")):
            hex_only = False
    return "".join(pattern), hex_only

def gen_char(char_type, hex_only):
    if char_type == "D":
        return str(random.randrange(10))
    if char_type == "A":
        letters = "ABCDEF" if hex_only else "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return random.choice(letters)
    pool = "0123456789ABCDEF" if hex_only else "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return random.choice(pool)

def gen_group_from_template(group):
    pattern, hex_only = char_pattern(group)
    if not pattern:
        return ""
    return "".join(gen_char(t, hex_only) for t in pattern)

entries = devices.get(board)
pool = entries if isinstance(entries, list) else None
if not pool:
    print("Board unsupported, trying random", file=sys.stderr)
    pool = flatten_entries(devices)

groups = []
if pool:
    template = random.choice(pool)
    groups = parse_groups(template.get("hwid"))

group_count = len(groups) or 4
prefix_len = min(2, group_count)
out_groups = []

for i in range(group_count):
    if i < prefix_len and i < len(groups) and groups[i]:
        out_groups.append(groups[i])
        continue
    template_group = groups[i] if i < len(groups) and groups[i] else "A0Z"
    out_groups.append(gen_group_from_template(template_group))

print(f"{board} {'-'.join(out_groups)}")
PY
