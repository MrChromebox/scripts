#!/bin/bash
#

# shellcheck disable=SC2154,SC2086,SC2059

# Variables used only in this file
usb_device=""

#######################
# Download Files List #
#######################
function download_files()
{
	log_fn
	local array_name=$1
	local base_url="$2"
	
	# Download all files in the array
	# Use eval for compatibility with older bash versions that don't support nameref (-n)
	local files
	eval "files=(\"\${${array_name}[@]}\")"
	
	for file in "${files[@]}"; do
		log_section "download: ${base_url}${file}"
		if ! $CURL -#LO "${base_url}${file}"; then
			echo_red "Error downloading ${file}; cannot continue"
			return 1
		fi
	done
	#line break
	echo -e ""
}

###################
# flash RW_LEGACY #
###################
function prompt_rwlegacy_firmware_type()
{
	local uefi_file="$1"
	local legacy_file="$2"

	echo -e ""
	echo_yellow "Firmware Type Selection"
	echo -e "Your device has the option of two RW_LEGACY firmware types."
	REPLY=""
	while [[ "$REPLY" != "L" && "$REPLY" != "l" && "$REPLY" != "U" && "$REPLY" != "u" ]]; do
		read -rep "Enter 'L' for Legacy BIOS (SeaBIOS), 'U' for UEFI (edk2/Tianocore): "
		if [[ "$REPLY" = "U" || "$REPLY" = "u" ]]; then
			rwlegacy_file=$uefi_file
		else
			rwlegacy_file=$legacy_file
		fi
	done
}

function flash_rwlegacy()
{
	log_fn
	#set working dir
	cd /tmp || fail_menu "Error changing to tmp dir; cannot proceed" || return

	# set dev mode legacy boot / AltFw flags
	if [[ "$isChromeOS" = true ]]; then
		run_quiet crossystem dev_boot_legacy=1
		run_quiet crossystem dev_boot_altfw=1
	fi

	#determine proper file
	if [[ "$device" = "link" ]]; then
		rwlegacy_file=$seabios_link
	elif [[ "$isHswBox" = true || "$isBdwBox" = true ]]; then
		rwlegacy_file=$seabios_hswbdw_box
	elif [[ "$isHswBook" = true || "$isBdwBook" = true ]]; then
		rwlegacy_file=$seabios_hswbdw_book
	elif [[ "$isByt" = true ]]; then
		rwlegacy_file=$seabios_baytrail
	elif [[ "$isBsw" = true ]]; then
		rwlegacy_file=$seabios_braswell
	elif [[ "$isSkl" = true ]]; then
		rwlegacy_file=$seabios_skylake
	elif [[ "$isApl" = true ]]; then
		prompt_rwlegacy_firmware_type "$rwl_altfw_apl" "$seabios_apl"
	elif [[ "$isKbl" = true ]]; then
		if [[ "$kbl_rwl18" = true ]]; then
			prompt_rwlegacy_firmware_type "$rwl_altfw_kbl_18" "$seabios_kbl_18"
		else
			prompt_rwlegacy_firmware_type "$rwl_altfw_kbl" "$seabios_kbl"
		fi
	elif [[ "$isWhl" = true ]]; then
		rwlegacy_file=$rwl_altfw_whl
	elif [[ "$device" = "drallion" ]]; then
		rwlegacy_file=$rwl_altfw_drallion
	elif [[ "$isCmlBox" = true ]]; then
		rwlegacy_file=$rwl_altfw_cml
	elif [[ "$isJsl" = true ]]; then
		rwlegacy_file=$rwl_altfw_jsl
	elif [[ "$isTgl" = true ]]; then
		rwlegacy_file=$rwl_altfw_tgl
	elif [[ "$isGlk" = true ]]; then
		rwlegacy_file=$rwl_altfw_glk
	elif [[ "$isAdl_fixed_rwl" = true ]]; then
		rwlegacy_file=$rwl_altfw_adl_fixed
	elif [[ "$isAdl" = true ]]; then
		rwlegacy_file=$rwl_altfw_adl
	elif [[ "$isAdlN" = true || "$isTwl" = true ]]; then
		rwlegacy_file=$rwl_altfw_adl_n
	elif [[ "$isMtl" = true ]]; then
		rwlegacy_file=$rwl_altfw_mtl
	elif [[ "$isStr" = true ]]; then
		rwlegacy_file=$rwl_altfw_stoney
	elif [[ "$isPco" = true ]]; then
		rwlegacy_file=$rwl_altfw_pco
	elif [[ "$isCzn" = true ]]; then
		rwlegacy_file=$rwl_altfw_czn
	elif [[ "$isMdn" = true ]]; then
		rwlegacy_file=$rwl_altfw_mdn
	else
		fail_menu "Unknown or unsupported device (${device}); cannot update RW_LEGACY firmware.
If your device is listed as supported on https://mrchromebox.tech/#devices,
then email MrChromebox@gmail.com  and include a screenshot of the main menu." || return
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

	local preferUSB=false
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
	
	rwlegacy_files=(
		"${rwlegacy_file}.md5"
		"${rwlegacy_file}"
	)
	download_files rwlegacy_files "${rwlegacy_source}" || return 1

	#verify checksum on downloaded file
	if ! md5sum -c "${rwlegacy_file}.md5" > /dev/null 2>&1; then
		fail_menu "RW_LEGACY download checksum fail; download corrupted, cannot flash" || return
	fi

	#preferUSB?
	if [[ "$preferUSB" = true ]]; then
		if ! $CURL -sLo bootorder "${cbfs_source}bootorder.usb"; then
			echo_red "Unable to download bootorder file; boot order cannot be changed."
		else
			run_quiet ${cbfstoolcmd} "${rwlegacy_file}" remove -n bootorder
			run_quiet ${cbfstoolcmd} "${rwlegacy_file}" add -n bootorder -f /tmp/bootorder -t raw
		fi
	fi

	#flash updated RW_LEGACY firmware
	echo_yellow "Installing RW_LEGACY firmware"
	[[ "$isChromeOS" = false ]] && FMAP="--fmap"
	if ! run_quiet ${flashromcmd} -w $FMAP -i RW_LEGACY:${rwlegacy_file} ${noverify} -o /tmp/flashrom.log; then
		cat /tmp/flashrom.log
		echo_red "An error occurred flashing the RW_LEGACY firmware."
	else
		echo_green "RW_LEGACY firmware successfully installed/updated."
		# update firmware type
		firmwareType="Stock ChromeOS w/RW_LEGACY"
		#Prevent from trying to boot stock ChromeOS install
		[[ "$boot_mounted" = true ]] && rm -rf /tmp/boot/syslinux > /dev/null 2>&1
	fi

	read -rep "Press [Enter] to return to the main menu."
}

#############################
# Install Full ROM Firmware #
#############################
function flash_full_rom()
{
	log_fn
	local slot="${1:-latest}"
	local coreboot_file=""
	local slot_label=""

	# ensure hardware write protect disabled
	if [[ "$wpEnabled" = true ]]; then
		fail_menu "\nHardware write-protect enabled, cannot flash Full ROM firmware."
		return
	fi

	if [[ "$slot" != "latest" && "$slot" != "previous" ]]; then
		fail_menu "Invalid firmware release slot: ${slot}" || return
	fi

	[[ -n "$device" ]] || fail_menu "Unable to determine device board name; cannot continue." || return

	coreboot_file=$(fullrom_resolve_slot "$slot")
	slot_label=$(fullrom_slot_label "$slot")
	if [[ -z "$coreboot_file" ]]; then
		if [[ "$slot" = "previous" ]]; then
			fail_menu "No previous UEFI release is configured; cannot continue." || return
		else
			fail_menu "Unable to determine firmware file for ${device^^}; cannot continue." || return
		fi
	fi
	if ! fullrom_firmware_available "$slot"; then
		if [[ "$slot" = "previous" ]]; then
			fail_menu "No previous UEFI firmware file is available for ${device^^}\n(${coreboot_file})" || return
		else
			fail_menu "No UEFI Full ROM firmware file is available for ${device^^}\n(${coreboot_file})" || return
		fi
	fi

	if [[ "$slot" = "previous" ]]; then
		echo_green "\nRollback to Previous UEFI Full ROM Release"
	else
		echo_green "\nInstall/Update UEFI Full ROM Firmware"
	fi
	echo_yellow "IMPORTANT: flashing the firmware has the potential to brick your device,
requiring relatively inexpensive hardware and some technical knowledge to
recover. Not all boards can be tested prior to release, and even then slight
differences in hardware can lead to unforeseen failures.
If you don't have the ability to recover from a bad flash, you're taking a risk.

You have been warned."

	[[ "$isChromeOS" = true ]] && echo_yellow "Also, flashing Full ROM firmware will remove your ability 
to run ChromeOS."

	read -rep "Do you wish to continue? [y/N] "
	[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

	#spacing
	echo -e ""

	#special warning for CR50 devices
	if [[ "$isStock" = true && "$hasCR50" = true ]]; then
		echo_yellow "NOTICE: flashing your Chromebook is serious business.
To ensure recovery in case something goes wrong when flashing,
be sure to set the ccd capability 'FlashAP Always' using your
USB-C debug cable, otherwise recovery will involve disassembling
your device (which is very difficult in some cases)."

		echo_yellow "If you wish to continue, type: 'I ACCEPT' and press enter."
		read -rep "Type I ACCEPT: "
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

	#rollback confirmation
	if [[ "$slot" = "previous" ]]; then
		echo_yellow "
This will roll back to the previous UEFI release ($(fullrom_slot_detail previous))."
		if fullrom_has_hotfix; then
			echo_yellow "The current release ($(fullrom_slot_detail latest)) is not offered for this device."
		fi
		read -rep "Proceed with rollback? [y/N] "
		[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
	fi

	#extract device serial if present in cbfs
	run_quiet ${cbfstoolcmd} /tmp/bios.bin extract -n serial_number -f /tmp/serial.txt

	#extract device HWID
	if [[ "$isStock" = true ]]; then
		_hwid_out=$(run_capture ${gbbutilitycmd} /tmp/bios.bin --get --hwid)
		echo "$_hwid_out" | sed 's/[^ ]* //' > /tmp/hwid.txt
	else
		run_quiet ${cbfstoolcmd} /tmp/bios.bin extract -n hwid -f /tmp/hwid.txt
	fi

	# create backup if existing firmware is stock
	if [[ "$isStock" = true ]]; then
		echo_yellow "\nCreate a backup copy of your stock firmware?"
		echo_yellow "This is highly recommended in case you wish to return your device to stock
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer."
		echo_yellow "If you have already created a backup using the menu option, you can skip this."
		read -erp "Create backup now? [Y/n] "
		if [[ "$REPLY" = "n" || "$REPLY" = "N" ]]; then
			echo_yellow "Skipping backup - ensure you have a backup stored safely!"
		else
			if ! backup_firmware; then
				fail_menu "Error creating stock firmware backup; cannot continue." || return
			fi
		fi
	fi

	#download firmware file
	cd /tmp || fail_menu "Error changing to tmp dir; cannot proceed" || return
	echo_yellow "\nDownloading Full ROM firmware\n(${coreboot_file})"
	log_section "flash_full_rom: slot=${slot} label=${slot_label} downloading ${coreboot_file}"

	if ! download_fullrom_release "$slot"; then
		fail_menu "Unable to download ${coreboot_file}; firmware file may be unavailable." || return
	fi

	#verify checksum on downloaded file
	if ! sha1sum -c "${coreboot_file}.sha1" > /dev/null 2>&1; then
		fail_menu "Firmware image checksum verification failed; download corrupted, cannot flash." || return
	fi

	#persist serial number?
	if [ -f /tmp/serial.txt ]; then
		echo_yellow "Persisting device serial number"
		run_quiet ${cbfstoolcmd} "${coreboot_file}" add -n serial_number -f /tmp/serial.txt -t raw
	fi

	#persist device HWID?
	if [ ! -f /tmp/hwid.txt ] || [ ! -s /tmp/hwid.txt ]; then
		echo_yellow "Creating device HWID from board name"
		echo "${boardName^^}" > /tmp/hwid.txt
	fi
	if [ -f /tmp/hwid.txt ]; then
		echo_yellow "Persisting device HWID"
		run_quiet ${cbfstoolcmd} "${coreboot_file}" add -n hwid -f /tmp/hwid.txt -t raw
	fi

	#Persist RW_MRC_CACHE from existing UEFI Full ROM only
	if [[ "$isFullRom" = true ]] && run_quiet ${cbfstoolcmd} /tmp/bios.bin read -r RW_MRC_CACHE -f /tmp/mrc.cache; then
		run_quiet ${cbfstoolcmd} "${coreboot_file}" write -r RW_MRC_CACHE -f /tmp/mrc.cache
	fi

	#Persist SMMSTORE if exists
	if run_quiet ${cbfstoolcmd} /tmp/bios.bin read -r SMMSTORE -f /tmp/smmstore; then
		run_quiet ${cbfstoolcmd} "${coreboot_file}" write -r SMMSTORE -f /tmp/smmstore
	fi

	# persist VPD if possible
	if extract_vpd /tmp/bios.bin; then
		# try writing to RO_VPD FMAP region
		if ! run_quiet ${cbfstoolcmd} "${coreboot_file}" write -r RO_VPD -f /tmp/vpd.bin; then
		# fall back to vpd.bin in CBFS
			run_quiet ${cbfstoolcmd} "${coreboot_file}" add -n vpd.bin -f /tmp/vpd.bin -t raw
		fi
	fi

	#disable software write-protect
	echo_yellow "Disabling software write-protect and clearing the WP range"
	require_software_wp_clear flash \
		"Error disabling software write-protect; unable to flash firmware." \
		"Error clearing software write-protect range; unable to flash firmware." || return

	#flash Full ROM firmware
	rm -f /tmp/flashrom.log /tmp/flashrom-attempt.log

	local flashrom_supports_o=false
	if ${flashromcmd} -V -o /dev/null > /dev/null 2>&1; then
		flashrom_supports_o=true
	fi

	# Write image; append flashrom output to /tmp/flashrom.log (never truncate it)
	_flash_fullrom_once() {
		local img="$1"
		local label="$2"
		local rc=0

		{
			echo "=== ${label}: writing ${img} ==="
			date
		} >> /tmp/flashrom.log

		if [[ "$flashrom_supports_o" = true ]]; then
			rm -f /tmp/flashrom-attempt.log
			run_quiet ${flashromcmd} ${flashrom_params} ${noverify} -w "${img}" -o /tmp/flashrom-attempt.log
			rc=$?
			[[ -f /tmp/flashrom-attempt.log ]] && cat /tmp/flashrom-attempt.log >> /tmp/flashrom.log
		else
			# shellcheck disable=SC2086
			${flashromcmd} ${flashrom_params} ${noverify} -w "${img}" >> /tmp/flashrom.log 2>&1
			rc=$?
		fi
		return "$rc"
	}

	echo_yellow "Installing Full ROM firmware (may take up to 90s)"
	log_section "flash_full_rom: writing ${coreboot_file}"
	if ! _flash_fullrom_once "${coreboot_file}" "attempt 1"; then
		echo_red "Firmware flash failed; retrying once..."
		log_section "flash_full_rom: retry writing ${coreboot_file}"
		if ! _flash_fullrom_once "${coreboot_file}" "attempt 2"; then
			echo_red "Firmware flash failed after retry."
			echo_yellow "Attempting to restore previous firmware from /tmp/bios.bin..."
			log_section "flash_full_rom: restoring /tmp/bios.bin"
			if _flash_fullrom_once "/tmp/bios.bin" "restore"; then
				echo_green "Previous firmware restored."
			else
				echo_red "CRITICAL: Failed to restore previous firmware."
				echo_red "DO NOT REBOOT. Seek recovery help if the device will not boot."
			fi
			echo_red "Please report this issue and include /tmp/flashrom.log"
			[[ -n "${MRCBX_LOG:-}" ]] && echo_red "(and session log ${MRCBX_LOG})"
			if [[ -f /tmp/flashrom.log ]]; then
				read -rp "Press [Enter] to view the flashrom log file, then space for next page, q to quit"
				more /tmp/flashrom.log
			fi
			fail_menu "An error occurred flashing the Full ROM firmware." || return
		fi
	fi

	if [[ "$slot" = "previous" ]]; then
		echo_green "Full ROM firmware successfully rolled back."
	else
		echo_green "Full ROM firmware successfully installed/updated."
	fi

	#Prevent from trying to boot stock ChromeOS install
	if [[ "$isStock" = true && "$isChromeOS" = true && "$boot_mounted" = true ]]; then
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
Select the D option from the main menu in order to do so."
	fi
	#set vars to indicate new firmware type
	isStock=false
	isFullRom=true
	# Add NVRAM reset note for 4.12 release
	echo_yellow "IMPORTANT:\n
This update uses a new format to store UEFI NVRAM data, and
will reset your BootOrder and boot entries. You may need to
manually Boot From File and reinstall your bootloader if
booting from the internal storage device fails."
	firmwareType="Full ROM / UEFI (pending reboot)"
	isUEFI=true

	read -rep "Press [Enter] to return to the main menu."
}

#############################
# Set Touchpad type in SSFC #
#############################
function set_touchpad_in_ssfc()
{
	log_fn
	echo_green "\nSet Touchpad type in SSFC"
	echo_yellow "NOTE: This operation only needs to be done once for GALTIC-based devices
on which you want to run Windows; Linux is not affected either way.
Setting the touchpad type in SSFC requires hardware WP to be disabled."

	read -rep "Do you wish to continue? [y/N] "
	[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

	# GALTIC boards update SSFC if needed for touchpad type
	echo -e ""
	echo_yellow "Checking if touchpad type set in SSFC"
	echo_yellow "Downloading ectool"
	if ! get_ectool; then
		fail_menu "Unable to download ectool; cannot continue" || return
	fi
	if ! run_quiet ${ectoolcmd} cbi get 8; then
		# SSFC not initialized
		echo_yellow "Initializing SSFC"
		if ! $ectoolcmd cbi set 8 0x0 4 1; then
			fail_menu "Unable to initialize SSFC; if HW WP is enabled, please disable and retry" || return
		fi
	fi
	ssfc_val=$($ectoolcmd cbi get 8 | grep -m1 'uint' | cut -f3 -d ' ')
	echo_yellow "Current SSFC value is $ssfc_val"
	
	# TOUCHPAD_OPTION is bits 62-63 in 64-bit SSFC.
	# This function reads/writes only the upper 32 bits (CBI tag 8, 4 bytes),
	# so those map to bits 30-31 within this 32-bit value.
	if [[ $((ssfc_val & 0xC0000000)) == 0 ]]; then
		#touchpad unset, so detect and set it
		if dmesg | grep "input:" | grep -q "ELAN0000"; then
			#ELAN0000 touchpad, set bit 30
			ssfc_val=$((ssfc_val | 0x40000000))
		else
			#ELAN2712 touchpad, set bit 31
			ssfc_val=$((ssfc_val | 0x80000000))
		fi

		echo_yellow "Setting new SSFC value $ssfc_val"
		if ! $ectoolcmd cbi set 8 $ssfc_val 4; then
			fail_menu "Error setting new SSFC value; if HW WP is enabled, please disable and retry" || return
		fi
		echo_green "Touchpad type successfully set in SSFC"
	else
		echo_yellow "Touchpad type is already set in SSFC; nothing to do"
	fi

	read -rep "Press [Enter] to return to the main menu."
}

##############################
# Set Storage type in FW_CONFIG #
##############################
function set_storage_in_fw_config()
{
	log_fn
	echo_green "\nSet Storage type in FW_CONFIG"
	echo_yellow "NOTE: This operation sets the storage type (NVMe or eMMC) in FW_CONFIG (CBI tag 6) for taeko/taniks boards.
Setting the storage type in FW_CONFIG requires hardware WP to be disabled."

	# Check if this is a taeko or taniks board
	if [[ "${device^^}" != "TAEKO" && "${device^^}" != "TANIKS" ]]; then
		fail_menu "This function is only for taeko/taniks boards" || return
	fi

	read -rep "Do you wish to continue? [y/N] "
	[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

	echo -e ""
	echo_yellow "Checking storage type in FW_CONFIG (CBI tag 6)"
	echo_yellow "Downloading ectool"
	if ! get_ectool; then
		fail_menu "Unable to download ectool; cannot continue" || return
	fi
	fw_config_val=$($ectoolcmd cbi get 6 | grep -m1 'uint' | cut -f3 -d ' ')
	if [ -z "$fw_config_val" ]; then
		fail_menu "Unable to read FW_CONFIG; cannot continue" || return
	fi
	echo_yellow "Current FW_CONFIG value is $fw_config_val"
	
	# BOOT_NVME_MASK is bit 12 in FW_CONFIG (0x1000)
	# BOOT_EMMC_MASK is bit 13 in FW_CONFIG (0x2000)
	# These are separate enable/disable bits
	nvme_bit=$((fw_config_val & 0x1000))
	emmc_bit=$((fw_config_val & 0x2000))
	current_storage=""
	
	if [[ $nvme_bit != 0 ]]; then
		current_storage="NVMe"
	elif [[ $emmc_bit != 0 ]]; then
		current_storage="eMMC"
	else
		current_storage="Not set"
	fi
	
	echo_green "Current storage type: $current_storage"
	echo -e "Storage type options:"
	echo -e "  0 = NVMe"
	echo -e "  1 = eMMC"
	echo -e ""
	REPLY=""
	while [[ "$REPLY" != "0" && "$REPLY" != "1" && "$REPLY" != "q" && "$REPLY" != "Q" ]]
	do
		read -rep "Enter storage type to set [0=NVMe, 1=eMMC, q=quit]: "
		if [[ "$REPLY" != "0" && "$REPLY" != "1" && "$REPLY" != "q" && "$REPLY" != "Q" ]]; then
			echo_red "Invalid choice. Please enter 0, 1, or q"
		fi
	done

	echo -e ""
	
	if [[ "$REPLY" = "q" || "$REPLY" = "Q" ]]; then
		echo_yellow "Quitting without changes"
		read -rep "Press [Enter] to return to the main menu."
		return 0
	fi
	
	# Clear both storage bits (bits 12 and 13)
	fw_config_val=$((fw_config_val & ~0x3000))
	
	# Set new storage type
	if [[ "$REPLY" = "1" ]]; then
		# Set eMMC enabled (bit 13 = 0x2000)
		fw_config_val=$((fw_config_val | 0x2000))
		new_storage="eMMC"
	else
		# Set NVMe enabled (bit 12 = 0x1000)
		fw_config_val=$((fw_config_val | 0x1000))
		new_storage="NVMe"
	fi
	
	if [[ "$current_storage" = "$new_storage" ]]; then
		echo_yellow "Storage type is already set to $new_storage; nothing to do"
		read -rep "Press [Enter] to return to the main menu."
		return 0
	fi
	
	echo_yellow "Setting storage type to $new_storage (new FW_CONFIG value: $fw_config_val)"
	if ! $ectoolcmd cbi set 6 $fw_config_val 4; then
		fail_menu "Error setting new FW_CONFIG value; if HW WP is enabled, please disable and retry" || return
	fi
	echo_green "Storage type successfully set to $new_storage in FW_CONFIG"

	read -rep "Press [Enter] to return to the main menu."
}

#########################
# Downgrade Touchpad FW #
#########################
function downgrade_touchpad_fw()
{
	log_fn
	# offer to downgrade touchpad firmware on EVE
	if [[ "${device^^}" = "EVE" ]]; then
		echo_green "\nDowngrade Touchpad Firmware"
		echo_yellow "If you plan to run Windows on your Pixelbook, it is necessary to downgrade
the touchpad firmware, otherwise the touchpad will not work."
		echo_yellow "You should do this after flashing the UEFI firmware, but before rebooting."
		read -rep "Do you wish to downgrade the touchpad firmware now? [y/N] "
		if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] ; then
			# ensure firmware write protect disabled
			if [[ "$wpEnabled" = true ]]; then
				fail_menu "\nHardware write-protect enabled, cannot downgrade touchpad firmware."
				return
			fi
			# download TP firmware
			echo_yellow "\nDownloading touchpad firmware\n(${touchpad_eve_fw})"
			
			touchpad_downgrade_files=(
				"${touchpad_eve_fw}"
				"${touchpad_eve_fw}.sha1"
			)
			download_files touchpad_downgrade_files "${other_source}" || return 1

			#verify checksum on downloaded file
			if sha1sum -c "${touchpad_eve_fw}.sha1" > /dev/null 2>&1; then
				# flash TP firmware
				echo_green "Flashing touchpad firmware -- do not touch the touchpad while updating!"
				if run_quiet ${flashromcmd/${flashrom_programmer}} -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw} -o /tmp/flashrom.log; then
					echo_green "Touchpad firmware successfully downgraded."
					echo_yellow "Please reboot your Pixelbook now."
				else
					# try with older eve flashrom
					local tpPath _tp_oldpwd
					[[ "$isChromeOS" = true ]] && tpPath="/usr/local/bin" || tpPath="/tmp"
					_tp_oldpwd=$PWD
					if ! cd "$tpPath"; then
						fail_menu "Error changing to ${tpPath}; cannot flash touchpad firmware." || return
					fi
					flashrom_eve_files=(
						"${flashrom_eve_tp}"
						"${flashrom_eve_tp}.sha1"
					)
					if ! download_files flashrom_eve_files "${util_source}"; then
						cd "$_tp_oldpwd" || true
						return 1
					fi
					if ! sha1sum -c "${flashrom_eve_tp}.sha1" > /dev/null 2>&1; then
						cd "$_tp_oldpwd" || true
						fail_menu "Flashrom Eve TP checksum fail; download corrupted, cannot flash." || return
					fi
					chmod +x ${flashrom_eve_tp}
					cd "$_tp_oldpwd" || true
					if run_quiet $tpPath/${flashrom_eve_tp} -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw} -o /tmp/flashrom.log; then
						echo_green "Touchpad firmware successfully downgraded."
						echo_yellow "Please reboot your Pixelbook now."
					else
						echo_red "Error flashing touchpad firmware:"
						cat /tmp/flashrom.log
						echo_yellow "\nThis function sometimes doesn't work under Linux, in which case it is
recommended to try under ChromiumOS."
					fi
				fi
			else
				fail_menu "Touchpad firmware download checksum fail; download corrupted, cannot flash." || return
			fi
		fi
		read -rep "Press [Enter] to return to the main menu."
	fi
}

#######################
# Upgrade Touchpad FW #
#######################
function upgrade_touchpad_fw()
{
	log_fn
	# offer to upgrade touchpad firmware on EVE
	if [[ "${device^^}" = "EVE" ]]; then
		echo_green "\nUpgrade Touchpad Firmware"
		echo_yellow "
If you plan to restore ChromeOS on your Pixelbook, it is necessary to upgrade
the touchpad firmware, otherwise the touchpad will not work."
		echo_yellow "You should do this after restoring the stock firmware, but before rebooting."
		read -rep "Do you wish to upgrade the touchpad firmware now? [y/N] "
		if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] ; then
			# ensure firmware write protect disabled
			if [[ "$wpEnabled" = true ]]; then
				fail_menu "\nHardware write-protect enabled, cannot upgrade touchpad firmware."
				return
			fi
			# download TP firmware
			echo_yellow "\nDownloading touchpad firmware\n(${touchpad_eve_fw_stock})"
			
			# Array of touchpad upgrade files to download
			touchpad_upgrade_files=(
				"${touchpad_eve_fw_stock}"
				"${touchpad_eve_fw_stock}.sha1"
			)
			
			# Download touchpad upgrade files
			if ! download_files touchpad_upgrade_files "${other_source}"; then
				return 1
			fi
			#verify checksum on downloaded file
			if sha1sum -c "${touchpad_eve_fw_stock}.sha1" > /dev/null 2>&1; then
				# flash TP firmware
				echo_green "Flashing touchpad firmware -- do not touch the touchpad while updating!"
				if run_quiet ${flashromcmd/${flashrom_programmer}} -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw_stock} -o /tmp/flashrom.log; then
					echo_green "Touchpad firmware successfully upgraded."
					echo_yellow "Please reboot your Pixelbook now."
				else
				# try with older eve flashrom
				local tpPath _tp_oldpwd
				[[ "$isChromeOS" = true ]] && tpPath="/usr/local/bin" || tpPath="/tmp"
				_tp_oldpwd=$PWD
				if ! cd "$tpPath"; then
					fail_menu "Error changing to ${tpPath}; cannot flash touchpad firmware." || return
				fi
				flashrom_eve_files=(
					"${flashrom_eve_tp}"
					"${flashrom_eve_tp}.sha1"
				)
				if ! download_files flashrom_eve_files "${util_source}"; then
					cd "$_tp_oldpwd" || true
					return 1
				fi
				if ! sha1sum -c "${flashrom_eve_tp}.sha1" > /dev/null 2>&1; then
					cd "$_tp_oldpwd" || true
					fail_menu "Flashrom Eve TP checksum fail; download corrupted, cannot flash." || return
				fi
				chmod +x ${flashrom_eve_tp}
				cd "$_tp_oldpwd" || true
				if run_quiet $tpPath/${flashrom_eve_tp} -p ec:type=tp -i EC_RW -w ${touchpad_eve_fw_stock} -o /tmp/flashrom.log; then
					echo_green "Touchpad firmware successfully upgraded."
					echo_yellow "Please reboot your Pixelbook now."
				else
					echo_red "Error flashing touchpad firmware:"
					cat /tmp/flashrom.log
					echo_yellow "\nThis function sometimes doesn't work under Linux, in which case it is
recommended to try under ChromiumOS."
				fi
			fi
			else
				fail_menu "Touchpad firmware download checksum fail; download corrupted, cannot flash." || return
			fi
		fi
		read -rep "Press [Enter] to return to the main menu."
	fi
}

###########################
# Flash Custom Firmware #
###########################
function flash_custom_firmware()
{
	log_fn
	# ensure hardware write protect disabled
	if [[ "$wpEnabled" = true ]]; then
		fail_menu "\nHardware write-protect enabled, cannot flash custom firmware."
		return
	fi

	echo_green "\nFlash Custom Firmware Image"
	echo_yellow "IMPORTANT: flashing custom firmware has the potential to brick your device,
requiring relatively inexpensive hardware and some technical knowledge to
recover. Make sure you have a backup of your current firmware before proceeding.
If you don't have the ability to recover from a bad flash, you're taking a risk.

You have been warned."

	read -rep "Do you wish to continue? [y/N] "
	[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

	echo -e ""
	echo_yellow "Please select firmware source:"
	echo -e "1) Flash from local filesystem"
	echo -e "2) Flash from USB device"
	echo -e "Q) Quit and return to main menu"
	echo -e ""
	flash_option=-1
	while :
	do
		read -rep "? " flash_option
		case $flash_option in
		1)  flash_firmware_from_local || return 1;
			break;
			;;
		2)  flash_firmware_from_usb || return 1;
			break;
			;;
		Q|q) flash_option="Q";
			break;
			;;
		esac
	done
	[[ "$flash_option" = "Q" ]] && return
}

function flash_firmware_from_local()
{
	log_fn
	echo_yellow "\nFlashing firmware from local filesystem"
	read -rep "Enter the full path to the custom firmware file: " firmware_path

	if [ -z "$firmware_path" ]; then
		fail_menu "No firmware path provided" || return
	fi

	if [ ! -f "$firmware_path" ]; then
		fail_menu "Firmware file not found: $firmware_path" || return
	fi

	if ! cp "$firmware_path" /tmp/custom-firmware.rom; then
		fail_menu "Failed to copy firmware file to /tmp" || return
	fi

	process_and_flash_custom_firmware "/tmp/custom-firmware.rom"
}

function flash_firmware_from_usb()
{
	log_fn
	local _usb_rc=0

	select_usb_device \
		"Connect the USB/SD device which contains the custom firmware and press [Enter] to continue." \
		"Enter the number for the device which contains the custom firmware:" \
		ro || _usb_rc=$?
	if [[ $_usb_rc -ne 0 ]]; then
		case $_usb_rc in
			1) fail_menu "No USB devices available to read firmware from." || return ;;
			2) fail_menu "USB device failed to mount; cannot proceed." || return ;;
		esac
	fi

	echo_yellow "\nFirmware Files on USB:"
	if ! ls /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null; then
		run_quiet umount /tmp/usb
		rmdir /tmp/usb
		fail_menu "No firmware files found on USB device." || return
	fi
	echo -e ""
	read -rep "Enter the firmware filename: " firmware_file
	firmware_file="/tmp/usb/${firmware_file}"
	if [ ! -f "$firmware_file" ]; then
		run_quiet umount /tmp/usb
		rmdir /tmp/usb
		fail_menu "Invalid filename entered; unable to flash custom firmware." || return
	fi

	if ! cp "$firmware_file" /tmp/custom-firmware.rom; then
		run_quiet umount /tmp/usb
		rmdir /tmp/usb
		fail_menu "Failed to copy firmware file to /tmp" || return
	fi

	run_quiet umount /tmp/usb
	rmdir /tmp/usb

	process_and_flash_custom_firmware "/tmp/custom-firmware.rom"
}

function process_and_flash_custom_firmware()
{
	log_fn
	local custom_firmware_file="$1"
	
	# Check if we can read the custom firmware
	if ! run_quiet ${cbfstoolcmd} "${custom_firmware_file}" print; then
		echo_yellow "Warning: Unable to read custom firmware with cbfstool. Proceeding anyway."
	fi
	
	# Extract current firmware data to preserve
	echo_yellow "Extracting device-specific data from current firmware"
	
	# Extract serial number if present
	run_quiet ${cbfstoolcmd} /tmp/bios.bin extract -n serial_number -f /tmp/serial.txt
	
	# Extract HWID if present
	run_quiet ${cbfstoolcmd} /tmp/bios.bin extract -n hwid -f /tmp/hwid.txt
	
	# Extract VPD if possible
	extract_vpd /tmp/bios.bin
	
	# Extract RW_MRC_CACHE if present
	run_quiet ${cbfstoolcmd} /tmp/bios.bin read -r RW_MRC_CACHE -f /tmp/mrc.cache
	
	# Extract SMMSTORE if present
	run_quiet ${cbfstoolcmd} /tmp/bios.bin read -r SMMSTORE -f /tmp/smmstore
	
	# Persist serial number if extracted
	if [ -f /tmp/serial.txt ]; then
		echo_yellow "Persisting device serial number"
		run_quiet ${cbfstoolcmd} "${custom_firmware_file}" add -n serial_number -f /tmp/serial.txt -t raw
	fi
	
	# Persist HWID if extracted
	if [ -f /tmp/hwid.txt ]; then
		echo_yellow "Persisting device HWID"
		hwid_content=$(cat /tmp/hwid.txt)
		if [[ "$hwid_content" =~ ^[A-Z0-9]+ ]]; then
			# Use gbb_utility if it's a proper HWID format
			run_quiet ${gbbutilitycmd} "${custom_firmware_file}" --set --hwid="$hwid_content"
		else
			# Use cbfstool for raw HWID data
			run_quiet ${cbfstoolcmd} "${custom_firmware_file}" add -n hwid -f /tmp/hwid.txt -t raw
		fi
	fi
	
	# Persist VPD if extracted
	if [ -f /tmp/vpd.bin ]; then
		echo_yellow "Persisting VPD data"
		if ! run_quiet ${cbfstoolcmd} "${custom_firmware_file}" write -r RO_VPD -f /tmp/vpd.bin; then
			run_quiet ${cbfstoolcmd} "${custom_firmware_file}" add -n vpd.bin -f /tmp/vpd.bin -t raw
		fi
	fi
	
	# Persist RW_MRC_CACHE if extracted
	if [ -f /tmp/mrc.cache ]; then
		echo_yellow "Persisting RW_MRC_CACHE"
		run_quiet ${cbfstoolcmd} "${custom_firmware_file}" write -r RW_MRC_CACHE -f /tmp/mrc.cache
	fi
	
	# Persist SMMSTORE if extracted
	if [ -f /tmp/smmstore ]; then
		echo_yellow "Persisting SMMSTORE"
		run_quiet ${cbfstoolcmd} "${custom_firmware_file}" write -r SMMSTORE -f /tmp/smmstore
	fi
	
	# Disable software write-protect
	echo_yellow "Disabling software write-protect and clearing the WP range"
	require_software_wp_clear flash \
		"Error disabling software write-protect; unable to flash firmware." \
		"Error clearing software write-protect range; unable to flash firmware." || return
	
	# Flash the custom firmware
	echo_yellow "Installing custom firmware (may take up to 90s)"
	rm -f /tmp/flashrom.log
	
	# Check if flashrom supports logging to file
	if ${flashromcmd} -V -o /dev/null > /dev/null 2>&1; then
		output_params="-o /tmp/flashrom.log"
		run_quiet ${flashromcmd} ${flashrom_params} ${noverify} -w "${custom_firmware_file}" -o /tmp/flashrom.log
	else
		output_params="/tmp/flashrom.log"
		run_flashrom ${flashromcmd} ${flashrom_params} ${noverify} -w "${custom_firmware_file}"
	fi
	
	if [ $? -ne 0 ]; then
		echo_red "Error running cmd: ${flashromcmd} ${flashrom_params} ${noverify} -w ${custom_firmware_file} ${output_params}"
		if [ -f /tmp/flashrom.log ]; then
			read -rp "Press [Enter] to view the flashrom log file, then space for next page, q to quit"
			more /tmp/flashrom.log
		fi
		fail_menu "An error occurred flashing the custom firmware. DO NOT REBOOT!" || return
	else
		echo_green "Custom firmware successfully installed/updated."
		
		# Update firmware type
		firmwareType="Custom Firmware (pending reboot)"
		isStock=false
		isFullRom=true
		isUEFI=true
		
		echo_yellow "IMPORTANT:
The first boot after flashing may take substantially
longer than subsequent boots -- up to 30s or more.
Be patient and eventually your device will boot :)"
	fi
		
	read -rep "Press [Enter] to return to the main menu."
}

########################
# Restore Stock Firmware #
##########################
function restore_stock_firmware()
{
	log_fn
		echo_green "\nRestore Stock Firmware"
		echo_yellow "Standard disclaimer: flashing the firmware has the potential to
brick your device, requiring relatively inexpensive hardware and some
technical knowledge to recover.  You have been warned."
		read -rep "Do you wish to continue? [y/N] "
		[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return
		# check if EOL
		if [ "$isEOL" = true ]; then
			echo_yellow "
VERY IMPORTANT:
Your device has reached end of life (EOL) and is no longer supported by Google.
Returning to stock firmware **IS NOT RECOMMENDED**.
MrChromebox will not provide any support for EOL devices running anything
other than the latest UEFI Full ROM firmware release."
			read -rep "Do you wish to continue? [y/N] "
			[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return
		fi
		#spacing
		echo -e ""
		# ensure hardware write protect disabled
		if [[ "$wpEnabled" = true ]]; then
			fail_menu "\nHardware write-protect enabled, cannot restore stock firmware."
			return
		fi
		# default file to download to
		firmware_file="/tmp/stock-firmware.rom"
		echo -e ""
		echo_yellow "Please select an option below for restoring the stock firmware:"
		echo -e "1) Restore using a firmware backup on USB"
		echo -e "2) Restore using a ChromeOS Recovery USB"
		echo -e "Q) Quit and return to main menu"
		echo -e ""
		restore_option=-1
		while :
		do
			read -rep "? " restore_option
			case $restore_option in
			1)  restore_fw_from_usb || return 1;
				break;
				;;
			2)  restore_fw_from_recovery || return 1;
				break;
				;;
			Q|q) restore_option="Q";
				break;
				;;
			esac
		done
		[[ "$restore_option" = "Q" ]] && return
		if [[ $restore_option -eq 2 ]]; then
			#extract VPD from current firmware if present
			if extract_vpd /tmp/bios.bin ; then
			#merge with recovery image firmware
				if [ -f /tmp/vpd.bin ]; then
					echo_yellow "Merging VPD into recovery image firmware"
					run_quiet ${cbfstoolcmd} ${firmware_file} write -r RO_VPD -f /tmp/vpd.bin
				fi
			fi
			#extract hwid from current firmware if present
			if run_quiet ${cbfstoolcmd} /tmp/bios.bin extract -n hwid -f /tmp/hwid.txt; then
				#merge with recovery image firmware
				hwid="$(sed 's/^hardware_id: //' /tmp/hwid.txt 2>/dev/null)"
				if [[ "$hwid" != "" ]]; then
					echo_yellow "Injecting HWID into recovery image firmware"
					run_quiet ${gbbutilitycmd} ${firmware_file} --set --hwid="$hwid"
				fi
			fi
		fi
		#clear GBB flags before flashing
		run_quiet ${gbbutilitycmd} ${firmware_file} --set --flags=0x0
		#flash stock firmware
		echo_yellow "Restoring stock firmware"
		# only verify part of flash we write
		if ! run_quiet ${flashromcmd} ${flashrom_params} ${noverify} -w "${firmware_file}" -o /tmp/flashrom.log; then
			cat /tmp/flashrom.log
			fail_menu "An error occurred restoring the stock firmware. DO NOT REBOOT!" || return
		fi
		#re-enable software WP to prevent recovery issues
		echo_yellow "Re-enabling software write-protect"
		run_quiet ${flashromcmd} --wp-region WP_RO --fmap
		if ! run_quiet ${flashromcmd} --wp-enable; then
			echo_red "Warning: unable to re-enable software write-protect;"
			echo_red "you may need to perform ChromeOS recovery with the battery disconnected."
		fi
		#all good
		echo_green "Stock firmware successfully restored."
		
		# Optionally reset CR50 NVRAM data if device has CR50
		if [[ "$hasCR50" = true ]]; then
			reset_cr50_nvram "$firmware_file"
		fi
		
		echo_green "After rebooting, you need to restore ChromeOS using ChromeOS Recovery media."
		echo_green "See: https://google.com/chromeos/recovery for more info."
		read -rep "Press [Enter] to return to the main menu."
		#set vars to indicate new firmware type
		isStock=true
		isFullRom=false
		isUEFI=false
		firmwareType="Stock ChromeOS (pending reboot)"
}

function restore_fw_from_usb()
{
	log_fn
	local _usb_rc=0

	select_usb_device \
		"Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue." \
		"Enter the number for the device which contains the stock firmware backup:" \
		ro || _usb_rc=$?
	if [[ $_usb_rc -ne 0 ]]; then
		case $_usb_rc in
			1) fail_menu "No USB devices available to read firmware backup." || return ;;
			2) fail_menu "USB device failed to mount; cannot proceed." || return ;;
		esac
	fi
	echo_yellow "\n(Potential) Firmware Files on USB:"
	if ! ls /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null; then
		run_quiet umount /tmp/usb
		rmdir /tmp/usb
		fail_menu "No firmware files found on USB device." || return
	fi
	echo -e ""
	read -rep "Enter the firmware filename:  " _usb_firmware_name
	_usb_firmware_path="/tmp/usb/${_usb_firmware_name}"
	if [ ! -f "${_usb_firmware_path}" ]; then
		run_quiet umount /tmp/usb
		rmdir /tmp/usb
		fail_menu "Invalid filename entered; unable to restore stock firmware." || return
	fi
	firmware_file="/tmp/stock-firmware.rom"
	if ! cp "${_usb_firmware_path}" "${firmware_file}"; then
		run_quiet umount /tmp/usb
		rmdir /tmp/usb
		fail_menu "Failed to copy firmware from USB; unable to restore stock firmware." || return
	fi
	run_quiet umount /tmp/usb
	rmdir /tmp/usb
	echo -e ""
}

function restore_fw_from_recovery()
{
	log_fn
	if ! command -v 7z >/dev/null 2>&1; then
		fail_menu "Error: 7z (7zip) is required but not found. Please install it via the 7zip package." || return
	fi
	local _usb_rc=0

	select_usb_device \
		"Connect a USB which contains a ChromeOS Recovery Image
and press [Enter] to continue." \
		"Enter the number which corresponds your ChromeOS Recovery USB:" \
		none || _usb_rc=$?
	if [[ $_usb_rc -ne 0 ]]; then
		fail_menu "No USB devices available to read from." || return
	fi
	echo -e ""
	echo_yellow "Using USB device: $usb_device"
	if ! extract_firmware_from_recovery_usb ${boardName,,} $usb_device ; then
		fail_menu "Error: failed to extract firmware for ${boardName^^} from this ChromeOS recovery USB" || return
	fi
	mv coreboot-Google_* ${firmware_file}
	# set a semi-legit HWID in case we don't have a backup below
	run_quiet ${gbbutilitycmd} --set --hwid="${boardName^^} ABC-123-XYZ-456" ${firmware_file}
	echo_yellow "Stock firmware successfully extracted from ChromeOS recovery image"
}

######################################
# Extract firmware from recovery usb #
######################################
function extract_firmware_from_recovery_usb()
{
	log_fn
	if [[ "$1" = "" || "$2" = "" ]]; then
		echo_red "Invalid or missing function parameters: [$*]"
		return 1
	fi
	local _workdir _home
	_board=$1
	_debugfs=${2}3
	_firmware=chromeos-firmwareupdate-$_board
	_home="${HOME:-/root}"
	_workdir=$(mktemp -d "${_home}/mrcbx-firmware.XXXXXX") || {
		echo_red "Failed to create temp directory under ${_home}"
		return 1
	}
	_unpacked="${_workdir}/unpacked"
	mkdir -p "$_unpacked"
	cd "$_workdir" || { rm -rf "$_workdir"; return 1; }

	echo_yellow "Extracting firmware from recovery USB"
	run_quiet sh -c "printf 'cd /usr/sbin\ndump chromeos-firmwareupdate ${_firmware}\nquit' | debugfs ${_debugfs}"
	if [ ! -f "$_firmware" ]; then
		echo_red "Failed to copy file 'chromeos-firmwareupdate' from Recovery USB"
		rm -rf "$_workdir"
		return 1
	fi
	TMPDIR="$_workdir" run_quiet sh "$_firmware" --unpack "$_unpacked" || {
		rm -rf "$_unpacked"
		mkdir -p "$_unpacked"
		TMPDIR="$_workdir" run_quiet sh "$_firmware" --sb_extract "$_unpacked" || {
			echo_red "Failed to extract shellball from 'chromeos-firmwareupdate'"
			rm -rf "$_workdir"
			return 1
		}
	}
	if [ -d $_unpacked/models/ ]; then
		_version=$(cat $_unpacked/VERSION | grep -m 1 -e Model.*$_board -A5 | grep "BIOS (RW) version:" | cut -f2 -d: | tr -d \ )
		if [ "$_version" = "" ]; then
			_version=$(cat $_unpacked/VERSION | grep -m 1 -e Model.*$_board -A5 | grep "BIOS version:" | cut -f2 -d: | tr -d \ )
		fi
		if [ -f $_unpacked/models/$_board/setvars.sh ]; then
			_bios_image=$(grep "IMAGE_MAIN" $_unpacked/models/$_board/setvars.sh | cut -f2 -d'"')
		else
			# special case for REEF, others?
			_version=$(grep -m1 "host" "$_unpacked/manifest.json" | cut -f12 -d'"')
			_bios_image=$(grep -m1 "image" "$_unpacked/manifest.json" | cut -f4 -d'"')
		fi
	elif [ -f "$_unpacked/manifest.json" ]; then
		_version=$(grep -m1 -A4 "$_board\":" "$_unpacked/manifest.json" | grep -m1 "rw" | sed 's/.*\(rw.*\)/\1/' | sed 's/.*\("Google.*\)/\1/' | cut -f2 -d'"')
		_bios_image=$(grep -m1 -A10 "$_board\":" "$_unpacked/manifest.json" | grep -m1 "image" | sed 's/.*"image": //' | cut -f2 -d'"')
	else
		if [ -f $_unpacked/VERSION ]; then
			_version=$(cat $_unpacked/VERSION | grep BIOS\ version: | cut -f2 -d: | tr -d \ )
			_bios_image=bios.bin
		else
			echo_red "Recovery image missing VERSION file. Shellball directory Contents:"
			ls -lart $_unpacked
			rm -rf "$_workdir"
			return 1
		fi
	fi
	if ! cp "$_unpacked/$_bios_image" "coreboot-${_version}.bin"; then
		rm -rf "$_workdir"
		return 1
	fi
	mv "coreboot-${_version}.bin" /tmp/
	cd /tmp || true
	rm -rf "$_workdir"
}


########################
# Extract firmware VPD #
########################
function extract_vpd()
{
	log_fn
	#check params
	if [[ -z "$1" ]]; then
		fail_menu "Error: extract_vpd(): missing function parameter"
		return
	fi

	local firmware_file="$1"

	#try FMAP extraction
	if ! run_quiet ${cbfstoolcmd} ${firmware_file} read -r RO_VPD -f /tmp/vpd.bin ; then
		#try CBFS extraction
		if ! run_quiet ${cbfstoolcmd} ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin ; then
			echo_yellow "No VPD found in current firmware"
			return 1
		fi
	fi
	echo_yellow "VPD extracted from current firmware"
}

#########################
# Backup Current Firmware #
#########################
function backup_current_firmware()
{
	log_fn
	echo_green "\nBackup Current Firmware"
	echo_yellow "This function allows you to backup the current firmware to either
a local file or a USB device. This is useful for creating backups
before flashing custom firmware."

	read -rep "Do you wish to continue? [y/N] "
	[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

	echo -e ""
	echo_yellow "Please select backup destination:"
	echo -e "1) Backup to local filesystem"
	echo -e "2) Backup to USB device"
	echo -e "Q) Quit and return to main menu"
	echo -e ""
	backup_option=-1
	while :
	do
		read -rep "? " backup_option
		case $backup_option in
		1)  backup_firmware_to_local || return 1;
			break;
			;;
		2)  backup_firmware_to_usb || return 1;
			break;
			;;
		Q|q) backup_option="Q";
			break;
			;;
		esac
	done
	[[ "$backup_option" = "Q" ]] && return
}

function backup_firmware_to_local()
{
	log_fn
	echo_yellow "\nBacking up firmware to local filesystem"
	echo -e "Enter the directory path for the backup (e.g., /home/user/backups/)"
	echo -e "Or just press [Enter] to use the current directory."
	read -rep "" backup_dir
	
	# Default to current directory if empty
	if [ -z "$backup_dir" ]; then
		backup_dir=$(pwd)
	fi
	
	# Remove trailing slash if present and normalize path
	backup_dir="${backup_dir%/}"
	
	# Create directory if it doesn't exist
	if [[ ! -d "$backup_dir" ]]; then
		echo_yellow "Creating directory: $backup_dir"
		mkdir -p "$backup_dir" || {
			echo_red "Failed to create directory: $backup_dir"
			return 1
		}
	fi
	
	# Generate backup filename
	backupname="BACKUP-${boardName}-$fwVer-$(date +%Y.%m.%d).rom"
	backup_path="$backup_dir/$backupname"

	echo_yellow "Saving firmware backup:\n$backup_path"
	if ! cp /tmp/bios.bin "$backup_path"; then
		echo_red "Failure copying firmware to $backup_path"
		return 1
	fi
	echo_green "Firmware backup complete."
	read -rep "Press [Enter] to return to the main menu."
}

function backup_firmware_to_usb()
{
	log_fn
	local _usb_rc=0

	select_usb_device \
		"Connect the USB/SD device to store the firmware backup and press [Enter]
to continue.  This is non-destructive, but it is best to ensure no other
USB/SD devices are connected." \
		"Enter the number for the device to be used for firmware backup:" \
		rw || _usb_rc=$?
	if [[ $_usb_rc -ne 0 ]]; then
		case $_usb_rc in
			1) backup_fail "No USB devices available to store firmware backup." ;;
			2) backup_fail "USB backup device failed to mount; cannot proceed. Ensure your USB is FAT32-formatted and try again." ;;
		esac
		return 1
	fi
	backupname="BACKUP-${boardName}-$fwVer-$(date +%Y.%m.%d).rom"
	echo_yellow "\nSaving firmware backup: ${backupname}"
	if ! cp /tmp/bios.bin /tmp/usb/${backupname}; then
		backup_fail "Failure copying firmware to USB; cannot proceed."
		return 1
	fi
	sync
	run_quiet umount /tmp/usb
	rmdir /tmp/usb
	echo_green "Firmware backup complete.\n\nRemove the USB stick and press [Enter] to continue."
	read -rep ""
}

#########################
# Backup stock firmware #
#########################
function backup_firmware()
{
	log_fn
	local _usb_rc=0

	select_usb_device \
		"Connect the USB/SD device to store the firmware backup and press [Enter]
to continue.  This is non-destructive, but it is best to ensure no other
USB/SD devices are connected." \
		"Enter the number for the device to be used for firmware backup:" \
		rw || _usb_rc=$?
	if [[ $_usb_rc -ne 0 ]]; then
		case $_usb_rc in
			1) backup_fail "No USB devices available to store firmware backup." ;;
			2) backup_fail "USB backup device failed to mount; cannot proceed. Ensure your USB is FAT32-formatted and try again." ;;
		esac
		return 1
	fi
	backupname="stock-firmware-${boardName}-$(date +%Y%m%d).rom"
	echo_yellow "\nSaving firmware backup as ${backupname}"
	if ! cp /tmp/bios.bin /tmp/usb/${backupname}; then
		backup_fail "Failure copying stock firmware to USB; cannot proceed."
		return 1
	fi
	sync
	run_quiet umount /tmp/usb
	rmdir /tmp/usb
	echo_green "Firmware backup complete. Remove the USB stick and press [Enter] to continue."
	read -rep ""
}

function backup_fail()
{
	run_quiet umount /tmp/usb
	run_quiet rmdir /tmp/usb
	fail_menu "\n$*"
}

####################
# Set Boot Options #
####################
function set_boot_options()
{
	log_fn
	# set boot options via firmware boot flags

	# ensure hardware write protect disabled
	if [[ "$wpEnabled" = true ]]; then
		fail_menu "\nHardware write-protect enabled, cannot set Boot Options / GBB Flags."
		return
	fi

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
	require_software_wp_clear strict \
		"Error disabling software write-protect; unable to set GBB flags." \
		"Error clearing software write-protect range; unable to set GBB flags." || return
	[[ "$isChromeOS" = false ]] && FMAP="--fmap"
	if ! run_flashrom ${flashromcmd} -r $FMAP -i GBB:/tmp/gbb.temp; then
		fail_menu "\nError reading firmware (non-stock?); unable to set boot options." || return
	fi
	if ! run_quiet ${gbbutilitycmd} --set --flags="${_flags}" /tmp/gbb.temp; then
		fail_menu "\nError setting boot options." || return
	fi
	if ! run_quiet ${flashromcmd} -w $FMAP -i GBB:/tmp/gbb.temp ${noverify} -o /tmp/flashrom.log; then
		cat /tmp/flashrom.log
		fail_menu "\nError writing back firmware; unable to set boot options." || return
	fi
	echo_green "\nFirmware Boot options successfully set."
	read -rep "Press [Enter] to return to the main menu."
}

###################
# Set Hardware ID #
###################
function set_hwid()
{
	log_fn
	# set HWID using gbb_utility
	# ensure hardware write protect disabled
	if [[ "$wpEnabled" = true ]]; then
		fail_menu "\nHardware write-protect enabled, cannot set HWID."
		return
	fi

	echo_green "Set Hardware ID (HWID) using gbb_utility"

	#get current HWID
	_hwid="$(run_capture crossystem hwid)"
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
		require_software_wp_clear strict \
			"Error disabling software write-protect; unable to set HWID." \
			"Error clearing software write-protect range; unable to set HWID." || return
		[[ "$isChromeOS" = false ]] && FMAP="--fmap"
		if ! run_flashrom ${flashromcmd} -r $FMAP -i GBB:/tmp/gbb.temp; then
			fail_menu "\nError reading firmware (non-stock?); unable to set HWID." || return
		fi
		if ! run_quiet ${gbbutilitycmd} --set --hwid="${hwid}" /tmp/gbb.temp; then
			fail_menu "\nError setting HWID." || return
		fi
		if ! run_quiet ${flashromcmd} -w $FMAP -i GBB:/tmp/gbb.temp ${noverify} -o /tmp/flashrom.log; then
			cat /tmp/flashrom.log
			fail_menu "\nError writing back firmware; unable to set HWID." || return
		fi
		echo_green "Hardware ID successfully set."
	fi
	read -rep "Press [Enter] to return to the main menu."
}

##########################
# Set HWID for UEFI ROM #
##########################
function set_hwid_uefi()
{
	log_fn
	# set HWID using cbfstool for UEFI firmware
	# ensure hardware write protect disabled
	if [[ "$wpEnabled" = true ]]; then
		fail_menu "\nHardware write-protect enabled, cannot set HWID."
		return
	fi

	echo_green "\nSet Hardware ID (HWID) for UEFI Firmware"

	# Get current HWID if present
	if run_quiet ${cbfstoolcmd} /tmp/bios.bin extract -n hwid -f /tmp/hwid_current.txt; then
		_current_hwid=$(cat /tmp/hwid_current.txt 2>/dev/null)
		if [[ -n "$_current_hwid" ]]; then
			echo_yellow "Current HWID is: $_current_hwid"
		fi
		rm -f /tmp/hwid_current.txt
	else
		echo_yellow "No current HWID found in firmware"
	fi

	echo_yellow "
WARNING: Changing HWID is not normally needed, and if you mess it up,
it could result in the wrong firmware being flashed, which will almost
certainly result in your device being bricked.
Proceed at your own risk."

	read -rep "Really change your HWID? [y/N] " confirm
	[[ "$confirm" = "Y" || "$confirm" = "y" ]] || return

	read -rep "This is serious. Are you really sure? [y/N] " confirm
	[[ "$confirm" = "Y" || "$confirm" = "y" ]] || return

	local hwid=""
	read -rep "Enter a new HWID: " hwid
	if [[ -z "$hwid" ]]; then
		fail_menu "No HWID entered; operation cancelled." || return
	fi

	echo -e ""
	read -rep "Confirm changing HWID to '$hwid' [y/N] " confirm
	if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
		echo_yellow "\nReading current firmware..."
		# Read current firmware to ensure we have the latest
		if ! run_flashrom ${flashromcmd} --fmap -i COREBOOT -r /tmp/bios_mod.bin; then
			cat /tmp/flashrom.log
			fail_menu "\nError reading firmware; unable to set HWID." || return
		fi

		echo_yellow "Modifying firmware..."
		# Remove old HWID if it exists
		run_quiet ${cbfstoolcmd} /tmp/bios_mod.bin remove -n hwid

		# Create new HWID file
		echo -n "$hwid" > /tmp/hwid_new.txt

		# Add new HWID to CBFS
		if ! run_quiet ${cbfstoolcmd} /tmp/bios_mod.bin add -n hwid -f /tmp/hwid_new.txt -t raw; then
			fail_menu "\nError adding HWID to firmware." || return
		fi

		# Disable software write-protect
		require_software_wp_clear flash \
			"Error disabling software write-protect; unable to set HWID." \
			"Error clearing software write-protect range; unable to set HWID." || return

		# Write firmware back
		echo_yellow "Writing firmware with new HWID..."
		if ! run_flashrom ${flashromcmd} --fmap -i COREBOOT -w /tmp/bios_mod.bin -N; then
			if [ -f /tmp/flashrom.log ]; then
				cat /tmp/flashrom.log
			fi
			fail_menu "\nError writing firmware; HWID not set. DO NOT REBOOT!" || return
		fi

		# Cleanup
		rm -f /tmp/hwid_new.txt /tmp/bios_mod.bin

		echo_green "Hardware ID successfully set. Reboot for the change to take effect."
	fi
	read -rep "Press [Enter] to return to the main menu."
}

###############
# Clear NVRAM #
###############
function clear_nvram()
{
	log_fn
	echo_green "\nClear UEFI NVRAM"
	echo_yellow "Clearing the NVRAM will remove all EFI variables\nand reset the boot order to the default."

	read -rep "Would you like to continue? [y/N] "
	[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

	echo_yellow "\nClearing NVRAM..."
	if ! run_flashrom ${flashromcmd} -E -i SMMSTORE --fmap; then
		cat /tmp/flashrom.log
		fail_menu "\nFailed to erase SMMSTORE firmware region; NVRAM not cleared." || return
	fi
	#all done
	echo_green "NVRAM has been cleared."
	read -rep "Press [Enter] to continue"
}

#############################
# Reset CR50 TPM NVRAM Data #
#############################
function reset_cr50_nvram()
{
	log_fn
	local firmware_file="$1"
	
	if [[ "$hasCR50" != true ]]; then
		return 0
	fi

	echo_yellow "\nResetting CR50 TPM and kernel version data..."

	# Download tpmc tool if needed
	if ! get_tpmc; then
		echo_red "Unable to download tpmc utility; cannot reset CR50 NVRAM."
		return 1
	fi

	# Clear and re-enable
	run_quiet ${tpmccmd} clear
	run_quiet ${tpmccmd} enable
	run_quiet ${tpmccmd} activate

	# Reset TPM data in CR50 NVRAM
	# First verify we can read from 0x1007 before writing
	if ! run_quiet ${tpmccmd} read 0x1007 0xa; then
		echo_red "Error: Failed to read from CR50 NVRAM index 0x1007."
		return 1
	fi
	
	# Write TPM reset command
	if ! run_quiet ${tpmccmd} write 0x1007 02 00 01 00 01 00 00 00 00 4f; then
		echo_red "Error: Failed to reset CR50 TPM data."
		return 1
	fi
	
	# Reset kernel version data in CR50 NVRAM
	# First verify we can read from 0x1008 before writing
	if ! run_quiet ${tpmccmd} read 0x1008 0xa; then
		echo_red "Error: Failed to read from CR50 NVRAM index 0x1008."
		return 1
	fi
	
	# Determine which command string to use based on FWID from config file
	if [[ -n "$firmware_file" && -f "$firmware_file" ]]; then
		# Extract config file from COREBOOT region
		if run_quiet ${cbfstoolcmd} "${firmware_file}" extract -n config -f /tmp/config.txt; then
			# Try to find FWID in the config
			fwid_line=$(grep -i "FWID" /tmp/config.txt 2>/dev/null | head -1)
			if [[ -n "$fwid_line" ]]; then
				# Extract major version (field 2 using . as delimiter)
				fwid_major=$(echo "$fwid_line" | cut -d'.' -f2)
				# Clean up any non-numeric characters
				fwid_major=$(echo "$fwid_major" | tr -cd '0-9')
				
				if [[ -n "$fwid_major" ]] && [[ "$fwid_major" -lt 12953 ]] 2>/dev/null; then
					# v0 secdata_kernel (< 12953)
					echo_yellow "Using v0 secdata_kernel format (FWID $fwid_major)"
					if ! run_quiet ${tpmccmd} write 0x1008 02 4c 57 52 47 01 00 01 00 00 00 00 55; then
						echo_red "Error: Failed to reset CR50 kernel version data."
						return 1
					fi
				else
					# v1 secdata kernel (>= 12953)
					echo_yellow "Using v1 secdata_kernel format (FWID $fwid_major)"
					if ! run_quiet ${tpmccmd} write 0x1008 10 28 0c 00 01 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00; then
						echo_red "Error: Failed to reset CR50 kernel version data."
						return 1
					fi
				fi
			else
				echo_red "Error: Could not find FWID in config file."
				return 1
			fi
		else
			echo_red "Error: Failed to extract config file from COREBOOT region."
			return 1
		fi
	else
		echo_red "Error: Firmware file not available for FWID check."
		return 1
	fi

	echo_green "\nCR50 NVRAM reset completed."
	return 0
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
	echo -e "${MENU}**${NUMBER}     Device: ${NORMAL}${deviceDesc}"
	echo -e "${MENU}**${NUMBER} Board Name: ${NORMAL}${boardName^^}"
	echo -e "${MENU}**${NUMBER}   Platform: ${NORMAL}$deviceCpuTypeName"
	echo -e "${MENU}**${NUMBER}    Fw Type: ${NORMAL}$firmwareType"
	echo -e "${MENU}**${NUMBER}     Fw Ver: ${NORMAL}$fwVer ($fwDate)"
	if [[ $isUEFI = true && $hasUEFIoption = true ]]; then
		local latest_file latest_ymd latest_label update_text
		latest_file=$(fullrom_resolve_slot "latest")
		latest_ymd=$(fullrom_file_date "$latest_file")
		latest_label=$(fullrom_slot_label "latest")
		if fullrom_date_newer_than_installed "$latest_ymd"; then
			if fullrom_has_hotfix; then
				update_text="Hotfix Available"
			else
				update_text="Update Available"
			fi
			echo -e "${MENU}**${NORMAL}             ${GREEN_TEXT}${update_text} (${latest_label})${NORMAL}"
		fi
	fi
	if [ "$wpEnabled" = true ]; then
		echo -e "${MENU}**${NUMBER}      Fw WP: ${RED_TEXT}Enabled${NORMAL}"
		WP_TEXT=${RED_TEXT}
	else
		echo -e "${MENU}**${NUMBER}      Fw WP: ${NORMAL}Disabled"
		WP_TEXT=${GREEN_TEXT}
	fi
	echo -e "${MENU}*********************************************************${NORMAL}"
}

function stock_menu() {

	show_header

	if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isStock" = true && "$isUnsupported" = false \
			&& ("$isCmlBook" = false || "$device" == "drallion") && "$isEOL" = false ) ]]; then
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
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} U)${MENU} Upgrade Touchpad Firmware ${NORMAL}"
	fi
	if [[ "$isJsl" = true &&  "$device" =~ "gal" ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} T)${MENU} Set Touchpad Type in SSFC ${NORMAL}"
	fi
	if [[ "${device^^}" = "TAEKO" || "${device^^}" = "TANIKS" ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} S)${MENU} Set Storage Type in FW_CONFIG ${NORMAL}"
	fi
	if [[ "$unlockMenu" = true || ("$isFullRom" = false && "$isStock" = true) ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 3)${MENU} Set Boot Options (GBB flags) ${NORMAL}"
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 4)${MENU} Set Hardware ID (HWID) ${NORMAL}"
	else
		echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 3)${GRAY_TEXT} Set Boot Options (GBB flags)${NORMAL}"
		echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 4)${GRAY_TEXT} Set Hardware ID (HWID) ${NORMAL}"
	fi
	if [[ "$unlockMenu" = true || "$isStock" = true ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} 5)${MENU} Backup Current Firmware ${NORMAL}"
	fi
	if [[ "$unlockMenu" = true || ( "$isChromeOS" = false  && "$isFullRom" = true ) ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 6)${MENU} Restore Stock Firmware (full) ${NORMAL}"
	fi
	if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} C)${MENU} Clear UEFI NVRAM ${NORMAL}"
	fi
	echo -e "${MENU}*********************************************************${NORMAL}"
	echo -e "${ENTER_LINE}Select a numeric menu option or${NORMAL}"
	echo -e "${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"

	read -re opt
	case $opt in

	1)	if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isStock" = true && "$isUnsupported" = false \
				&& ("$isCmlBook" = false || "$device" == "drallion") && "$isEOL" = false ) ]]; then
			flash_rwlegacy
		elif [[ "$isEOL" = true ]]; then
			fail_menu "The RW_LEGACY firmware update is not supported for devices which have reached end-of-life" || true
		fi
		menu_fwupdate
		;;

	2)	if [[ "$unlockMenu" = true || "$hasUEFIoption" = true ]]; then
			flash_full_rom latest
		fi
			menu_fwupdate
		;;

	[dD])	if [[ "${device^^}" = "EVE" ]]; then
			downgrade_touchpad_fw
		fi
		menu_fwupdate
		;;

	[uU])	if [[ "${device^^}" = "EVE" ]]; then
			upgrade_touchpad_fw
		fi
		menu_fwupdate
		;;

	[tT])	if [[ "$isJsl" = true &&  "$device" =~ "gal" ]]; then
			set_touchpad_in_ssfc
		fi
		menu_fwupdate
		;;

	[sS])	if [[ "${device^^}" = "TAEKO" || "${device^^}" = "TANIKS" ]]; then
			set_storage_in_fw_config
		fi
		menu_fwupdate
		;;

	3)	if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
				&& "$isFullRom" = false && "$isStock" = true ]]; then
			set_boot_options
		fi
		menu_fwupdate
		;;

	4)	if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
				&& "$isFullRom" = false && "$isStock" = true ]]; then
			set_hwid
		fi
		menu_fwupdate
		;;

	5)	if [[ "$unlockMenu" = true || "$isStock" = true ]]; then
			backup_current_firmware
		fi
		menu_fwupdate
		;;

	6)	if [[ "$unlockMenu" = true || "$isChromeOS" = false && "$isUnsupported" = false \
				&& "$isFullRom" = true ]]; then
			restore_stock_firmware
		fi
		menu_fwupdate
		;;

	[rR])	echo -e "\nRebooting...\n";
		cleanup
		if ! reboot 2>/dev/null; then
			systemctl reboot -i
		fi
		exit
		;;

	[pP])	echo -e "\nPowering off...\n";
		cleanup
		poweroff
		exit
		;;

	[qQ])	cleanup;
		exit;
		;;

	[lL])	if [ "$unlockMenu" = false ]; then
			echo_yellow "\nAre you sure you wish to unlock all menu functions?"
			read -rep "Only do this if you really know what you are doing... [y/N]? "
			[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && unlockMenu=true
		fi
		menu_fwupdate
		;;

	[cC])	if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
			clear_nvram
		fi
		menu_fwupdate
		;;

	*)	clear
		menu_fwupdate;
		;;

	esac
}


unlockMenu=false

function uefi_menu() {

	show_header

	if [[ "$hasUEFIoption" = true && "$isUnsupported" = false ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 1)${MENU} Install/Update UEFI (Full ROM) Firmware ${NORMAL}"
	else
		echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update UEFI (Full ROM) Firmware${NORMAL}"
	fi
	if [[ "$isChromeOS" = false  && "$isFullRom" = true && "$isUnsupported" = false ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 2)${MENU} Restore Stock Firmware ${NORMAL}"
	else
		echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 2)${GRAY_TEXT} Restore Stock ChromeOS Firmware ${NORMAL}"
	fi
	if [[ "$unlockMenu" = true || ("$isUEFI" = true && "$isUnsupported" = false) ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} 3)${MENU} Backup Current Firmware ${NORMAL}"
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 4)${MENU} Flash Custom Firmware ${NORMAL}"
	fi
	if [[ "$isUEFI" = true ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} 5)${MENU} Set Hardware ID (HWID) ${NORMAL}"
	fi
	if fullrom_can_rollback; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 6)${MENU} Rollback to Previous UEFI Release ($(fullrom_slot_label previous)) ${NORMAL}"
	else
		echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 6)${GRAY_TEXT} Rollback to Previous UEFI Release ${NORMAL}"
	fi
	if [[ "${device^^}" = "EVE" ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} D)${MENU} Downgrade Touchpad Firmware ${NORMAL}"
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} U)${MENU} Upgrade Touchpad Firmware ${NORMAL}"
	fi
	if [[ "$isJsl" = true &&  "$device" =~ "gal" ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} T)${MENU} Set Touchpad Type in SSFC ${NORMAL}"
	fi
	if [[ "${device^^}" = "TAEKO" || "${device^^}" = "TANIKS" ]]; then
		echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} S)${MENU} Set Storage Type in FW_CONFIG ${NORMAL}"
	fi
	if [[ "$unlockMenu" = true || ("$isUEFI" = true && "$isUnsupported" = false) ]]; then
		echo -e "${MENU}**${WP_TEXT}     ${NUMBER} C)${MENU} Clear UEFI NVRAM ${NORMAL}"
	fi
	echo -e "${MENU}*********************************************************${NORMAL}"
	echo -e "${ENTER_LINE}Select a numeric menu option or${NORMAL}"
	echo -e "${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"

	read -re opt
	case $opt in

	1)	if [[ "$hasUEFIoption" = true && "$isUnsupported" = false ]]; then
			flash_full_rom latest
		fi
		uefi_menu
		;;

	2)	if [[ "$isChromeOS" = false && "$isUnsupported" = false && "$isFullRom" = true ]]; then
			restore_stock_firmware
			menu_fwupdate
		else
			uefi_menu
		fi
		;;

	3)	if [[ "$unlockMenu" = true || ("$isUEFI" = true && "$isUnsupported" = false) ]]; then
			backup_current_firmware
		fi
		uefi_menu
		;;

	4)	if [[ "$unlockMenu" = true || ("$isUEFI" = true && "$isUnsupported" = false) ]]; then
			flash_custom_firmware
		fi
		uefi_menu
		;;

	5)	if [[ "$isUEFI" = true ]]; then
			set_hwid_uefi
		fi
		uefi_menu
		;;

	6)	if fullrom_can_rollback; then
			flash_full_rom previous
		fi
		uefi_menu
		;;

	[dD])	if [[  "${device^^}" = "EVE" ]]; then
			downgrade_touchpad_fw
		fi
		uefi_menu
		;;

	[uU])	if [[  "${device^^}" = "EVE" ]]; then
			upgrade_touchpad_fw
		fi
		uefi_menu
		;;

	[tT])	if [[ "$isJsl" = true &&  "$device" =~ "gal" ]]; then
			set_touchpad_in_ssfc
		fi
		uefi_menu
		;;

	[sS])	if [[ "${device^^}" = "TAEKO" || "${device^^}" = "TANIKS" ]]; then
			set_storage_in_fw_config
		fi
		uefi_menu
		;;

	[rR])	echo -e "\nRebooting...\n";
		cleanup
		if ! reboot 2>/dev/null; then
			systemctl reboot -i
		fi
		exit
		;;

	[pP])	echo -e "\nPowering off...\n";
		cleanup
		poweroff
		exit
		;;

	[qQ])  cleanup;
	exit;
	;;

	[cC])	if [[ "$isUEFI" = true && "$isUnsupported" = false ]]; then
			clear_nvram
		fi
		uefi_menu
		;;

	*)	clear
		uefi_menu;
		;;

	esac
}
