#!/bin/bash
#
# This script will install/update the custom coreboot 
# firmware on a Haswell-based Asus/HP/Acer/Dell ChromeBox
#
# Created by Matt DeVillier	<matt.devillier@gmail.com>
#
# May be freely distributed and modified as needed, 
# as long as proper attribution is given.
#

#globals
dropbox_url="https://dl.dropboxusercontent.com/u/98309225/"
flashromcmd="/tmp/flashrom"
cbfstoolcmd="/tmp/cbfstool"
preferUSB=false
useHeadless=false
addPXE=false
pxeDefault=false

# Must run as root 
if [ $(whoami) != "root" ]; then
	echo -e "You need to run this script as root; use 'sudo bash <script name>'"
	exit
fi

#header
echo -e "\nChromeBox Firmware Updater v1.4"
echo -e "(c) Matt DeVillier <matt.devillier@gmail.com>"
echo -e "$***************************************************"

#show warning
echo -e "\n!! WARNING !!
This firmware is only valid for Haswell-based Asus/HP/Acer/Dell
ChromeBoxes with Celeron 2955U/2957U, Core i3-4010U/4030U, Core i7-4600U CPUs
which are already running my custom coreboot firmware.
Use on any other device will almost certainly brick it.\n"

read -p "Do you wish to continue? [y/N] "
[ "$REPLY" == "y" ] || exit

working_dir=`pwd`
cd /tmp

#check if update needed
echo -e "\nChecking if update available...\n"
curl -s -L -O ${dropbox_url}/latest.version
if [[ $? -ne 0 || ! -f latest.version ]]; then 
	echo -e "Error downloading firmware version information; cannot proceed."
	#restore working dir
	cd ${working_dir}
	exit
fi
curr_fw=$(echo `dmesg | grep -m1 "DMI: Google Panther" | awk '{print $NF}'` | awk -F'/' '{print $3$1$2}')
if [ "$curr_fw" == "" ]; then
	curr_fw=$(echo `dmesg | grep -m1 "Panther, BIOS" | awk '{print $NF}'` | awk -F'/' '{print $3$1$2}')
	if [ "$curr_fw" == "" ]; then
		echo -e "Error: unable to determine current firmware version; aborting."
		exit
	fi
fi

latest_fw=`cat latest.version | awk '{print $1}'`
coreboot_file=`cat latest.version | awk '{print $2}'`

if [ "$curr_fw" -ge "$latest_fw" ]; then
	echo -e "You already have the latest firmware ($latest_fw)\n"
	read -p "Would you like to install anyway? [y/N] "
	if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
		exit
	fi
else
	echo -e "Firmware update available ($latest_fw)"
fi

#headless?
echo -e "\nInstall \"headless\" firmware? This is only needed for servers"
read -p "running without a connected display. [y/N] "
if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
	useHeadless=true
fi

#USB boot priority
echo -e ""
read -p "Default to booting from any connected USB device? If N, always boot from the internal SSD unless selected from boot menu. [y/N] "
if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
	preferUSB=true
fi

#addPXE?
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

#check for/get flashrom
if [ ! -f ${flashromcmd} ]; then
	echo -e "\nDownloading flashrom utility"
	curl -s -L -O ${dropbox_url}/flashrom.tar.gz
	if [ $? -ne 0 ]; then 
		echo -e "Error downloading flashrom; cannot proceed."
		#restore working dir
		cd ${working_dir}
		exit
	fi
	tar -zxf flashrom.tar.gz
	if [ $? -ne 0 ]; then 
		echo -e "Error extracting flashrom; cannot proceed."
		#restore working dir
		cd ${working_dir}
		exit
	fi
	#set +x
	chmod +x ./flashrom
fi

#check for/get cbfstool
if [ ! -f ${cbfstoolcmd} ]; then
	echo -e "\nDownloading cbfstool utility"
	curl -s -L -O ${dropbox_url}/cbfstool.tar.gz
	if [ $? -ne 0 ]; then 
		echo -e  "Error downloading cbfstool; cannot proceed."
		#restore working dir
		cd ${working_dir}
		exit
	fi
	tar -zxf cbfstool.tar.gz
	if [ $? -ne 0 ]; then 
		echo -e "Error extracting cbfstool; cannot proceed."
		#restore working dir
		cd ${working_dir}
		exit
	fi
	#set +x
	chmod +x ./cbfstool
fi

#read existing firmware and try to extract MAC address info
echo -e "\nReading current firmware"
${flashromcmd} -r bios.bin > /dev/null 2>&1
if [ $? -ne 0 ]; then 
	echo -e "Failure reading current firmware; cannot proceed."
	cd ${working_dir}
	exit
fi

#check if contains MAC address, extract
${cbfstoolcmd} bios.bin extract -n vpd.bin -f vpd.bin >& /dev/null
if [ $? -ne 0 ]; then 
	echo -e "Failure extracting MAC address from current firmware; default will be used"
fi

#download firmware file
echo -e "\nDownloading coreboot firmware"
curl -s -L -O "${dropbox_url}${coreboot_file}"
curl -s -L -O "${dropbox_url}${coreboot_file}.md5"
curl -s -L -O "${dropbox_url}bootorder"
curl -s -L -O "${dropbox_url}hsw_1038_cbox_headless.dat"
curl -s -L -O "${dropbox_url}10ec8168.rom"
#verify checksum on downloaded file
md5sum -c ${coreboot_file}.md5 > /dev/null 2>&1
if [ $? -eq 0 ]; then
	#check if we have a VPD to restore
	if [ -f /tmp/vpd.bin ]; then
		${cbfstoolcmd} ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw	
	fi
	#preferUSB?
	if [ "$preferUSB" = true  ]; then
		${cbfstoolcmd} ${coreboot_file} add -n bootorder -f /tmp/bootorder -t raw	
	fi
	#useHeadless?
	if [ "$useHeadless" = true  ]; then
		${cbfstoolcmd} ${coreboot_file} remove -n pci8086,0406.rom
		${cbfstoolcmd} ${coreboot_file} add -f /tmp/hsw_1038_cbox_headless.dat -n pci8086,0406.rom -t optionrom
	fi
	#addPXE?
	if [ "$addPXE" = true  ]; then
		${cbfstoolcmd} ${coreboot_file} add -f /tmp/10ec8168.rom -n pci10ec,8168.rom -t optionrom
		#PXE default?
		if [ "$pxeDefault" = true  ]; then
			${cbfstoolcmd} ${coreboot_file} extract -n bootorder -f /tmp/bootorder > /dev/null 2>&1
			${cbfstoolcmd} ${coreboot_file} remove -n bootorder > /dev/null 2>&1
			sed -i '1s/^/\/pci@i0cf8\/pci-bridge@1c\/*@0\n/' /tmp/bootorder
			${cbfstoolcmd} ${coreboot_file} add -n bootorder -f /tmp/bootorder -t raw
		fi
	fi
	#flash coreboot firmware
	echo -e "\nInstalling firmware: ${coreboot_file}"
	${flashromcmd} -w "${coreboot_file}" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "\ncoreboot firmware successfully updated."
		echo -e "Please power cycle your ChromeBox to complete the update.\n"
	else
		echo -e "\nAn error occurred flashing the coreboot firmware. DO NOT REBOOT!"
	fi
else
	#download checksum fail
	echo -e  "\ncoreboot firmware download checksum fail; download corrupted, cannot flash."
fi	
#clean up
cd ${working_dir}

