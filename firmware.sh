#!/bin/bash
#

# shellcheck disable=SC2154,SC2086,SC2059

###################
# flash RW_LEGACY #
###################
function flash_rwlegacy()
{
	#set working dir
	cd /tmp || { exit_red "Error changing to tmp dir; cannot proceed"; return 1; }

	# set dev mode legacy boot / AltFw flags
	if [ "${isChromeOS}" = true ]; then
		crossystem dev_boot_legacy=1 > /dev/null 2>&1
		crossystem dev_boot_altfw=1 > /dev/null 2>&1
	fi

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
	elif [ "$isKbl" = true ]; then
		rwlegacy_file=$seabios_kbl
	elif [ "$isWhl" = true ]; then
		rwlegacy_file=$rwl_altfw_whl
	elif [ "$device" = "drallion" ]; then
		rwlegacy_file=$rwl_altfw_drallion
	elif [ "$isCmlBox" = true ]; then
		rwlegacy_file=$rwl_altfw_cml
	elif [ "$isJsl" = true ]; then
		rwlegacy_file=$rwl_altfw_jsl
	elif [ "$isTgl" = true ]; then
		rwlegacy_file=$rwl_altfw_tgl
	elif [ "$isGlk" = true ]; then
		rwlegacy_file=$rwl_altfw_glk
	elif [ "$isAdl" = true ]; then
		rwlegacy_file=$rwl_altfw_adl
	elif [ "$isAdlN" = true ]; then
		rwlegacy_file=$rwl_altfw_adl_n
	elif [ "$isStr" = true ]; then
		rwlegacy_file=$rwl_altfw_stoney
	elif [ "$isPco" = true ]; then
		rwlegacy_file=$rwl_altfw_pco
	elif [ "$isCzn" = true ]; then
		rwlegacy_file=$rwl_altfw_czn
	elif [ "$isMdn" = true ]; then
		rwlegacy_file=$rwl_altfw_mdn
	else
		echo_red "Unknown or unsupported device (${device}); cannot update RW_LEGACY firmware."
		echo_red "If your device is listed as supported on https://mrchromebox.tech/#devices,\n
then email MrChromebox@gmail.com  and include a screenshot of the main menu."
		read -rep "Press enter to return to the main menu"
		return 1
	fi

	if [[ "$rwlegacy_file" = *"altfw"* ]]; then
		echo_green "\nInstall/Update RW_LEGACY Firmware (AltFw / edk2)"
	else
		echo_green "\nInstall/Update RW_LEGACY Firmware (Legacy BIOS / SeaBIOS)"
	fi

	echo_yellow "
NOTE: RW_LEGACY firmware cannot be used to run Windows. Period.
If you are looking to run Windows, see the documentation on coolstar.org.
MrChromebox does not provide any support for running Windows."
		REPLY=""
		read -rep "Press Y to continue or any other key to return to the main menu. "
		[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

	preferUSB=false
	if [[ "$rwlegacy_file" != *"altfw"* ]]; then
		echo -e ""
		#USB boot priority
		echo_yellow "Default to booting from USB?"
		read -rep "If N, always boot from internal storage unless selected from boot menu. [y/N] "
		[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && preferUSB=true
		echo -e ""
	fi

	#download RW_LEGACY update
	echo_yellow "\nDownloading RW_LEGACY firmware update\n(${rwlegacy_file})"
	$CURL -sLO "${rwlegacy_source}${rwlegacy_file}.md5"
	$CURL -sLO "${rwlegacy_source}${rwlegacy_file}"
	#verify checksum on downloaded file
	if ! md5sum -c "${rwlegacy_file}.md5" --quiet 2> /dev/null; then
		exit_red "RW_LEGACY download checksum fail; download corrupted, cannot flash"
		return 1
	fi

	#preferUSB?
	if [ "$preferUSB" = true  ]; then
		if ! $CURL -sLo bootorder "${cbfs_source}bootorder.usb"; then
			echo_red "Unable to download bootorder file; boot order cannot be changed."
		else
			${cbfstoolcmd} "${rwlegacy_file}" remove -n bootorder > /dev/null 2>&1
			${cbfstoolcmd} "${rwlegacy_file}" add -n bootorder -f /tmp/bootorder -t raw > /dev/null 2>&1
		fi
	fi

	#flash updated RW_LEGACY firmware
	echo_yellow "Installing RW_LEGACY firmware"
	if ! ${flashromcmd} -w -i RW_LEGACY:${rwlegacy_file} -o /tmp/flashrom.log > /dev/null 2>&1; then
		cat /tmp/flashrom.log
		echo_red "An error occurred flashing the RW_LEGACY firmware."
	else
		echo_green "RW_LEGACY firmware successfully installed/updated."
		# update firmware type
		firmwareType="Stock ChromeOS w/RW_LEGACY"
		#Prevent from trying to boot stock ChromeOS install
		rm -rf /tmp/boot/syslinux > /dev/null 2>&1
	fi

	read -rep "Press [Enter] to return to the main menu."
}


#############################
# Install Full ROM Firmware #
#############################
function flash_full_rom()
{
	echo_green "\nInstall/Update UEFI Full ROM Firmware"
	echo_yellow "IMPORTANT: flashing the firmware has the potential to brick your device, 
requiring relatively inexpensive hardware and some technical knowledge to 
recover.Not all boards can be tested prior to release, and even then slight 
differences in hardware can lead to unforseen failures.
If you don't have the ability to recover from a bad flash, you're taking a risk.

You have been warned."

	[[ "$isChromeOS" = true ]] && echo_yellow "Also, flashing Full ROM firmware will remove your ability to run ChromeOS."

	read -rep "Do you wish to continue? [y/N] "
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
	read -re
	[[ "$REPLY" = "I ACCEPT" ]] || return
	fi

	#UEFI notice if flashing from ChromeOS or Legacy
	if [[ ! -d /sys/firmware/efi ]]; then
		[[ "$isChromeOS" = true ]] && currOS="ChromeOS" || currOS="Your Legacy-installed OS"
		echo_yellow "
NOTE: After flashing UEFI firmware, you will need to install a UEFI-compatible
OS; ${currOS} will no longer be bootable. See https://mrchromebox.tech/#faq"
		REPLY=""
		read -rep "Press Y to continue or any other key to abort. "
		[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
	fi

	# PCO boot device notice
	if [[ "$isPCO" = true && ! -d /sys/firmware/efi ]]; then
		echo_yellow "
NOTE: Booting from eMMC on AMD Picasso-based devices does not currently work --
only NVMe, SD and USB. If you have a device with eMMC storage you will not be
able to boot from it after installing the UEFI Full ROM firmware."
		REPLY=""
		read -rep "Press Y to continue or any other key to abort. "
		[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
	fi

	#determine correct file / URL
	firmware_source=${fullrom_source}
	eval coreboot_file="$`echo "coreboot_uefi_${device}"`"
	if [[ "$coreboot_file" = "" ]]; then
		exit_red "The script does not currently have a firmware file for your device (${device^^}); cannot continue."; return 1
	fi

	#rammus special case (upgrade from older UEFI firmware)
	if [ "$device" = "rammus" ]; then
		echo -e ""
		echo_yellow "Unable to determine Chromebook model"
		echo -e "Because of your current firmware, I'm unable to
determine the exact mode of your Chromebook.  Are you using
an Asus C425 (LEONA) or Asus C433/C434 (SHYVANA)?
"
		REPLY=""
		while [[ "$REPLY" != "L" && "$REPLY" != "l" && "$REPLY" != "S" && "$REPLY" != "s"  ]]
		do
			read -rep "Enter 'L' for LEONA, 'S' for SHYVANA: "
			if [[ "$REPLY" = "S" || "$REPLY" = "s" ]]; then
				coreboot_file=${coreboot_uefi_shyvana}
			else
				coreboot_file=${coreboot_uefi_leona}
			fi
		done
	fi

	#coral special case (variant not correctly identified)
	if [ "$device" = "coral" ]; then
		echo -e ""
		echo_yellow "Unable to determine correct Chromebook model"
		echo -e "Because of your current firmware, I'm unable to determine the exact mode of your Chromebook.  
Please select the number for the correct option from the list below:"

		coral_boards=(
			"ASTRONAUT (Acer Chromebook 11 [C732])"
			"BABYMEGA (Asus Chromebook C223NA)"
			"BABYTIGER (Asus Chromebook C523NA)"
			"BLACKTIP (CTL Chromebook NL7/NL7T)"
			"BLUE (Acer Chromebook 15 [CB315])"
			"BRUCE (Acer Chromebook Spin 15 [CP315])"
			"EPAULETTE (Acer Chromebook 514)"
			"LAVA (Acer Chromebook Spin 11 [CP311])"
			"NASHER (Dell Chromebook 11 5190)"
			"NASHER360 (Dell Chromebook 11 5190 2-in-1)"
			"RABBID (Asus Chromebook C423)"
			"ROBO (Lenovo 100e Chromebook)"
			"ROBO360 (Lenovo 500e Chromebook)"
			"SANTA (Acer Chromebook 11 [CB311-8H])"
			"WHITETIP (CTL Chromebook J41/J41T)"
			)

		select board in "${coral_boards[@]}"; do
			board=$(echo ${board,,} | cut -f1 -d ' ')
			eval coreboot_file=$`echo "coreboot_uefi_${board}"`
			break;
		done
	fi

	#extract device serial if present in cbfs
	${cbfstoolcmd} /tmp/bios.bin extract -n serial_number -f /tmp/serial.txt >/dev/null 2>&1

	#extract device HWID
	if [[ "$isStock" = "true" ]]; then
		${gbbutilitycmd} /tmp/bios.bin --get --hwid | sed 's/[^ ]* //' > /tmp/hwid.txt 2>/dev/null
	else
		${cbfstoolcmd} /tmp/bios.bin extract -n hwid -f /tmp/hwid.txt >/dev/null 2>&1
	fi

	# create backup if existing firmware is stock
	if [[ "$isStock" = "true" ]]; then
		if [[ "$hasShellball" = "false" && "$isEOL" = "false" ]]; then
			REPLY=y
		else
			echo_yellow "\nCreate a backup copy of your stock firmware?"
			read -erp "This is highly recommended in case you wish to return your device to stock
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. [Y/n] "
		fi
		[[ "$REPLY" = "n" || "$REPLY" = "N" ]] && true || backup_firmware
		#check that backup succeeded
		[ $? -ne 0 ] && return 1
	fi

	#download firmware file
	cd /tmp || { exit_red "Error changing to tmp dir; cannot proceed"; return 1; }
	echo_yellow "\nDownloading Full ROM firmware\n(${coreboot_file})"
	$CURL -sLO "${firmware_source}${coreboot_file}"
	$CURL -sLO "${firmware_source}${coreboot_file}.sha1"

	#verify checksum on downloaded file
	if ! sha1sum -c "${coreboot_file}.sha1" --quiet > /dev/null 2>&1; then 
		exit_red "Firmware download checksum fail; download corrupted, cannot flash."; return 1
	fi

	#persist serial number?
	if [ -f /tmp/serial.txt ]; then
		echo_yellow "Persisting device serial number"
		${cbfstoolcmd} "${coreboot_file}" add -n serial_number -f /tmp/serial.txt -t raw > /dev/null 2>&1
	fi

	#persist device HWID?
	if [ -f /tmp/hwid.txt ]; then
		echo_yellow "Persisting device HWID"
		${cbfstoolcmd} "${coreboot_file}" add -n hwid -f /tmp/hwid.txt -t raw > /dev/null 2>&1
	fi

	#Persist RW_MRC_CACHE UEFI Full ROM firmware
	${cbfstoolcmd} /tmp/bios.bin read -r RW_MRC_CACHE -f /tmp/mrc.cache > /dev/null 2>&1
	if [[ $isFullRom = "true" && $? -eq 0 ]]; then
		${cbfstoolcmd} "${coreboot_file}" write -r RW_MRC_CACHE -f /tmp/mrc.cache > /dev/null 2>&1
	fi

	#Persist SMMSTORE if exists
	if ${cbfstoolcmd} /tmp/bios.bin read -r SMMSTORE -f /tmp/smmstore > /dev/null 2>&1; then
		${cbfstoolcmd} "${coreboot_file}" write -r SMMSTORE -f /tmp/smmstore > /dev/null 2>&1
	fi

	# persist VPD if possible
	if extract_vpd /tmp/bios.bin; then
		# try writing to RO_VPD FMAP region
		if ! ${cbfstoolcmd} "${coreboot_file}" write -r RO_VPD -f /tmp/vpd.bin > /dev/null 2>&1; then
			# fall back to vpd.bin in CBFS
			${cbfstoolcmd} "${coreboot_file}" add -n vpd.bin -f /tmp/vpd.bin -t raw > /dev/null 2>&1
		fi
	fi

	#disable software write-protect
	echo_yellow "Disabling software write-protect and clearing the WP range"
	if ! ${flashromcmd} --wp-disable > /dev/null 2>&1 && [[ "$swWp" = "enabled" ]]; then
		exit_red "Error disabling software write-protect; unable to flash firmware."; return 1
	fi

	#clear SW WP range
	if ! ${flashromcmd} --wp-range 0 0 > /dev/null 2>&1; then
		# use new command format as of commit 99b9550
		if ! ${flashromcmd} --wp-range 0,0 > /dev/null 2>&1 && [[ "$swWp" = "enabled" ]]; then
			exit_red "Error clearing software write-protect range; unable to flash firmware."; return 1
		fi
	fi

	#flash Full ROM firmware

	# clear log file
	rm -f /tmp/flashrom.log

	echo_yellow "Installing Full ROM firmware (may take up to 90s)"
	#check if flashrom supports --noverify-all
	if ${flashromcmd} -h | grep -q "noverify-all" ; then
		noverify="-N"
	else
		noverify="-n"
	fi
	#check if flashrom supports logging to file
	if ${flashromcmd} -V -o /dev/null > /dev/null 2>&1; then
		output_params=">/dev/null 2>&1 -o /tmp/flashrom.log"
		${flashromcmd} ${flashrom_params} ${noverify} -w ${coreboot_file} >/dev/null 2>&1 -o /tmp/flashrom.log
	else
		output_params=">/tmp/flashrom.log 2>&1"
		${flashromcmd} ${flashrom_params} ${noverify} -w ${coreboot_file} >/tmp/flashrom.log 2>&1
	fi
	if [ $? -ne 0 ]; then
		echo_red "Error running cmd: ${flashromcmd} ${flashrom_params} ${noverify} -w ${coreboot_file} ${output_params}"
		if [ -f /tmp/flashrom.log ]; then
			read -rp "Press enter to view the flashrom log file, then space for next page, q to quit"
			more /tmp/flashrom.log
		fi
		exit_red "An error occurred flashing the Full ROM firmware. DO NOT REBOOT!"; return 1
	else
		echo_green "Full ROM firmware successfully installed/updated."

		#Prevent from trying to boot stock ChromeOS install
		if [[ "$isStock" = true && "$isChromeOS" = true ]]; then
			rm -rf /tmp/boot/efi > /dev/null 2>&1
			rm -rf /tmp/boot/syslinux > /dev/null 2>&1
		fi

		#Warn about long RAM training time
		echo_yellow "IMPORTANT:\nThe first boot after flashing may take substantially
longer than subsequent boots -- up to 30s or more.
Be patient and eventually your device will boot :)"

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
		firmwareType="Full ROM / UEFI (pending reboot)"
		isUEFI=true
	fi

	read -rep "Press [Enter] to return to the main menu."
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
		read -rep "Do you wish to downgrade the touchpad firmware now? [y/N] "
		if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] ; then
			# ensure firmware write protect disabled
			[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot downgrade touchpad firmware."; return 1; }
			# download TP firmware
			echo_yellow "\nDownloading touchpad firmware\n(${touchpad_eve_fw})"
			$CURL -s -LO "${other_source}${touchpad_eve_fw}"
			$CURL -s -LO "${other_source}${touchpad_eve_fw}.sha1"
			#verify checksum on downloaded file
			if sha1sum -c ${touchpad_eve_fw}.sha1 --quiet > /dev/null 2>&1; then
				# flash TP firmware
				echo_green "Flashing touchpad firmware -- do not touch the touchpad while updating!"
				if ${flashromcmd/${flashrom_programmer}} -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw} -o /tmp/flashrom.log >/dev/null 2>&1; then
					echo_green "Touchpad firmware successfully downgraded."
					echo_yellow "Please reboot your Pixelbook now."
				else
					# try with older eve flashrom
					(
						cd /tmp/boot/util
						$CURL -sLO "${util_source}flashrom_eve_tp"
						chmod +x flashrom_eve_tp
					)
					if /tmp/boot/util/flashrom_eve_tp -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw} -o /tmp/flashrom.log >/dev/null 2>&1; then
						echo_green "Touchpad firmware successfully downgraded."
						echo_yellow "Please reboot your Pixelbook now."
					else
						echo_red "Error flashing touchpad firmware:"
						cat /tmp/flashrom.log
						echo_yellow "\nThis function sometimes doesn't work under Linux, in which case it is\nrecommended to try under ChromiumOS."
					fi
				fi
			else
				echo_red "Touchpad firmware download checksum fail; download corrupted, cannot flash."
			fi
		fi
		read -rep "Press [Enter] to return to the main menu."
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

	read -rep "Do you wish to continue? [y/N] "
	[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

	# check if EOL
	if [ "$isEOL" = true ]; then
		echo_yellow "\nVERY IMPORTANT:
Your device has reached end of life (EOL) and is no longer supported by Google.
Returning the to stock firmware **IS NOT RECOMMENDED**.
MrChromebox will not provide any support for EOL devices running anything
other than the latest UEFI Full ROM firmware release."

		read -rep "Do you wish to continue? [y/N] "
		[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return
	fi

	#spacing
	echo -e ""

	# ensure hardware write protect disabled
	[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot restore stock firmware."; return 1; }

	# default file to download to
	firmware_file="/tmp/stock-firmware.rom"

	echo -e ""
	echo_yellow "Please select an option below for restoring the stock firmware:"
	echo -e "1) Restore using a shellball image (downloaded) [if available]"
	echo -e "2) Restore using a firmware backup on USB"
	echo -e "3) Restore using a ChromeOS Recovery USB"
	echo -e "Q) Quit and return to main menu"
	echo -e ""

	restore_option=-1
	while :
	do
		read -rep "? " restore_option
		case $restore_option in

			1)  if [[ "$hasShellball" = "true" ]]; then
					restore_fw_from_shellball || return 1;
					break;
				else
					echo -e "\nUnfortunately I don't have a stock firmware available to download for '${boardName^^}'
at this time. Please select another option from the menu.\n";
				fi
				;;

			2)  restore_fw_from_usb || return 1;
				break;
				;;
			3)  restore_fw_from_recovery || return 1;
				break;
				;;
			Q|q) restore_option="Q";
				break;
				;;
		esac
	done
	[[ "$restore_option" = "Q" ]] && return

	if [[ $restore_option -ne 2 ]]; then 
		#extract VPD from current firmware if present
		if extract_vpd /tmp/bios.bin ; then
			#merge with shellball/recovery image firmware
			if [ -f /tmp/vpd.bin ]; then
				echo_yellow "Merging VPD into shellball/recovery image firmware"
				${cbfstoolcmd} ${firmware_file} write -r RO_VPD -f /tmp/vpd.bin > /dev/null 2>&1
			fi
		fi

		#extract hwid from current firmware if present
		if ${cbfstoolcmd} /tmp/bios.bin extract -n hwid -f /tmp/hwid.txt > /dev/null 2>&1; then
			#merge with shellball/recovery image firmware
			hwid="$(sed 's/^hardware_id: //' /tmp/hwid.txt 2>/dev/null)"
			if [[ "$hwid" != "" ]]; then
				echo_yellow "Injecting HWID into shellball/recovery image firmware"
				${gbbutilitycmd} ${firmware_file} --set --hwid="$hwid" > /dev/null 2>&1
			fi
		fi
	fi

	#clear GBB flags before flashing
	${gbbutilitycmd} ${firmware_file} --set --flags=0x0 > /dev/null 2>&1

	#flash stock firmware
	echo_yellow "Restoring stock firmware"
	# only verify part of flash we write
	if ! ${flashromcmd} ${flashrom_params} -N -w "${firmware_file}" -o /tmp/flashrom.log > /dev/null 2>&1; then
		cat /tmp/flashrom.log
		exit_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"; return 1
	fi

	#re-enable software WP to prevent recovery issues
	echo_yellow "Re-enabling software write-protect"
	${flashromcmd} --wp-region WP_RO --fmap > /dev/null 2>&1
	if ! ${flashromcmd} --wp-enable > /dev/null 2>&1; then
		echo_red "Warning: unable to re-enable software write-protect;
you may need to perform ChromeOS recovery with the battery disconnected."
	fi

	#all good
	echo_green "Stock firmware successfully restored."
	echo_green "After rebooting, you need to restore ChromeOS using ChromeOS Recovery media.
See: https://google.com/chromeos/recovery for more info."
	read -rep "Press [Enter] to return to the main menu."
	#set vars to indicate new firmware type
	isStock=true
	isFullRom=false
	isUEFI=false
	firmwareType="Stock ChromeOS (pending reboot)"
}

function restore_fw_from_usb()
{
	read -rep "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "
		
		list_usb_devices || { exit_red "No USB devices available to read firmware backup."; return 1; }
		usb_dev_index=""
		while [[ "$usb_dev_index" = "" || ($usb_dev_index -le 0 && $usb_dev_index -gt $num_usb_devs) ]]; do
			read -rep "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
			if [[ "$usb_dev_index" = "" || ($usb_dev_index -le 0 && $usb_dev_index -gt $num_usb_devs) ]]; then
				echo -e "Error: Invalid option selected; enter a number from the list above."
			fi
		done
		usb_device="${usb_devs[${usb_dev_index}-1]}"
		mkdir /tmp/usb > /dev/null 2>&1
		mount "${usb_device}" /tmp/usb > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			mount "${usb_device}1" /tmp/usb
		fi
		if [ $? -ne 0 ]; then
			echo_red "USB device failed to mount; cannot proceed."
			read -rep "Press [Enter] to return to the main menu."
			umount /tmp/usb > /dev/null 2>&1
			return
		fi
		#select file from USB device
		echo_yellow "\n(Potential) Firmware Files on USB:"
		if ! ls  /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null; then
			echo_red "No firmware files found on USB device."
			read -rep "Press [Enter] to return to the main menu."
			umount /tmp/usb > /dev/null 2>&1
			return 1
		fi
		echo -e ""
		read -rep "Enter the firmware filename:  " firmware_file
		firmware_file=/tmp/usb/${firmware_file}
		if [ ! -f ${firmware_file} ]; then
			echo_red "Invalid filename entered; unable to restore stock firmware."
			read -rep "Press [Enter] to return to the main menu."
			umount /tmp/usb > /dev/null 2>&1
			return 1
		fi
		#text spacing
		echo -e ""
}

function restore_fw_from_shellball()
{
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
		read -rep "? " fw_num
		if [[ $fw_num -lt 1 ||  $fw_num -gt 5 ]]; then
			exit_red "Invalid input - cancelling"
			return 1
		fi
		#confirm menu selection
		echo -e ""
		read -rep "Confirm selection number ${fw_num} [y/N] "
		[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || { exit_red "User cancelled restoring stock firmware"; return; }

		#download firmware file
		echo -e ""
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
		read -rep "? [y/N] "
		if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
			exit_red "Device detection failed; unable to restoring stock firmware"
			return 1
		fi
		echo -e ""
		_device=${boardName,,}
	fi

	#download shellball ROM
	echo_yellow "Downloading shellball.${_device}.bin"
	if ! $CURL -sLo ${firmware_file} ${shellball_source}shellball.${_device}.bin; then
		exit_red "Error downloading; unable to restore stock firmware."
		return 1
	fi
}

function restore_fw_from_recovery()
{
	echo -e "\nConnect a USB which contains a ChromeOS Recovery Image"
	read -rep "and press [Enter] to continue. "
	
	list_usb_devices || { exit_red "No USB devices available to read from."; return 1; }
	usb_dev_index=""
	while [[ "$usb_dev_index" = "" || ($usb_dev_index -le 0 && ! $usb_dev_index -gt $num_usb_devs) ]]; do
		read -rep "Enter the number which corresponds your ChromeOS Recovery USB: " usb_dev_index
		if [[ "$usb_dev_index" = "" || ($usb_dev_index -le 0 && $usb_dev_index -gt $num_usb_devs) ]]; then
			echo -e "Error: Invalid option selected; enter a number from the list above."
		fi
	done
	usb_device="${usb_devs[${usb_dev_index}-1]}"
	echo -e ""
	if ! extract_shellball_from_recovery_usb ${boardName,,} $usb_device ; then
		exit_red "Error: failed to extract firmware from ChromeOS recovery USB"
		return 1
	fi
	mv coreboot-Google_* ${firmware_file}
	# set a semi-legit HWID in case we don't have a backup below
	${gbbutilitycmd} --set --hwid="${boardName^^} ABC-123-XYZ-456" ${firmware_file} > /dev/null
	echo_yellow "Stock firmware successfully extracted from ChromeOS recovery image"
}

######################################
# Extract firmware from recovery usb #
######################################
function extract_shellball_from_recovery_usb()
{
	_board=$1
	_debugfs=${2}3
	_shellball=chromeos-firmwareupdate-$_board
	_unpacked=$(mktemp -d)

	echo_yellow "Extracting firmware from recovery USB"
	printf "cd /usr/sbin\ndump chromeos-firmwareupdate $_shellball\nquit" | debugfs $_debugfs >/dev/null 2>&1

	if ! sh $_shellball --unpack $_unpacked >/dev/null 2>&1; then
		sh $_shellball --sb_extract $_unpacked >/dev/null 2>&1
	fi

	if [ -d $_unpacked/models/ ]; then
		_version=$(cat $_unpacked/VERSION | grep -m 1 -e Model.*$_board -A5 | grep "BIOS (RW) version:" | cut -f2 -d: | tr -d \ )
		if [ "$_version" = "" ]; then
			_version=$(cat $_unpacked/VERSION | grep -m 1 -e Model.*$_board -A5 | grep "BIOS version:" | cut -f2 -d: | tr -d \ )
		fi
		_bios_image=$(grep "IMAGE_MAIN" $_unpacked/models/$_board/setvars.sh | cut -f2 -d\")
	else
		_version=$(cat $_unpacked/VERSION | grep BIOS\ version: | cut -f2 -d: | tr -d \ )
		_bios_image=bios.bin
	fi
	cp $_unpacked/$_bios_image coreboot-$_version.bin
	rm -rf "$_unpacked"
	rm $_shellball
}


########################
# Extract firmware VPD #
########################
function extract_vpd()
{
	#check params
	[[ -z "$1" ]] && { exit_red "Error: extract_vpd(): missing function parameter"; return 1; }

	local firmware_file="$1"

	#try FMAP extraction
	if ! ${cbfstoolcmd} ${firmware_file} read -r RO_VPD -f /tmp/vpd.bin >/dev/null 2>&1 ; then
		#try CBFS extraction
		if ! ${cbfstoolcmd} ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin >/dev/null 2>&1 ; then
			return 1
		fi
	fi
	echo_yellow "VPD extracted from current firmware"
	return 0
}


#########################
# Backup stock firmware #
#########################
function backup_firmware()
{
	echo -e ""
	read -rep "Connect the USB/SD device to store the firmware backup and press [Enter]
to continue.  This is non-destructive, but it is best to ensure no other
USB/SD devices are connected. "

	if ! list_usb_devices; then
		backup_fail "No USB devices available to store firmware backup."
		return 1
	fi

	usb_dev_index=""
	while [[ "$usb_dev_index" = "" || ($usb_dev_index -le 0 && $usb_dev_index -gt $num_usb_devs) ]]; do
		read -rep "Enter the number for the device to be used for firmware backup: " usb_dev_index
		if [[ "$usb_dev_index" = "" || ($usb_dev_index -le 0 && $usb_dev_index -gt $num_usb_devs) ]]; then
			echo -e "Error: Invalid option selected; enter a number from the list above."
		fi
	done

	usb_device="${usb_devs[${usb_dev_index}-1]}"
	mkdir /tmp/usb > /dev/null 2>&1
	if ! mount "${usb_device}" /tmp/usb > /dev/null 2>&1; then
		if ! mount "${usb_device}1" /tmp/usb > /dev/null 2>&1; then
			backup_fail "USB backup device failed to mount; cannot proceed."
			return 1
		fi
	fi
	backupname="stock-firmware-${boardName}-$(date +%Y%m%d).rom"
	echo_yellow "\nSaving firmware backup as ${backupname}"
	if ! cp /tmp/bios.bin /tmp/usb/${backupname}; then
		backup_fail "Failure copying stock firmware to USB; cannot proceed."
		return 1
	fi
	sync
	umount /tmp/usb > /dev/null 2>&1
	rmdir /tmp/usb
	echo_green "Firmware backup complete. Remove the USB stick and press [Enter] to continue."
	read -rep ""
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

	echo_green "\nSet Firmware Boot Options (GBB Flags)"
	echo_yellow "Select your preferred boot delay and default boot option.
You can always override the default using [CTRL+D] or
[CTRL+L] on the Developer Mode boot screen"

	echo -e "1) Short boot delay (1s) + Legacy Boot/AltFw default
2) Long boot delay (30s) + Legacy Boot/AltFw default
3) Short boot delay (1s) + ChromeOS default
4) Long boot delay (30s) + ChromeOS default
5) Reset to factory default
6) Cancel/exit
"
	local _flags=0x0
	while :
	do
		read -rep "? " n
		case $n in
			1) _flags=0x4A9; break;;
			2) _flags=0x4A8; break;;
			3) _flags=0xA9; break;;
			4) _flags=0xA8; break;;
			5) _flags=0x0; break;;
			6) read -rep "Press [Enter] to return to the main menu."; break;;
			*) echo -e "invalid option";;
		esac
	done
	[[ $n -eq 6 ]] && return
	echo_yellow "\nSetting boot options..."
	
	#disable software write-protect
	if ! ${flashromcmd} --wp-disable > /dev/null 2>&1; then
		exit_red "Error disabling software write-protect; unable to set GBB flags."; return 1
	fi
	if ! ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
		exit_red "\nError reading firmware (non-stock?); unable to set boot options."; return 1
	fi
	if ! ${gbbutilitycmd} --set --flags="${_flags}" /tmp/gbb.temp > /dev/null; then
		exit_red "\nError setting boot options."; return 1
	fi
	if ! ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
		exit_red "\nError writing back firmware; unable to set boot options."; return 1
	fi

	echo_green "\nFirmware Boot options successfully set."

	read -rep "Press [Enter] to return to the main menu."
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
	if [[ "$_hwid" != "" ]]; then
		echo_yellow "Current HWID is $_hwid"
	fi

	echo_yellow "Are you sure you know what you're doing here? 
Changing this is not normally needed, and if you mess it up,
MrChromebox is not going to help you fix it. This won't let
you run a different/newer version of ChromeOS.
Proceed at your own risk."

	read -rep "Really change your HWID? [y/N] " confirm
	[[ "$confirm" = "Y" || "$confirm" = "y" ]] || return

	read -rep "This is serious. Are you really sure? [y/N] " confirm
	[[ "$confirm" = "Y" || "$confirm" = "y" ]] || return

	read -rep "Enter a new HWID (use all caps): " hwid
	echo -e ""
	read -rep "Confirm changing HWID to $hwid [y/N] " confirm
	if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
		echo_yellow "\nSetting hardware ID..."
		#disable software write-protect
		if ! ${flashromcmd} --wp-disable > /dev/null 2>&1; then
			exit_red "Error disabling software write-protect; unable to set HWID."; return 1
		fi
		if ! ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then 
			exit_red "\nError reading firmware (non-stock?); unable to set HWID."; return 1
		fi
		if ! ${gbbutilitycmd} --set --hwid="${hwid}" /tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError setting HWID."; return 1
		fi
		if ! ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError writing back firmware; unable to set HWID."; return 1
		fi
		
		echo_green "Hardware ID successfully set."
	fi
	read -rep "Press [Enter] to return to the main menu."
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

	read -rep "Confirm removing ChromeOS bitmaps? [y/N] " confirm
	if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
		echo_yellow "\nRemoving bitmaps..."
		#disable software write-protect
		if ! ${flashromcmd} --wp-disable > /dev/null 2>&1; then
			exit_red "Error disabling software write-protect; unable to remove bitmaps."; return 1
		fi
		#read GBB region
		if ! ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError reading firmware (non-stock?); unable to remove bitmaps."; return 1
		fi
		touch /tmp/null-images > /dev/null 2>&1
		#set bitmaps to null
		if ! ${gbbutilitycmd} --set --bmpfv=/tmp/null-images /tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError removing bitmaps."; return 1
		fi
		#flash back to board
		if ! ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError writing back firmware; unable to remove bitmaps."; return 1
		fi
		
		echo_green "ChromeOS bitmaps successfully removed."
	fi
	read -rep "Press [Enter] to return to the main menu."
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

	read -rep "Confirm restoring ChromeOS bitmaps? [y/N] " confirm
	if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
		echo_yellow "\nRestoring bitmaps..."
		#disable software write-protect
		if ! ${flashromcmd} --wp-disable > /dev/null 2>&1; then
			exit_red "Error disabling software write-protect; unable to restore bitmaps."; return 1
		fi
		#download shellball
		if ! $CURL -sLo /tmp/shellball.rom ${shellball_source}shellball.${device}.bin; then 
			exit_red "Error downloading shellball; unable to restore bitmaps."; return 1
		fi 
		#extract GBB region, bitmaps
		if ! ${cbfstoolcmd} /tmp/shellball.rom read -r GBB -f gbb.new >/dev/null 2>&1; then
			exit_red "Error extracting GBB region from shellball; unable to restore bitmaps."; return 1
		fi
		if ! ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError reading firmware (non-stock?); unable to restore bitmaps."; return 1
		fi
		#inject bitmaps into GBB
		if ! ${gbbutilitycmd} --get --bmpfv=/tmp/bmpfv /tmp/gbb.new > /dev/null && \
				${gbbutilitycmd} --set --bmpfv=/tmp/bmpfv /tmp/gbb.temp > /dev/null; then
			exit_red "\nError restoring bitmaps."; return 1
		fi
		#flash back to device
		if ! ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1; then
			exit_red "\nError writing back firmware; unable to restore bitmaps."; return 1
		fi

		echo_green "ChromeOS bitmaps successfully restored."
	fi
	read -rep "Press [Enter] to return to the main menu."
}

###############
# Clear NVRAM #
###############
function clear_nvram() {
	echo_green "\nClear UEFI NVRAM"
	echo_yellow "Clearing the NVRAM will remove all EFI variables\nand reset the boot order to the default."
	read -rep "Would you like to continue? [y/N] "
	[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

	echo_yellow "\nClearing NVRAM..."
	if ! ${flashromcmd} -E -i SMMSTORE --fmap > /tmp/flashrom.log 2>&1; then
		cat /tmp/flashrom.log
		exit_red "\nFailed to erase SMMSTORE firmware region; NVRAM not cleared."
		return 1;
	fi
	#all done
	echo_green "NVRAM has been cleared."
	read -rep "Press Enter to continue"
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
	if [[ $isUEFI = true && $hasUEFIoption = true ]]; then
		# check if update available
		curr_yy=$(echo $fwDate | cut -f 3 -d '/')
		curr_mm=$(echo $fwDate | cut -f 1 -d '/')
		curr_dd=$(echo $fwDate | cut -f 2 -d '/')
		eval coreboot_file=$`echo "coreboot_uefi_${device}"`
		date=$(echo $coreboot_file | grep -o "mrchromebox.*" | cut -f 2 -d '_' | cut -f 1 -d '.')
		uefi_yy=$(echo $date | cut -c1-4)
		uefi_mm=$(echo $date | cut -c5-6)
		uefi_dd=$(echo $date | cut -c7-8)
		if [[ ("$firmwareType" != *"pending"*) && (($uefi_yy > $curr_yy) || \
			("$uefi_yy" = "$curr_yy" && "$uefi_mm" > "$curr_mm") || \
			("$uefi_yy" = "$curr_yy" && "$uefi_mm" = "$curr_mm" && "$uefi_dd" > "$curr_dd")) ]]; then
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

	if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && "$isUnsupported" = false \
			&& "$isCmlBook" = false && "$isEOL" = false ) ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} 1)${MENU} Install/Update RW_LEGACY Firmware ${NORMAL}"
	else
		echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update RW_LEGACY Firmware ${NORMAL}"
	fi

	if [[ "$unlockMenu" = true || "$hasUEFIoption" = true ]]; then
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
	if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} C)${MENU} Clear UEFI NVRAM ${NORMAL}"
	fi
	echo -e "${MENU}*********************************************************${NORMAL}"
	echo -e "${ENTER_LINE}Select a numeric menu option or${NORMAL}"
	echo -e "${nvram}${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"
	
	read -re opt
	case $opt in

		1)  if [[ "$unlockMenu" = true || "$isEOL" = false && ("$isChromeOS" = true && "$isCmlBook" = false \
					|| "$isFullRom" = false && "$isBootStub" = false && "$isUnsupported" = false) ]]; then
				flash_rwlegacy
			elif [[ "$isEOL" = "true" ]]; then
				echo_red "The RW_LEGACY firmware update is not supported for devices which have reached end-of-life"
				read -rep "Press enter to return to the main menu"
			fi 
			menu_fwupdate
			;;

		2)  if [[ "$unlockMenu" = true || "$hasUEFIoption" = true ]]; then
				flash_full_rom
			fi
			menu_fwupdate
			;;

		[dD])  if [[ "${device^^}" = "EVE" ]]; then
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
				read -rep "Only do this if you really know what you are doing... [y/N]? "
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
	echo -e "${ENTER_LINE}Select a numeric menu option or${NORMAL}"
	echo -e "${nvram}${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"

	read -re opt
	case $opt in

		1)  if [[ "$hasUEFIoption" = true ]]; then
				flash_full_rom
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
