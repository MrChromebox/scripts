#!/bin/bash
#

# shellcheck disable=SC2164,SC2155

########################################
# Global Variables and Configuration  #
########################################

# USB device handling
export usb_devs=""
export usb_device_count=0

# System detection
export isChromeOS=true
isChromiumOS=false
isMusl=false

# Firmware tool paths
export flashromcmd=""
export flashrom_params=""
export flashrom_programmer="-p internal:boardmismatch=force"
export cbfstoolcmd=""
export gbbutilitycmd=""
export ectoolcmd=""
export tpmccmd=""

# Firmware state
export firmwareType=""
export isStock=true
export isFullRom=false
export isUEFI=false
export wpEnabled=false

# Terminal color codes for UI
NORMAL=$(echo "\033[m")
MENU=$(echo "\033[36m") #Blue
NUMBER=$(echo "\033[33m") #yellow
FGRED=$(echo "\033[41m")
RED_TEXT=$(echo "\033[31m")
GRAY_TEXT=$(echo "\033[1;30m")
GREEN_TEXT=$(echo "\033[1;32m")
ENTER_LINE=$(echo "\033[33m")

########################################
# Utility Functions                    #
########################################

# Print text in red color
function echo_red() {
	echo -e "\E[0;31m$1"
	echo -e '\e[0m'
}

# Print text in green color
function echo_green() {
	echo -e "\E[0;32m$1"
	echo -e '\e[0m'
}

# Print text in yellow color
function echo_yellow() {
	echo -e "\E[1;33m$1"
	echo -e '\e[0m'
}
# Print error message and wait for user input
function exit_red() {
	echo_red "$@"
	read -rep "Press [Enter] to return to the main menu."
}

# Print error message and exit script
function die() {
	echo_red "$@"
	exit 1
}

########################################
# Full ROM firmware resolution         #
########################################

function fullrom_build_file() {
	local dev="$1"
	local date="$2"

	[[ -n "$dev" && -n "$date" ]] || return 1
	echo "coreboot_edk2-${dev}-mrchromebox_${date}.rom"
}

# Sets _fullrom_slot_{date,folder,label,is_hotfix}
function fullrom_slot_info() {
	local slot="$1"
	local flat=false

	_fullrom_slot_date=""
	_fullrom_slot_folder=""
	_fullrom_slot_label=""
	_fullrom_slot_is_hotfix=false

	[[ "${fullrom_layout:-versioned}" = "flat" ]] && flat=true

	if [[ "$slot" = "latest" ]]; then
		if fullrom_has_hotfix; then
			_fullrom_slot_date="${FW_HOTFIX[$device]}"
			_fullrom_slot_folder=""
			_fullrom_slot_label=$(fullrom_format_display_date "${_fullrom_slot_date}")
			_fullrom_slot_is_hotfix=true
		else
			_fullrom_slot_date="${release_current_date}"
			[[ -n "$release_current_version" ]] || return 1
			if [[ "$flat" = true ]]; then
				_fullrom_slot_folder=""
			else
				_fullrom_slot_folder="MrChromebox-${release_current_version}"
			fi
			_fullrom_slot_label="MrChromebox-${release_current_version}"
		fi
	elif [[ "$slot" = "previous" ]]; then
		_fullrom_slot_date="${release_previous_date}"
		[[ -n "$release_previous_version" ]] || return 1
		if [[ "$flat" = true ]]; then
			_fullrom_slot_folder=""
		else
			_fullrom_slot_folder="MrChromebox-${release_previous_version}"
		fi
		_fullrom_slot_label="MrChromebox-${release_previous_version}"
	else
		return 1
	fi

	[[ -n "$_fullrom_slot_date" ]] || return 1
	if [[ "$flat" != true && "$_fullrom_slot_is_hotfix" != true ]]; then
		[[ -n "$_fullrom_slot_folder" ]] || return 1
	fi
	return 0
}

function fullrom_cdn_base_for_slot() {
	local slot="$1"

	fullrom_slot_info "$slot" || return 1
	if [[ "${fullrom_layout:-versioned}" = "flat" ]]; then
		echo "${fullrom_source}"
	elif [[ -n "$_fullrom_slot_folder" ]]; then
		echo "${fullrom_source}${_fullrom_slot_folder}/"
	else
		echo "${fullrom_source}"
	fi
}

function fullrom_http_available() {
	local url="$1"
	local curl_cmd="${CURL:-curl}"

	[[ -n "$url" ]] || return 1
	${curl_cmd} -sfI -L "${url}" 2>/dev/null | grep -qiE '^HTTP/[0-9.]+ 200'
}

function fullrom_firmware_available() {
	local slot="$1"
	local file=""
	local base=""
	local url=""

	file=$(fullrom_resolve_slot "$slot") || return 1
	base=$(fullrom_cdn_base_for_slot "$slot") || return 1
	url="${base}${file}"

	fullrom_http_available "$url" && return 0

	# Fall back to flat CDN root if versioned path is missing
	if [[ "${fullrom_layout:-versioned}" = "versioned" && "$base" != "${fullrom_source}" ]]; then
		fullrom_http_available "${fullrom_source}${file}"
	else
		return 1
	fi
}

function download_fullrom_release() {
	local slot="$1"
	local file=""
	local base=""

	file=$(fullrom_resolve_slot "$slot") || return 1
	base=$(fullrom_cdn_base_for_slot "$slot") || return 1

	fullrom_files=(
		"${file}"
		"${file}.sha1"
	)
	if download_files fullrom_files "${base}"; then
		return 0
	fi

	if [[ "${fullrom_layout:-versioned}" = "versioned" && "$base" != "${fullrom_source}" ]]; then
		download_files fullrom_files "${fullrom_source}" && return 0
	fi
	return 1
}

function fullrom_file_date() {
	local file="$1"
	echo "$file" | grep -o 'mrchromebox_[0-9]\{8\}' | cut -d_ -f2
}

function fullrom_format_display_date() {
	local ymd="$1"
	echo "${ymd:4:2}/${ymd:6:2}/${ymd:0:4}"
}

function fullrom_installed_yyyymmdd() {
	local mm dd yy
	[[ -n "$fwDate" ]] || return 1
	mm=$(echo "$fwDate" | cut -f1 -d'/')
	dd=$(echo "$fwDate" | cut -f2 -d'/')
	yy=$(echo "$fwDate" | cut -f3 -d'/')
	printf "%04d%02d%02d" "$((10#$yy))" "$((10#$mm))" "$((10#$dd))"
}

function fullrom_has_hotfix() {
	[[ -n "${FW_HOTFIX[$device]:-}" ]]
}

function fullrom_resolve_slot() {
	local slot="$1"

	fullrom_slot_info "$slot" || return 1
	fullrom_build_file "$device" "${_fullrom_slot_date}"
}

function fullrom_slot_label() {
	local slot="$1"

	fullrom_slot_info "$slot" || return 1
	echo "${_fullrom_slot_label}"
}

# e.g. MrChromebox-2603.2 (05/17/2026)
function fullrom_slot_detail() {
	local slot="$1"

	fullrom_slot_info "$slot" || return 1
	if [[ "$_fullrom_slot_is_hotfix" = true ]]; then
		echo "${_fullrom_slot_label}"
	else
		echo "${_fullrom_slot_label} ($(fullrom_format_display_date "${_fullrom_slot_date}"))"
	fi
}

function fullrom_date_newer_than_installed() {
	local target_ymd="$1"
	local installed_ymd

	[[ -n "$target_ymd" ]] || return 1
	[[ "$firmwareType" = *"pending"* ]] && return 1
	installed_ymd=$(fullrom_installed_yyyymmdd) || return 1
	[[ "$target_ymd" -gt "$installed_ymd" ]]
}

function fullrom_can_rollback() {
	local installed

	[[ -n "$release_previous_date" ]] || return 1
	if [[ "${fullrom_layout:-versioned}" != "flat" ]]; then
		[[ -n "$release_previous_version" ]] || return 1
	fi
	[[ -n "$device" ]] || return 1
	installed=$(fullrom_installed_yyyymmdd) || return 0
	[[ "$installed" != "$release_previous_date" ]]
}

########################################
# Session Logging                      #
########################################

: "${MRCBX_LOG:=/tmp/mrchromebox.log}"

# Initialize session log after supporting scripts are sourced
function session_log_init() {
	diagnostic_report_set log.path "$MRCBX_LOG"
	{
		echo "=== session_log_init: supporting scripts loaded ==="
		echo "script_date: ${script_date:-unknown}"
		echo
	} >> "$MRCBX_LOG" 2>/dev/null || true
}

# Write a section banner to the session log
function log_section() {
	[[ -n "$MRCBX_LOG" ]] || return 0
	{
		echo "=== $* ==="
	} >> "$MRCBX_LOG" 2>/dev/null || true
}

# Log function entry (call as first line of action functions)
function log_fn() {
	[[ -n "$MRCBX_LOG" ]] || return 0
	{
		echo ">> ${FUNCNAME[1]}"
	} >> "$MRCBX_LOG" 2>/dev/null || true
}

# Append a captured command transcript to the session log
function _log_command() {
	local rc="$1" cmd="$2" output_file="$3"
	[[ -n "$MRCBX_LOG" ]] || return 0
	{
		echo "=== ${cmd} ==="
		if [[ -n "$output_file" && -f "$output_file" ]]; then
			cat "$output_file"
		fi
		echo "=== exit ${rc} ==="
		echo
	} >> "$MRCBX_LOG" 2>/dev/null || true
}

# Run a command quietly on the terminal, capturing output in the session log
function run_quiet() {
	local rc=0
	local cmd_output
	cmd_output=$(mktemp /tmp/mrcbx-cmd.XXXXXX) || cmd_output=""

	if [[ -n "$cmd_output" ]]; then
		"$@" > "$cmd_output" 2>&1
		rc=$?
	else
		"$@" >/dev/null 2>&1
		rc=$?
	fi

	_log_command "$rc" "$*" "$cmd_output"
	rm -f "$cmd_output"
	return "$rc"
}

# Run flashrom, capturing output in the session log and /tmp/flashrom.log
function run_flashrom() {
	local rc=0
	rm -f /tmp/flashrom.log
	# Match legacy ${flashromcmd} ... > /tmp/flashrom.log word-splitting
	# shellcheck disable=SC2086
	$* > /tmp/flashrom.log 2>&1
	rc=$?
	_log_command "$rc" "$*" /tmp/flashrom.log
	return "$rc"
}

# Run a command, log output, and return output for capture
function run_capture() {
	local output rc=0
	output=$("$@" 2>&1) || rc=$?
	{
		echo "=== $* ==="
		echo "$output"
		echo "=== exit ${rc} ==="
		echo
	} >> "$MRCBX_LOG" 2>/dev/null || true
	echo "$output"
	return "$rc"
}

########################################
# Device Detection Functions           #
########################################

# List all available USB devices with vendor/model info
function list_usb_devices() {
	# Enumerate USB-backed block devices via lsblk TRAN field
	lsblk -dnpo NAME,TRAN 2>/dev/null | awk '$2=="usb"{print $1}' > /tmp/usb_block_devices
	# Fallback: none -> try sysfs heuristic (older systems without TRAN)
	if [ ! -s /tmp/usb_block_devices ]; then
		stat -c %N /sys/block/sd* 2>/dev/null | grep usb | cut -f1 -d ' ' \
			| sed "s/[']//g;s|/sys/block|/dev|" > /tmp/usb_block_devices
	fi
	mapfile -t usb_devs < /tmp/usb_block_devices
	[ ${#usb_devs[@]} -gt 0 ] || return 1
	
	echo -e "\nDevices available:\n"
	usb_device_count=0
	for dev in "${usb_devs[@]}"
	do
		((usb_device_count+=1))
	# Resolve base device name for sysfs
	dev_base=$(basename "${dev}")
	# Read vendor/model from sysfs (most reliable)
	vendor=$(sed 's/^ *//;s/ *$//' "/sys/block/${dev_base}/device/vendor" 2>/dev/null)
	model=$(sed 's/^ *//;s/ *$//' "/sys/block/${dev_base}/device/model" 2>/dev/null)
	# Fallbacks for vendor/model
	if [ -z "${vendor}" ] || [ -z "${model}" ]; then
		# Try lsblk fields
		[ -z "${vendor}" ] && vendor=$(lsblk -dno VENDOR "${dev}" 2>/dev/null)
		[ -z "${model}" ] && model=$(lsblk -dno MODEL "${dev}" 2>/dev/null)
		# Try udevadm properties as last resort
		if [ -z "${vendor}" ] || [ -z "${model}" ]; then
			dev_info=$(udevadm info --query=property --name="${dev}" 2>/dev/null)
			[ -z "${vendor}" ] && vendor=$(echo "$dev_info" | grep "^ID_VENDOR=" | cut -d'=' -f2)
			[ -z "${model}" ] && model=$(echo "$dev_info" | grep "^ID_MODEL=" | cut -d'=' -f2)
		fi
	fi
	# Normalize whitespace: trim ends and squeeze internal spaces
	vendor=$(echo -n "${vendor}" | sed 's/^\s\+//;s/\s\+$//' | tr -s ' ')
	model=$(echo -n "${model}" | sed 's/^\s\+//;s/\s\+$//' | tr -s ' ')
	# Determine size (bytes -> human GB with 1 decimal)
	bytes=$(lsblk -dnbo SIZE "${dev}" 2>/dev/null)
	if [ -z "${bytes}" ]; then
		sectors=$(cat "/sys/block/${dev_base}/size" 2>/dev/null)
		if [ -n "${sectors}" ]; then
			bytes=$((sectors * 512))
		fi
	fi
	if [ -n "${bytes}" ] && [ "${bytes}" -gt 0 ] 2>/dev/null; then
		# Use awk for floating point division
		sz=$(awk -v b="${bytes}" 'BEGIN { printf "%.1f GB", b/1024/1024/1024 }')
	else
		sz=""
	fi
		label=""
		[ -n "${vendor}" ] && label="${vendor}"
		if [ -n "${model}" ]; then
			if [ -n "${label}" ]; then
				label="${label} ${model}"
			else
				label="${model}"
			fi
		fi
		echo -n "$usb_device_count)"
		[ -n "${label}" ] && echo -n " ${label}"
		[ -n "${sz}" ] && echo -e " (${sz})" || echo -e ""
	done
	echo -e ""
}

########################################
# Tool Management Functions            #
########################################

# Download and setup cbfstool utility if not present
function get_cbfstool() {
	if [ ! -f "${cbfstoolcmd}" ]; then
		(
			cd "$(dirname "${cbfstoolcmd}")"
			#echo_yellow "Downloading cbfstool utility"
			util_file=""
			if [[ "$isMusl" = true ]]; then
				util_file="cbfstool-musl.tar.gz"
			else
				util_file="cbfstool.tar.gz"
			fi
			if ! ${CURL} -sLo "cbfstool.tar.gz" "${util_source}${util_file}"; then
				echo_red "Error downloading cbfstool; cannot proceed."
				return 1
			fi
			if ! tar -zxf cbfstool.tar.gz --no-same-owner; then
				echo_red "Error extracting cbfstool; cannot proceed."
				return 1
			fi
			#set +x
			chmod +x cbfstool
		) || return 1
	fi
}

# Download and setup flashrom utility if not present
function get_flashrom() {
	if [ ! -f "${flashromcmd}" ]; then
		(
			cd "$(dirname "${flashromcmd}")"
			util_file=""
			if [[ "$isChromeOS" = true ]]; then
				#needed to avoid dependencies not found on older ChromeOS
				util_file="flashrom_old.tar.gz"
			else
				if [[ "$isMusl" = true ]]; then
					util_file="flashrom-musl.tar.gz"
				else
					util_file="flashrom_ups_int_20241214.tar.gz"
				fi
			fi
			if ! ${CURL} -sLo "flashrom.tar.gz" "${util_source}${util_file}"; then
				echo_red "Error downloading flashrom; cannot proceed."
				return 1
			fi
			if ! tar -zxf flashrom.tar.gz --no-same-owner; then
				echo_red "Error extracting flashrom; cannot proceed."
				return 1
			fi
			#set +x
			chmod +x flashrom
		) || return 1
	fi
	#check if flashrom supports --noverify-all
	if ${flashromcmd} -h | grep -q "noverify-all" ; then
		export noverify="-N"
	else
		export noverify="-n"
	fi
	# append programmer type
	[[ "$isChromeOS" = false ]] && flashrom_programmer="${flashrom_programmer} --use-first-chip"
	flashromcmd="${flashromcmd} ${flashrom_programmer}"

}

# Download and setup gbb_utility if not present
function get_gbb_utility() {
	if [ ! -f "${gbbutilitycmd}" ]; then
		(
			cd "$(dirname "${gbbutilitycmd}")"
			util_file=""
			if [[ "$isMusl" = true ]]; then
				util_file="gbb_utility-musl.tar.gz"
			else
			util_file="gbb_utility.tar.gz"
			fi
			if ! ${CURL} -sLo "gbb_utility.tar.gz" "${util_source}${util_file}"; then
				echo_red "Error downloading gbb_utility; cannot proceed."
				return 1
			fi
			if ! tar -zxf gbb_utility.tar.gz --no-same-owner; then
				echo_red "Error extracting gbb_utility; cannot proceed."
				return 1
			fi
			#set +x
			chmod +x gbb_utility
		) || return 1
	fi
}

# Download and setup ectool utility if not present
function get_ectool() {
	# Regardless if running under ChromeOS or Linux, can put ectool
	# in same place as cbfstool
	ectoolcmd="$(dirname "${cbfstoolcmd}")/ectool"
	if [ ! -f "${ectoolcmd}" ]; then
		(
			cd "$(dirname "${ectoolcmd}")"
			if ! ${CURL} -sLO "${util_source}ectool.tar.gz"; then
				echo_red "Error downloading ectool; cannot proceed."
				return 1
			fi
			if ! tar -zxf ectool.tar.gz --no-same-owner; then
				echo_red "Error extracting ectool; cannot proceed."
				return 1
			fi
			#set +x
			chmod +x ectool
		) || return 1
	fi
	return 0
}

# Download and setup tpmc utility if not present
function get_tpmc() {
	# Regardless if running under ChromeOS or Linux, can put tpmc
	# in same place as cbfstool
	tpmccmd="$(dirname "${cbfstoolcmd}")/tpmc"
	if [ ! -f "${tpmccmd}" ]; then
		(
			cd "$(dirname "${tpmccmd}")"
			if ! ${CURL} -sLO "${util_source}tpmc.tar.gz"; then
				echo_red "Error downloading tpmc; cannot proceed."
				return 1
			fi
			if ! tar -zxf tpmc.tar.gz --no-same-owner; then
				echo_red "Error extracting tpmc; cannot proceed."
				return 1
			fi
			#set +x
			chmod +x tpmc
		) || return 1
	fi
	return 0
}

########################################
# Diagnostic Report Functions          #
########################################

# Save diagnostic report for troubleshooting
# Save diagnostic report to temporary file
function diagnostic_report_save() {
	(
		echo "mrchromebox firmware-util diagnostic report"
		date
		echo
		for key in "${!diagnostic_report_data[@]}"; do
		echo "[$key]"
		echo "${diagnostic_report_data[$key]}"
		echo
		done
	) > /tmp/mrchromebox_diag.txt
}

# Set diagnostic report data for given key
function diagnostic_report_set() {
	declare -gA diagnostic_report_data
	local key="$1"
	shift
	diagnostic_report_data[$key]="$*"
}

########################################
# Main Setup and Initialization        #
########################################

# Perform preliminary setup and validation
function prelim_setup()
{
	log_fn
	# Must run as root
	[ "$(whoami)" = "root" ] || die "You need to run this script with sudo; use 'sudo bash <script name>'"
	
	# Can't run from a VM/container
	[[ "$(cat /etc/hostname 2>/dev/null)" = "penguin" ]] && die "This script cannot be run from a ChromeOS Linux container;
you must use a VT2 terminal as directed per https://mrchromebox.tech/#fwscript"
	
	#must be x86_64
	[ "$(uname -m)"  = 'x86_64' ] \
		|| die "This script only supports 64-bit OS on x86_64-based devices; ARM devices are not supported."
	
	#check for required tools
	if ! command -v which > /dev/null 2>&1; then
		echo_red "Required package 'which' not found; cannot continue.  Please install and try again."
		return 1
	fi
	if ! which dmidecode > /dev/null 2>&1; then
		echo_red "Required package 'dmidecode' not found; cannot continue.  Please install and try again."
		return 1
	fi
	if ! which tar > /dev/null 2>&1; then
		echo_red "Required package 'tar' not found; cannot continue.  Please install and try again."
		return 1
	fi
	if ! which md5sum > /dev/null 2>&1; then	
		echo_red "Required package 'md5sum' not found; cannot continue.  Please install and try again."
		return 1
	fi
	if ! which sha1sum > /dev/null 2>&1; then
		echo_red "Required package 'sha1sum' not found; cannot continue.  Please install and try again."
		return 1
	fi
	
	#get device name
	device=$(dmidecode -s system-product-name | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g' | awk 'NR==1{print $1}')
	diagnostic_report_set dmidecode.device "$device"
	if [[ $? -ne 0 || "${device}" = "" ]]; then
		echo_red "Unable to determine Chromebox/book model; cannot continue."
		echo_red "It's likely you are using an unsupported ARM-based ChromeOS device,
only x86_64-based devices are supported at this time."
		echo_red "Please note that WSL (Windows Subsystem for Linux) is not supported and NEVER will.
Run this from a Linux Live USB instead."
		return 1
	fi

	#start with a known good state
	cleanup

	#check if running under ChromeOS / ChromiumOS
	if [ -f /etc/lsb-release ]; then
		diagnostic_report_set lsb-release "$(cat /etc/lsb-release)"
		if ! grep -q "Chrome OS" /etc/lsb-release; then
			isChromeOS=false
		fi
		if grep -q "Chromium OS" /etc/lsb-release; then
			isChromiumOS=true
		fi
	else
		isChromeOS=false
		isChromiumOS=false
	fi

	if [[ "$isChromeOS" = true || "$isChromiumOS" = true ]]; then
		#disable power mgmt
		run_quiet initctl stop powerd
		# try to mount p12 as /tmp/boot
		rootdev=$(rootdev -d -s)
		# Determine partition prefix based on device type
		if [[ "${rootdev}" =~ (mmcblk|nvme) ]]; then
			part_pfx="p"
		else
			part_pfx=""
		fi
		part_num="${part_pfx}12"
		export boot_mounted=false
		if mount | grep -q "${rootdev}""${part_num}"; then
			boot_mounted=true
		else
			#mount boot
			run_quiet mkdir /tmp/boot
			run_quiet mount "$(rootdev -d -s)""${part_num}" /tmp/boot && boot_mounted=true
		fi
		#set cmds
		#check if we need to use a newer flashrom which supports output to log file (-o)
		flashromcmd=$(which flashrom)
		if ! ${flashromcmd} -V -o /dev/null > /dev/null 2>&1 || [[ -d /sys/firmware/efi ]]; then
			flashromcmd=/usr/local/bin/flashrom
		fi
		cbfstoolcmd=/usr/local/bin/cbfstool
		gbbutilitycmd=$(which gbb_utility)
	else
		#set cmds
		flashromcmd=/tmp/flashrom
		cbfstoolcmd=/tmp/cbfstool
		gbbutilitycmd=/tmp/gbb_utility
	fi

	#check if running on a musl system
	ldd /bin/sh 2>/dev/null | grep -q musl && isMusl=true

	#get required tools
	echo -e "\nDownloading required tools..."
	if ! get_cbfstool; then
		echo_red "Unable to download cbfstool utility; cannot continue"
		return 1
	fi
	if ! get_gbb_utility; then
		echo_red "Unable to download gbb_utility utility; cannot continue"
		return 1
	fi
	if ! get_flashrom; then
		echo_red "Unable to download flashrom utility; cannot continue"
		return 1
	fi

	# unload Intel SPI driver if loaded, causes issues with flashrom
	run_quiet rmmod spi_intel_platform

	#get device firmware info
	echo -e "\nGetting device/system info..."
	flashrom_params=""
	flashrom_rc=1
	flashrom_has_ifd=false
	isIntel=false
	grep -q -i Intel /proc/cpuinfo && isIntel=true
	${flashromcmd} -h 2>&1 | grep -q -- '--ifd' && flashrom_has_ifd=true

	# Intel: prefer IFD BIOS-region access (FD/ME are typically host-locked).
	# Bundled Linux flashrom always supports --ifd; older ChromeOS flashrom may not.
	if [[ "$isIntel" = true && "$flashrom_has_ifd" = true ]]; then
		${flashromcmd} --ifd -i bios -r /tmp/bios.bin > /tmp/flashrom.log 2>&1
		flashrom_rc=$?
		_log_command "$flashrom_rc" "${flashromcmd} --ifd -i bios -r /tmp/bios.bin" /tmp/flashrom.log
		[[ "$flashrom_rc" -eq 0 ]] && flashrom_params="--ifd -i bios"
	fi
	# Full-chip read: non-Intel, or ChromeOS when IFD is unavailable/failed.
	# Non-ChromeOS Intel must succeed via IFD (no full-chip fallback).
	if [[ "$flashrom_rc" -ne 0 ]] && { [[ "$isIntel" != true ]] || [[ "$isChromeOS" = true || "$isChromiumOS" = true ]]; }; then
		${flashromcmd} -r /tmp/bios.bin > /tmp/flashrom.log 2>&1
		flashrom_rc=$?
		_log_command "$flashrom_rc" "${flashromcmd} -r /tmp/bios.bin" /tmp/flashrom.log
	fi
	
	if [[ "$flashrom_rc" -ne 0 ]]; then
		echo_red "\nFlashrom is unable to read current firmware; cannot continue:"
		if [ -f /tmp/flashrom.log ]; then
			cat /tmp/flashrom.log
			echo ""
		fi
		if [[ -n "$MRCBX_LOG" ]]; then
			echo_red "Session log: ${MRCBX_LOG}"
		fi
		echo_red "You may need to add 'iomem=relaxed' to your kernel parameters,
or trying running from a Live USB with a more permissive kernel (eg, Ubuntu 23.04+)."
		echo_red "If you have UEFI SecureBoot enabled, you need to disable it to run 
the script/update your firmware."
		return 1;
	fi

	# Sanity-check the read image has a usable CBFS/FMAP
	# Default region is COREBOOT; older Chromebooks use BOOT_STUB instead
	${cbfstoolcmd} /tmp/bios.bin print > /tmp/cbfs-print.log 2>&1
	cbfs_rc=$?
	_log_command "$cbfs_rc" "${cbfstoolcmd} /tmp/bios.bin print" /tmp/cbfs-print.log
	if [[ "$cbfs_rc" -ne 0 ]]; then
		${cbfstoolcmd} /tmp/bios.bin print -r BOOT_STUB > /tmp/cbfs-print.log 2>&1
		cbfs_rc=$?
		_log_command "$cbfs_rc" "${cbfstoolcmd} /tmp/bios.bin print -r BOOT_STUB" /tmp/cbfs-print.log
	fi
	if [[ "$cbfs_rc" -ne 0 ]]; then
		echo_red "\nFirmware read succeeded but the image is not a valid CBFS/FMAP; cannot continue:"
		if [ -f /tmp/cbfs-print.log ]; then
			cat /tmp/cbfs-print.log
			echo ""
		fi
		if [[ -n "$MRCBX_LOG" ]]; then
			echo_red "Session log: ${MRCBX_LOG}"
		fi
		echo_red "The SPI flash contents could not be read correctly.
You may need to add 'iomem=relaxed' to your kernel parameters,
or try running from a Live USB with a more permissive kernel (eg, Ubuntu 23.04+)."
		return 1
	fi

	# FMAP layout used for region checks / flashrom -i fallbacks
	${cbfstoolcmd} /tmp/bios.bin layout -w > /tmp/layout 2>/dev/null
	# If IFD unavailable, restrict writes to SI_BIOS (maps to IFD BIOS region)
	if [[ -z "$flashrom_params" ]] && grep -q "'SI_BIOS'" /tmp/layout 2>/dev/null; then
		flashrom_params="-i SI_BIOS"
	fi
	diagnostic_report_set flashrom_params "${flashrom_params:-"(none)"}"
	
	# firmware date/version
	fwVer=$(dmidecode -s bios-version)
	fwVer="${fwVer#"${fwVer%%[![:space:]]*}"}"  # Remove leading whitespace
	fwVer="${fwVer%"${fwVer##*[![:space:]]}"}"  # Remove trailing whitespace
	fwVendor=$(dmidecode -s bios-vendor)
	# Workaround for ChromeOS devices booting Linux via RWL showing no BIOS version
	[[ -z "$fwVer" && "$fwVendor" = "coreboot" ]] && fwVer="Google_Unknown"
	fwDate=$(dmidecode -s bios-release-date)
	diagnostic_report_set fwVer "$fwVer"
	diagnostic_report_set fwDate "$fwDate"

	# check firmware type
	if [[ "$fwVer" = "Google_"* ]]; then
		# stock firmware
		isStock=true
		firmwareType="Stock ChromeOS"
		# check BOOT_STUB
		if grep -q "'BOOT_STUB'" /tmp/layout 2>/dev/null; then
			if ! ${cbfstoolcmd} /tmp/bios.bin print -r BOOT_STUB 2>/dev/null | grep -e "vboot" >/dev/null 2>&1 ; then
				[[ "${device^^}" != "LINK" ]] && firmwareType="Stock w/modified BOOT_STUB"
			fi
		fi
		# check RW_LEGACY
		if ${cbfstoolcmd} /tmp/bios.bin print -r RW_LEGACY 2>/dev/null | grep -e "payload" -e "altfw" >/dev/null 2>&1 ; then
			firmwareType="Stock ChromeOS w/RW_LEGACY"
		fi
	else
		# non-stock firmware
		isStock=false
		isFullRom=true
		if [[ -d /sys/firmware/efi ]]; then
			isUEFI=true
			firmwareType="Full ROM / UEFI"
		else
			firmwareType="Full ROM / Legacy"
		fi
	fi

	diagnostic_report_set firmwareType "$firmwareType"

	#check WP status
	echo -e "\nChecking WP state..."
	#save SW WP state
	wp_status_out=$(run_capture ${flashromcmd} --wp-status)
	if echo "$wp_status_out" | grep -qiE 'enabled|protection mode: hardware'; then
		swWp="enabled"
	else
		swWp="disabled"
	fi
	#test disabling SW WP to see if HW WP enabled
	run_quiet ${flashromcmd} --wp-disable
	[[ $? -ne 0 && $swWp = "enabled" ]] && wpEnabled=true
	#restore previous SW WP state
	[[ ${swWp} = "enabled" ]] && run_quiet ${flashromcmd} --wp-enable
	diagnostic_report_set wpEnabled "$wpEnabled"
	diagnostic_report_set swWp "$swWp"

	# disable SW WP and reboot if needed
	if [[ "$isChromeOS" = true &&  "${wpEnabled}" != "true" &&  "${swWp}" = "enabled" ]]; then
		# prompt user to disable swWP and reboot
		echo_yellow "\nWARNING: your device currently has software write-protect enabled.\n
If you plan to flash the UEFI firmware, you must first disable it and reboot before flashing.
Would you like to disable sofware WP and reboot your device?"
		read -rep "Press Y (then enter) to disable software WP and reboot, or just press enter to skip and continue. "
		# Validate user input
		if [[ "$REPLY" =~ ^[Yy]$ ]]; then
			echo -e "\nDisabling software WP..."
			if ! run_quiet ${flashromcmd} --wp-disable; then
				exit_red "\nError disabling software write-protect -- hardware WP is still enabled."
				return 1
			fi
			echo -e "\nClearing the WP range(s)..."
			if ! run_quiet ${flashromcmd} --wp-range 0 0; then
				# use new command format as of commit 99b9550
				if ! run_quiet ${flashromcmd} --wp-range 0,0; then
					#re-run to output error
					${flashromcmd} --wp-range 0,0
					exit_red "\nError clearing software write-protect range."
					return 1
				fi
			fi
			echo_green "\nSoftware WP disabled, rebooting in 5s"
			reboot
			# ensure we don't show the main menu while the system processes the reboot signal
			die
		fi
	fi
	
	# Get/set HWID, boardname, device
	if echo "$firmwareType" | grep -q -e "Stock"; then
		if [[ "$isChromeOS" = true && ! -d /sys/firmware/efi ]]; then
			# Stock ChromeOS
			_hwid=$(crossystem hwid)
		else
			# Stock + RW_LEGACY: read HWID from GBB
			_hwid=$($gbbutilitycmd --get --hwid /tmp/bios.bin | sed -E 's/hardware_id: //g')
		fi
		_hwid=$(echo "$_hwid" | sed -E 's/X86//g' | sed -E 's/ *$//g')
		boardName=$(echo "${_hwid^^}" | cut -f1 -d '-' | cut -f1 -d ' ')
		device=${boardName,,}
	else
		_hwid=${device^^}
		boardName=${device^^}
	fi

	diagnostic_report_set _hwid "$_hwid"
	diagnostic_report_set boardName "$boardName"

	# get device info from database
	if get_device_info "$_hwid"; then
		deviceCpuType=$(get_cpu_type "$_hwid")
		deviceCpuTypeName=$(get_cpu_type_name "$deviceCpuType")
		deviceDesc=$(get_device_description "$_hwid")
		deviceOverride=$(get_device_override "$_hwid")
		if [[ -n "$deviceOverride" ]]; then
			device="$deviceOverride"
		fi
	else
		deviceCpuType="UNK"
		deviceCpuTypeName="(unrecognized)"
		deviceDesc="Unrecognized Device"
		isUnsupported=true
		hasUEFIoption=false
	fi
		
	diagnostic_report_set device "$device"
	diagnostic_report_set device.override "$deviceOverride"
	diagnostic_report_set deviceDesc "$deviceDesc"
	diagnostic_report_set deviceCpuType.id "$deviceCpuType"
	diagnostic_report_set deviceCpuType.Name "$deviceCpuTypeName"
	diagnostic_report_set hasUEFIoption "$hasUEFIoption"
	diagnostic_report_set isUnsupported "$isUnsupported"
}

########################################
# Cleanup Function                     #
########################################

# Clean up temporary files and mounts
function cleanup()
{
	# unmount p12 if mounted
	run_quiet umount /tmp/boot
}
