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

#where the stuff is
script_url="https://raw.githubusercontent.com/MrChromebox/scripts/master/"
scriptdir="$(realpath "$(dirname "$0")")"

#ensure output of system tools in en-us for parsing
export LC_ALL=C

#set working dir
if grep -q "Chrom" /etc/lsb-release ; then
	# needed for ChromeOS/ChromiumOS v82+
	mkdir -p /usr/local/bin
	cd /usr/local/bin
else
	cd /tmp
fi

# clear screen / show banner
printf "\ec"
echo -e "\nMrChromebox Firmware Utility Script starting up"

if [ "$1" = '-n' ]; then
	# Emulate curl by copying files from the directory with the script, or log the URLs to download & fail.
	# Intended for no-network (=> no-OOBE on ChromeOS) and reproduction scenarios.
	# Logs the curl cmdlines to stdout (for script(1) use) and to ./curls;
	# this means that you can use a reusable medium on the chromebook and do
	#   mount /dev/sda /media
	#   bash /media/firmware-utl.sh -n
	#   umount /media
	# on the target machine, then `sh curls` on a trusted network-connected machine,
	# and repeat this twice to get all the artifacts for your system.
	curl() {
		{ printf '%q ' curl "$@"; echo; } | tee -a "$scriptdir/curls"
		OPTIND=1
		curl_file=
		while getopts sLOo: curl_flag; do
			case "$curl_flag" in
				[sLO])	;;
				o)	curl_file="$OPTARG" ;;
				*)	echo "unknown curl flag -$curl_flag" >&2; return 1 ;;
			esac
		done
		shift "$((OPTIND - 1))"
		[ -n "$curl_file" ] || curl_file="${1##*/}"
		[ -s "$scriptdir/$curl_file" ] && cp -v "$scriptdir/$curl_file" .
	}
	export CURL=curl

#check for cmd line param, expired CrOS certs
elif ! curl -sLo /dev/null https://mrchromebox.tech/index.html || [[ "$1" = "-k" ]]; then
	export CURL="curl -k"
else
	export CURL="curl"
fi

#get support scripts
echo -e "\nDownloading supporting files..."
rm -rf firmware.sh functions.sh sources.sh >/dev/null 2>&1
$CURL -sLO ${script_url}firmware.sh
rc0=$?
$CURL -sLO ${script_url}functions.sh
rc1=$?
$CURL -sLO ${script_url}sources.sh
rc2=$?
if [[ $rc0 -ne 0 || $rc1 -ne 0 || $rc2 -ne 0 ]]; then
	echo -e "Error downloading one or more required files; cannot continue"
	exit 1
fi

source ./sources.sh
source ./firmware.sh
source ./functions.sh

#set working dir
cd /tmp

#do setup stuff
prelim_setup || exit 1

#show menu
menu_fwupdate
