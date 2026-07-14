#!/bin/bash
#


#define these here for easy updating
export script_date="[2026-07-14]"

# versioned: full_rom/MrChromebox-${version}/…  |  flat: full_rom/… (override for private deploys)
export fullrom_layout="${fullrom_layout:-versioned}"

# version = CDN subdir + UI label; date = YYYYMMDD in the .rom filename
export release_current_version="2606.0"
export release_current_date="20260709"
export release_previous_version="2603.2"
export release_previous_date="20260517"

# per-board hotfix build dates (skips release_current for that board)
declare -A FW_HOTFIX=(
	# [eve]=20260715
	# [karma]=20260722
)

#where the stuff is
export util_source="https://www.mrchromebox.tech/files/util/"
export rwlegacy_source="https://www.mrchromebox.tech/files/firmware/rw_legacy/"
export bootstub_source="https://www.mrchromebox.tech/files/firmware/boot_stub/"
export fullrom_source="https://www.mrchromebox.tech/files/firmware/full_rom/"
export cbfs_source="https://www.mrchromebox.tech/files/firmware/cbfs/"
export other_source="https://www.mrchromebox.tech/files/firmware/other/"

#RW_LEGACY payloads
export seabios_link="seabios-link-mrchromebox_20180912.bin"
export seabios_hswbdw_box="seabios-hswbdw_box-mrchromebox_20180912.bin"
export seabios_hswbdw_book="seabios-hswbdw_book-mrchromebox_20180912.bin"
export seabios_baytrail="seabios-byt-mrchromebox_20180912.bin"
export seabios_braswell="seabios-bsw-mrchromebox_20180912.bin"
export seabios_skylake="seabios-skl-mrchromebox_20180912.bin"
export seabios_apl="seabios-apl-mrchromebox_20180912.bin"
export seabios_kbl="seabios-kbl-mrchromebox_20250227.bin"
export seabios_kbl_18="seabios-kbl_18-mrchromebox_20250227.bin"
export rwl_altfw_apl="rwl_altfw-kbl_apl-mrchromebox_20260319.bin"
export rwl_altfw_kbl="rwl_altfw-kbl_apl-mrchromebox_20260319.bin"
export rwl_altfw_kbl_18="rwl_altfw-kbl_18-mrchromebox_20260319.bin"
export rwl_altfw_whl="rwl_altfw-whl-mrchromebox_20251119.bin"
export rwl_altfw_cml="rwl_altfw-cml-mrchromebox_20251031.bin"
export rwl_altfw_drallion="rwl_altfw-drallion-mrchromebox_20251031.bin"
export rwl_altfw_glk="rwl_altfw-glk-mrchromebox_20251031.bin"
export rwl_altfw_jsl="rwl_altfw-jsl-mrchromebox_20251031.bin"
export rwl_altfw_tgl="rwl_altfw-tgl-mrchromebox_20251031.bin"
export rwl_altfw_adl="rwl_altfw-adl-mrchromebox_20251031.bin"
export rwl_altfw_adl_fixed="rwl_altfw-adl_2-mrchromebox_20251031.bin"
export rwl_altfw_adl_n="rwl_altfw-adl_n-mrchromebox_20251031.bin"
export rwl_altfw_mtl="rwl_altfw-mtl-mrchromebox_20251031.bin"

#RWL - AMD
export rwl_altfw_stoney="rwl_altfw-str-mrchromebox_20251031.bin"
export rwl_altfw_pco="rwl_altfw-pco-mrchromebox_20251031.bin"
export rwl_altfw_mdn="rwl_altfw-mdn-mrchromebox_20251031.bin"
export rwl_altfw_czn="rwl_altfw-czn-mrchromebox_20251031.bin"

#hsw/bdw headless VBIOS
export hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
export pxe_optionrom="10ec8168.rom"


# other
export flashrom_eve_tp="flashrom_eve_tp"
export touchpad_eve_fw="rose_v1.1.8546-ee1861e9e.bin"
export touchpad_eve_fw_stock="rose_v2.0.653-dfd8046c6.bin"
