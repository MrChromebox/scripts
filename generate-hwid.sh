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

if [[ ! -s "${data_file}" ]]; then
  echo "Error: database file not found: ${data_file}" >&2
  exit 1
fi

get_hwids_for_board() {
  awk -v board="$board" '
    $0 ~ "\"" board "\"[[:space:]]*:[[:space:]]*\\[" { in_block=1; next }
    in_block && /"hwid"[[:space:]]*:/ {
      hwid=$0
      sub(/.*"hwid"[[:space:]]*:[[:space:]]*"/, "", hwid)
      sub(/".*/, "", hwid)
      if (hwid != "") print hwid
    }
    in_block && /]/ { exit }
  ' "${data_file}"
}

get_all_hwids() {
  awk '
    /"hwid"[[:space:]]*:/ {
      hwid=$0
      sub(/.*"hwid"[[:space:]]*:[[:space:]]*"/, "", hwid)
      sub(/".*/, "", hwid)
      if (hwid != "") print hwid
    }
  ' "${data_file}"
}

rand_digit() {
  printf '%d' $((RANDOM % 10))
}

rand_letter() {
  local letters="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  printf '%s' "${letters:RANDOM%26:1}"
}

rand_hex_letter() {
  local letters="ABCDEF"
  printf '%s' "${letters:RANDOM%6:1}"
}

rand_hex() {
  local chars="0123456789ABCDEF"
  printf '%s' "${chars:RANDOM%16:1}"
}

rand_alnum() {
  local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  printf '%s' "${chars:RANDOM%36:1}"
}

gen_group() {
  local tmpl="$1"
  local out=""
  local i=""
  local ch=""
  local hex_only=0

  if [[ "${tmpl}" =~ ^[0-9A-F]+$ ]]; then
    hex_only=1
  fi

  for ((i=0; i<${#tmpl}; i++)); do
    ch="${tmpl:i:1}"
    if [[ "${ch}" =~ [0-9] ]]; then
      out+=$(rand_digit)
    elif [[ "${ch}" =~ [A-Z] ]]; then
      if (( hex_only )); then
        out+=$(rand_hex_letter)
      else
        out+=$(rand_letter)
      fi
    else
      if (( hex_only )); then
        out+=$(rand_hex)
      else
        out+=$(rand_alnum)
      fi
    fi
  done

  if [[ -z "${out}" ]]; then
    if (( hex_only )); then
      out="$(rand_hex)$(rand_hex)$(rand_hex)"
    else
      out="$(rand_alnum)$(rand_alnum)$(rand_alnum)"
    fi
  fi

  printf '%s' "${out}"
}

hwids=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && hwids+=("${line}")
done < <(get_hwids_for_board)

if [[ ${#hwids[@]} -eq 0 ]]; then
  echo "Board unsupported, trying random" >&2
  while IFS= read -r line; do
    [[ -n "${line}" ]] && hwids+=("${line}")
  done < <(get_all_hwids)
fi

if [[ ${#hwids[@]} -eq 0 ]]; then
  echo "Error: no HWIDs available in database." >&2
  exit 1
fi

template="${hwids[RANDOM % ${#hwids[@]}]}"
groups_str=""
if [[ "${template}" == *" "* ]]; then
  groups_str="${template#* }"
fi

groups=()
if [[ -n "${groups_str}" ]]; then
  IFS='-' read -r -a groups <<< "${groups_str}"
fi

if [[ ${#groups[@]} -eq 0 ]]; then
  groups=("A0Z" "A0Z" "A0Z" "A0Z")
  prefix_len=0
else
  prefix_len=2
  if (( prefix_len > ${#groups[@]} )); then
    prefix_len=${#groups[@]}
  fi
fi

out_groups=()
for ((i=0; i<${#groups[@]}; i++)); do
  if (( i < prefix_len )); then
    out_groups+=("${groups[i]}")
  else
    out_groups+=("$(gen_group "${groups[i]}")")
  fi
done

echo "${board} $(IFS=-; echo "${out_groups[*]}")"
