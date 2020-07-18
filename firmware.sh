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

echo_green "\nInstall/Update RW_LEGACY Firmware (Legacy BIOS)"

#determine proper file
if [ "$device" = "link" ]; then
    rwlegacy_file=$seabios_link
elif [[ "$isHswBox" = true || "$isBdwBox" = true ]]; then
    rwlegacy_file=$seabios_hswbdw_box
elif [[ "$isHswBook" = true || "$isBdwBook" = true ]]; then
    rwlegacy_file=$seabios_hswbdw_book
elif [ "$isByt" = true ]; then
    rwlegacy_file=$seabios_baytrail
elif [ "$isBsw" = true ]; then
    rwlegacy_file=$seabios_braswell
elif [ "$isSkl" = true ]; then
    rwlegacy_file=$seabios_skylake
elif [ "$isApl" = true ]; then
    rwlegacy_file=$seabios_apl
elif [ "$kbl_use_rwl18" = true ]; then
    rwlegacy_file=$seabios_kbl_18
elif [ "$isStr" = true ]; then
    rwlegacy_file=$rwl_altfw_stoney
elif [ "$isKbl" = true ]; then
    rwlegacy_file=$seabios_kbl
#elif [ "$useAltfwStd" = true ]; then
#    rwlegacy_file=$rwl_altfw
else
    echo_red "Unknown or unsupported device (${device}); cannot update RW_LEGACY firmware."
    read -ep "Press enter to return to the main menu"
    return 1
fi


preferUSB=false
useHeadless=false
if [[ -z "$1" && "$rwlegacy_file" != *"altfw"* ]]; then
    echo -e ""
    #USB boot priority
    echo_yellow "Default to booting from USB?"
    read -ep "If N, always boot from internal storage unless selected from boot menu. [y/N] "
    [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && preferUSB=true
    echo -e ""
    #headless?
    if [[ "$rwlegacy_file" = "$seabios_hswbdw_box" && "$device" != "monroe" ]]; then
        echo_yellow "Install \"headless\" firmware?"
        read -ep "This is only needed for servers running without a connected display. [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && useHeadless=true
        echo -e ""
    fi
fi

#download SeaBIOS update
echo_yellow "\nDownloading RW_LEGACY firmware update\n(${rwlegacy_file})"
curl -s -L -O ${rwlegacy_source}${rwlegacy_file}.md5
curl -s -L -O ${rwlegacy_source}${rwlegacy_file}
#verify checksum on downloaded file
md5sum -c ${rwlegacy_file}.md5 --quiet 2> /dev/null
[[ $? -ne 0 ]] && { exit_red "RW_LEGACY download checksum fail; download corrupted, cannot flash"; return 1; }

#preferUSB?
if [ "$preferUSB" = true  ]; then
    #swanky special case
    if [[ "$device" = "swanky" ]]; then
    	curl -s -L -o bootorder "${cbfs_source}bootorder.usb2"
    else
	curl -s -L -o bootorder "${cbfs_source}bootorder.usb"
    fi
    if [ $? -ne 0 ]; then
        echo_red "Unable to download bootorder file; boot order cannot be changed."
    else
        ${cbfstoolcmd} ${rwlegacy_file} remove -n bootorder > /dev/null 2>&1
        ${cbfstoolcmd} ${rwlegacy_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
    fi
fi
#useHeadless?
if [ "$useHeadless" = true  ]; then
    curl -s -L -O "${cbfs_source}${hswbdw_headless_vbios}"
    if [ $? -ne 0 ]; then
        echo_red "Unable to download headless VGA BIOS; headless firmware cannot be installed."
    else
        ${cbfstoolcmd} ${rwlegacy_file} remove -n pci8086,0406.rom > /dev/null 2>&1
        rc0=$?
        ${cbfstoolcmd} ${rwlegacy_file} add -f ${hswbdw_headless_vbios} -n pci8086,0406.rom -t optionrom > /dev/null 2>&1
        rc1=$?
        if [[ "$rc0" -ne 0 || "$rc1" -ne 0 ]]; then
            echo_red "Warning: error installing headless VGA BIOS"
        else
            echo_yellow "Headless VGA BIOS installed"
        fi
    fi
fi

#handle NINJA VGABIOS
if [[ "$device" = "ninja" ]]; then
    #extract vbios from stock BOOT_STUB, inject into RWL
     ${cbfstoolcmd} bios.bin extract -r BOOT_STUB -n pci8086,0f31.rom -f vgabios.bin > /dev/null 2>&1
     rc0=$?
     ${cbfstoolcmd} ${rwlegacy_file} remove -n pci8086,0f31.rom > /dev/null 2>&1
     rc1=$?
     ${cbfstoolcmd} ${rwlegacy_file} add -f vgabios.bin -n pci8086,0f31.rom -t optionrom > /dev/null 2>&1
     rc2=$?
     if [[ "$rc0" -ne 0 || "$rc1" -ne 0 || "$rc2" -ne 0 ]]; then
            echo_red "Warning: error installing VGA BIOS"
        else
            echo_yellow "VGA BIOS installed"
        fi
fi

#flash updated legacy BIOS
echo_yellow "Installing RW_LEGACY firmware"
${flashromcmd} -w -i RW_LEGACY:${rwlegacy_file} -o /tmp/flashrom.log > /dev/null 2>&1
if [ $? -ne 0 ]; then
    cat /tmp/flashrom.log
    echo_red "An error occurred flashing the RW_LEGACY firmware."
else
  echo_green "RW_LEGACY firmware successfully installed/updated."
  # update firmware type
  firmwareType="Stock ChromeOS w/RW_LEGACY"
fi

if [ -z "$1" ]; then
    read -ep "Press [Enter] to return to the main menu."
fi
}


#############################
# Install coreboot Firmware #
#############################
function flash_coreboot()
{

fwTypeStr=""
if [[ "$hasLegacyOption" = true && "$unlockMenu" = true ]]; then
    fwTypeStr="Legacy/UEFI"
else
    fwTypeStr="UEFI"
fi

echo_green "\nInstall/Update ${fwTypeStr} Full ROM Firmware"
echo_yellow "Standard disclaimer: flashing the firmware has the potential to
brick your device, requiring relatively inexpensive hardware and some
technical knowledge to recover.  You have been warned."

[[ "$isChromeOS" = true ]] && echo_yellow "Also, flashing Full ROM firmware will remove your ability to run ChromeOS."

read -ep "Do you wish to continue? [y/N] "
[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot flash Full ROM firmware."; return 1; }

#special warning for CR50 devices
if [[ "$isStock" = true && "$hasCR50" = true ]]; then
echo_yellow "NOTICE: flashing your Chromebook is serious business. 
To ensure recovery in case something goes wrong when flashing,
be sure to set the ccd capability 'FlashAP Always' using your 
USB-C debug cable, otherwise recovery will involve disassembling
your device (which is very difficult in some cases)."

echo_yellow "If you wish to continue, type: 'I ACCEPT' and press enter."
read -e
[[ "$REPLY" = "I ACCEPT" ]] || return
fi

#UEFI or legacy firmware
if [[ ! -z "$1" || ( "$isUEFI" = true && "$unlockMenu" = false ) || "$hasLegacyOption" = false ]]; then
    useUEFI=true
else
    useUEFI=false
    if [[ "$hasUEFIoption" = true ]]; then
        echo -e ""
        echo_yellow "Install UEFI-compatible firmware?"
        echo -e "UEFI firmware is the preferred option for all OSes.
Legacy SeaBIOS firmware is deprecated but available for Chromeboxes to enable
PXE (network boot) capability and compatibility with Legacy OS installations.\n"
        REPLY=""
        while [[ "$REPLY" != "U" && "$REPLY" != "u" && "$REPLY" != "L" && "$REPLY" != "l"  ]]
        do
            read -ep "Enter 'U' for UEFI, 'L' for Legacy: "
            if [[ "$REPLY" = "U" || "$REPLY" = "u" ]]; then
                useUEFI=true
            fi
        done
    fi
fi

# Windows support disclaimer
if [[ "$isStock" = true && "$useUEFI" = true && "$runsWindows" = false ]]; then
clear
echo_red "VERY IMPORTANT:"
echo -e "Although UEFI firmware is available for your device,
running Windows on it is $RED_TEXT**NOT SUPPORTED**$NORMAL, no matter what
some Youtube video claims. If you post on reddit asking for
help, your post will likely be locked or deleted. Additionally,
your device may not be fully functional under Linux either. 
Do your homework and be sure you understand what you are getting into."

echo_yellow "\nIf you still wish to continue, type: 'I UNDERSTAND' and press enter
(or just press enter to return to the main menu)"
read -e
[[ "$REPLY" = "I UNDERSTAND" ]] || return
fi

#UEFI notice if flashing from ChromeOS or Legacy
if [[ "$useUEFI" = true && ! -d /sys/firmware/efi ]]; then
    [[ "$isChromeOS" = true ]] && currOS="ChromeOS" || currOS="Your Legacy-installed OS"
    echo_yellow "
NOTE: After flashing UEFI firmware, you will need to install a UEFI-compatible
OS; ${currOS} will no longer be bootable. See https://mrchromebox.tech/#faq"
    REPLY=""
    read -ep "Press Y to continue or any other key to abort. "
    [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
fi

#determine correct file / URL
firmware_source=${fullrom_source}
if [[ "$hasUEFIoption" = true || "$hasLegacyOption" = true ]]; then
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
        read -ep "Unable to automatically determine trackpad type. Does your Peppy have an Elan pad? [y/N] "
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

#auron special case (upgrade from coolstar legacy rom)
if [ "$device" = "auron" ]; then
    echo -e ""
    echo_yellow "Unable to determine Chromebook model"
    echo -e "Because of your current firmware, I'm unable to
determine the exact mode of your Chromebook.  Are you using
an Acer C740 (Auron_Paine) or Acer C910/CB5-571 (Auron_Yuna)?
"
    REPLY=""
    while [[ "$REPLY" != "P" && "$REPLY" != "p" && "$REPLY" != "Y" && "$REPLY" != "y"  ]]
    do
        read -ep "Enter 'P' for Auron_Paine, 'Y' for Auron_Yuna: "
        if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
            if [ "$useUEFI" = true ]; then
                coreboot_file=${coreboot_uefi_auron_yuna}
            else
                coreboot_file=${coreboot_auron_yuna}
            fi
        else
            if [ "$useUEFI" = true ]; then
                coreboot_file=${coreboot_uefi_auron_paine}
            else
                coreboot_file=${coreboot_auron_paine}
            fi
        fi
    done
fi

#extract MAC address if needed
if [[ "$hasLAN" = true ]]; then
    #check if contains MAC address, extract
    extract_vpd /tmp/bios.bin
    if [ $? -ne 0 ]; then
        #TODO - user enter MAC manually?
        echo_red "\nWarning: firmware doesn't contain VPD info - unable to persist MAC address."
        read -ep "Do you wish to continue? [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
    fi
fi

#extract device serial if present in cbfs
${cbfstoolcmd} /tmp/bios.bin extract -n serial_number -f /tmp/serial.txt >/dev/null 2>&1

# create backup if existing firmware is stock
if [[ "$isStock" == "true" ]]; then
    if [[ "$hasShellball" = "false" ]]; then
        REPLY=y
    else
        echo_yellow "\nCreate a backup copy of your stock firmware?"
        read -ep "This is highly recommended in case you wish to return your device to stock
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. [Y/n] "
    fi
    [[ "$REPLY" = "n" || "$REPLY" = "N" ]] && true || backup_firmware
    #check that backup succeeded
    [ $? -ne 0 ] && return 1
fi

#headless?
useHeadless=false
if [[ $useUEFI = false && ( "$isHswBox" = true || "$isBdwBox" = true ) ]]; then
    echo -e ""
    echo_yellow "Install \"headless\" firmware?"
    read -ep "This is only needed for servers running without a connected display. [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        useHeadless=true
    fi
fi

#USB boot priority
preferUSB=false
if [[ $useUEFI = false ]]; then
    echo -e ""
    echo_yellow "Default to booting from USB?"
    echo -e "If you default to USB, then any bootable USB device
will have boot priority over the internal SSD.
If you default to SSD, you will need to manually select
the USB Device from the Boot Menu in order to boot it.
    "
    REPLY=""
    while [[ "$REPLY" != "U" && "$REPLY" != "u" && "$REPLY" != "S" && "$REPLY" != "s"  ]]
    do
        read -ep "Enter 'U' for USB, 'S' for SSD: "
        if [[ "$REPLY" = "U" || "$REPLY" = "u" ]]; then
            preferUSB=true
        fi
    done
fi

#add PXE?
addPXE=false
if [[  $useUEFI = false && "$hasLAN" = true ]]; then
    echo -e ""
    echo_yellow "Add PXE network booting capability?"
    read -ep "(This is not needed for by most users) [y/N] "
    if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
        addPXE=true
        echo -e ""
        echo_yellow "Boot PXE by default?"
        read -ep "(will fall back to SSD/USB) [y/N] "
        if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
            pxeDefault=true
        fi
    fi
fi

#download firmware file
cd /tmp
echo_yellow "\nDownloading Full ROM firmware\n(${coreboot_file})"
curl -s -L -O "${firmware_source}${coreboot_file}"
curl -s -L -O "${firmware_source}${coreboot_file}.sha1"

#verify checksum on downloaded file
sha1sum -c ${coreboot_file}.sha1 --quiet > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "Firmware download checksum fail; download corrupted, cannot flash."; return 1; }

#check if we have a VPD to restore
if [ -f /tmp/vpd.bin ]; then
    ${cbfstoolcmd} ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw > /dev/null 2>&1
fi

#preferUSB?
if [[ "$preferUSB" = true  && $useUEFI = false ]]; then
	curl -s -L -o bootorder "${cbfs_source}bootorder.usb"
	if [ $? -ne 0 ]; then
	    echo_red "Unable to download bootorder file; boot order cannot be changed."
	else
	    ${cbfstoolcmd} ${coreboot_file} remove -n bootorder > /dev/null 2>&1
	    ${cbfstoolcmd} ${coreboot_file} add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
	fi
fi

#persist serial number?
if [ -f /tmp/serial.txt ]; then
    echo_yellow "Persisting device serial number"
    ${cbfstoolcmd} ${coreboot_file} add -n serial_number -f /tmp/serial.txt -t raw > /dev/null 2>&1
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

#Persist RW_MRC_CACHE for BSW Full ROM firmware
${cbfstoolcmd} /tmp/bios.bin read -r RW_MRC_CACHE -f /tmp/mrc.cache > /dev/null 2>&1
if [[ $isBsw = "true" &&  $isFullRom = "true" && $? -eq 0 ]]; then
    ${cbfstoolcmd} ${coreboot_file} write -r RW_MRC_CACHE -f /tmp/mrc.cache > /dev/null 2>&1
fi

#Persist SMMSTORE if exists
${cbfstoolcmd} /tmp/bios.bin read -r SMMSTORE -f /tmp/smmstore > /dev/null 2>&1
if [[ $useUEFI = "true" &&  $? -eq 0 ]]; then
    ${cbfstoolcmd} ${coreboot_file} write -r SMMSTORE -f /tmp/smmstore > /dev/null 2>&1
fi

#disable software write-protect
echo_yellow "Disabling software write-protect and clearing the WP range"
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error disabling software write-protect; unable to flash firmware."; return 1
fi

#clear SW WP range
${flashromcmd} --wp-range 0 0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	exit_red "Error clearing software write-protect range; unable to flash firmware."; return 1
fi

#flash Full ROM firmware

#flash without verify, to avoid IFD mismatch upon verification 
echo_yellow "Installing Full ROM firmware (may take up to 90s)"
${flashromcmd} -n -w "${coreboot_file}" -o /tmp/flashrom.log > /dev/null 2>&1
if [ $? -ne 0 ]; then
    cat /tmp/flashrom.log
    exit_red "An error occurred flashing the Full ROM firmware. DO NOT REBOOT!"; return 1
else
    echo_green "Full ROM firmware successfully installed/updated."

    #Prevent from trying to boot stock ChromeOS install
    if [[ "$isStock" = true && "$isChromeOS" = true ]]; then
       rm -rf /tmp/boot/efi > /dev/null 2>&1
       rm -rf /tmp/boot/syslinux > /dev/null 2>&1
    fi

    #Warn about long RAM training time, keyboard on Braswell
    if [[ "$isBsw" = true ]]; then
        echo_yellow "IMPORTANT:\nThe first boot after flashing may take substantially
longer than subsequent boots -- up to 30s or more.
Be patient and eventually your device will boot :)"
        echo_yellow "Additionally, GalliumOS users need to use the v3.0 ISO; the keyboard
will not work with older versions due a bug in the older kernel."
    fi
    # Add note on touchpad firmware for EVE
    if [[ "${device^^}" = "EVE" && "$isStock" = true ]]; then
        echo_yellow "IMPORTANT:\n
If you're going to run Windows on your Pixelbook, you must downgrade
the touchpad firmware now (before rebooting) otherwise it will not work.
Select the D option from the main main in order to do so."
    fi
    #set vars to indicate new firmware type
    isStock=false
    isFullRom=true
    # Add NVRAM reset note for 4.12 release
    if [[ "$isUEFI" = true && "$useUEFI" = true ]]; then
        echo_yellow "IMPORTANT:\n
This update uses a new format to store UEFI NVRAM data, and
will reset your BootOrder and boot entries. You may need to 
manually Boot From File and reinstall your bootloader if 
booting from the internal storage device fails."
    fi
    if [[ "$useUEFI" = "true" ]]; then
        firmwareType="Full ROM / UEFI (pending reboot)"
        isUEFI=true
    else
        firmwareType="Full ROM / Legacy (pending reboot)"
    fi
fi

read -ep "Press [Enter] to return to the main menu."
}

#########################
# Downgrade Touchpad FW #
#########################
function downgrade_touchpad_fw()
{
# offer to downgrade touchpad firmware on EVE
if [[ "${device^^}" = "EVE" ]]; then
    echo_green "\nDowngrade Touchpad Firmware"
    echo_yellow "If you plan to run Windows on your Pixelbook, it is necessary to downgrade 
the touchpad firmware, otherwise the touchpad will not work."
    echo_yellow "You should do this after flashing the UEFI firmware, but before rebooting."
    read -ep "Do you wish to downgrade the touchpad firmware now? [y/N] "
    if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] ; then
        # ensure firmware write protect disabled
        [[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot downgrade touchpad firmware."; return 1; }
        # download TP firmware
        echo_yellow "\nDownloading touchpad firmware\n(${touchpad_eve_fw})"
        curl -s -LO "${other_source}${touchpad_eve_fw}"
        curl -s -LO "${other_source}${touchpad_eve_fw}.sha1"
        #verify checksum on downloaded file
        sha1sum -c ${touchpad_eve_fw}.sha1 --quiet > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            # flash TP firmware
            echo_green "Flashing touchpad firmware -- do not touch the touchpad while updating!"
            ${flashromcmd} -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw} -o /tmp/flashrom.log >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo_green "Touchpad firmware successfully downgraded."
                echo_yellow "Please reboot your Pixelbook now."
            else 
                echo_red "Error flashing touchpad firmware:"
                cat /tmp/flashrom.log
                echo_yellow "\nThis function sometimes doesn't work under Linux, in which case it is\nrecommended to try under ChromiumOS."
            fi
        else
            echo_red "Touchpad firmware download checksum fail; download corrupted, cannot flash."
        fi
        read -ep "Press [Enter] to return to the main menu."
    fi
fi
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

read -ep "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot restore stock firmware."; return 1; }

firmware_file=""

read -ep "Do you have a firmware backup file on USB? [y/N] "
if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
    read -ep "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "
    list_usb_devices
    [ $? -eq 0 ] || { exit_red "No USB devices available to read firmware backup."; return 1; }
    read -ep "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
    [ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || { exit_red "Error: Invalid option selected."; return 1; }
    usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
    mkdir /tmp/usb > /dev/null 2>&1
    mount "${usb_device}" /tmp/usb > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        mount "${usb_device}1" /tmp/usb
    fi
    if [ $? -ne 0 ]; then
        echo_red "USB device failed to mount; cannot proceed."
        read -ep "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    #select file from USB device
    echo_yellow "\n(Potential) Firmware Files on USB:"
    ls  /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null
    if [ $? -ne 0 ]; then
        echo_red "No firmware files found on USB device."
        read -ep "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    echo -e ""
    read -ep "Enter the firmware filename:  " firmware_file
    firmware_file=/tmp/usb/${firmware_file}
    if [ ! -f ${firmware_file} ]; then
        echo_red "Invalid filename entered; unable to restore stock firmware."
        read -ep "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    #text spacing
    echo -e ""

else
    if [[ "$hasShellball" = false ]]; then
        exit_red "\nUnfortunately I don't have a stock firmware available to download for '${boardName^^}' at this time."
        return 1
    fi

    #download firmware extracted from recovery image
    echo_yellow "\nThat's ok, I'll download a shellball firmware for you."

    if [ "${boardName^^}" = "PANTHER" ]; then
        echo -e "Which device do you have?\n"
        echo "1) Asus CN60 [PANTHER]"
        echo "2) HP CB1 [ZAKO]"
        echo "3) Dell 3010 [TRICKY]"
        echo "4) Acer CXI [MCCLOUD]"
        echo "5) LG Chromebase [MONROE]"
        echo ""
        read -ep "? " fw_num
        if [[ $fw_num -lt 1 ||  $fw_num -gt 5 ]]; then
            exit_red "Invalid input - cancelling"
            return 1
        fi
        #confirm menu selection
        echo -e ""
        read -ep "Confirm selection number ${fw_num} [y/N] "
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
            5) _device="monroe";
                ;;
        esac


    else
	    #confirm device detection
        echo_yellow "Confirm system details:"
        echo -e "Device: ${deviceDesc}"
        echo -e "Board Name: ${boardName^^}"
        echo -e ""
        read -ep "? [y/N] "
        if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
            exit_red "Device detection failed; unable to restoring stock firmware"
            return 1
        fi
        echo -e ""
        _device=${boardName,,}
    fi

    #download shellball ROM
    echo_yellow "Downloading shellball.${_device}.bin"
    curl -s -L -o /tmp/stock-firmware.rom ${shellball_source}shellball.${_device}.bin;
    [[ $? -ne 0 ]] && { exit_red "Error downloading; unable to restore stock firmware."; return 1; }

    #extract VPD if present
    if [[ "$hasLAN" = true ]]; then
        #extract VPD from current firmware
        extract_vpd /tmp/bios.bin
        #merge with recovery image firmware
        if [ -f /tmp/vpd.bin ]; then
            echo_yellow "Merging VPD into recovery image firmware"
            ${cbfstoolcmd} /tmp/stock-firmware.rom write -r RO_VPD -f /tmp/vpd.bin > /dev/null 2>&1
        fi
    fi
    firmware_file=/tmp/stock-firmware.rom
fi

#disable software write-protect
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
#if [[ $? -ne 0 && ( "$isBsw" = false || "$isFullRom" = false ) ]]; then
    exit_red "Error disabling software write-protect; unable to restore stock firmware."; return 1
fi

#clear SW WP range
${flashromcmd} --wp-range 0 0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	exit_red "Error clearing software write-protect range; unable to restore stock firmware."; return 1
fi

#flash stock firmware
echo_yellow "Restoring stock firmware"
# we won't verify here, since we need to flash the entire BIOS region
# but don't want to get a mismatch from the IFD or ME 
${flashromcmd} -n -w "${firmware_file}" -o /tmp/flashrom.log > /dev/null 2>&1
if [ $? -ne 0 ]; then
    cat /tmp/flashrom.log
    exit_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"; return 1
fi

#all good
echo_green "Stock firmware successfully restored."
echo_green "After rebooting, you will need to restore ChromeOS using the ChromeOS recovery media,
then re-run this script to reset the Firmware Boot Flags (GBB Flags) to factory default."
read -ep "Press [Enter] to return to the main menu."
#set vars to indicate new firmware type
isStock=true
isFullRom=false
isUEFI=false
firmwareType="Stock ChromeOS (pending reboot)"
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
    #try FMAP extraction
    ${cbfstoolcmd} ${firmware_file} read -r RO_VPD -f /tmp/vpd.bin >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        #try CBFS extraction
        ${cbfstoolcmd} ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo_red "Failure extracting MAC address from current firmware."
            return 1
        fi
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
read -ep "Connect the USB/SD device to store the firmware backup and press [Enter]
to continue.  This is non-destructive, but it is best to ensure no other
USB/SD devices are connected. "
list_usb_devices
if [ $? -ne 0 ]; then
    backup_fail "No USB devices available to store firmware backup."
    return 1
fi

read -ep "Enter the number for the device to be used for firmware backup: " usb_dev_index
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
backupname="stock-firmware-${boardName}-$(date +%Y%m%d).rom"
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
read -ep ""
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
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot set Boot Options / GBB Flags."; return 1; }


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
    read -ep "? " n
    case $n in
        1) _flags=0x4A9; break;;
        2) _flags=0x4A8; break;;
        3) _flags=0xA9; break;;
        4) _flags=0xA8; break;;
        5) _flags=0x0; break;;
        6) read -ep "Press [Enter] to return to the main menu."; break;;
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
read -ep "Press [Enter] to return to the main menu."
}


###################
# Set Hardware ID #
###################
function set_hwid()
{
# set HWID using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot set HWID."; return 1; }

echo_green "Set Hardware ID (HWID) using gbb_utility"

#get current HWID
_hwid="$(crossystem hwid)" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_yellow "Current HWID is $_hwid"
fi
read -ep "Enter a new HWID (use all caps): " hwid
echo -e ""
read -ep "Confirm changing HWID to $hwid [y/N] " confirm
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
read -ep "Press [Enter] to return to the main menu."
}


##################
# Remove Bitmaps #
##################
function remove_bitmaps()
{
# remove bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot remove bitmaps."; return 1; }

echo_green "\nRemove ChromeOS Boot Screen Bitmaps"

read -ep "Confirm removing ChromeOS bitmaps? [y/N] " confirm
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
read -ep "Press [Enter] to return to the main menu."
}


##################
# Restore Bitmaps #
##################
function restore_bitmaps()
{
# restore bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot restore bitmaps."; return 1; }

echo_green "\nRestore ChromeOS Boot Screen Bitmaps"

read -ep "Confirm restoring ChromeOS bitmaps? [y/N] " confirm
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
read -ep "Press [Enter] to return to the main menu."
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
[[ "$isByt" = false ]] && { exit_red "\nThis functionality is only available for Baytrail ChromeOS devices currently"; return 1; }

echo_green "\nInstall/Update BOOT_STUB Firmware (Legacy BIOS)"

echo_yellow "Standard disclaimer: flashing the firmware has the potential to
brick your device, requiring relatively inexpensive hardware and some
technical knowledge to recover.  You have been warned."

echo_yellow "Also, flashing the BOOT_STUB will remove the ability to run ChromeOS,
so only proceed if you're going to run Linux exclusively."

read -ep "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y"|| "$REPLY" = "y" ]] || return

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot flash/modify BOOT_STUB firmware."; return 1; }

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
read -ep "Default to booting from USB? If N, always boot from internal storage unless selected from boot menu. [y/N] "
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
        echo_green "BOOT_STUB firmware successfully flashed"
    fi
fi
read -ep "Press [Enter] to return to the main menu."
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

echo_green "\nRestore stock BOOT_STUB firmware"

echo_yellow "Standard disclaimer: flashing the firmware has the potential to
brick your device, requiring relatively inexpensive hardware and some
technical knowledge to recover.  You have been warned."

read -ep "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot restore BOOT_STUB firmware."; return 1; }

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
flash_rwlegacy skip_prompt > /dev/null

echo_green "Stock BOOT_STUB firmware successfully restored"

#all done
read -ep "Press [Enter] to return to the main menu."
}


function clear_nvram() {
echo_green "\nClear UEFI NVRAM"
echo_yellow "Clearing the NVRAM will remove all EFI variables\nand reset the boot order to the default."
read -ep "Would you like to continue? [y/N] "
[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

echo_yellow "\nClearing NVRAM..."
${flashromcmd} -E -i SMMSTORE > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo_red "\nFailed to erase SMMSTORE firmware region; NVRAM not cleared."
    return 1;
fi
#all done
echo_green "NVRAM has been cleared."
read -ep "Press Enter to continue"
}

########################
# Firmware Update Menu #
########################
function menu_fwupdate() {

    if [[ "$isFullRom" = true ]]; then
        uefi_menu
    else
        stock_menu
    fi
}

function show_header() {
    printf "\ec"
    echo -e "${NORMAL}\n ChromeOS Device Firmware Utility Script ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Mr Chromebox <mrchromebox@gmail.com> ${NORMAL}"
    echo -e "${MENU}*********************************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER}   Device: ${NORMAL}${deviceDesc} (${boardName^^})"
    echo -e "${MENU}**${NUMBER} Platform: ${NORMAL}$deviceCpuType"
    echo -e "${MENU}**${NUMBER}  Fw Type: ${NORMAL}$firmwareType"
    echo -e "${MENU}**${NUMBER}   Fw Ver: ${NORMAL}$fwVer ($fwDate)"
    if [[ $isUEFI == true && $hasUEFIoption = true ]]; then
        # check if update available
        curr_yy=`echo $fwDate | cut -f 3 -d '/'`
        curr_mm=`echo $fwDate | cut -f 1 -d '/'`
        curr_dd=`echo $fwDate | cut -f 2 -d '/'`
        eval coreboot_file=$`echo "coreboot_uefi_${device}"`
        date=`echo $coreboot_file | grep -o "mrchromebox.*" | cut -f 2 -d '_' | cut -f 1 -d '.'`
        uefi_yy=`echo $date | cut -c1-4`
        uefi_mm=`echo $date | cut -c5-6`
        uefi_dd=`echo $date | cut -c7-8`
        if [[ ("$firmwareType" != *"pending"*) && (($uefi_yy > $curr_yy) || \
            ($uefi_yy == $curr_yy && $uefi_mm > $curr_mm) || \
            ($uefi_yy == $curr_yy && $uefi_mm == $curr_mm && $uefi_dd > $curr_dd)) ]]; then
            echo -e "${MENU}**${NORMAL}           ${GREEN_TEXT}Update Available ($uefi_mm/$uefi_dd/$uefi_yy)${NORMAL}"
        fi
    fi
    if [ "$wpEnabled" = true ]; then
        echo -e "${MENU}**${NUMBER}    Fw WP: ${RED_TEXT}Enabled${NORMAL}"
	WP_TEXT=${RED_TEXT}
    else
        echo -e "${MENU}**${NUMBER}    Fw WP: ${NORMAL}Disabled"
	WP_TEXT=${GREEN_TEXT}
    fi
    echo -e "${MENU}*********************************************************${NORMAL}"
}

function stock_menu() {
    
    show_header

    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && "$isUnsupported" = false ) ]]; then
        echo -e "${MENU}**${WP_TEXT}     ${NUMBER} 1)${MENU} Install/Update RW_LEGACY Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update RW_LEGACY Firmware ${NORMAL}"
    fi

    if [[ "$unlockMenu" = true || "$hasUEFIoption" = true || "$hasLegacyOption" = true ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 2)${MENU} Install/Update UEFI (Full ROM) Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 2)${GRAY_TEXT} Install/Update UEFI (Full ROM) Firmware${NORMAL}"
    fi
    if [[ "${device^^}" = "EVE" ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} D)${MENU} Downgrade Touchpad Firmware ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false ) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 3)${MENU} Set Boot Options (GBB flags) ${NORMAL}"
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 4)${MENU} Set Hardware ID (HWID) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 3)${GRAY_TEXT} Set Boot Options (GBB flags)${NORMAL}"
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 4)${GRAY_TEXT} Set Hardware ID (HWID) ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && \
		("$isHsw" = true || "$isBdw" = true || "$isByt" = true || "$isBsw" = true )) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 5)${MENU} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 6)${MENU} Restore ChromeOS Bitmaps ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isChromeOS" = false  && "$isFullRom" = true ) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 7)${MENU} Restore Stock Firmware (full) ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isByt" = true && "$isBootStub" = true && "$isChromeOS" = false ) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 8)${MENU} Restore Stock BOOT_STUB ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
        echo -e "${MENU}**${WP_TEXT}     ${NUMBER} C)${MENU} Clear UEFI NVRAM ${NORMAL}"
    fi
    echo -e "${MENU}*********************************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or${NORMAL}"
    echo -e "${nvram}${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"
    
    read -e opt
    case $opt in

        1)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isFullRom" = false \
                    && "$isBootStub" = false && "$isUnsupported" = false ]]; then
                flash_rwlegacy
            fi
            menu_fwupdate
            ;;

        2)  if [[  "$unlockMenu" = true || "$hasUEFIoption" = true || "$hasLegacyOption" = true ]]; then
                flash_coreboot
            fi
            menu_fwupdate
            ;;

        [dD])  if [[  "${device^^}" = "EVE" ]]; then
                downgrade_touchpad_fw
            fi
            menu_fwupdate
            ;;

        3)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                    && "$isFullRom" = false && "$isBootStub" = false ]]; then
                set_boot_options
            fi
            menu_fwupdate
            ;;

        4)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                    && "$isFullRom" = false && "$isBootStub" = false ]]; then
                set_hwid
            fi
            menu_fwupdate
            ;;

        5)  if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && \
                    ( "$isHsw" = true || "$isBdw" = true || "$isByt" = true || "$isBsw" = true ) )  ]]; then
                remove_bitmaps
            fi
            menu_fwupdate
            ;;

        6)  if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && \
                    ( "$isHsw" = true || "$isBdw" = true || "$isByt" = true || "$isBsw" = true ) )  ]]; then
                restore_bitmaps
            fi
            menu_fwupdate
            ;;

        7)  if [[ "$unlockMenu" = true || "$isChromeOS" = false && "$isUnsupported" = false \
                    && "$isFullRom" = true ]]; then
                restore_stock_firmware
            fi
            menu_fwupdate
            ;;

        8)  if [[ "$unlockMenu" = true || "$isBootStub" = true ]]; then
                restore_boot_stub
            fi
            menu_fwupdate
            ;;

        [rR])  echo -e "\nRebooting...\n";
            cleanup
            reboot
            exit
            ;;

        [pP])  echo -e "\nPowering off...\n";
            cleanup
            poweroff
            exit
            ;;

        [qQ])  cleanup;
            exit;
            ;;

        [U])  if [ "$unlockMenu" = false ]; then
                echo_yellow "\nAre you sure you wish to unlock all menu functions?"
                read -ep "Only do this if you really know what you are doing... [y/N]? "
                [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && unlockMenu=true
            fi
            menu_fwupdate
            ;;

        [cC]) if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
                clear_nvram
            fi
            menu_fwupdate
            ;;

        *)  clear
            menu_fwupdate;
            ;;
    esac
}

function uefi_menu() {
    
    show_header

    if [[ "$hasUEFIoption" = true ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 1)${MENU} Install/Update UEFI (Full ROM) Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update UEFI (Full ROM) Firmware${NORMAL}"
    fi
    if [[ "$isChromeOS" = false  && "$isFullRom" = true ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 2)${MENU} Restore Stock Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 2)${GRAY_TEXT} Restore Stock ChromeOS Firmware ${NORMAL}"
    fi
    if [[ "${device^^}" = "EVE" ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} D)${MENU} Downgrade Touchpad Firmware ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
        echo -e "${MENU}**${WP_TEXT}     ${NUMBER} C)${MENU} Clear UEFI NVRAM ${NORMAL}"
    fi
    echo -e "${MENU}*********************************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or${NORMAL}"
    echo -e "${nvram}${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"

    read -e opt
    case $opt in

        1)  if [[ "$hasUEFIoption" = true ]]; then
                flash_coreboot
            fi
            uefi_menu
            ;;

        2)  if [[ "$isChromeOS" = false && "$isUnsupported" = false \
                    && "$isFullRom" = true ]]; then
                restore_stock_firmware
                menu_fwupdate
            else
              uefi_menu
            fi
            ;;

        [dD])  if [[  "${device^^}" = "EVE" ]]; then
                downgrade_touchpad_fw
            fi
            uefi_menu
            ;;

        [rR])  echo -e "\nRebooting...\n";
            cleanup
            reboot
            exit
            ;;

        [pP])  echo -e "\nPowering off...\n";
            cleanup
            poweroff
            exit
            ;;

        [qQ])  cleanup;
            exit;
            ;;

        [cC]) if [[ "$isUEFI" = true ]]; then
                clear_nvram
            fi
            uefi_menu
            ;;

        *)  clear
            uefi_menu;
            ;;
    esac
}
