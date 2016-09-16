#!/bin/bash
#


###################
# flash RW_LEGACY #
###################
function flash_rwlegacy()
{

#set working dir
cd /tmp

# set dev mode legacy boot flag 
if [ "${isChromeOS}" = true ]; then
    crossystem dev_boot_legacy=1 > /dev/null 2>&1
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
elif [ "$isBraswell" = true ]; then
    seabios_file=$seabios_braswell
elif [ "$isSkylake" = true ]; then
    seabios_file=$seabios_skylake
else
    echo_red "Unknown or unsupported device (${device}); cannot update Legacy BIOS."; return 1
fi


preferUSB=false
useHeadless=false
if [ -z "$1" ]; then
    echo -e ""
    #USB boot priority
    echo_yellow "Default to booting from USB?"
    read -p "If N, always boot from internal storage unless selected from boot menu. [y/N] "
    [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && preferUSB=true    
    echo -e ""
    #headless?
    if [ "$seabios_file" = "$seabios_hswbdw_box" ]; then
        echo_yellow "Install \"headless\" firmware?"
        read -p "This is only needed for servers running without a connected display. [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && useHeadless=true
        echo -e ""
    fi
fi

#download SeaBIOS update
echo_yellow "\nDownloading RW_LEGACY firmware update"
curl -s -L -O ${rwlegacy_source}${seabios_file}.md5
curl -s -L -O ${rwlegacy_source}${seabios_file}
#verify checksum on downloaded file
md5sum -c ${seabios_file}.md5 --quiet 2> /dev/null
[[ $? -ne 0 ]] && { exit_red "RW_LEGACY download checksum fail; download corrupted, cannot flash"; return 1; }

#preferUSB?
if [ "$preferUSB" = true  ]; then
    curl -s -L -o bootorder "${cbfs_source}bootorder.usb"
    if [ $? -ne 0 ]; then
        echo_red "Unable to download bootorder file; boot order cannot be changed."
    else
        ${cbfstoolcmd} ${seabios_file} remove -n bootorder > /dev/null 2>&1
        ${cbfstoolcmd} ${seabios_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
    fi      
fi
#useHeadless?
if [ "$useHeadless" = true  ]; then
    curl -s -L -O "${cbfs_source}${hswbdw_headless_vbios}"
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
echo_yellow "Installing RW_LEGACY firmware (${seabios_file})"
${flashromcmd} -w -i RW_LEGACY:${seabios_file} > /dev/null 2>&1
echo_green "Legacy BIOS / RW_LEGACY firmware successfully installed/updated."  
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
echo_green "\nInstall/Update Custom coreboot Firmware (Full ROM)"
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

#UEFI or legacy firmware
useUEFI=false
if [[ "$hasUEFIoption" = true ]]; then
    echo -e ""
    echo_yellow "Install UEFI-compatible firmware?"
    echo -e "UEFI firmware is preferred for Windows and OSX;
Linux requires the use of a boot manager like rEFInd.
Some Linux distros (like GalliumOS) are not UEFI-compatible
and work better with Legacy Boot (SeaBIOS) firmware.  If you
have an existing Linux install using RW_LEGACY or BOOT_STUB
firmware, then choose the Legacy option.
"
    REPLY=""
    while [[ "$REPLY" != "U" && "$REPLY" != "u" && "$REPLY" != "L" && "$REPLY" != "l"  ]]
    do
        read -p "Enter 'U' for UEFI, 'L' for Legacy: "
        if [[ "$REPLY" = "U" || "$REPLY" = "u" ]]; then
            useUEFI=true
        fi
    done 
fi

#determine correct file / URL
firmware_source=${fullrom_source}
if [ "$isHswBox" = true ]; then
    if [ "$useUEFI" = true ]; then
        coreboot_file=$coreboot_uefi_hsw_box
    else
        coreboot_file=$coreboot_hsw_box
    fi
elif [[ "$isBdwBox" = true || "$isHswBook" = true || "$isBdwBook" = true \
            || "$device" = "stumpy" || "$bayTrailHasFullROM" = "true" ]]; then
    if [ "$useUEFI" = true ]; then
        eval coreboot_file=$`echo "coreboot_uefi_${device}"`
    else
        eval coreboot_file=$`echo "coreboot_${device}"`
    fi
else
    exit_red "Unknown or unsupported device (${device^^}); cannot continue."; return 1
fi

#peppy special case
if [ "$device" = "peppy" ]; then
    hasElan=$(cat /proc/bus/input/devices | grep "Elan")
    hasCypress=$(cat /proc/bus/input/devices | grep "Cypress")
    if [[ $hasElan = "" && $hasCypress = "" ]]; then
        echo -e ""
        read -p "Unable to automatically determine trackpad type. Does your Peppy have an Elan pad? [y/N] "
        if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
            if [ "$useUEFI" = true ]; then
                coreboot_file=${coreboot_uefi_peppy_elan}
            else 
                coreboot_file=${coreboot_peppy_elan}
            fi
        fi
    elif [[ $hasElan != "" ]]; then 
        if [ "$useUEFI" = true ]; then
            coreboot_file=${coreboot_uefi_peppy_elan}
        else 
            coreboot_file=${coreboot_peppy_elan}
        fi
    fi
fi

#extract MAC address if needed
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
    echo_yellow "\nCreate a backup copy of your stock firmware?"
    read -p "This is highly recommended in case you wish to return your device to stock 
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. [Y/n] "
    [ "$REPLY" = "n" ] || backup_firmware
fi
#check that backup succeeded
[ $? -ne 0 ] && return 1

#headless?
useHeadless=false
if [[ $useUEFI = false && ( "$isHswBox" = true || "$isBdwBox" = true ) ]]; then
    echo -e ""
    echo_yellow "Install \"headless\" firmware?"
    read -p "This is only needed for servers running without a connected display. [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        useHeadless=true
    fi
fi

#USB boot priority
preferUSB=false
if [[  $useUEFI = false ]]; then 
    echo -e ""
    echo_yellow "Default to booting from USB?"
    read -p "If N, always boot from the internal SSD unless selected from boot menu. [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        preferUSB=true
    fi
 fi

#add PXE?
addPXE=false
if [[  $useUEFI = false && ( "$isHswBox" = true || "$isBdwBox" = true || "$device" = "ninja" ) ]]; then
    echo -e ""
    echo_yellow "Add PXE network booting capability?"
    read -p "(This is not needed for by most users) [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        addPXE=true
        echo -e ""
        echo_yellow "Boot PXE by default?"
        read -p "(will fall back to SSD/USB) [y/N] "
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
    curl -s -L -o bootorder "${cbfs_source}bootorder.usb"
    if [ $? -ne 0 ]; then
        echo_red "Unable to download bootorder file; boot order cannot be changed."
    else
        ${cbfstoolcmd} ${coreboot_file} remove -n bootorder > /dev/null 2>&1 
        ${cbfstoolcmd} ${coreboot_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
    fi
fi
#useHeadless?
if [ "$useHeadless" = true  ]; then
    curl -s -L -O "${cbfs_source}${hswbdw_headless_vbios}"
    if [ $? -ne 0 ]; then
        echo_red "Unable to download headless VGA BIOS; headless firmware cannot be installed."
    else
        ${cbfstoolcmd} ${coreboot_file} remove -n pci8086,0406.rom > /dev/null 2>&1
        ${cbfstoolcmd} ${coreboot_file} add -f ${hswbdw_headless_vbios} -n pci8086,0406.rom -t optionrom > /dev/null 2>&1
    fi      
fi
#addPXE?
if [ "$addPXE" = true  ]; then
    curl -s -L -O "${cbfs_source}${pxe_optionrom}"
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
    echo_green "Custom coreboot firmware (Full ROM) successfully installed/updated."
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
    if [[ "$hasShellball" = false ]]; then
        exit_red "\nUnfortunately I don't have a stock firmware available to download for '${device^^}' at this time."
        return 1
    fi

    #download firmware extracted from recovery image
    echo_yellow "\nThat's ok, I'll download a shellball firmware for you."
    
    if [ "${device^^}" = "PANTHER" ]; then
        echo -e "Which ChromeBox do you have?\n"
        echo "1) Asus CN60 [PANTHER]"
        echo "2) HP CB1 [ZAKO]"
        echo "3) Dell 3010 [TRICKY]"
        echo "4) Acer CXI [MCCLOUD]"
        echo ""
        read -p "? " fw_num
        if [[ $fw_num -lt 1 ||  $fw_num -gt 8 ]]; then
            exit_red "Invalid input - cancelling"
            return 1
        fi
        #confirm menu selection
        echo -e ""
        read -p "Confirm selection number ${fw_num} [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || { exit_red "User cancelled restoring stock firmware"; return; }
        
        #download firmware file
        echo -e ""
        echo_yellow "Downloading recovery image firmware file" 
        case "$fw_num" in
            1) _device="panther";
                ;;
            2) _device="zako";
                ;;
            3) _device="tricky";
                ;;
            4) _device="mccloud";
                ;;
        esac
        
            
    else
	    #confirm device detection
        echo_yellow "Confirm system details:"
        echo -e "Device: ${deviceDesc}"
        echo -e "Board Name: ${device^^}"
        echo -e ""
        read -p "? [y/N] "
        if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
            exit_red "Device detection failed; unable to restoring stock firmware"
            return 1
        fi
        echo -e ""
        _device=${device}
    fi
    
    #download shellball ROM
    curl -s -L -o /tmp/stock-firmware.rom ${shellball_source}shellball.${_device}.bin;
    [[ $? -ne 0 ]] && { exit_red "Error downloading; unable to restore stock firmware."; return 1; }
    
    #extract VPD if present
    if [[ "$isHswBox" = true || "$isBdwBox" = true || "$device" = "ninja" ]]; then
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
    fi
    firmware_file=/tmp/stock-firmware.rom
fi

#flash stock firmware
echo_yellow "Restoring stock firmware"
${flashromcmd} -w ${firmware_file} > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"; return 1; }
#all good
echo_green "Stock firmware successfully restored."
echo_green "After rebooting, you will need to restore ChromeOS using the ChromeOS recovery media,
then re-run this script to reset the Firmware Boot Flags (GBB Flags) to factory default."
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

# ensure hardware write protect disabled if in ChromeOS
if [[ "$isChromeOS" = true && ( "$(crossystem wpsw_cur)" == "1" || "$(crossystem wpsw_boot)" == "1" ) ]]; then
    exit_red "\nHardware write-protect enabled, cannot set Boot Options / GBB Flags."; return 1
fi

[[ -z "$1" ]] && legacy_text="Legacy Boot" || legacy_text="$1"


echo_green "\nSet Firmware Boot Options (GBB Flags)"
echo_yellow "Select your preferred boot delay and default boot option.
You can always override the default using [CTRL+D] or 
[CTRL+L] on the Developer Mode boot screen"

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
#disable software write-protect
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error disabling software write-protect; unable to set GBB flags."; return 1
fi
${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to set boot options."; return 1; }
${gbbutilitycmd} --set --flags="${_flags}" /tmp/gbb.temp > /dev/null
[[ $? -ne 0 ]] && { exit_red "\nError setting boot options."; return 1; }
${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to set boot options."; return 1; }
echo_green "\nFirmware Boot options successfully set."
read -p "Press [Enter] to return to the main menu."
}


###################
# Set Hardware ID #
###################
function set_hwid() 
{
# set HWID using gbb_utility

# ensure hardware write protect disabled if in ChromeOS
if [[ "$isChromeOS" = true && ( "$(crossystem wpsw_cur)" == "1" || "$(crossystem wpsw_boot)" == "1" ) ]]; then
    exit_red "\nHardware write-protect enabled, cannot set HWID."; return 1
fi

echo_green "Set Hardware ID (HWID) using gbb_utility"

#get current HWID
_hwid="$(crossystem hwid)" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_yellow "Current HWID is $_hwid"
fi
read -p "Enter a new HWID (use all caps): " hwid
echo -e ""
read -p "Confirm changing HWID to $hwid [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nSetting hardware ID..."
    #disable software write-protect
    ${flashromcmd} --wp-disable > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "Error disabling software write-protect; unable to set HWID."; return 1
    fi
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to set HWID."; return 1; }
    ${gbbutilitycmd} --set --hwid="${hwid}" /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError setting HWID."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to set HWID."; return 1; }
    echo_green "Hardware ID successfully set."
fi
read -p "Press [Enter] to return to the main menu."
}


##################
# Remove Bitmaps #
##################
function remove_bitmaps() 
{
# remove bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled if in ChromeOS
if [[ "$isChromeOS" = true && ( "$(crossystem wpsw_cur)" == "1" || "$(crossystem wpsw_boot)" == "1" ) ]]; then
    exit_red "\nHardware write-protect enabled, cannot remove bitmaps."; return 1
fi

echo_green "\nRemove ChromeOS Boot Screen Bitmaps"

read -p "Confirm removing ChromeOS bitmaps? [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nRemoving bitmaps..."
    #disable software write-protect
    ${flashromcmd} --wp-disable > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "Error disabling software write-protect; unable to remove bitmaps."; return 1
    fi
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to remove bitmaps."; return 1; }
    touch /tmp/null-images > /dev/null 2>&1
    ${gbbutilitycmd} --set --bmpfv=/tmp/null-images /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError removing bitmaps."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to remove bitmaps."; return 1; }
    echo_green "ChromeOS bitmaps successfully removed."
fi
read -p "Press [Enter] to return to the main menu."
}


##################
# Restore Bitmaps #
##################
function restore_bitmaps() 
{
# restore bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled if in ChromeOS
if [[ "$isChromeOS" = true && ( "$(crossystem wpsw_cur)" == "1" || "$(crossystem wpsw_boot)" == "1" ) ]]; then
    exit_red "\nHardware write-protect enabled, cannot restore bitmaps."; return 1
fi

echo_green "\nRestore ChromeOS Boot Screen Bitmaps"

read -p "Confirm restoring ChromeOS bitmaps? [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nRestoring bitmaps..."
    #disable software write-protect
    ${flashromcmd} --wp-disable > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "Error disabling software write-protect; unable to restore bitmaps."; return 1
    fi
    #download shellball
    curl -s -L -o /tmp/shellball.rom ${shellball_source}shellball.${device}.bin;
    [[ $? -ne 0 ]] && { exit_red "Error downloading shellball; unable to restore bitmaps."; return 1; }
    #extract GBB region, bitmaps
    ${cbfstoolcmd} /tmp/shellball.rom read -r GBB -f gbb.new >/dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "Error extracting GBB region from shellball; unable to restore bitmaps."; return 1; }
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to restore bitmaps."; return 1; }
    ${gbbutilitycmd} --get --bmpfv=/tmp/bmpfv /tmp/gbb.new > /dev/null
    ${gbbutilitycmd} --set --bmpfv=/tmp/bmpfv /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError restoring bitmaps."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to restore bitmaps."; return 1; }
    echo_green "ChromeOS bitmaps successfully restored."
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
if [[ "$isChromeOS" = true && ( "$(crossystem wpsw_cur)" == "1" || "$(crossystem wpsw_boot)" == "1" ) ]]; then
    exit_red "\nHardware write-protect enabled, cannot flash/modify BOOT_STUB firmware."; return 1
fi

# cd to working dir
cd /tmp

#download SeaBIOS payload
curl -s -L -O ${bootstub_source}/${bootstub_payload_baytrail}
curl -s -L -O ${bootstub_source}/${bootstub_payload_baytrail}.md5 

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
    curl -s -L -o bootorder ${cbfs_source}/bootorder.usb 
else
    curl -s -L -o bootorder ${cbfs_source}/bootorder.emmc
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
${cbfstoolcmd} boot_stub.bin remove -n etc/sdcard6 > /dev/null 2>&1
${cbfstoolcmd} boot_stub.bin add-payload -n fallback/payload -f ${bootstub_payload_baytrail} -c lzma > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "There was an error modifying the BOOT_STUB payload, nothing has been flashed."; return 1
else
    ${cbfstoolcmd} boot_stub.bin add -n bootorder -f bootorder -t raw > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 3000 -n etc/boot-menu-wait > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd071f000 -n etc/sdcard0 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd071d000 -n etc/sdcard1 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd071c000 -n etc/sdcard2 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd081f000 -n etc/sdcard3 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd081c000 -n etc/sdcard4 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd091f000 -n etc/sdcard5 > /dev/null 2>&1
    ${cbfstoolcmd} boot_stub.bin add-int -i 0xd091c000 -n etc/sdcard6 > /dev/null 2>&1

    #flash modified BOOT_STUB back
    echo_yellow "Flashing modified BOOT_STUB firmware"
    ${flashromcmd} -w -i BOOT_STUB:boot_stub.bin > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        #flash back stock BOOT_STUB
        dd if=rw_legacy.bin of=boot_stub.bin bs=1M count=1 > /dev/null 2>&1
        ${flashromcmd} -w -i BOOT_STUB:boot_stub.bin > /dev/null 2>&1
        echo_red "There was an error flashing the modified BOOT_STUB, but the stock one has been restored."
    else
        echo_green "Legacy boot capable BOOT_STUB firmware successfully flashed"
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

#check OS
[[ "$isChromeOS" = true ]] && { exit_red "\nThis functionality is not available under ChromeOS."; return 1; }

echo_green "\nRestore stock BOOT_STUB from backup"

echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

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
if [[ $? -ne 0 ]]; then
    echo_yellow "No valid BOOT_STUB backup found; attempting to download/extract from a shellball ROM"
    #download and extract from shellball ROM
    curl -s -L -o /tmp/shellball.rom ${shellball_source}shellball.${device}.bin
    if [[ $? -ne 0 ]]; then 
        exit_red "No valid BOOT_STUB backup found; error downloading shellball ROM; unable to restore stock BOOT_STUB."
        return 1
    fi
    ${cbfstoolcmd} shellball.rom read -r BOOT_STUB -f boot_stub.stock >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "No valid BOOT_STUB backup found; error reading shellball ROM; unable to restore stock BOOT_STUB."
        return 1
    fi
    ${cbfstoolcmd} boot_stub.stock extract -n config -f config.${device} > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        exit_red "No BOOT_STUB backup available; unable to restore stock BOOT_STUB"
        return 1
    fi
fi

#verify valid for this device
cat config.${device} | grep ${device} > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "No valid BOOT_STUB backup found; unable to restore stock BOOT_STUB"; return 1; }

#restore stock BOOT_STUB
echo_yellow "Restoring stock BOOT_STUB"
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
    echo -e "${NORMAL}\n ChromeOS Firmware Utility Script ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Mr. Chromebox <mr.chromebox@gmail.com>\n ${NORMAL}"
    echo -e "${NORMAL} Paypal towards beer/programmer fuel welcomed at above address :)\n ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER} System Info ${NORMAL}"
    echo -e "${MENU}**${NORMAL} Device: ${deviceDesc}"
    echo -e "${MENU}**${NORMAL} Board Name: ${device^^}"
    echo -e "${MENU}**${NORMAL} CPU Type: $deviceCpuType"
    echo -e "${MENU}**${NORMAL} Fw Type: $firmwareType"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NORMAL}"
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false ) ]]; then
        echo -e "${MENU}**${NUMBER} 1)${MENU} Install/Update RW_LEGACY Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update RW_LEGACY Firmware ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBaytrail" = true && "$bayTrailHasFullROM" = false ) ]]; then
        echo -e "${MENU}**${NUMBER} 2)${MENU} Install/Update BOOT_STUB Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 2)${GRAY_TEXT} Install/Update BOOT_STUB Firmware ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( ( "$isBaytrail" = false && "$isBraswell" = false && "$isSkylake" = false ) \
            || "$bayTrailHasFullROM" = "true" ) ]]; then
        echo -e "${MENU}**${NUMBER} 3)${MENU} Install/Update Custom coreboot Firmware (Full ROM) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 3)${GRAY_TEXT} Install/Update Custom coreboot Firmware (Full ROM) ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false ) ]]; then
        echo -e "${MENU}**${NUMBER} 4)${MENU} Set Boot Options (GBB flags) ${NORMAL}"
        echo -e "${MENU}**${NUMBER} 5)${MENU} Set Hardware ID (HWID) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 4)${GRAY_TEXT} Set Boot Options (GBB flags)${NORMAL}"
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 5)${GRAY_TEXT} Set Hardware ID (HWID) ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && "$isSkylake" = false) ]]; then
        echo -e "${MENU}**${NUMBER} 6)${MENU} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${MENU}**${NUMBER} 7)${MENU} Restore ChromeOS Bitmaps ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 6)${GRAY_TEXT} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 7)${GRAY_TEXT} Restore ChromeOS Bitmaps ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isBaytrail" = true && "$isBootStub" = true && "$isChromeOS" = false ) ]]; then
        echo -e "${MENU}**${NUMBER} 8)${MENU} Restore Stock BOOT_STUB ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 8)${GRAY_TEXT} Restore Stock BOOT_STUB ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isChromeOS" = false  && "$isFullRom" = true ) ]]; then
        echo -e "${MENU}**${NUMBER} 9)${MENU} Restore Stock Firmware (full) ${NORMAL}" 
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 9)${GRAY_TEXT} Restore Stock Firmware (full) ${NORMAL}" 
    fi
    echo -e "${MENU}**${NORMAL}"
    echo -e "${MENU}**${NUMBER} R)${NORMAL} Reboot ${NORMAL}"
    echo -e "${MENU}**${NUMBER} P)${NORMAL} Power Off ${NORMAL}"
    echo -e "${MENU}**${NORMAL}"
    echo -e "${MENU}**${NUMBER} U)${NORMAL} Unlock Disabled Functions ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or ${RED_TEXT}q to quit ${NORMAL}"
    
    read opt
            
    while [ opt != '' ]
        do
        if [[ $opt = "q" ]]; then 
                exit;
        else
            case $opt in
                    
                1)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isFullRom" = false \
                            && "$isBootStub" = false ]]; then
                        update_rwlegacy     
                    fi
                    menu_fwupdate
                    ;;
                    
                2)  if [[ "$unlockMenu" = true || "$isBaytrail" = true && "$bayTrailHasFullROM" = false ]]; then
                        modify_boot_stub  
                    fi
                    menu_fwupdate        
                    ;;
                    
                3)  if [[ "$unlockMenu" = true || ( "$isUnsupported" = false && "$isBaytrail" = false \
                            && "$isBraswell" = false && "$isSkylake" = false ) \
                            || ( "$isBaytrail" = true && "$bayTrailHasFullROM" = true ) ]]; then
                        flash_coreboot
                    fi        
                    menu_fwupdate
                    ;;
                    
                4)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                            && "$isFullRom" = false && "$isBootStub" = false ]]; then
                        set_boot_options   
                    fi
                    menu_fwupdate
                    ;;
                    
                5)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                            && "$isFullRom" = false && "$isBootStub" = false ]]; then
                        set_hwid   
                    fi
                    menu_fwupdate
                    ;;
                                                            
                6)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                            && "$isFullRom" = false && "$isBootStub" = false && "$isSkylake" = false ]]; then
                        remove_bitmaps   
                    fi
                    menu_fwupdate
                    ;;
                    
                7)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                            && "$isFullRom" = false && "$isBootStub" = false && "$isSkylake" = false ]]; then
                        restore_bitmaps   
                    fi
                    menu_fwupdate
                    ;;
                    
                8)  if [[ "$unlockMenu" = true || "$isBootStub" = true ]]; then
                        restore_boot_stub
                    fi
                    menu_fwupdate
                    ;;   
                
                9)  if [[ "$unlockMenu" = true || "$isChromeOS" = false && "$isUnsupported" = false \
                            && "$isFullRom" = true ]]; then
                        restore_stock_firmware   
                    fi
                    menu_fwupdate
                    ;;
                    
                [rR])  echo -e "\nRebooting...\n";
                    cleanup;
                    reboot;
                    exit;
                    ;;
                    
                [pP])  echo -e "\nPowering off...\n";
                    cleanup;
                    poweroff;
                    exit;
                    ;;
                
                [qQ])  cleanup;
                    exit;
                    ;;
                
                [uU])  if [ "$unlockMenu" = false ]; then
                        echo_yellow "\nAre you sure you wish to unlock all menu functions?"
                        read -p "Only do this if you really know what you are doing... [y/N]? "
                        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && unlockMenu=true
                    fi
                    menu_fwupdate
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


