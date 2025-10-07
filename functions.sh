#!/bin/bash
#

# shellcheck disable=SC2164,SC2155

#misc globals
export usb_devs=""
export num_usb_devs=0

export isChromeOS=true
isChromiumOS=false
export flashromcmd=""
export flashrom_params=""
export flashrom_programmer="-p internal:boardmismatch=force"
export cbfstoolcmd=""
export gbbutilitycmd=""
export ectoolcmd=""

export firmwareType=""
export isStock=true
export isFullRom=false
export isUEFI=false
export wpEnabled=false

isMusl=false

#menu text output
NORMAL=$(echo "\033[m")
MENU=$(echo "\033[36m") #Blue
NUMBER=$(echo "\033[33m") #yellow
FGRED=$(echo "\033[41m")
RED_TEXT=$(echo "\033[31m")
GRAY_TEXT=$(echo "\033[1;30m")
GREEN_TEXT=$(echo "\033[1;32m")
ENTER_LINE=$(echo "\033[33m")

function echo_red()
{
	echo -e "\E[0;31m$1"
	echo -e '\e[0m'
}

function echo_green()
{
	echo -e "\E[0;32m$1"
	echo -e '\e[0m'
}

function echo_yellow()
{
	echo -e "\E[1;33m$1"
	echo -e '\e[0m'
}
function exit_red()
{
	echo_red "$@"
	read -rep "Press [Enter] to return to the main menu."
}

function die()
{
	echo_red "$@"
	exit 1
}

####################
# list USB devices #
####################
function list_usb_devices()
{
	stat -c %N /sys/block/sd* 2>/dev/null | grep usb | cut -f1 -d ' ' \
		| sed "s/[']//g;s|/sys/block|/dev|" > /tmp/usb_block_devices
	eval usb_devs="($(cat  /tmp/usb_block_devices))"
	[ "$usb_devs" != "" ] || return 1
	
	echo -e "\nDevices available:\n"
	num_usb_devs=0
	for dev in "${usb_devs[@]}"
	do
		((num_usb_devs+=1))
		vendor=$(udevadm info --query=all --name=${dev#"/dev/"} | grep -E "ID_VENDOR=" | awk -F"=" '{print 
		$2}')
		model=$(udevadm info --query=all --name=${dev#"/dev/"} | grep -E "ID_MODEL=" | awk -F"=" '{print $2}')
		sz=$(fdisk -l 2> /dev/null | grep "Disk ${dev}" | awk '{print $3}')
		echo -n "$num_usb_devs)"
		if [ -n "${vendor}" ]; then
			echo -n " ${vendor}"
		fi
		if [ -n "${model}" ]; then
			echo -n " ${model}"
		fi
		echo -e " (${sz} GB)"
	done
	echo -e ""
}

################
# Get cbfstool #
################
function get_cbfstool()
{
	if [ ! -f "${cbfstoolcmd}" ]; then
		working_dir=$(pwd)
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
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		if ! tar -zxf cbfstool.tar.gz --no-same-owner; then
			echo_red "Error extracting cbfstool; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		#set +x
		chmod +x cbfstool
		#restore working dir
		cd "${working_dir}"
	fi
}

################
# Get flashrom #
################
function get_flashrom()
{
	if [ ! -f "${flashromcmd}" ]; then
		working_dir=$(pwd)
		cd "$(dirname "${flashromcmd}")"
		util_file=""
		if [[ "$isChromeOS" = true ]]; then
			#needed to avoid dependencies not found on older ChromeOS
			util_file="flashrom_old.tar.gz"
		else
			flashrom_programmer="${flashrom_programmer} --use-first-chip"
			if [[ "$isMusl" = true ]]; then
				util_file="flashrom-musl.tar.gz"
			else
				util_file="flashrom_ups_int_20241214.tar.gz"
			fi
		fi
		if ! ${CURL} -sLo "flashrom.tar.gz" "${util_source}${util_file}"; then
			echo_red "Error downloading flashrom; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		if ! tar -zxf flashrom.tar.gz --no-same-owner; then
			echo_red "Error extracting flashrom; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		#set +x
		chmod +x flashrom
		#restore working dir
		cd "${working_dir}"
	fi
	#check if flashrom supports --noverify-all
	if ${flashromcmd} -h | grep -q "noverify-all" ; then
		export noverify="-N"
	else
		export noverify="-n"
	fi
	# append programmer type
	flashromcmd="${flashromcmd} ${flashrom_programmer}"

}

###################
# Get gbb_utility #
###################
function get_gbb_utility()
{
	if [ ! -f "${gbbutilitycmd}" ]; then
		working_dir=$(pwd)
		cd "$(dirname "${gbbutilitycmd}")"
		util_file=""
		if [[ "$isMusl" = true ]]; then
			util_file="gbb_utility-musl.tar.gz"
		else
		util_file="gbb_utility.tar.gz"
		fi
		if ! ${CURL} -sLo "gbb_utility.tar.gz" "${util_source}${util_file}"; then
			echo_red "Error downloading gbb_utility; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		if ! tar -zxf gbb_utility.tar.gz; then
			echo_red "Error extracting gbb_utility; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		#set +x
		chmod +x gbb_utility
		#restore working dir
		cd "${working_dir}"
	fi
}

##############
# Get ectool #
##############
function get_ectool()
{
	# Regardless if running under ChromeOS or Linux, can put ectool
	# in same place as cbfstool
	ectoolcmd="$(dirname "${cbfstoolcmd}")/ectool"
	if [ ! -f "${ectoolcmd}" ]; then
		working_dir=$(pwd)
		cd "$(dirname "${ectoolcmd}")"
		if ! ${CURL} -sLO "${util_source}ectool.tar.gz"; then
			echo_red "Error downloading ectool; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		if ! tar -zxf ectool.tar.gz; then
			echo_red "Error extracting ectool; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		#set +x
		chmod +x ectool
		#restore working dir
		cd "${working_dir}"
	fi
	return 0
}

##################################################
# Diagnostic report for troubleshooting purposes #
##################################################
function diagnostic_report_save()
{
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

function diagnostic_report_set() {
	declare -gA diagnostic_report_data
	local key="$1"
	shift
	diagnostic_report_data[$key]="$*"
}

################
# Prelim Setup #
################
function prelim_setup()
{
	# Must run as root
	[ "$(whoami)" = "root" ] || die "You need to run this script with sudo; use 'sudo bash <script name>'"
	
	# Can't run from a VM/container
	[[ "$(cat /etc/hostname 2>/dev/null)" = "penguin" ]] && die "This script cannot be run from a ChromeOS 
	Linux container; you must use a VT2 terminal as directed per https://mrchromebox.tech/#fwscript"
	
	#must be x86_64
	[ "$(uname -m)"  = 'x86_64' ] \
		|| die "This script only supports 64-bit OS on x86_64-based devices; ARM devices are not supported."
	
	#check for required tools
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
		initctl stop powerd > /dev/null 2>&1
		# try to mount p12 as /tmp/boot
		rootdev=$(rootdev -d -s)
		[[ "${rootdev}" =~ "mmcblk" || "${rootdev}" =~ "nvme" ]] && part_pfx="p" || part_pfx="" part_num="${part_pfx}12"
		export boot_mounted=$(mount | grep "${rootdev}""${part_num}")
		if [ "${boot_mounted}" = "" ]; then
			#mount boot
			mkdir /tmp/boot >/dev/null 2>&1
			mount "$(rootdev -d -s)""${part_num}" /tmp/boot >/dev/null 2>&1 && boot_mounted=true
		else
			boot_mounted=true
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
	rmmod spi_intel_platform >/dev/null 2>&1

	#get device firmware info
	echo -e "\nGetting device/system info..."
	if grep -q -i Intel /proc/cpuinfo; then
		#try reading only BIOS region
		if ${flashromcmd} --ifd -i bios -r /tmp/bios.bin > /tmp/flashrom.log 2>&1; then
			flashrom_params="--ifd -i bios"
		else
			#read entire firmware
			${flashromcmd} -r /tmp/bios.bin > /tmp/flashrom.log 2>&1
		fi
	else
		#read entire firmware
		${flashromcmd} -r /tmp/bios.bin > /tmp/flashrom.log 2>&1
	fi

	if [ $? -ne 0 ]; then
		echo_red "\nFlashrom is unable to read current firmware; cannot continue:"
		if [[ "$isChromeOS" = "false" ]]; then
			if [ -f /tmp/flashrom.log ]; then
				cat /tmp/flashrom.log
				echo ""
			fi
		fi
		echo_red "You may need to add 'iomem=relaxed' to your kernel parameters,
or trying running from a Live USB with a more permissive kernel (eg, Ubuntu 23.04+)."
		echo_red "If you have UEFI SecureBoot enabled, you need to disable it to run 
the script/update your firmware."
		return 1;
	fi
	
	# firmware date/version
	fwVer=$(dmidecode -s bios-version)
	fwDate=$(dmidecode -s bios-release-date)
	diagnostic_report_set fwVer "$fwVer"
	diagnostic_report_set fwDate "$fwDate"

	# check firmware type
	if [[ "$fwVer" = "Google_"* ]]; then
		# stock firmware
		isStock=true
		firmwareType="Stock ChromeOS"
		# check BOOT_STUB
		if grep "BOOT_STUB" /tmp/layout >/dev/null 2>&1; then
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
	${flashromcmd} --wp-status 2>&1 | grep -i -e "enabled" -e "protection mode: hardware" >/dev/null
	[[ $? -eq 0 ]] && swWp="enabled" || swWp="disabled"
	#test disabling SW WP to see if HW WP enabled
	${flashromcmd} --wp-disable > /dev/null 2>&1
	[[ $? -ne 0 && $swWp = "enabled" ]] && wpEnabled=true
	#restore previous SW WP state
	[[ ${swWp} = "enabled" ]] && ${flashromcmd} --wp-enable > /dev/null 2>&1
	diagnostic_report_set wpEnabled "$wpEnabled"
	diagnostic_report_set swWp "$swWp"

	# disable SW WP and reboot if needed
	if [[ "$isChromeOS" = true &&  "${wpEnabled}" != "true" &&  "${swWp}" = "enabled" ]]; then
		# prompt user to disable swWP and reboot
		echo_yellow "\nWARNING: your device currently has software write-protect enabled.\n
If you plan to flash the UEFI firmware, you must first disable it and reboot before flashing.
Would you like to disable sofware WP and reboot your device?"
		read -rep "Press Y (then enter) to disable software WP and reboot, or just press enter to skip and continue. "
		if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] ; then
			echo -e "\nDisabling software WP..."
			if ! ${flashromcmd} --wp-disable > /dev/null 2>&1; then
				exit_red "\nError disabling software write-protect -- hardware WP is still enabled."; return 1
			fi
			echo -e "\nClearing the WP range(s)..."
			if ! ${flashromcmd} --wp-range 0 0 > /dev/null 2>&1; then
				# use new command format as of commit 99b9550
				if ! ${flashromcmd} --wp-range 0,0 > /dev/null 2>&1; then
					#re-run to output error
					${flashromcmd} --wp-range 0,0
					exit_red "\nError clearing software write-protect range."; return 1
				fi
			fi
			echo_green "\nSoftware WP disabled, rebooting in 5s"
			reboot
			# ensure we don't show the main menu while the system processes the reboot signal
			die
		fi
	fi

	diagnostic_report_set firmwareType "$firmwareType"
	
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

###########
# Cleanup #
###########
function cleanup()
{
	#remove temp files, unmount temp stuff
	umount /tmp/boot > /dev/null 2>&1
}
