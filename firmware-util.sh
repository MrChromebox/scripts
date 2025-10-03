#!/bin/bash
#
# This script offers provides the ability to update the
# Legacy Boot payload, set boot options, and install
# a custom coreboot firmware for supported
# ChromeOS devices
#
# Created by Mr.Chromebox <mrchromebox@gmail.com>
#
# May be freely distributed and modified as needed,
# as long as proper attribution is given.
#

# shellcheck disable=SC2164

#path to directory where script is saved
script_dir="$(dirname "$(readlink -f "$0")")"

#where the stuff is
script_url="https://raw.githubusercontent.com/MrChromebox/scripts/main/"

#ensure output of system tools in en-us for parsing
export LC_ALL=C

#set working dir
if grep -q "Chrom" /etc/lsb-release; then
	# needed for ChromeOS/ChromiumOS v82+
	mkdir -p /usr/local/bin && cd /usr/local/bin
else
	mkdir -p /tmp && cd /tmp
fi

# clear screen / show banner
printf "\ec"
echo -e "\nMrChromebox Firmware Utility Script starting up"
#check for cmd line param, expired CrOS certs
if ! curl -sLo /dev/null https://mrchromebox.tech/index.html || [[ "$1" = "-k" ]]; then
	export CURL="curl -k"
else
	export CURL="curl"
fi

if [ ! -d "$script_dir/.git" ]; then
	script_dir="."

	# Array of required files to download
	required_files=(
		"device-db.sh"
		"device-db-functions.sh"
		"firmware.sh"
		"functions.sh"
		"sources.sh"
	)

	#get support scripts
	echo -e "\nDownloading supporting files..."

	for file in "${required_files[@]}"; do
		rm -rf "${file}" >/dev/null 2>&1
		if ! $CURL -sLO "${script_url}${file}"; then
			echo -e "\nError downloading $file; cannot continue"
			exit 1
		fi
	done

fi

source "$script_dir/device-db.sh"
source "$script_dir/device-db-functions.sh"
source "$script_dir/sources.sh"
source "$script_dir/firmware.sh"
source "$script_dir/functions.sh"

#set working dir
cd /tmp

#do setup stuff
prelim_setup
prelim_setup_result="$?"

#saving setup state for troubleshooting
diagnostic_report_save
troubleshooting_msg=(
	" * diagnosics report has been saved to /tmp/mrchromebox_diag.txt"
	" * go to https://forum.chrultrabook.com/ for help"
)
if [ "$prelim_setup_result" -ne 0 ]; then
	IFS=$'\n'
	echo "MrChromebox Firmware Utility setup was unsuccessful" >/dev/stderr
	echo "${troubleshooting_msg[*]}" >/dev/stderr
	exit 1
fi

#show menu

trap 'check_unsupported' EXIT
function check_unsupported() {
	if [ "$isUnsupported" = true ]; then
		IFS=$'\n'
		echo "MrChromebox Firmware Utility didn't recognize your device" >/dev/stderr
		echo "${troubleshooting_msg[*]}" >/dev/stderr
	fi
}

menu_fwupdate
