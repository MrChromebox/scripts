#!/bin/bash
#


###################
# flash RW_LEGACY #
###################
function flash_rwlegacy()
{

#set working dir
cd /tmp

# set dev mode boot flags 
if [ "${isChromeOS}" = true ]; then
    crossystem dev_boot_legacy=1 dev_boot_signed_only=0 > /dev/null 2>&1
fi

echo_green "\nInstall/Update Legacy BIOS (RW_LEGACY)"

#determine proper file 
if [[ "$isHswBox" = true || "$isBdwBox" = true ]]; then
    seabios_file=$seabios_hswbdw_box
elif [ "$isHswBook" = true ]; then
    seabios_file=$seabios_hsw_book
elif [ "$isBdwBook" = true ]; then
    seabios_file=$seabios_bdw_book
elif [ "$isBaytrail" = true ]; then
    seabios_file=$seabios_baytrail
else
    echo_red "Unknown or unsupported device (${device}); cannot update Legacy BIOS."; return 1
fi


preferUSB=false
useHeadless=false
if [ -z "$1" ]; then
    echo -e ""
    #USB boot priority
    read -p "Default to booting from USB? If N, always boot from internal storage unless selected from boot menu. [y/N] "
    [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && preferUSB=true    
    echo -e ""
    #headless?
    if [ "$seabios_file" = "$seabios_hswbdw_box" ]; then
        read -p "Install \"headless\" firmware? This is only needed for servers running without a connected display. [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && useHeadless=true
        echo -e ""
    fi
fi

#download SeaBIOS update
echo_yellow "\nDownloading Legacy BIOS update"
curl -s -L -O ${dropbox_url}${seabios_file}.md5
curl -s -L -O ${dropbox_url}${seabios_file}
#verify checksum on downloaded file
md5sum -c ${seabios_file}.md5 --quiet 2> /dev/null
[[ $? -ne 0 ]] && { exit_red "Legacy BIOS download checksum fail; download corrupted, cannot flash"; return 1; }

#preferUSB?
if [ "$preferUSB" = true  ]; then
    curl -s -L -o bootorder "${dropbox_url}bootorder.usb"
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
        rc0=$?
        ${cbfstoolcmd} ${seabios_file} add -f ${hswbdw_headless_vbios} -n pci8086,0406.rom -t optionrom > /dev/null 2>&1
        rc1=$?
        if [[ "$rc0" -ne 0 || "$rc1" -ne 0 ]]; then
            echo_red "Warning: error installing headless VGA BIOS"
        else
            echo_yellow "Headless VGA BIOS installed"
        fi
    fi      
fi
#flash updated legacy BIOS
echo_yellow "Installing Legacy BIOS / RW_LEGACY (${seabios_file})"
${flashromcmd} -w -i RW_LEGACY:${seabios_file} > /dev/null 2>&1
echo_green "Legacy BIOS successfully updated."  
}


######################
# update legacy BIOS #
######################
function update_rwlegacy()
{
flash_rwlegacy
read -p "Press [Enter] to return to the main menu."
}


#############################
# Install coreboot Firmware #
#############################
function flash_coreboot()
{
echo_green "\nInstall/Update Custom coreboot Firmware"
echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

read -p "Do you wish to continue? [y/N] "
[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled if in ChromeOS
if [[ "$isChromeOS" = true && ( "$(crossystem wpsw_cur)" == "1" || "$(crossystem wpsw_boot)" == "1" ) ]]; then
    exit_red "\nHardware write-protect enabled, cannot flash coreboot firmware."; return 1
fi

#determine correct file / URL
firmware_source=${firmware_source_main}
[[ "$isHswBook" = true || "$isBdwBook" = true ]] && firmware_source=${firmware_source_coolstar}
if [ "$isHswBox" = true ]; then
    coreboot_file=$coreboot_hsw_box
elif [[ "$isBdwBox" = true || "$isHswBook" = true || "$isBdwBook" = true || "$device" = "stumpy" || "$bayTrailHasFullROM" = "true" ]]; then
    eval coreboot_file=$`echo "coreboot_${device}"`
else
    exit_red "Unknown or unsupported device (${device}); cannot continue."; return 1
fi

#peppy special case
if [ "$device" = "peppy" ]; then
    hasElan=$(cat /proc/bus/input/devices | grep "Elan")
    hasCypress=$(cat /proc/bus/input/devices | grep "Cypress")
    if [[ $hasElan = "" && $hasCypress = "" ]]; then
        read -p "Unable to automatically determine trackpad type. Does your Peppy have an Elan pad? [y/N]"
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && coreboot_file=${coreboot_peppy_elan}
    elif [[ $hasElan != "" ]]; then 
        coreboot_file=${coreboot_peppy_elan}
    fi
fi

#read existing firmware and try to extract MAC address info
echo_yellow "Reading current firmware"
${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
if [ $? -ne 0 ]; then 
    echo_red "Failure reading current firmware; cannot proceed."
    read -p "Press [Enter] to return to the main menu."
    return;
fi

if [[ "$isHswBox" = true || "$isBdwBox" = true || "$device" = "ninja" ]]; then
    #check if contains MAC address, extract
    extract_vpd /tmp/bios.bin
    if [ $? -ne 0 ]; then
        #TODO - user enter MAC manually?
        echo_red "\nWarning: firmware doesn't contain VPD info - skipping persistence of MAC address."
    fi
fi

#check if existing firmware is stock
grep -obUa "vboot" /tmp/bios.bin >/dev/null
if [ $? -eq 0 ]; then
    read -p "Create a backup copy of your stock firmware? [Y/n]

This is highly recommended in case you wish to return your device to stock 
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. "
    [ "$REPLY" = "n" ] || backup_firmware
fi
#check that backup succeeded
[ $? -ne 0 ] && return 1

#headless?
useHeadless=false
if [[ "$isHswBox" = true || "$isBdwBox" = true ]]; then
    echo -e ""
    read -p "Install \"headless\" firmware? This is only needed for servers running without a connected display. [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        useHeadless=true
    fi
fi

#USB boot priority
preferUSB=false
echo -e ""
read -p "Default to booting from USB? If N, always boot from the internal SSD unless selected from boot menu. [y/N] "
if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
    preferUSB=true
fi

#add PXE?
addPXE=false
if [[ "$isHswBox" = true || "$isBdwBox" = true || "$device" = "ninja" ]]; then
    echo -e ""
    read -p "Add PXE network booting capability? (This is not needed for by most users) [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        addPXE=true
        echo -e ""
        read -p "Boot PXE by default? (will fall back to SSD/USB) [y/N] "
        if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
            pxeDefault=true 
        fi
    fi
fi

#download firmware file
cd /tmp
echo_yellow "\nDownloading coreboot firmware"
curl -s -L -O "${firmware_source}${coreboot_file}"
curl -s -L -O "${firmware_source}${coreboot_file}.md5"

#verify checksum on downloaded file
md5sum -c ${coreboot_file}.md5 --quiet > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "coreboot firmware download checksum fail; download corrupted, cannot flash."; return 1; }

#check if we have a VPD to restore
if [ -f /tmp/vpd.bin ]; then
    ${cbfstoolcmd} ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw > /dev/null 2>&1
fi
#preferUSB?
if [ "$preferUSB" = true  ]; then
    curl -s -L -o bootorder "${dropbox_url}bootorder.usb"
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

#disable software write-protect
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error disabling software write-protect; unable to flash firmware."; return 1
fi

#flash coreboot firmware
echo_yellow "Installing custom coreboot firmware (${coreboot_file})"
${flashromcmd} -w "${coreboot_file}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_green "Custom coreboot firmware successfully installed/updated."
else
    echo_red "An error occurred flashing the coreboot firmware. DO NOT REBOOT!"
fi

read -p "Press [Enter] to return to the main menu."
}


##########################
# Restore Stock Firmware #
##########################
function restore_stock_firmware()
{
echo_green "\nRestore Stock Firmware"
echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

read -p "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

#spacing
echo -e ""

firmware_file=""

read -p "Do you have a firmware backup file on USB? [y/N] "
if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
    read -p "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "      
    list_usb_devices
    [ $? -eq 0 ] || { exit_red "No USB devices available to read firmware backup."; return 1; }
    read -p "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
    [ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || { exit_red "Error: Invalid option selected."; return 1; }
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
    echo_yellow "\n(Potential) Firmware Files on USB:"
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
    if [[ "$isHswBox" = false && "$isBdwBox" = false && "$device" != "ninja" ]]; then
        exit_red "\nUnfortunately I don't have a stock firmware available to download for \"$device\" at this time."; return 1
    fi

    #download firmware extracted from recovery image
    echo_yellow "\nThat's ok, I'll download one for you. Which ChromeBox do you have?"
    if [ "$device" != "panther" ]; then
        echo_yellow "I'm pretty sure it's \"$device\""
    fi
    
    echo "1) Asus CN60 (Haswell) [Panther]"
    echo "2) HP CB1 (Haswell) [Zako]"
    echo "3) Dell 3010 (Haswell) [Tricky]"
    echo "4) Acer CXI (Haswell) [McCloud]"
    echo "5) Asus CN62 (Broadwell) [Guado]"
    echo "6) Acer CXI2 (Broadwell) [Rikku]"
    echo "7) Lenovo ThinkCentre (Broadwell) [Tidus]"
    echo "8) AOpen Chromebox Commercial (Baytrail) [Ninja]"
    echo ""
    read -p "? " fw_num
    if [[ $fw_num -lt 1 ||  $fw_num -gt 8 ]]; then
		exit_red "Invalid input - cancelling"; return
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
        6) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/qd59yozS;
            ;;
        7) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/uidxAG1E;
            ;;
        8) curl -s -L -o /tmp/stock-firmware.rom https://db.tt/3xsP2Qtj
            ;;
    esac
    [[ $? -ne 0 ]] && { exit_red "Error downloading; unable to restore stock firmware."; return 1; }
    
    #read current firmware to extract VPD
    echo_yellow "Reading current firmware"
    ${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "Failure reading current firmware; cannot proceed."; return 1; }
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
[[ $? -ne 0 ]] && { exit_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"; return 1; }
#all good
echo_green "Stock firmware successfully restored."
echo_green "After rebooting, you will need to restore ChromeOS using the ChromeOS recovery media."
read -p "Press [Enter] to return to the main menu."
}


########################
# Extract firmware VPD #
########################
function extract_vpd() 
{
#check params
[[ -z "$1" ]] && { exit_red "Error: extract_vpd(): missing function parameter"; return 1; }

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
if [ $? -ne 0 ]; then
    backup_fail "No USB devices available to store firmware backup."
    return 1
fi

read -p "Enter the number for the device to be used for firmware backup: " usb_dev_index
if [ $usb_dev_index -le 0 ] || [ $usb_dev_index  -gt $num_usb_devs ]; then
    backup_fail "Error: Invalid option selected."
    return 1
fi

usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
mkdir /tmp/usb > /dev/null 2>&1
mount "${usb_device}" /tmp/usb > /dev/null 2>&1
if [ $? != 0 ]; then
    mount "${usb_device}1" /tmp/usb
fi
if [ $? -ne 0 ]; then
    backup_fail "USB backup device failed to mount; cannot proceed."
    return 1
fi
backupname="stock-firmware-${device}-$(date +%Y%m%d).rom"
echo_yellow "\nSaving firmware backup as ${backupname}"
cp /tmp/bios.bin /tmp/usb/${backupname}
if [ $? -ne 0 ]; then
    backup_fail "Failure reading stock firmware for backup; cannot proceed."
    return 1
fi
sync
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb
echo_green "Firmware backup complete. Remove the USB stick and press [Enter] to continue."
read -p ""
}

function backup_fail()
{
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb > /dev/null 2>&1
exit_red "\n$@"
}


####################
# Set Boot Options #
####################
function set_boot_options() 
{
# set boot options via firmware boot flags
# ensure hardware write protect disabled
if [[ "$isChromeOS" = true && "$(crossystem wpsw_cur)" != *"0"* ]]; then
    exit_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot set boot options."; return 1
fi

[[ -z "$1" ]] && legacy_text="Legacy Boot" || legacy_text="$1"


echo_green "\nSet Boot Options (GBB Flags)"
echo_yellow "Select your preferred boot delay and default boot option.
You can always override the default using [CTRL-D] or 
[CTRL-L] on the developer mode boot splash screen"

echo -e "1) Short boot delay (1s) + ${legacy_text} default
2) Long boot delay (30s) + ${legacy_text} default
3) Short boot delay (1s) + ChromeOS default
4) Long boot delay (30s) + ChromeOS default
5) Reset to factory default
6) Cancel/exit
"
local _flags=0x0
while :
do
    read -p "? " n  
    case $n in
        1) _flags=0x489; break;;
        2) _flags=0x488; break;;
        3) _flags=0x89; break;;
        4) _flags=0x88; break;;
        5) _flags=0x0; break;;
        6) read -p "Press [Enter] to return to the main menu."; break;;
        *) echo -e "invalid option";;
    esac
done
[[ $n -eq 6 ]] && return
echo_yellow "\nSetting boot options..."
${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to set boot options."; return 1; }
${gbbutilitycmd} --set --flags="${_flags}" /tmp/gbb.temp > /dev/null
[[ $? -ne 0 ]] && { exit_red "\nError setting boot options."; return 1; }
${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to set boot options."; return 1; }
echo_green "\nBoot options successfully set."
read -p "Press [Enter] to return to the main menu."
}


###################
# Set Hardware ID #
###################
function set_hwid() 
{
# set hwid using gbb_utility
# ensure hardware write protect disabled
if [[ "$isChromeOS" = true && "$(crossystem wpsw_cur)" != *"0"* ]]; then
    exit_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot set hwid."; return 1
fi

echo_green "Set Hardware ID (hwid) using gbb_utility"

#get current hwid
_hwid="$(crossystem hwid)" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_yellow "Current hwid is $_hwid"
fi
read -p "Enter a new hwid (use all caps): " hwid
echo -e ""
read -p "Confirm changing hwid to $hwid [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nSetting hardware ID..."
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to set hwid."; return 1; }
    ${gbbutilitycmd} --set --hwid="${hwid}" /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError setting hwid."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to set hwid."; return 1; }
    echo_green "Hardware ID successfully set."
fi
read -p "Press [Enter] to return to the main menu."
}


####################
# Modify BOOT_STUB #
####################
function modify_boot_stub() 
{
# backup BOOT_STUB into RW_LEGACY
# modify BOOT_STUB for legacy booting
# flash back modified slots

#check baytrail
[[ "$isBaytrail" = false ]] && { exit_red "\nThis functionality is only available for Baytrail ChromeOS devices currently"; return 1; }

echo_green "\nInstall/Update Legacy BIOS (BOOT_STUB)"

echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

echo_yellow "Also, flashing the BOOT_STUB will remove the ability to run ChromeOS,
so only proceed if you're going to run Linux exclusively."

read -p "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y"|| "$REPLY" = "y" ]] || return

#check WP status
if [[ "$isChromeOS" = true && "$(crossystem wpsw_cur)" != "0" && "$(crossystem wpsw_boot)" != "0" ]]; then
    exit_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot modify BOOT_STUB."; return 1
fi

# cd to working dir
cd /tmp

#download SeaBIOS payload
curl -s -L -O ${dropbox_url}/${bootstub_payload_baytrail}
curl -s -L -O ${dropbox_url}/${bootstub_payload_baytrail}.md5 

#verify checksum on downloaded file
md5sum -c ${bootstub_payload_baytrail}.md5 --quiet > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "SeaBIOS payload download checksum fail; download corrupted, cannot flash."; return 1; }

#read BOOT_STUB and RW_LEGACY slots
echo_yellow "\nReading current firmware"
${flashromcmd} -r -i BOOT_STUB:boot_stub.bin  > /dev/null 2>&1
rc0=$?
${flashromcmd} -r -i RW_LEGACY:rw_legacy.bin  > /dev/null 2>&1
rc1=$?
[[ $rc0 -ne 0 || $rc1 -ne 0 ]] && { exit_red "Error reading current firmware, unable to flash."; return 1; }

#if BOOT_STUB is stock
${cbfstoolcmd} boot_stub.bin extract -n fallback/vboot -f whocares -m x86 > /dev/null 2>&1
if [[ "$isChromeOS" = true ||  $? -eq 0 ]]; then

    #copy BOOT_STUB into top 1MB of RW_LEGACY
    echo_yellow "Backing up stock BOOT_STUB"
    dd if=boot_stub.bin of=rw_legacy.bin bs=1M conv=notrunc > /dev/null 2>&1
    #flash back
    ${flashromcmd} -w -i RW_LEGACY:rw_legacy.bin > /dev/null 2>&1
else
    echo_yellow "Non-stock BOOT_STUB, skipping backup"
fi


#USB boot priority
read -p "Default to booting from USB? If N, always boot from internal storage unless selected from boot menu. [y/N] "
if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
    curl -s -L -o bootorder ${dropbox_url}/bootorder.usb 
else
    curl -s -L -o bootorder ${dropbox_url}/bootorder.hdd
fi


#modify BOOT_STUB for legacy booting
echo_yellow "\nModifying BOOT_STUB for legacy boot"
${cbfstoolcmd} boot_stub.bin remove -n fallback/payload > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n fallback/vboot > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n bootorder > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/boot-menu-wait > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard0 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard1 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard2 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard3 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard4 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard5 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin add-payload -n fallback/payload -f ${bootstub_payload_baytrail} -c lzma > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "There was an error modifying the BOOT_STUB payload, nothing has been flashed."; return 1
else
    ${cbfstoolcmd} boot_stub.bin add -n bootorder -f bootorder -t raw > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 3000 -n etc/boot-menu-wait > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd071c000 -n etc/sdcard0 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd071d000 -n etc/sdcard1 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd071f000 -n etc/sdcard2 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd081f000 -n etc/sdcard3 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd091c000 -n etc/sdcard4 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd091f000 -n etc/sdcard5 > /dev/null 2>&1

    #flash modified BOOT_STUB back
    echo_yellow "Flashing modified BOOT_STUB"
    ${flashromcmd} -w -i BOOT_STUB:boot_stub.bin > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        #flash back stock BOOT_STUB
        dd if=rw_legacy.bin of=boot_stub.bin bs=1M count=1 > /dev/null 2>&1
        ${flashromcmd} -w -i BOOT_STUB:boot_stub.bin > /dev/null 2>&1
        echo_red "There was an error flashing the modified BOOT_STUB, but the stock one has been restored."
    else
        echo_green "Legacy boot capable BOOT_STUB successfully flashed"
    fi
fi
read -p "Press [Enter] to return to the main menu."
}


#####################
# Restore BOOT_STUB #
#####################
function restore_boot_stub() 
{
# read backed-up BOOT_STUB from RW_LEGACY
# verify valid for device
# flash back to BOOT_STUB
# set GBB flags to ensure dev mode, legacy boot
# offer RW_LEGACY update

#check baytrail
[[ "$isBaytrail" = false ]] && { exit_red "\nThis functionality is only available for Baytrail ChromeOS devices currently"; return 1; }
#check OS
[[ "$isChromeOS" = true ]] && { exit_red "\nThis functionality is not available under ChromeOS."; return 1; }

echo_green "\nRestore stock BOOT_STUB from backup"

echo_yellow "Warning: this function is only intended for users who installed 
a legacy boot capable BOOT_STUB via this script.  If you installed 
a different one (eg, John Lewis') then this will not work, and
could potentially brick your device."

read -p "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return


# cd to working dir
cd /tmp

#read backed-up BOOT_STUB from RW_LEGACY slot
echo_yellow "\nReading current firmware"
${flashromcmd} -r -i BOOT_STUB:boot_stub.bin  > /dev/null 2>&1
rc0=$?
${flashromcmd} -r -i RW_LEGACY:rw_legacy.bin > /dev/null 2>&1
rc1=$?
${flashromcmd} -r -i GBB:gbb.bin > /dev/null 2>&1
rc2=$?
if [[ $rc0 -ne 0 || $rc1 -ne 0  || $rc2 -ne 0 ]]; then
    exit_red "Error reading current firmware, unable to flash."; return 1
fi

#truncate to 1MB
dd if=rw_legacy.bin of=boot_stub.stock bs=1M count=1 > /dev/null 2>&1

#verify valid BOOT_STUB
${cbfstoolcmd} boot_stub.stock extract -n config -f config.${device} > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "No valid BOOT_STUB backup found; unable to restore stock BOOT_STUB"; return 1; }

#verify valid for this device
cat config.${device} | grep ${device} > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "No valid BOOT_STUB backup found; unable to restore stock BOOT_STUB"; return 1; }

#restore stock BOOT_STUB
echo_yellow "\Restoring stock BOOT_STUB"
${flashromcmd} -w -i BOOT_STUB:boot_stub.stock > /dev/null 2>&1
if [ $? -ne 0 ]; then
    #flash back non-stock BOOT_STUB
    ${flashromcmd} -w -i BOOT_STUB:boot_stub.bin > /dev/null 2>&1
    exit_red "There was an error restoring the stock BOOT_STUB, but the modified one has been left in place."; return 1
fi

#ensure GBB flags are sane
${gbbutilitycmd} --set --flags=0x88 gbb.bin  > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo_red "Warning: there was an error setting the GBB flags." || return 1
fi
${flashromcmd} -w -i GBB:gbb.bin > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo_red "Warning: there was an error flashing the GBB region; GBB flags in unknown state" || return 1
fi

#update legacy BIOS
flash_rwlegacy skip_usb > /dev/null

echo_green "Stock BOOT_STUB successfully restored"

#all done
read -p "Press [Enter] to return to the main menu."
}

########################
# Firmware Update Menu #
########################
function menu_fwupdate() {
    clear
    echo -e "${NORMAL}\n ChromeOS device Firmware Utility ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Mr. Chromebox <mr.chromebox@gmail.com>\n ${NORMAL}"
    echo -e "${NORMAL} Paypal towards beer/programmer fuel welcomed at above address :)\n ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NORMAL}"
    echo -e "${MENU}**${NUMBER} 1)${MENU} Install/Update Legacy BIOS in RW_LEGACY slot${NORMAL}"
    if [ "$isBaytrail" = true ]; then
        echo -e "${MENU}**${NUMBER} 2)${MENU} Install/Update Legacy BIOS in BOOT_STUB slot ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 2)${GRAY_TEXT} Install/Update Legacy BIOS in BOOT_STUB slot ${NORMAL}"
    fi
    if [[ "$isBaytrail" = false || "$bayTrailHasFullROM" = "true" ]]; then
        echo -e "${MENU}**${NUMBER} 3)${MENU} Install/Update Custom coreboot Firmware (Full ROM) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 3)${GRAY_TEXT} Install/Update Custom coreboot Firmware (Full ROM) ${NORMAL}"
    fi
    echo -e "${MENU}**${NUMBER} 4)${MENU} Set Boot Options (GBB flags)${NORMAL}"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Set Hardware ID (hwid) ${NORMAL}"
    if [[ "$isBaytrail" = true && "$isChromeOS" = false ]]; then
        echo -e "${MENU}**${NUMBER} 6)${MENU} Restore Stock BOOT_STUB slot ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 6)${GRAY_TEXT} Restore Stock BOOT_STUB slot ${NORMAL}"
    fi
    if [[ "$isChromeOS" = false  && ( "$isBaytrail" = false || "$bayTrailHasFullROM" = "true" ) ]]; then
        echo -e "${MENU}**${NUMBER} 7)${MENU} Restore Stock Firmware ${NORMAL}" 
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 7)${GRAY_TEXT} Restore Stock Firmware ${NORMAL}" 
    fi
    echo -e "${MENU}**${NORMAL}"
    echo -e "${MENU}**${NUMBER} 8)${NORMAL} Reboot ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 9)${NORMAL} Power Off ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or ${RED_TEXT}q to quit${NORMAL}"
    
    read opt
            
    while [ opt != '' ]
        do
        if [[ $opt = "q" ]]; then 
                exit;
        else
            if [ "$isBaytrail" = true ]; then
                case $opt in
                    2)  modify_boot_stub;
                        menu_fwupdate;
                        ;;
                esac
                if [ "$isChromeOS" = false ]; then
                    case $opt in
                        6)  restore_boot_stub;
                            menu_fwupdate;
                            ;;
                    esac
                fi
                if [[ "$bayTrailHasFullROM" = "true" ]]; then
                    case $opt in
                        3)  flash_coreboot;
                            menu_fwupdate;
                            ;;
                    esac
                    if [ "$isChromeOS" = false ]; then
                        case $opt in
                            7)  restore_stock_firmware;
							    menu_fwupdate;
                                ;;
                        esac
                    fi
                fi
            else 
                case $opt in
                    3)  flash_coreboot;
                        menu_fwupdate;
                        ;;
                esac
                if [ "$isChromeOS" = false ]; then
                    case $opt in
                        7)  restore_stock_firmware;
							menu_fwupdate;
                            ;;
                    esac
                fi
            fi
            #options always available
            case $opt in
                
                1)  update_rwlegacy;    
                    menu_fwupdate;
                    ;;
                4)  set_boot_options;   
                    menu_fwupdate;
                    ;;
                5)  set_hwid;
                    menu_fwupdate;
                    ;;                      
                8)  echo -e "\nRebooting...\n";
                    cleanup;
                    reboot;
                    exit;
                    ;;
                9)  echo -e "\nPowering off...\n";
                    cleanup;
                    poweroff;
                    exit;
                    ;;
                q)  cleanup;
                    exit;
                    ;;
                \n) cleanup;
                    exit;
                    ;;
                *)  clear;
                    menu_fwupdate;
                    ;;
            esac
        fi
    done
}


