#!/bin/bash
#
# This script offers provides the ability to update the 
# Legacy Boot payload, set boot options, and install
# a custom coreboot firmware for supported
# ChromeOS devices 
#
# Created by Matt DeVillier	<matt.devillier@gmail.com>
#
# May be freely distributed and modified as needed, 
# as long as proper attribution is given.
#

#define these here for easy updating
script_date="[2016-02-25]"

OE_version_base="OpenELEC-Generic.x86_64"
OE_version_stable="6.0.199-Intel_EGL"
OE_version_latest="6.94.2"

coreboot_hsw_box="coreboot-seabios-hsw_chromebox-20160217-mattdevo.rom"
coreboot_bdw_box="coreboot-seabios-bdw_chromebox-20160217-mattdevo.rom"
coreboot_stumpy="coreboot-seabios-stumpy-20160217-mattdevo.rom"
coreboot_file=${coreboot_hsw_box}

seabios_hsw_box="seabios-hsw-box-20160217-mattdevo.bin"
seabios_hsw_book="seabios-hsw-book-20160217-mattdevo.bin"
seabios_bdw="seabios-bdw-book-20160217-mattdevo.bin"
seabios_file=${seabios_hsw_box}

hswbdw_headless_vbios="hswbdw_vgabios_1039_cbox_headless.dat"

OE_url_official="http://releases.openelec.tv/"
OE_url_EGL="https://dl.dropboxusercontent.com/u/98309225/"
OE_url=${OE_url_EGL}
KB_url="https://www.distroshare.com/distros/download/62_64/"
chrx_url="https://chrx.org/go"

pxe_optionrom="10ec8168.rom"

#other globals
usb_devs=""
num_usb_devs=0
usb_device=""
isChromeOS=true
isChromiumOS=false
flashromcmd=""
cbfstoolcmd=""
gbbflagscmd=""
preferUSB=false
useHeadless=false
addPXE=false
pxeDefault=false

#device groups
device=""
hsw_boxes=('<Panther>' '<Zako>' '<Tricky>' '<Mccloud>');
hsw_books=('<Falco>' '<Leon>' '<Monroe>' '<Peppy>' '<Wolf>');
bdw_boxes=('<Guado>' '<Rikku>' '<Tidus>');
bdw_update_legacy=('<Auron_Paine>' '<Auron_Yuna>' '<Gandof>' '<Guado>' '<Lulu>' '<Rikku>' '<Samus>' '<Tidus>');


#text output
NORMAL=`echo "\033[m"`
MENU=`echo "\033[36m"` #Blue
NUMBER=`echo "\033[33m"` #yellow
FGRED=`echo "\033[41m"`
RED_TEXT=`echo "\033[31m"`
GRAY_TEXT=`echo "\033[1;30m"`
ENTER_LINE=`echo "\033[33m"`

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


####################
# list USB devices #
####################
function list_usb_devices()
{
#list available drives, excluding internal HDD and root device
rootdev="/dev/sda"
if [ `which rootdev` ]; then
	rootdev=`rootdev -d -s`
fi	
eval usb_devs="(`fdisk -l 2> /dev/null | grep -v 'Disk /dev/sda' | grep -v "Disk $rootdev" | grep 'Disk /dev/sd' | awk -F"/dev/sd|:" '{print $2}'`)"
#ensure at least 1 drive available
[ "$usb_devs" != "" ] || return 1
echo -e "\nDevices available:\n"
num_usb_devs=0
for dev in "${usb_devs[@]}" 
do
num_usb_devs=$(($num_usb_devs+1))
vendor=`udevadm info --query=all --name=sd${dev} | grep -E "ID_VENDOR=" | awk -F"=" '{print $2}'`
model=`udevadm info --query=all --name=sd${dev} | grep -E "ID_MODEL=" | awk -F"=" '{print $2}'`
sz=`fdisk -l 2> /dev/null | grep "Disk /dev/sd${dev}" | awk '{print $3}'`
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
return 0
}



##################################
# Create Kodibuntu Install Media #
##################################
function create_kb_install_media()
{
echo_green "\nCreate Kodibuntu Installation Media"
trap kb_fail INT TERM EXIT

#check free space on /tmp
free_spc=`df -m /tmp | awk 'FNR == 2 {print $4}'`
[ "$free_spc" > "800" ] || die "Temp directory has insufficient free space to download Kodibuntu ISO."

echo_yellow "Custom/updated Kodibuntu ISO courtesy of HugeGreenBug @ www.distroshare.com"

read -p "Connect the USB/SD device (min 1GB) to be used as Kodibuntu installation media and press [Enter] to continue.
This will erase all contents of the USB/SD device, so be sure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || die "No USB devices available to create Kodibuntu install media."
read -p "Enter the number for the device to be used to install Kodibuntu: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"

#get Kodibuntu
echo_yellow "\nDownloading Kodibuntu installer ISO..."
cd /tmp
curl -L -o kodibuntu.iso $KB_url
if [ $? -ne 0 ]; then
	die "Failed to download Kodibuntu; check your Internet connection and try again"
fi
echo_yellow "\nDownload complete; creating install media...
(this will take a few minutes)"

dd if=kodibuntu.iso of=${usb_device} bs=1M conv=fdatasync >/dev/null 2>&1; sync
if [ $? -ne 0 ]; then
	die "Error creating Kodibuntu install media."
fi
trap - INT TERM EXIT
echo_green "
Creation of Kodibuntu install media is complete.
Upon reboot, press [ESC] at the boot menu prompt, then select your USB/SD device from the list."

echo_yellow "If you have not already done so, run the 'Install/update custom coreboot firmware' option before reboot."

read -p "Press [Enter] to return to the main menu."
}

function kb_fail() {
trap - INT TERM EXIT
die "\nKodibuntu installation media creation failed; retry with different USB/SD media"
}


#####################
# Select OE Version #
#####################
function select_oe_version()
{
	OE_url=${OE_url_EGL}
	OE_version="${OE_version_base}-${OE_version_latest}"
	if [ "$OE_version_latest" != "$OE_version_stable" ]; then
		read -p "Do you want to install an unofficial beta of OpenELEC 7.0 (${OE_version_latest}) ?
It is based on Kodi 16.0 and is reasonably stable, but unofficial/unsupported.

If N, the latest stable version of OpenELEC 6.0 ($OE_version_stable) based on Kodi 15.2 will be used. [Y/n] "
		if [[ "$REPLY" == "n" || "$REPLY" == "N" ]]; then
			OE_version="${OE_version_base}-${OE_version_stable}"
			#OE_url=${OE_url_official}
		fi
		echo -e "\n"
	fi	
}


###########################
# Create OE Install Media #
###########################
function create_oe_install_media()
{
echo_green "\nCreate OpenELEC Installation Media"
trap oe_fail INT TERM EXIT

#check free space on /tmp
free_spc=`df -m /tmp | awk 'FNR == 2 {print $4}'`
[ "$free_spc" > "500" ] || die "Temp directory has insufficient free space to create OpenELEC install media."

#Install beta version?
select_oe_version

read -p "Connect the USB/SD device (min 512MB) to be used as OpenELEC installation media and press [Enter] to continue.
This will erase all contents of the USB/SD device, so be sure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || die "No USB devices available to create OpenELEC install media."
read -p "Enter the number for the device to be used to install OpenELEC: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"

#get OpenELEC
echo_yellow "\nDownloading OpenELEC installer image..."
img_file="${OE_version}.img"
img_url="${OE_url}${img_file}.gz"

cd /tmp
curl -L -o ${img_file}.gz $img_url
if [ $? -ne 0 ]; then
	die "Failed to download OpenELEC; check your Internet connection and try again"
fi

echo_yellow "\nDownload complete; creating install media..."

gunzip -f ${img_file}.gz >/dev/null 2>&1
if [ $? -ne 0 ]; then
	die "Failed to extract OpenELEC download; check your Internet connection and try again"
fi

dd if=$img_file of=${usb_device} bs=1M conv=fdatasync >/dev/null 2>&1; sync
if [ $? -ne 0 ]; then
	die "Error creating OpenELEC install media."
fi
trap - INT TERM EXIT
echo_green "
Creation of OpenELEC install media is complete.
Upon reboot, press [ESC] at the boot menu prompt, then select your USB/SD device from the list."

echo_yellow "If you have not already done so, run the 'Install/update: Custom coreboot Firmware' option before reboot."

read -p "Press [Enter] to return to the main menu."
}

function oe_fail() {
trap - INT TERM EXIT
die "\nOpenELEC installation media creation failed; retry with different USB/SD media"
}

function die()
{
	echo_red "$@"
	exit 1
}

function option_picked() {
    COLOR='\033[01;31m' # bold red
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
}


######################
# flash legacy BIOS #
######################
function flash_legacy()
{
cd /tmp

# set dev mode boot flags 
crossystem dev_boot_legacy=1 dev_boot_signed_only=0 > /dev/null

echo_yellow "\nChecking if Legacy BIOS update available..."

#determine proper file 
isHswBox=`echo ${hsw_boxes[*]} | grep "<$device>"`
isHswBook=`echo ${hsw_books[*]} | grep "<$device>"`
isBdw=`echo ${bdw_update_legacy[*]} | grep "<$device>"`
if [ "$isHswBox" != "" ]; then
	seabios_file=$seabios_hsw_box
elif [ "$isHswBook" != "" ]; then
	seabios_file=$seabios_hsw_book
elif [ "$isBdw" != "" ]; then
	seabios_file=$seabios_bdw
else
	echo_red "Unknown or unsupported device (${device}); cannot update Legacy BIOS."
	return
fi

#USB boot priority
preferUSB=false
if [ -z "$1" ]; then
	echo -e ""
	read -p "Default to booting from USB? If N, always boot from the internal SSD unless selected from boot menu. [y/N] "
	if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
		preferUSB=true
	fi	
	echo -e ""
	#headless?
	useHeadless=false
	if [ "$seabios_file" == "$seabios_hsw_box" ]; then
		read -p "Install \"headless\" firmware? This is only needed for servers running without a connected display. [y/N] "
		if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
			useHeadless=true
		fi
		echo -e ""
	fi
fi

#download SeaBIOS update
echo_yellow "\nDownloading Legacy BIOS/SeaBIOS"
curl -s -L -O ${dropbox_url}${seabios_file}.md5
curl -s -L -O ${dropbox_url}${seabios_file}
#verify checksum on downloaded file
md5sum -c ${seabios_file}.md5 --quiet 2> /dev/null
if [ $? -eq 0 ]; then
	#preferUSB?
	if [ "$preferUSB" = true  ]; then
		curl -s -L -O "${dropbox_url}bootorder"
		if [ $? -ne 0 ]; then
			echo_red "Unable to download bootorder file; boot order cannot be changed."
		else
			${cbfstoolcmd} ${seabios_file} remove -n bootorder > /dev/null 2>&1
			${cbfstoolcmd} ${seabios_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
		fi		
	fi
	#useHeadless?
	if [ "$useHeadless" = true  ]; then
		curl -s -L -O "${dropbox_url}${hswbdw_headless_vbios}"
		if [ $? -ne 0 ]; then
			echo_red "Unable to download headless VGA BIOS; headless firmware cannot be installed."
		else
			${cbfstoolcmd} ${seabios_file} remove -n pci8086,0406.rom > /dev/null 2>&1
			${cbfstoolcmd} ${seabios_file} add -f ${hswbdw_headless_vbios} -n pci8086,0406.rom -t optionrom > /dev/null 2>&1
		fi		
	fi
	#flash updated legacy BIOS
	echo_yellow "Installing Legacy BIOS: ${seabios_file}"
	${flashromcmd} -w -i RW_LEGACY:${seabios_file} > /dev/null 2>&1
	echo_green "Legacy BIOS successfully updated."
else
	#download checksum fail
	echo_red "Legacy BIOS download checksum fail; download corrupted, cannot flash"
fi		
}


######################
# update legacy BIOS #
######################
function update_legacy()
{
flash_legacy
read -p "Press [Enter] to return to the main menu.";
}


#############################
# Install coreboot Firmware #
#############################
function flash_coreboot()
{
echo_green "\nInstall/Update Custom coreboot Firmware"
echo_red "!! WARNING !!  This function is only valid for the following devices:"
echo -e " - Asus ChromeBox CN62 (Broadwell Celeron 3205U/i3-5010U/i7-5500U) [Guado]
 - Acer ChromeBox CXI2 (Broadwell Celeron 3205U/i3-5010U) [Rikku]
 - Lenovo ThinkCentre ChromeBox (Broadwell Celeron 3205U/i3-5010U) [Tidus]

 - Asus ChromeBox CN60 (Haswell Celeron 2955U/i3-4010U/i7-4600U) [Panther]
 - HP ChromeBox CB1 (Haswell Celeron 2955U/i7-4600U) [Zako]
 - Dell ChromeBox 3010 (Haswell Celeron 2955U/i3-4030U) [Tricky]
 - Acer ChromeBox CXI (Haswell Celeron 2975U/i3-4030U) [McCloud]
 
 - Samsung Series 3 ChromeBox (SandyBridge Celeron B840/i5-2450U) [Stumpy]
"
echo_red "Use on any other device will almost certainly brick it."
echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

read -p "Do you wish to continue? [y/N] "
[ "$REPLY" == "y" ] || return

#spacing
echo -e ""

# ensure hardware write protect disabled if in ChromeOS/ChromiumOS
if [[ "$isChromeOS" = true || "$isChromiumOS" = true ]]; then
	if [[ "`crossystem | grep wpsw_cur`" != *"0"* ]]; then
		echo_red "\nHardware write-protect enabled, cannot flash coreboot firmware."
		read -p "Press [Enter] to return to the main menu."
		return;
	fi
fi

#check device 
isHswBox=`echo ${hsw_boxes[*]} | grep "<$device>"`
isBdwBox=`echo ${bdw_boxes[*]} | grep "<$device>"`
if [ "$isHswBox" != "" ]; then
	coreboot_file=$coreboot_hsw_box
elif [ "$isBdwBox" != "" ]; then
	coreboot_file=$coreboot_bdw_box
elif [ "$device" == "Stumpy" ]; then
	coreboot_file=$coreboot_stumpy
else
	echo_red "Unknown or unsupported device (${device}); cannot continue."
	read -p "Press [Enter] to return to the main menu."
	return
fi

#read existing firmware and try to extract MAC address info
echo_yellow "Reading current firmware"
${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
if [ $? -ne 0 ]; then 
	echo_red "Failure reading current firmware; cannot proceed."
	read -p "Press [Enter] to return to the main menu."
	return;
fi

if [[ "$coreboot_file" == "$coreboot_hsw_box" || "$coreboot_file" == "$coreboot_bdw_box" ]]; then
	#check if contains MAC address, extract
	extract_vpd /tmp/bios.bin
	if [ $? -ne 0 ]; then
		#need user to supply stock firmware file for VPD extract 
		read -p "
Your current firmware does not contain data for the device MAC address.  
Would you like to load it from a previously backed-up stock firmware file? [y/N] "
		if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
			read -p "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "
			
			list_usb_devices
			[ $? -eq 0 ] || die "No USB devices available to read firmware backup."
			read -p "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
			[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
			usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
			mkdir /tmp/usb > /dev/null 2>&1
			mount "${usb_device}" /tmp/usb > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				mount "${usb_device}1" /tmp/usb
			fi
			if [ $? -ne 0 ]; then
				echo_red "USB device failed to mount; cannot proceed."
				read -p "Press [Enter] to return to the main menu."
				return
			fi
			#extract MAC from user-supplied stock firmware
			extract_vpd /tmp/usb/stock-firmware.rom
			if [ $? -ne 0 ]; then
				#unable to extract from stock firmware backup
				echo_red "Failure reading stock firmware backup; cannot proceed."
				read -p "Press [Enter] to return to the main menu."
				return
			fi
		else
			#TODO - user enter MAC manually?
			echo_red "\nSkipping persistence of MAC address."
		fi

	fi
fi

#check if existing firmware is stock
grep -obUa "vboot" /tmp/bios.bin >/dev/null
if [ $? -eq 0 ]; then
	read -p "Create a backup copy of your stock firmware? [Y/n]

This is highly recommended in case you wish to return your device to stock 
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. "
	[ "$REPLY" == "n" ] || backup_firmware
fi

#headless?
useHeadless=false
if [[ "$coreboot_file" == "$coreboot_hsw_box" || "$coreboot_file" == "$coreboot_bdw_box" ]]; then
	echo -e ""
	read -p "Install \"headless\" firmware? This is only needed for servers running without a connected display. [y/N] "
	if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
		useHeadless=true
	fi
fi

#USB boot priority
preferUSB=false
echo -e ""
read -p "Default to booting from USB? If N, always boot from the internal SSD unless selected from boot menu. [y/N] "
if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
	preferUSB=true
fi

#add PXE?
addPXE=false
if [[ "$coreboot_file" == "$coreboot_hsw_box" || "$coreboot_file" == "$coreboot_bdw_box" ]]; then
	echo -e ""
	read -p "Add PXE network booting capability? (This is not needed for by most users) [y/N] "
	if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
		addPXE=true
		echo -e ""
		read -p "Boot PXE by default? (will fall back to SSD/USB) [y/N] "
		if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
			pxeDefault=true	
		fi
	fi
fi

#download firmware file
cd /tmp
echo_yellow "\nDownloading coreboot firmware"
curl -s -L -O "${dropbox_url}${coreboot_file}"
curl -s -L -O "${dropbox_url}${coreboot_file}.md5"


#verify checksum on downloaded file
md5sum -c ${coreboot_file}.md5 --quiet > /dev/null 2>&1
if [ $? -eq 0 ]; then
	#check if we have a VPD to restore
	if [ -f /tmp/vpd.bin ]; then
		${cbfstoolcmd} ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw > /dev/null 2>&1
	fi
	#preferUSB?
	if [ "$preferUSB" = true  ]; then
		curl -s -L -O "${dropbox_url}bootorder"
		if [ $? -ne 0 ]; then
			echo_red "Unable to download bootorder file; boot order cannot be changed."
		else
			${cbfstoolcmd} ${coreboot_file} remove -n bootorder > /dev/null 2>&1 
			${cbfstoolcmd} ${coreboot_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
		fi
	fi
	#useHeadless?
	if [ "$useHeadless" = true  ]; then
		curl -s -L -O "${dropbox_url}${hswbdw_headless_vbios}"
		if [ $? -ne 0 ]; then
			echo_red "Unable to download headless VGA BIOS; headless firmware cannot be installed."
		else
			${cbfstoolcmd} ${coreboot_file} remove -n pci8086,0406.rom > /dev/null 2>&1
			${cbfstoolcmd} ${coreboot_file} add -f ${hswbdw_headless_vbios} -n pci8086,0406.rom -t optionrom > /dev/null 2>&1
		fi		
	fi
	#addPXE?
	if [ "$addPXE" = true  ]; then
		curl -s -L -O "${dropbox_url}${pxe_optionrom}"
		if [ $? -ne 0 ]; then
			echo_red "Unable to download PXE option ROM; PXE capability cannot be added."
		else
			${cbfstoolcmd} ${coreboot_file} add -f ${pxe_optionrom} -n pci10ec,8168.rom -t optionrom > /dev/null 2>&1
			#PXE default?
			if [ "$pxeDefault" = true  ]; then
				${cbfstoolcmd} ${coreboot_file} extract -n bootorder -f /tmp/bootorder > /dev/null 2>&1
				${cbfstoolcmd} ${coreboot_file} remove -n bootorder > /dev/null 2>&1
				sed -i '1s/^/\/pci@i0cf8\/pci-bridge@1c\/*@0\n/' /tmp/bootorder
				${cbfstoolcmd} ${coreboot_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
			fi
		fi		
	fi
	#flash coreboot firmware
	echo_yellow "Installing custom coreboot firmware: ${coreboot_file}"
	${flashromcmd} -w "${coreboot_file}" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo_green "Custom coreboot firmware successfully installed/updated."
	else
		echo_red "An error occurred flashing the coreboot firmware. DO NOT REBOOT!"
	fi
else
	#download checksum fail
	echo_red "coreboot firmware download checksum fail; download corrupted, cannot flash."
fi	

read -p "Press [Enter] to return to the main menu."
}

##########################
# Restore Stock Firmware #
##########################
function restore_stock_firmware()
{
echo_green "\nRestore Stock Firmware"
echo_red "!! WARNING !!  This function is only valid for the following devices:"
echo -e " - Asus ChromeBox CN62 (Broadwell Celeron 3205U/i3-5010U/i7-5500U) [Guado]

 - Asus ChromeBox (Haswell Celeron 2955U/i3-4010U/i7-4600U) [Panther]
 - HP ChromeBox (Haswell Celeron 2955U/i7-4600U) [Zako]
 - Dell ChromeBox (Haswell Celeron 2955U/i3-4030U) [Tricky]
 - Acer ChromeBox (Haswell Celeron 2975U/i3-4030U) [McCloud]
"
echo_red "Use on any other device will almost certainly brick it."
echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

read -p "Do you wish to continue? [y/N] "
[ "$REPLY" == "y" ] || return

#spacing
echo -e ""

# ensure hardware write protect disabled if in ChromiumOS
if [[ "$isChromiumOS" = true ]]; then
	if [[ "`crossystem | grep wpsw_cur`" != *"0"* ]]; then
		echo_red "\nHardware write-protect enabled, cannot restore stock firmware."
		read -p "Press [Enter] to return to the main menu."
		return
	fi
fi

#check device 
isHswBox=`echo ${hsw_boxes[*]} | grep "<$device>"`
isBdwBox=`echo ${bdw_boxes[*]} | grep "<$device>"`
if [[ "$isHswBox" == "" && "$isBdwBox" == "" ]]; then
	echo_red "Unknown or unsupported device (${device}); cannot continue."
	read -p "Press [Enter] to return to the main menu."
	return
fi

firmware_file=""

read -p "Do you have a firmware backup file on USB? [y/N] "
if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
	read -p "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "		
	list_usb_devices
	[ $? -eq 0 ] || die "No USB devices available to read firmware backup."
	read -p "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
	[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
	usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
	mkdir /tmp/usb > /dev/null 2>&1
	mount "${usb_device}" /tmp/usb > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		mount "${usb_device}1" /tmp/usb
	fi
	if [ $? -ne 0 ]; then
		echo_red "USB device failed to mount; cannot proceed."
		read -p "Press [Enter] to return to the main menu."
		umount /tmp/usb > /dev/null 2>&1
		return
	fi
	#select file from USB device
	echo_yellow "\nFirmware Files on USB:"
	ls  /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null
	if [ $? -ne 0 ]; then
		echo_red "No firmware files found on USB device."
		read -p "Press [Enter] to return to the main menu."
		umount /tmp/usb > /dev/null 2>&1
		return
	fi
	echo -e ""
	read -p "Enter the firmware filename:  " firmware_file
	firmware_file=/tmp/usb/${firmware_file}
	if [ ! -f ${firmware_file} ]; then
		echo_red "Invalid filename entered; unable to restore stock firmware."
		read -p "Press [Enter] to return to the main menu."
		umount /tmp/usb > /dev/null 2>&1
		return
	fi
	#text spacing
	echo -e ""
	
else
	#download firmware extracted from recovery image
	echo_yellow "\nThat's ok, I'll download one for you. Which ChromeBox do you have?"
	echo "1) Asus CN60 (Haswell)"
	echo "2) HP CB1 (Haswell)"
	echo "3) Dell 3010 (Haswell)"
	echo "4) Acer CB1 (Haswell)"
	echo "5) Asus CN62 (Broadwell)"
	echo ""
	read -p "? " fw_num
	if [[ $fw_num -lt 1 ||  $fw_num -gt 4 ]]; then
		echo_red "Invalid input - cancelling"
		read -p "Press [Enter] to return to the main menu."
		umount /tmp/usb > /dev/null 2>&1
	fi
	
	#download firmware file
	echo_yellow "\nDownloading recovery image firmware file" 
	case "$fw_num" in
		1) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/sLQL9i1p;
			;;
		2) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/8NmzlrZ6;
			;;
		3) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/IXLtQ097;
			;;
		4) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/Nh5EeEti;
			;;
		5) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/r0sKwJYe;
			;;
	esac
	if [ $? -ne 0 ]; then
		echo_red "Error downloading; unable to restore stock firmware."
		read -p "Press [Enter] to return to the main menu."
		return
	fi
	
	#read current firmware to extract VPD
	echo_yellow "Reading current firmware"
	${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
	if [ $? -ne 0 ]; then 
		echo_red "Failure reading current firmware; cannot proceed."
		read -p "Press [Enter] to return to the main menu."
		return;
	fi
	#extract VPD
	extract_vpd /tmp/bios.bin
	#merge with recovery image firmware
	if [ -f /tmp/vpd.bin ]; then
		echo_yellow "Merging VPD into recovery image firmware"
		dd if=/tmp/vpd.bin bs=1 seek=$((0x00600000)) count=$((0x00004000)) of=/tmp/stock-firmware.rom conv=notrunc > /dev/null 2>&1
	fi
	firmware_file=/tmp/stock-firmware.rom
fi

#flash stock firmware
echo_yellow "Restoring stock firmware"
${flashromcmd} -w ${firmware_file} > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo_green "Stock firmware successfully restored."
	echo_green "After rebooting, you will need to restore ChromeOS using the ChromeOS recovery media."
	read -p "Press [Enter] to reboot."
	echo -e "\nRebooting...\n";
	cleanup;
	reboot;
else
	echo_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"
	read -p "Press [Enter] to return to the main menu."
fi
}

########################
# Extract firmware VPD #
########################
function extract_vpd() 
{
#check params
if [ -z "$1" ] 
then
 die "Error: extract_vpd(): missing function parameter"
 read -p "Press [Enter] to return to the main menu."
 return 1
fi
firmware_file="$1"
#check if file contains MAC address
grep -obUa "ethernet_mac" ${firmware_file} >/dev/null
if [ $? -eq 0 ]; then
	#we have a MAC; determine if stock firmware (FMAP) or coreboot (CBFS)
	grep -obUa "vboot" ${firmware_file} >/dev/null
	if [ $? -eq 0 ]; then
		#stock firmware, extract w/dd
		extract_cmd="dd if=${firmware_file} bs=1 skip=$((0x00600000)) count=$((0x00004000)) of=/tmp/vpd.bin"
	else
		#coreboot firmware, extract w/cbfstool
		extract_cmd="${cbfstoolcmd} ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin > /dev/null 2>&1"
	fi
	#run extract command
	${extract_cmd} >& /dev/null
	if [ $? -ne 0 ]; then 
		echo_red "Failure extracting MAC address from current firmware."
		return 1
	fi
else
	#file doesn't contain VPD
	return 1
fi
return 0
}

################
# Get cbfstool #
################
function get_cbfstool()
{
if [ ! -f ${cbfstoolcmd} ]; then
	working_dir=`pwd`
	if [[ "$isChromeOS" = false && "$isChromiumOS" = false ]]; then
		cd /tmp
	else
		#have to use /dev/sdx12 due to noexec restrictions
		rootdev=`rootdev -d -s`
		boot_mounted=`mount | grep ${rootdev}12`
		if [ "${boot_mounted}" == "" ]; then
			#mount boot
			mkdir /tmp/boot >/dev/null 2>&1
			mount `rootdev -d -s`12 /tmp/boot
			if [ $? -ne 0 ]; then 
				echo_red "Error mounting boot partition; cannot proceed."
				return 1
			fi
		fi
		#create util dir
		mkdir /tmp/boot/util 2>/dev/null
		cd /tmp/boot/util
	fi
	
	#echo_yellow "Downloading cbfstool utility"
	curl -s -L -O ${dropbox_url}/cbfstool.tar.gz
	if [ $? -ne 0 ]; then 
		echo_red "Error downloading cbfstool; cannot proceed."
		#restore working dir
		cd ${working_dir}
		return 1
	fi
	tar -zxf cbfstool.tar.gz --no-same-owner
	if [ $? -ne 0 ]; then 
		echo_red "Error extracting cbfstool; cannot proceed."
		#restore working dir
		cd ${working_dir}
		return 1
	fi
	#set +x
	chmod +x cbfstool
	#restore working dir
	cd ${working_dir}
fi
return 0	
}


################
# Get flashrom #
################
function get_flashrom()
{
if [ ! -f ${flashromcmd} ]; then
	working_dir=`pwd`
	cd /tmp

	curl -s -L -O ${dropbox_url}/flashrom.tar.gz
	if [ $? -ne 0 ]; then 
		echo_red "Error downloading flashrom; cannot proceed."
		#restore working dir
		cd ${working_dir}
		return 1
	fi
	tar -zxf flashrom.tar.gz
	if [ $? -ne 0 ]; then 
		echo_red "Error extracting flashrom; cannot proceed."
		#restore working dir
		cd ${working_dir}
		return 1
	fi
	#set +x
	chmod +x flashrom
	#restore working dir
	cd ${working_dir}
fi
return 0	
}



#########################
# Backup stock firmware #
#########################
function backup_firmware() 
{
echo -e ""
read -p "Connect the USB/SD device to store the firmware backup and press [Enter] 
to continue.  This is non-destructive, but it is best to ensure no other 
USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || die "No USB devices available to store firmware backup."
read -p "Enter the number for the device to be used for firmware backup: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
mkdir /tmp/usb > /dev/null 2>&1
mount "${usb_device}" /tmp/usb > /dev/null 2>&1
if [ $? != 0 ]; then
	mount "${usb_device}1" /tmp/usb
fi
[ $? -eq 0 ] || backup_fail "USB backup device failed to mount; cannot proceed."
model=`dmidecode | grep -m1 "Product Name:" | awk '{print $3}'`
backupname="stock-firmware-${model}-$(date +%Y%m%d).rom"
echo_yellow "\nSaving firmware backup as ${backupname}"
cp /tmp/bios.bin /tmp/usb/${backupname}
[ $? -eq 0 ] || backup_fail "Failure reading stock firmware for backup; cannot proceed."
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb
echo_green "Firmware backup complete. Remove the USB stick and press [Enter] to continue."
read -p ""
}

function backup_fail()
{
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb
die "$@"
}


###########################
# Set Boot Options - Kodi #
###########################
function set_boot_options_kodi() 
{
# set boot options via firmware boot flags
# ensure hardware write protect disabled
if [[ "`crossystem | grep wpsw_cur`" == *"0"* ]]; then

	echo_green "
Select your preferred boot delay and default boot option.
You can always override the default using [CTRL-D] or 
[CTRL-L] on the developer mode boot splash screen"
	echo_yellow "Note: these options are not relevant for a standalone setup, and should
only be set AFTER completing the 2nd stage of a dual-boot setup.  It's strongly
recommended that you test your dual boot setup before setting these options."
	echo -e "1) Short boot delay (1s) + OpenELEC/Ubuntu default
2) Long boot delay (30s) + OpenELEC/Ubuntu default
3) Short boot delay (1s) + ChromeOS default
4) Long boot delay (30s) + ChromeOS default
5) Reset to factory default
6) Cancel/exit
"
	while :
	do
		read n
		echo_yellow "\nSetting boot options..."
		case $n in
			1) $gbbflagscmd 0x489 > /dev/null 2>&1; break;;
			2) $gbbflagscmd 0x488 > /dev/null 2>&1; break;;
			3) $gbbflagscmd 0x9 > /dev/null 2>&1; break;;
			4) $gbbflagscmd 0x8 > /dev/null 2>&1; break;;
			5) $gbbflagscmd 0x0 > /dev/null 2>&1; break;;
			6) read -p "Press [Enter] to return to the main menu."; return; break;;
			*) invalid option;;
		esac
	done
	if [ $? -eq 0 ]; then
		echo_green "\nBoot options successfully set."
	else
		echo_red "\nError setting boot options."
	fi
else
	echo_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot set boot options."
fi
read -p "Press [Enter] to return to the main menu."
}

####################
# Set Boot Options #
####################
function set_boot_options() 
{
# set boot options via firmware boot flags
# ensure hardware write protect disabled
if [[ "`crossystem | grep wpsw_cur`" == *"0"* ]]; then

	echo_green "
Select your preferred boot delay and default boot option.
You can always override the default using [CTRL-D] or 
[CTRL-L] on the developer mode boot splash screen"

	echo -e "1) Short boot delay (1s) + Legacy Boot default
2) Long boot delay (30s) + Legacy Boot default
3) Short boot delay (1s) + ChromeOS default
4) Long boot delay (30s) + ChromeOS default
5) Reset to factory default
6) Cancel/exit
"
	while :
	do
		read n
		echo_yellow "\nSetting boot options..."
		case $n in
			1) $gbbflagscmd 0x489 > /dev/null 2>&1; break;;
			2) $gbbflagscmd 0x488 > /dev/null 2>&1; break;;
			3) $gbbflagscmd 0x9 > /dev/null 2>&1; break;;
			4) $gbbflagscmd 0x8 > /dev/null 2>&1; break;;
			5) $gbbflagscmd 0x0 > /dev/null 2>&1; break;;
			6) read -p "Press [Enter] to return to the main menu."; return; break;;
			*) invalid option;;
		esac
	done
	if [ $? -eq 0 ]; then
		echo_green "\nBoot options successfully set."
	else
		echo_red "\nError setting boot options."
	fi
else
	echo_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot set boot options."
fi
read -p "Press [Enter] to return to the main menu."
}


###################
# Set Hardware ID #
###################
function set_hwid() 
{
# set hwid using gbb_utility
# ensure hardware write protect disabled
if [[ "`crossystem wpsw_cur`" == "0" || "`crossystem wpsw_boot`" == "0" ]]; then

	#get current hwid
	_hwid="`crossystem hwid`"

	echo_green "
Set Hardware ID (hwid) using gbb_utility"
	echo_yellow "
Current hwid is $_hwid. Enter a new hwid (use all caps):"
	read hwid
	echo -e ""
	read -p "Confirm changing hwid to $hwid [y/N] " confirm
	if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
		echo_yellow "\nSetting hardware ID..."
		flashrom -r /tmp/bios.temp > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo_red "\nError reading firmware; unable to set hwid."
			read -p "Press [Enter] to return to the main menu."
			return
		fi
		gbb_utility --set --hwid='$hwid' /tmp/bios.temp /tmp/bios.new > /dev/null
		if [ $? -ne 0 ]; then
			echo_red "\nError setting hwid."
			read -p "Press [Enter] to return to the main menu."
			return
		fi
		flashrom -w /tmp/bios.new > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo_red "\nError writing back firmware; unable to set hwid."
			read -p "Press [Enter] to return to the main menu."
			return
		fi
		echo_green "Hardware ID successfully set."

	fi
else
	echo_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot set hwid."
fi
read -p "Press [Enter] to return to the main menu."
}


##########################
# Install OE (dual boot) #
##########################
function chrOpenELEC() 
{
echo_green "\nOpenELEC / Dual Boot Install"

target_disk="`rootdev -d -s`"
# Do partitioning (if we haven't already)
ckern_size="`cgpt show -i 6 -n -s -q ${target_disk}`"
croot_size="`cgpt show -i 7 -n -s -q ${target_disk}`"
state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"

max_openelec_size=$(($state_size/1024/1024/2))
rec_openelec_size=$(($max_openelec_size - 1))
# If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]; then
	echo_green "Stage 1: Repartitioning the internal HDD"
	
	# prevent user from booting into legacy until install complete
	crossystem dev_boot_usb=0 dev_boot_legacy=0 > /dev/null 2>&1
	
	while :
	do
		echo "Enter the size in GB you want to reserve for OpenELEC Storage."
		read -p "Acceptable range is 2 to $max_openelec_size but $rec_openelec_size is the recommended maximum: " openelec_size
		if [ $openelec_size -ne $openelec_size 2>/dev/null ]; then
			echo_red "\n\nWhole numbers only please...\n\n"
			continue
		elif [ $openelec_size -lt 2 -o $openelec_size -gt $max_openelec_size ]; then
			echo_red "\n\nThat number is out of range. Enter a number 2 through $max_openelec_size\n\n"
			continue
		fi
		break
	done
	# We've got our size in GB for ROOT-C so do the math...

	#calculate sector size for rootc
	rootc_size=$(($openelec_size*1024*1024*2))

	#kernc is always 512mb
	kernc_size=1024000

	#new stateful size with rootc and kernc subtracted from original
	stateful_size=$(($state_size - $rootc_size - $kernc_size))

	#start stateful at the same spot it currently starts at
	stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"

	#start kernc at stateful start plus stateful size
	kernc_start=$(($stateful_start + $stateful_size))

	#start rootc at kernc start plus kernc size
	rootc_start=$(($kernc_start + $kernc_size))

	#Do the real work

	echo_yellow "\n\nModifying partition table to make room for OpenELEC." 
	umount -f /mnt/stateful_partition > /dev/null 2>&1

	# stateful first
	cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}

	# now kernc
	cgpt add -i 6 -b $kernc_start -s $kernc_size -l KERN-C -t "kernel" ${target_disk}

	# finally rootc
	cgpt add -i 7 -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}

	echo_green "Stage 1 complete; after reboot ChromeOS will \"repair\" itself."
	echo_yellow "Afterwards, you must re-download/re-run this script to complete OpenELEC setup."

	read -p "Press [Enter] to reboot..."
	reboot
	exit
fi

echo_yellow "Stage 1 / repartitioning completed, moving on."
echo_green "\nStage 2: Installing OpenELEC"

#Install beta version?
select_oe_version

#target partitions
target_rootfs="${target_disk}7"
target_kern="${target_disk}6"

if mount|grep ${target_rootfs}
then
  OE_install_error "Refusing to continue since ${target_rootfs} is formatted and mounted. Try rebooting"
fi

#format partitions, disable journaling, set labels
mkfs.ext4 -v -m0 -O ^has_journal -L KERN-C ${target_kern} > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to format OE partition(s); reboot and try again"
fi
mkfs.ext4 -v -m0 -O ^has_journal -L ROOT-C ${target_rootfs} > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to format OE partition(s); reboot and try again"
fi
 
#mount partitions
if [ ! -d /tmp/System ]
then
  mkdir /tmp/System
fi
mount -t ext4 ${target_kern} /tmp/System > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to mount OE System partition; reboot and try again"
fi

if [ ! -d /tmp/Storage ]
then
  mkdir /tmp/Storage
fi
mount -t ext4 ${target_rootfs} /tmp/Storage > /dev/null
if [ $? -ne 0 ]; then
	OE_install_error "Failed to format OE Storage partition; reboot and try again"
fi

echo_yellow "\nPartitions formatted and mounted"

echo_yellow "Updating bootloader"

#get/extract syslinux
tar_file="${dropbox_url}syslinux-5.10-md.tar.bz2"
curl -s -L -o /tmp/Storage/syslinux.tar.bz2 $tar_file 
if [ $? -ne 0 ]; then
	OE_install_error "Failed to download syslinux; check your Internet connection and try again"
fi
cd /tmp/Storage
tar -xpjf syslinux.tar.bz2
if [ $? -ne 0 ]; then
	OE_install_error "Failed to extract syslinux download; reboot and try again"
fi

#install extlinux on OpenELEC kernel partition
cd /tmp/Storage/syslinux-5.10/extlinux/
./extlinux -i /tmp/System/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to install extlinux; reboot and try again"
fi

#create extlinux.conf
echo -e "DEFAULT linux\nPROMPT 0\nLABEL linux\nKERNEL /KERNEL\nAPPEND boot=LABEL=KERN-C disk=LABEL=ROOT-C tty quiet" > /tmp/System/extlinux.conf

#Upgrade/modify existing syslinux install
if [ ! -d /tmp/boot ]
then
  mkdir /tmp/boot
fi
if  ! mount | grep /tmp/boot > /dev/null ; then
	mount /dev/sda12 /tmp/boot > /dev/null
fi
if [ $? -ne 0 ]; then
	OE_install_error "Failed to mount boot partition; reboot and try again"
fi

#create syslinux.cfg
rm -f /tmp/boot/syslinux/* 2>/dev/null
echo -e "DEFAULT openelec\nPROMPT 0\nLABEL openelec\nCOM32 chain.c32\nAPPEND label=KERN-C" > /tmp/boot/syslinux/syslinux.cfg

#copy chain loader files
cp /tmp/Storage/syslinux-5.10/com32/chain/chain.c32 /tmp/boot/syslinux/chain.c32
cp /tmp/Storage/syslinux-5.10/com32/lib/libcom32.c32 /tmp/boot/syslinux/libcom32.c32
cp /tmp/Storage/syslinux-5.10/com32/libutil/libutil.c32 /tmp/boot/syslinux/libutil.c32

#install/update syslinux
cd /tmp/Storage/syslinux-5.10/linux/
rm -f /tmp/boot/ldlinux.* 1>/dev/null 2>&1
./syslinux -i -f /dev/sda12 -d syslinux
if [ $? -ne 0 ]; then
	OE_install_error "Failed to install syslinux; reboot and try again"
fi

echo_yellow "Downloading OpenELEC"

#get OpenELEC
tar_file="${OE_version}.tar"
tar_url="${OE_url}${tar_file}"
cd /tmp/Storage
curl -L -o $tar_file $tar_url
if [ $? -ne 0 ]; then
	echo_yellow "Failed to download OE; trying dropbox mirror"
	tar_url="${dropbox_url}${tar_file}"
	wget -O $tar_file $tar_url
	if [ $? -ne 0 ]; then
		OE_install_error "Failed to download OpenELEC; check your Internet connection and try again"
	fi
fi
echo_yellow "\nOpenELEC download complete; installing..."
tar -xpf $tar_file
if [ $? -ne 0 ]; then
	OE_install_error "Failed to extract OpenELEC download; check your Internet connection and try again"
fi

#install
cp /tmp/Storage/${OE_version}/target/KERNEL /tmp/System/
cp /tmp/Storage/${OE_version}/target/SYSTEM /tmp/System/

#sanity check file sizes
[ -s /tmp/System/KERNEL ] || OE_install_error "OE KERNEL has file size 0"
[ -s /tmp/System/SYSTEM ] || OE_install_error "OE SYSTEM has file size 0"

#update legacy BIOS
flash_legacy skip_usb > /dev/null

echo_green "OpenELEC Installation Complete"
read -p "Press [Enter] to return to the main menu."
}

function OE_install_error()
{
rm -rf /tmp/Storage > /dev/null 2>&1
rm -rf /tmp/System > /dev/null 2>&1
cleanup
die "Error: $@"

}




##############################
# Install Ubuntu (dual boot) #
##############################
function chrUbuntu() 
{
echo_green "\nUbuntu / Dual Boot Install"
echo_green "Now using reynhout's chrx script - www.chrx.org"

target_disk="`rootdev -d -s`"
# Do partitioning (if we haven't already)
ckern_size="`cgpt show -i 6 -n -s -q ${target_disk}`"
croot_size="`cgpt show -i 7 -n -s -q ${target_disk}`"
state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"

max_ubuntu_size=$(($state_size/1024/1024/2))
rec_ubuntu_size=$(($max_ubuntu_size - 1))
# If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]; then
	
	#update legacy BIOS
	flash_legacy skip_usb > /dev/null
	
	echo_green "Stage 1: Repartitioning the internal HDD"
	
	while :
	do
		echo "Enter the size in GB you want to reserve for Ubuntu."
		read -p "Acceptable range is 6 to $max_ubuntu_size  but $rec_ubuntu_size is the recommended maximum: " ubuntu_size
		if [ $ubuntu_size -ne $ubuntu_size 2> /dev/null]; then
			echo_red "\n\nWhole numbers only please...\n\n"
			continue
		elif [ $ubuntu_size -lt 6 -o $ubuntu_size -gt $max_ubuntu_size ]; then
			echo_red "\n\nThat number is out of range. Enter a number 6 through $max_ubuntu_size\n\n"
			continue
		fi
		break
	done
	# We've got our size in GB for ROOT-C so do the math...

	#calculate sector size for rootc
	rootc_size=$(($ubuntu_size*1024*1024*2))

	#kernc is always 16mb
	kernc_size=32768

	#new stateful size with rootc and kernc subtracted from original
	stateful_size=$(($state_size - $rootc_size - $kernc_size))

	#start stateful at the same spot it currently starts at
	stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"

	#start kernc at stateful start plus stateful size
	kernc_start=$(($stateful_start + $stateful_size))

	#start rootc at kernc start plus kernc size
	rootc_start=$(($kernc_start + $kernc_size))

	#Do the real work

	echo_green "\n\nModifying partition table to make room for Ubuntu." 

	umount -f /mnt/stateful_partition > /dev/null 2>&1

	# stateful first
	cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}

	# now kernc
	cgpt add -i 6 -b $kernc_start -s $kernc_size -l KERN-C -t "kernel" ${target_disk}

	# finally rootc
	cgpt add -i 7 -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}
	
	echo_green "Stage 1 complete; after reboot ChromeOS will \"repair\" itself."
	echo_yellow "Afterwards, you must re-download/re-run this script to complete Ubuntu setup."
	read -p "Press [Enter] to reboot and continue..."

	cleanup
	reboot
	exit
fi
echo_yellow "Stage 1 / repartitioning completed, moving on."
echo_green "Stage 2: Installing Ubuntu via chrx"

#init vars
ubuntu_package="galliumos"
ubuntu_version="latest"

#select Ubuntu metapackage
validPackages=('<galliumos>' '<ubuntu>' '<kubuntu>' '<lubuntu>' '<xubuntu>' '<edubuntu>');
echo -e "\nEnter the Ubuntu (or Ubuntu-derivative) to install.  Valid options are `echo ${validPackages[*]}`.
If no (valid) option is entered, 'galliumos' will be used."
read -p "" ubuntu_package	

packageValid=`echo ${validPackages[*]} | grep "<$ubuntu_package>"`
if [[ "$ubuntu_package" == "" || "$packageValid" == "" ]]; then
	ubuntu_package="galliumos"
fi

#select Ubuntu version
if [ "$ubuntu_package" != "galliumos" ]; then
	validVersions=('<lts>' '<latest>' '<dev>' '<15.10>' '<15.04>' '<14.10>' '<14.04>');
	echo -e "\nEnter the Ubuntu version to install. Valid options are `echo ${validVersions[*]}`. 
If no (valid) version is entered, 'latest' will be used."
	read -p "" ubuntu_version	

	versionValid=`echo ${validVersions[*]} | grep "<$ubuntu_version>"`
	if [[ "$ubuntu_version" == "" || "$versionValid" == "" ]]; then
		ubuntu_version="latest"
	fi
fi



#Install Kodi?
kodi_install=""
read -p "Do you wish to install Kodi ? [Y/n] "
if [[ "$REPLY" != "n" && "$REPLY" != "N" ]]; then
	kodi_install="-p kodi"
fi

echo_green "\nInstallation is ready to begin.\nThis is going to take some time, so be patient."

read -p "Press [Enter] to continue..."
echo -e ""

#Install via chrx
export CHRX_NO_REBOOT=1
curl -L -s -o chrx ${chrx_url}
sh ./chrx -d ${ubuntu_package} -r ${ubuntu_version} -H ChromeBox -y $kodi_install

#chrx will end with prompt for user to press enter to reboot
read -p ""
cleanup;
reboot;
}


####################
# Install OE (USB) #
####################
function OpenELEC_USB() 
{
echo_green "\nOpenELEC / USB Install"

#check free space on /tmp
free_spc=`df -m /tmp | awk 'FNR == 2 {print $4}'`
[ "$free_spc" > "500" ] || die "Temp directory has insufficient free space to create OpenELEC install media."

#Install beta version?
select_oe_version

read -p "Connect the USB/SD device (min 4GB) to be used and press [Enter] to continue.
This will erase all contents of the USB/SD device, so be sure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || die "No USB devices available onto which to install OpenELEC."
read -p "Enter the number for the device to be used for OpenELEC: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
target_disk="/dev/sd${usb_devs[${usb_dev_index}-1]}"

echo_yellow "\nSetting up and formatting partitions..."

# Do partitioning (if we haven't already)
echo -e "o\nn\np\n1\n\n+512M\nn\np\n\n\n\na\n1\nw" | fdisk ${target_disk} >/dev/null 2>&1
partprobe > /dev/null 2>&1

OE_System=${target_disk}1
OE_Storage=${target_disk}2

#format partitions, disable journaling, set labels
mkfs.ext4 -v -m0 -O ^has_journal -L System $OE_System > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to format OE partition(s); reboot and try again"
fi
e2label $OE_System System > /dev/null 2>&1
mkfs.ext4 -v -m0 -O ^has_journal -L Storage $OE_Storage > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to format OE partition(s); reboot and try again"
fi
e2label $OE_Storage Storage > /dev/null 2>&1
 
#mount partitions
if [ ! -d /tmp/System ]; then
  mkdir /tmp/System
fi
mount -t ext4 $OE_System /tmp/System > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to mount OE System partition; reboot and try again"
fi

if [ ! -d /tmp/Storage ]; then
  mkdir /tmp/Storage
fi
mount -t ext4 $OE_Storage /tmp/Storage > /dev/null
if [ $? -ne 0 ]; then
	OE_install_error "Failed to format OE Storage partition; reboot and try again"
fi

echo_yellow "Partitions formatted and mounted; installing bootloader"

#get/extract syslinux
tar_file="${dropbox_url}syslinux-5.10-md.tar.bz2"
curl -s -L -o /tmp/Storage/syslinux.tar.bz2 $tar_file > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to download syslinux; check your Internet connection and try again"
fi
cd /tmp/Storage
tar -xpjf syslinux.tar.bz2
if [ $? -ne 0 ]; then
	OE_install_error "Failed to extract syslinux download; reboot and try again"
fi

#write MBR
cd /tmp/Storage/syslinux-5.10/mbr/
dd if=./mbr.bin of=${target_disk} bs=440 count=1 > /dev/null 2>&1

#install extlinux on OpenELEC System partition
cd /tmp/Storage/syslinux-5.10/extlinux/
./extlinux -i /tmp/System/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OE_install_error "Failed to install extlinux; reboot and try again"
fi

#create extlinux.conf
echo -e "DEFAULT linux\nPROMPT 0\nLABEL linux\nKERNEL /KERNEL\nAPPEND boot=LABEL=System disk=LABEL=Storage tty quiet ssh" > /tmp/System/extlinux.conf

echo_yellow "Downloading OpenELEC"

#get OpenELEC
tar_file="${OE_version}.tar"
tar_url="${OE_url}${tar_file}"
cd /tmp/Storage
curl -L -o $tar_file $tar_url
if [ $? -ne 0 ]; then
	echo_yellow "Failed to download OE; trying dropbox mirror"
	tar_url="${dropbox_url}${tar_file}"
	curl -L -o $tar_file $tar_url
	if [ $? -ne 0 ]; then
		OE_install_error "Failed to download OpenELEC; check your Internet connection and try again"
	fi
fi
echo_yellow "\nOpenELEC download complete; installing..."
tar -xpf $tar_file
if [ $? -ne 0 ]; then
	OE_install_error "Failed to extract OpenELEC download; check your Internet connection and try again"
fi

#install
cp /tmp/Storage/${OE_version}/target/KERNEL /tmp/System/
cp /tmp/Storage/${OE_version}/target/SYSTEM /tmp/System/

#sanity check file sizes
[ -s /tmp/System/KERNEL ] || OE_install_error "OE KERNEL has file size 0"
[ -s /tmp/System/SYSTEM ] || OE_install_error "OE SYSTEM has file size 0"

#cleanup storage
rm -rf /tmp/Storage/*

#update legacy BIOS
if [ "$isChromeOS" = true ]; then
	flash_legacy > /dev/null
fi
	
echo_green "OpenELEC USB Installation Complete"
read -p "Press [Enter] to return to the main menu."
}

function OE_install_error()
{
rm -rf /tmp/Storage > /dev/null 2>&1
rm -rf /tmp/System > /dev/null 2>&1
cleanup
die "Error: $@"

}


################
# Prelim Setup #
################

function prelim_setup() {

# Must run as root 
[ $(whoami) == "root" ] || die "You need to run this script as root; use 'sudo bash <script name>'"

#get device name
device=`dmidecode | grep -m1 "Product Name:" | awk '{print $3}'`
if [ $? -ne 0 ]; then
	echo_red "Unable to determine ChromeBox/Book model; cannot continue."
	return -1
fi

#check if running under ChromeOS
cat /etc/lsb-release | grep "Chrome OS" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	isChromeOS=false
fi

#check if running under ChromiumOS
cat /etc/lsb-release | grep "Chromium OS" > /dev/null 2>&1
if [ $? -eq 0 ]; then
	isChromiumOS=true
fi

if [[ "$isChromeOS" = true || "$isChromiumOS" = true ]]; then
	#disable power mgmt
	initctl stop powerd > /dev/null 2>&1
	#set cmds
	flashromcmd=/usr/sbin/flashrom
	cbfstoolcmd=/tmp/boot/util/cbfstool
	gbbflagscmd=/usr/share/vboot/bin/set_gbb_flags.sh
else
	#set cmds
	flashromcmd=/tmp/flashrom
	cbfstoolcmd=/tmp/cbfstool
fi

#start with a known good state
cleanup

#get required tools
get_flashrom
if [ $? -ne 0 ]; then
	echo_red "Unable to download flashrom utility; cannot continue"
	return -1
fi
get_cbfstool
if [ $? -ne 0 ]; then
	echo_red "Unable to download cbfstool utility; cannot continue"
	return -1
fi

return 0
}


###########
# Cleanup #
###########
function cleanup() {

#remove temp files, unmount temp stuff
if [ -d /tmp/boot/util ]; then
	rm -rf /tmp/boot/util > /dev/null 2>&1
fi
umount /tmp/boot > /dev/null 2>&1
umount /tmp/Storage > /dev/null 2>&1
umount /tmp/System > /dev/null 2>&1
umount /tmp/urfs/proc > /dev/null 2>&1
umount /tmp/urfs/dev/pts > /dev/null 2>&1
umount /tmp/urfs/dev > /dev/null 2>&1
umount /tmp/urfs/sys > /dev/null 2>&1
umount /tmp/urfs > /dev/null 2>&1
umount /tmp/usb > /dev/null 2>&1
}


########################
# Firmware Update Menu #
########################
function menu_fwupdate() {
    clear
	echo -e "${NORMAL}\n ChromeOS device Firmware Utility ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Matt DeVillier <matt.devillier@gmail.com>\n ${NORMAL}"
	echo -e "${NORMAL} Paypal towards beer/programmer fuel welcomed at above address :)\n ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
	echo -e "${MENU}**${NORMAL}    Stock Firmware ${NORMAL}"
	if [ "$isChromeOS" = false ]; then
		echo -e "${GRAY_TEXT}**${GRAY_TEXT} 1)${GRAY_TEXT} Set Boot Options (gbb flags)${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT} 2)${GRAY_TEXT} Set Hardware ID (hwid) ${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT} 3)${GRAY_TEXT} Update Legacy BIOS (RW_LEGACY / SeaBIOS)${GRAY_TEXT}"
		echo -e "${MENU}**${NUMBER} 4)${MENU} Restore Stock Firmware ${NORMAL}"	
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}"
	else
		echo -e "${MENU}**${NUMBER} 1)${MENU} Set Boot Options (gbb flags)${NORMAL}"
		echo -e "${MENU}**${NUMBER} 2)${MENU} Set Hardare ID (hwid) ${NORMAL}"
		echo -e "${MENU}**${NUMBER} 3)${MENU} Update Legacy BIOS (RW_LEGACY / SeaBIOS)${NORMAL}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT} 4)${GRAY_TEXT} Restore Stock Firmware ${GRAY_TEXT}"
		echo -e "${MENU}**${NORMAL}"
	fi
	echo -e "${MENU}**${NORMAL}    Custom coreboot Firmware ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Install/Update Custom coreboot Firmware ${NORMAL}"
	echo -e "${MENU}**${NORMAL}"
	echo -e "${MENU}**${NUMBER} 6)${NORMAL} Reboot ${NORMAL}"
	echo -e "${MENU}**${NUMBER} 7)${NORMAL} Power Off ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or ${RED_TEXT}q to quit${NORMAL}"
    
	read opt
			
	while [ opt != '' ]
		do
		if [[ $opt = "q" ]]; then 
				exit;
		else
			if [ "$isChromeOS" = true ]; then
				case $opt in
					1)	set_boot_options;
						menu_fwupdate;
						;;
					2)	set_hwid;	
						menu_fwupdate;
						;;
					3)	update_legacy;	
						menu_fwupdate;
						;;
					*)
						;;
				esac
			else 
				case $opt in
					4)	restore_stock_firmware;
						menu_fwupdate;
						;;
					*)
						;;
				esac
			fi
			
			case $opt in
			
			5)	flash_coreboot;
				menu_fwupdate;
				;;						
			6)	echo -e "\nRebooting...\n";
				cleanup;
				reboot;
				exit;
				;;
			7)	echo -e "\nPowering off...\n";
				cleanup;
				poweroff;
				exit;
				;;
			q)	exit;
				;;
			\n)	exit;
				;;
			*)	clear;
				menu_fwupdate;
				;;
		esac
	fi
	done
}


#############
# Kodi Menu #
#############
function menu_kodi() {
    clear
	echo -e "${NORMAL}\n ChromeBox Kodi E-Z Setup ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Matt DeVillier <matt.devillier@gmail.com>\n ${NORMAL}"
	echo -e "${NORMAL} Paypal towards beer/programmer fuel welcomed at above address :)\n ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
	if [ "$isChromeOS" = false ]; then
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}     Dual Boot  (only available in ChromeOS)${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  1)${GRAY_TEXT} Install: ChromeOS + Ubuntu ${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  2)${GRAY_TEXT} Install: ChromeOS + OpenELEC ${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  3)${GRAY_TEXT} Install: OpenELEC on USB ${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  4)${GRAY_TEXT} Set Boot Options ${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  5)${GRAY_TEXT} Update Legacy BIOS (SeaBIOS)${GRAY_TEXT}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}"
	else
		echo -e "${MENU}**${NORMAL}     Dual Boot ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  1)${MENU} Install: ChromeOS + Ubuntu ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  2)${MENU} Install: ChromeOS + OpenELEC ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  3)${MENU} Install: OpenELEC on USB ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  4)${MENU} Set Boot Options ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  5)${MENU} Update Legacy BIOS (SeaBIOS)${NORMAL}"
		echo -e "${MENU}**${NORMAL}"
	fi
	echo -e "${MENU}**${NORMAL}     Standalone ${NORMAL}"
    echo -e "${MENU}**${NUMBER}  6)${MENU} Install/Update: Custom coreboot Firmware ${NORMAL}"
    echo -e "${MENU}**${NUMBER}  7)${MENU} Create OpenELEC Install Media ${NORMAL}"
	echo -e "${MENU}**${NUMBER}  8)${MENU} Create Kodibuntu Install Media ${NORMAL}"
	echo -e "${MENU}**${NORMAL}"
	echo -e "${MENU}**${NUMBER}  9)${NORMAL} Reboot ${NORMAL}"
	echo -e "${MENU}**${NUMBER} 10)${NORMAL} Power Off ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or ${RED_TEXT}q to quit${NORMAL}"
    
	read opt
	
	while [ opt != '' ]
		do
		if [[ $opt = "q" ]]; then 
				exit;
		else
			if [ "$isChromeOS" = true ]; then
				case $opt in
					1)	clear;
						chrUbuntu;
						menu_kodi;
						;;
					2)  clear;
						chrOpenELEC;
						menu_kodi;
						;;
					3)	clear;
						OpenELEC_USB;
						menu_kodi;
						;;
					4)	clear;
						set_boot_options_kodi;
						menu_kodi;
						;;
					5)	clear;
						update_legacy;	
						menu_kodi;
						;;
					*)
						;;
				esac
			fi
			
			case $opt in
				
			6)	clear;
				flash_coreboot;
				menu_kodi;
				;;		
			7) 	clear;
				create_oe_install_media;
				menu_kodi;
				;;				
			8) 	clear;
				create_kb_install_media;
				menu_kodi;
				;;
			9)	echo -e "\nRebooting...\n";
				cleanup;
				reboot;
				exit;
				;;
			10)	echo -e "\nPowering off...\n";
				cleanup;
				poweroff;
				exit;
				;;
			q)	cleanup;
				exit;
				;;
			\n)	cleanup;
				exit;
				;;
			*)	clear;
				menu_kodi;
				;;
		esac
	fi
	done
}



