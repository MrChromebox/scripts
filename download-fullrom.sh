#!/usr/bin/env bash
#
# Download MrChromebox Full ROM firmware for a release.
#
# Usage:
#   download-fullrom.sh [options] <board> [board...]
#   download-fullrom.sh [options] --all
#   download-fullrom.sh [options] <version> <board> [board...]
#   download-fullrom.sh [options] <version> --all
#
# Examples:
#   download-fullrom.sh --list-versions
#   download-fullrom.sh drobit              # latest (hotfix or current release)
#   download-fullrom.sh --all
#   download-fullrom.sh 2606.1 drobit       # pin a release train
#   download-fullrom.sh 2606.1 --all -o /tmp/roms
#
# Latest (no version): uses FW_HOTFIX[board] from sources.sh when set
# (flat CDN root + hotfix date); otherwise release_current under
# MrChromebox-<version>/.
#
# Pinned <version>: always MrChromebox-<version>/ (ignores hotfixes).
#
# Catalog: prefers SHA256SUMS in a pinned release directory when present.
# Otherwise builds filenames as:
#   coreboot_edk2-<board>-mrchromebox_<YYYYMMDD>.rom
#
# Metadata (sources.sh / device-db.sh):
#   - If this script lives in a git checkout (.git present), use copies
#     alongside the script.
#   - Otherwise fetch from GitHub into /tmp (cached until reboot / cleanup).
#
# Created by Mr.Chromebox <mrchromebox@gmail.com>
#

set -euo pipefail

script_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
device_db_url="https://raw.githubusercontent.com/MrChromebox/scripts/main/device-db.sh"
sources_url="https://raw.githubusercontent.com/MrChromebox/scripts/main/sources.sh"
meta_cache_dir="/tmp/mrchromebox-fullrom-meta-${UID:-$(id -u)}"

OUTDIR=""
DATE=""
JOBS=4
DRY_RUN=0
ALL=0
LIST_VERSIONS=0
KEEP_GOING=0
USE_LATEST=0
VERSION=""
BOARDS=()
BOARD_INPUTS=()
FILES=()
SOURCES_ORIGIN=""
FULLROM_SOURCE=""
RELEASE_CURRENT_VERSION=""
RELEASE_CURRENT_DATE=""
RELEASE_PREVIOUS_VERSION=""
RELEASE_PREVIOUS_DATE=""
declare -A FW_HOTFIX=()
declare -A DEVICE_DB=()
DEVICE_DB_ORIGIN=""

usage() {
	cat <<'EOF'
Download MrChromebox Full ROM firmware for a release.

Usage:
  download-fullrom.sh --list-versions
  download-fullrom.sh [options] <board> [board...]
  download-fullrom.sh [options] --all
  download-fullrom.sh [options] <version> <board> [board...]
  download-fullrom.sh [options] <version> --all

With no <version>, downloads the latest image for each board: FW_HOTFIX
override from sources.sh when set, otherwise the current release train.

Board arguments may be ROM slugs (drobit) or ChromeOS HWIDs
(DROBIT). Quote full HWID strings ("DROBIT C4B-...") so spaces
and glob characters are not interpreted by the shell.

Options:
  -l, --list-versions   Show current/previous slots and any FW_HOTFIX boards
  -d, --date YYYYMMDD   Filename build date (pinned <version> only; required
                        if SHA256SUMS is absent and version is unknown)
  -o, --outdir DIR      Output directory (default: ./MrChromebox-<version>)
  -j, --jobs N          Parallel downloads with --all (default: 4)
  -k, --keep-going      Continue after failed downloads (default with --all)
  -n, --dry-run         Print URLs only; do not download
  -h, --help            Show this help

Board arguments: ROM slug (drobit) or device HWID (DROBIT). Quote
full HWID strings ("DROBIT C4B-...") so the shell does not split on
spaces or expand glob characters (*, ?, [). HWIDs are matched against
device-db.sh (including per-board ROM slug overrides such as Librem).

CDN path and release slots come from sources.sh. That file (and device-db.sh)
are used from the script directory when running inside a git clone; otherwise
downloaded to /tmp and reused until cleared/reboot.
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

http_ok() {
	local url="$1"
	local code
	code=$(curl -sI -L -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 "$url" || true)
	[[ "$code" = "200" ]]
}

fetch_text() {
	local url="$1"
	curl -fsSL --connect-timeout 10 --max-time 60 "$url"
}

running_from_git_repo() {
	[[ -d "$script_dir/.git" ]]
}

# Print path to sources.sh or device-db.sh (local checkout or /tmp cache).
ensure_meta_file() {
	local name="$1"
	local url="$2"
	local dest partial

	if running_from_git_repo; then
		dest="$script_dir/$name"
		[[ -f "$dest" ]] || die "Missing ${dest} (incomplete git checkout?)"
		printf '%s' "$dest"
		return 0
	fi

	mkdir -p "$meta_cache_dir"
	dest="$meta_cache_dir/$name"
	if [[ ! -f "$dest" ]]; then
		partial="${dest}.partial"
		printf 'Fetching %s -> %s\n' "$name" "$dest" >&2
		curl -fsSL --connect-timeout 10 --max-time 60 -o "$partial" "$url" \
			|| { rm -f "$partial"; die "Failed to download ${url}"; }
		mv -f "$partial" "$dest"
	fi
	printf '%s' "$dest"
}

normalize_version() {
	local v="$1"
	v="${v#MrChromebox-}"
	v="${v#mrchromebox-}"
	printf '%s' "$v"
}

is_version_token() {
	[[ "$1" =~ ^([Mm]r[Cc]hromebox-)?[0-9]+\.[0-9]+$ ]]
}

fullrom_root() {
	local base="${FULLROM_SOURCE}"
	[[ -n "$base" ]] || die "fullrom_source not loaded; call load_sources first"
	[[ "$base" = */ ]] || base="${base}/"
	printf '%s' "$base"
}

# Versioned release directory (pinned train or current when not hotfix)
cdn_version_dir() {
	local ver="${1:-$VERSION}"
	printf '%sMrChromebox-%s/' "$(fullrom_root)" "$ver"
}

rom_name() {
	local board="$1"
	local date="$2"
	printf 'coreboot_edk2-%s-mrchromebox_%s.rom' "$board" "$date"
}

board_hotfix_date() {
	local board="$1"
	printf '%s' "${FW_HOTFIX[$board]:-}"
}

# Latest URL for one board (hotfix flat root or current versioned train)
latest_url_for_board() {
	local board="$1"
	local hf date file
	hf=$(board_hotfix_date "$board")
	if [[ -n "$hf" ]]; then
		file=$(rom_name "$board" "$hf")
		printf '%s%s' "$(fullrom_root)" "$file"
	else
		file=$(rom_name "$board" "$RELEASE_CURRENT_DATE")
		printf '%s%s' "$(cdn_version_dir "$RELEASE_CURRENT_VERSION")" "$file"
	fi
}

parse_args() {
	local -a positionals=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				usage
				exit 0
				;;
			-d|--date)
				[[ $# -ge 2 ]] || die "$1 requires a value"
				DATE="$2"
				shift 2
				;;
			-o|--outdir)
				[[ $# -ge 2 ]] || die "$1 requires a value"
				OUTDIR="$2"
				shift 2
				;;
			-j|--jobs)
				[[ $# -ge 2 ]] || die "$1 requires a value"
				JOBS="$2"
				shift 2
				;;
			-k|--keep-going)
				KEEP_GOING=1
				shift
				;;
			-n|--dry-run)
				DRY_RUN=1
				shift
				;;
			-l|--list-versions)
				LIST_VERSIONS=1
				shift
				;;
			--all)
				ALL=1
				shift
				;;
			--)
				shift
				break
				;;
			-*)
				die "unknown option: $1"
				;;
			*)
				positionals+=("$1")
				shift
				;;
		esac
	done
	while [[ $# -gt 0 ]]; do
		positionals+=("$1")
		shift
	done

	VERSION=""
	BOARDS=()
	BOARD_INPUTS=()
	USE_LATEST=0

	if [[ ${#positionals[@]} -gt 0 ]] && is_version_token "${positionals[0]}"; then
		VERSION=$(normalize_version "${positionals[0]}")
		positionals=("${positionals[@]:1}")
	else
		USE_LATEST=1
	fi

	if [[ ${#positionals[@]} -gt 0 ]]; then
		local p
		for p in "${positionals[@]}"; do
			BOARD_INPUTS+=("$p")
		done
	fi
}

# Sets SOURCES_* and FW_HOTFIX from sources.sh
load_sources() {
	local path line
	SOURCES_TEXT=""
	SOURCES_ORIGIN=""
	FULLROM_SOURCE=""
	RELEASE_CURRENT_VERSION=""
	RELEASE_CURRENT_DATE=""
	RELEASE_PREVIOUS_VERSION=""
	RELEASE_PREVIOUS_DATE=""
	FW_HOTFIX=()

	path=$(ensure_meta_file "sources.sh" "$sources_url") || return 1
	SOURCES_ORIGIN="$path"
	SOURCES_TEXT=$(<"$path")

	FULLROM_SOURCE=$(sed -n 's/^export fullrom_source="\([^"]*\)".*/\1/p' <<<"$SOURCES_TEXT" | head -n1)
	RELEASE_CURRENT_VERSION=$(sed -n 's/^export release_current_version="\([^"]*\)".*/\1/p' <<<"$SOURCES_TEXT" | head -n1)
	RELEASE_CURRENT_DATE=$(sed -n 's/^export release_current_date="\([0-9]*\)".*/\1/p' <<<"$SOURCES_TEXT" | head -n1)
	RELEASE_PREVIOUS_VERSION=$(sed -n 's/^export release_previous_version="\([^"]*\)".*/\1/p' <<<"$SOURCES_TEXT" | head -n1)
	RELEASE_PREVIOUS_DATE=$(sed -n 's/^export release_previous_date="\([0-9]*\)".*/\1/p' <<<"$SOURCES_TEXT" | head -n1)

	[[ -n "$FULLROM_SOURCE" ]] || die "fullrom_source missing in ${SOURCES_ORIGIN}"
	[[ -n "$RELEASE_CURRENT_VERSION" && -n "$RELEASE_CURRENT_DATE" ]] \
		|| die "release_current_version/date missing in ${SOURCES_ORIGIN}"

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		if [[ "$line" =~ \[([A-Za-z0-9_]+)\]=([0-9]{8}) ]]; then
			FW_HOTFIX["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
		fi
	done < <(sed -n '/^declare -A FW_HOTFIX=/,/^)/p' <<<"$SOURCES_TEXT")
}

format_display_date() {
	local ymd="$1"
	[[ "$ymd" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})$ ]] || { printf '%s' "$ymd"; return; }
	printf '%s/%s/%s' "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[1]}"
}

list_versions() {
	local board base
	load_sources || die "Could not load sources.sh"

	base=$(fullrom_root)

	log "Release slots from ${SOURCES_ORIGIN}:"
	log "  current   MrChromebox-${RELEASE_CURRENT_VERSION}  ($(format_display_date "$RELEASE_CURRENT_DATE"))"
	log "            ${base}MrChromebox-${RELEASE_CURRENT_VERSION}/"
	if [[ -n "$RELEASE_PREVIOUS_VERSION" && -n "$RELEASE_PREVIOUS_DATE" ]]; then
		log "  previous  MrChromebox-${RELEASE_PREVIOUS_VERSION}  ($(format_display_date "$RELEASE_PREVIOUS_DATE"))"
		log "            ${base}MrChromebox-${RELEASE_PREVIOUS_VERSION}/"
	fi
	if [[ ${#FW_HOTFIX[@]} -gt 0 ]]; then
		log "  hotfixes  (flat ${base})"
		for board in $(printf '%s\n' "${!FW_HOTFIX[@]}" | sort); do
			log "            ${board}  $(format_display_date "${FW_HOTFIX[$board]}")"
		done
	fi
}

resolve_pinned_date() {
	local resolved=""
	if [[ -n "$DATE" ]]; then
		[[ "$DATE" =~ ^[0-9]{8}$ ]] || die "--date must be YYYYMMDD"
		return 0
	fi
	if [[ "$VERSION" = "$RELEASE_CURRENT_VERSION" ]]; then
		DATE="$RELEASE_CURRENT_DATE"
	elif [[ "$VERSION" = "$RELEASE_PREVIOUS_VERSION" ]]; then
		DATE="$RELEASE_PREVIOUS_DATE"
	else
		die "Could not determine build date for version ${VERSION}; pass --date YYYYMMDD"
	fi
	log "Using build date ${DATE} from ${SOURCES_ORIGIN}"
}

boards_from_device_db_text() {
	local text="$1"
	local line hwid info flags override slug
	local entry_re='\["([^"]+)"\]="([^"]+)"'
	local slug_re='^([A-Za-z0-9_]+)'
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ $entry_re ]] || continue
		hwid="${BASH_REMATCH[1]}"
		info="${BASH_REMATCH[2]}"
		IFS='|' read -r _ _ override flags _ <<<"${info}||||"
		[[ "$flags" == *noUEFI* ]] && continue
		if [[ -n "$override" ]]; then
			slug="$override"
		elif [[ "$hwid" =~ $slug_re ]]; then
			slug="${BASH_REMATCH[1]}"
		else
			continue
		fi
		[[ "$slug" =~ ^[A-Za-z0-9_]+$ ]] || continue
		printf '%s\n' "$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
	done <<<"$text" | sort -u
}

# Load DEVICE_DB patterns from device-db.sh (same matching model as the util).
load_device_db() {
	local path text line
	local entry_re='\["([^"]+)"\]="([^"]+)"'

	DEVICE_DB=()
	path=$(ensure_meta_file "device-db.sh" "$device_db_url") || die "Could not load device-db.sh"
	DEVICE_DB_ORIGIN="$path"
	text=$(<"$path")
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ "$line" =~ $entry_re ]] || continue
		DEVICE_DB["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
	done <<<"$text"
	[[ ${#DEVICE_DB[@]} -gt 0 ]] || die "No DEVICE_DB entries in ${DEVICE_DB_ORIGIN}"
}

normalize_hwid_input() {
	local h="$1"
	# Match util: strip X86 suffix noise and trailing spaces
	h="${h//X86/}"
	h="${h%"${h##*[![:space:]]}"}"
	h="${h#"${h%%[![:space:]]*}"}"
	printf '%s' "$h"
}

# Longest-pattern match like device-db-functions get_db_info; prints entry or empty.
lookup_device_db_entry() {
	local hwid="$1"
	local hwid_uc pattern best_pattern="" best_entry=""

	hwid_uc="${hwid^^}"
	if [[ -n "${DEVICE_DB[$hwid]:-}" ]]; then
		printf '%s' "${DEVICE_DB[$hwid]}"
		return 0
	fi
	if [[ -n "${DEVICE_DB[$hwid_uc]:-}" ]]; then
		printf '%s' "${DEVICE_DB[$hwid_uc]}"
		return 0
	fi
	for pattern in "${!DEVICE_DB[@]}"; do
		# shellcheck disable=SC2254
		if [[ "$hwid_uc" == $pattern ]]; then
			if [[ ${#pattern} -gt ${#best_pattern} ]]; then
				best_pattern="$pattern"
				best_entry="${DEVICE_DB[$pattern]}"
			fi
		fi
	done
	printf '%s' "$best_entry"
}

slug_from_db_entry() {
	local entry="$1"
	local hwid_hint="$2"
	local override flags slug
	IFS='|' read -r _ _ override flags _ <<<"${entry}||||"
	[[ "$flags" == *noUEFI* ]] && return 2
	if [[ -n "$override" ]]; then
		slug="$override"
	else
		slug=$(printf '%s' "${hwid_hint^^}" | cut -f1 -d'-' | cut -f1 -d' ')
	fi
	slug=$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')
	[[ "$slug" =~ ^[a-z0-9_]+$ ]] || return 1
	printf '%s' "$slug"
}

# Resolve a user token (HWID or board slug) to a ROM board slug.
resolve_token_to_board() {
	local raw="$1"
	local input entry slug rc

	input=$(normalize_hwid_input "$raw")
	[[ -n "$input" ]] || die "Empty board/HWID argument"

	entry=$(lookup_device_db_entry "$input")
	if [[ -n "$entry" ]]; then
		rc=0
		slug=$(slug_from_db_entry "$entry" "$input") || rc=$?
		if [[ "$rc" -eq 2 ]]; then
			die "Device '${input}' is flagged noUEFI (no Full ROM image)"
		fi
		[[ "$rc" -eq 0 && -n "$slug" ]] || die "Could not derive board slug from HWID '${input}'"
		if [[ "${input,,}" != "$slug" ]]; then
			printf "Resolved '%s' -> %s\n" "$raw" "$slug" >&2
		fi
		printf '%s' "$slug"
		return 0
	fi

	# No DB hit: accept bare board slug
	slug=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
	if [[ "$slug" =~ ^[a-z0-9_]+$ ]]; then
		printf '%s' "$slug"
		return 0
	fi
	die "Unknown HWID or board name: '${raw}'"
}

resolve_board_list() {
	local text="" path="" input board
	local -A seen=()

	if [[ "$ALL" -eq 1 ]]; then
		KEEP_GOING=1
		path=$(ensure_meta_file "device-db.sh" "$device_db_url") || die "Could not load device-db.sh"
		log "Loading board list from ${path}"
		text=$(<"$path")
		mapfile -t BOARDS < <(boards_from_device_db_text "$text")
		[[ ${#BOARDS[@]} -gt 0 ]] || die "No boards found in device-db"
		return 0
	fi

	[[ ${#BOARD_INPUTS[@]} -gt 0 ]] || die "Specify one or more boards/HWIDs, or --all"
	load_device_db
	BOARDS=()
	for input in "${BOARD_INPUTS[@]}"; do
		board=$(resolve_token_to_board "$input")
		if [[ -n "${seen[$board]:-}" ]]; then
			continue
		fi
		seen[$board]=1
		BOARDS+=("$board")
	done
	[[ ${#BOARDS[@]} -gt 0 ]] || die "No boards resolved from arguments"
}

# Populate FILES as "hash|url"
load_catalog() {
	local base sums_url sums line hash file board want url
	FILES=()

	if [[ "$USE_LATEST" -eq 1 ]]; then
		[[ -z "$DATE" ]] || die "--date is only valid with a pinned <version>"
		resolve_board_list
		for board in "${BOARDS[@]}"; do
			url=$(latest_url_for_board "$board")
			FILES+=("|${url}")
			if [[ -n "$(board_hotfix_date "$board")" ]]; then
				log "  ${board}: hotfix $(board_hotfix_date "$board")"
			fi
		done
		return 0
	fi

	# Pinned version: optional SHA256SUMS, else build names (no hotfixes)
	base=$(cdn_version_dir "$VERSION")
	sums_url="${base}SHA256SUMS"

	if http_ok "$sums_url"; then
		log "Using catalog ${sums_url}"
		sums=$(fetch_text "$sums_url") || die "Failed to download SHA256SUMS"
		resolve_board_list
		while IFS= read -r line || [[ -n "$line" ]]; do
			[[ -z "$line" || "$line" =~ ^# ]] && continue
			if [[ "$line" =~ ^([0-9a-fA-F]{64})[[:space:]]+\*?([^[:space:]]+)$ ]]; then
				hash="${BASH_REMATCH[1]}"
				file="${BASH_REMATCH[2]}"
			else
				continue
			fi
			[[ "$file" == *.rom ]] || continue
			if [[ "$ALL" -eq 0 ]]; then
				want=0
				for board in "${BOARDS[@]}"; do
					case "$file" in
						coreboot_edk2-"${board}"-mrchromebox_*.rom) want=1; break ;;
					esac
				done
				[[ "$want" -eq 1 ]] || continue
			fi
			FILES+=("${hash}|${base}${file}")
		done <<<"$sums"
		[[ ${#FILES[@]} -gt 0 ]] || die "No matching entries in SHA256SUMS"
		return 0
	fi

	resolve_pinned_date
	resolve_board_list
	for board in "${BOARDS[@]}"; do
		file=$(rom_name "$board" "$DATE")
		FILES+=("|${base}${file}")
	done
}

download_one() {
	local hash="$1"
	local url="$2"
	local file dest tmp

	file=$(basename "$url")
	dest="${OUTDIR}/${file}"
	tmp="${dest}.partial"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		log "$url"
		return 0
	fi

	if [[ -f "$dest" && -n "$hash" ]] && have_cmd sha256sum; then
		if echo "${hash}  ${dest}" | sha256sum -c --status 2>/dev/null; then
			log "ok (cached): ${file}"
			return 0
		fi
	fi

	if ! curl -fsSL --connect-timeout 10 --max-time 600 \
		-o "$tmp" "$url"; then
		rm -f "$tmp"
		err "download failed: ${url}"
		return 1
	fi

	if [[ -n "$hash" ]] && have_cmd sha256sum; then
		if ! echo "${hash}  ${tmp}" | sha256sum -c --status 2>/dev/null; then
			rm -f "$tmp"
			err "checksum mismatch: ${file}"
			return 1
		fi
	fi

	mv -f "$tmp" "$dest"
	log "ok: ${file}"
	return 0
}

run_downloads() {
	local entry hash url fail=0 active=0
	local -a pids=()

	mkdir -p "$OUTDIR"

	if [[ ${#FILES[@]} -eq 1 || "$DRY_RUN" -eq 1 ]]; then
		JOBS=1
	fi

	for entry in "${FILES[@]}"; do
		hash="${entry%%|*}"
		url="${entry#*|}"

		if [[ "$JOBS" -eq 1 ]]; then
			if ! download_one "$hash" "$url"; then
				fail=$((fail + 1))
				[[ "$KEEP_GOING" -eq 1 ]] || return 1
			fi
			continue
		fi

		download_one "$hash" "$url" &
		pids+=("$!")
		active=$((active + 1))
		if [[ "$active" -ge "$JOBS" ]]; then
			if ! wait "${pids[0]}"; then
				fail=$((fail + 1))
				[[ "$KEEP_GOING" -eq 1 ]] || { wait || true; return 1; }
			fi
			pids=("${pids[@]:1}")
			active=$((active - 1))
		fi
	done

	if [[ ${#pids[@]} -gt 0 ]]; then
		for pid in "${pids[@]}"; do
			if ! wait "$pid"; then
				fail=$((fail + 1))
				[[ "$KEEP_GOING" -eq 1 ]] || return 1
			fi
		done
	fi

	if [[ "$fail" -gt 0 ]]; then
		err "${fail} download(s) failed (see messages above)"
		return 1
	fi
	return 0
}

main() {
	have_cmd curl || die "curl is required"

	parse_args "$@"
	[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || die "--jobs must be a positive integer"

	if [[ "$LIST_VERSIONS" -eq 1 ]]; then
		list_versions
		exit 0
	fi

	if [[ "$ALL" -eq 1 && ${#BOARD_INPUTS[@]} -gt 0 ]]; then
		die "use either --all or explicit board names, not both"
	fi
	if [[ "$ALL" -eq 0 && ${#BOARD_INPUTS[@]} -eq 0 ]]; then
		usage >&2
		echo >&2
		die "specify board name(s)/HWID(s) or --all"
	fi
	# Missing images are expected for some boards in a given release
	[[ "$ALL" -eq 1 ]] && KEEP_GOING=1

	load_sources || die "Could not load sources.sh"

	if [[ "$USE_LATEST" -eq 1 ]]; then
		VERSION="$RELEASE_CURRENT_VERSION"
	fi

	[[ -n "$OUTDIR" ]] || OUTDIR="./MrChromebox-${VERSION}"

	if [[ "$USE_LATEST" -eq 1 ]]; then
		log "Release: latest (MrChromebox-${RELEASE_CURRENT_VERSION} / FW_HOTFIX)"
	else
		log "Release: MrChromebox-${VERSION} (pinned)"
	fi
	[[ "$DRY_RUN" -eq 1 ]] || log "Output:  ${OUTDIR}"

	load_catalog
	log "Files:   ${#FILES[@]}"
	run_downloads
}

main "$@"
