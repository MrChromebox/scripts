#!/bin/bash
#


#define these here for easy updating
script_date="[2016-08-05]"

#where the stuff is
util_source="https://www.mrchromebox.tech/files/util/"
rwlegacy_source="https://www.mrchromebox.tech/files/firmware/rw_legacy/"
bootstub_source="https://www.mrchromebox.tech/files/firmware/boot_stub/"
fullrom_source="https://www.mrchromebox.tech/files/firmware/full_rom/"
fullrom_source_coolstar="https://dl.dropboxusercontent.com/u/59964215/chromebook/ROM/"
shellball_source="https://www.mrchromebox.tech/files/firmware/shellball/"
cbfs_source="https://www.mrchromebox.tech/files/firmware/cbfs/"

#LE sources
LE_url_official="http://releases.libreelec.tv/"
LE_url=${LE_url_official}
chrx_url="https://chrx.org/go"

#LE version
LE_version_base="LibreELEC-Generic.x86_64"
LE_version_stable="7.0.2"
LE_version_latest="7.90.003"

#syslinux version
syslinux_version="syslinux-6.04-pre1"

#SBIB full ROMs
coreboot_stumpy="coreboot-seabios-stumpy-mrchromebox-20160805.rom"

#Haswell full ROMs
coreboot_hsw_box="coreboot-seabios-panther-mrchromebox-20160805.rom"
coreboot_peppy="coreboot-seabios-peppy-20160108-coolstar.rom"
coreboot_peppy_elan="coreboot-seabios-peppy-20160108-coolstar-elan.rom"
coreboot_falco="coreboot-seabios-falco-20160108-coolstar.rom"
coreboot_wolf="coreboot-seabios-wolf-20160108-coolstar.rom"
coreboot_leon="coreboot-seabios-leon-20160108-coolstar.rom"

#Broadwell full ROMs
coreboot_guado="coreboot-seabios-guado-mrchromebox-20160805.rom"
coreboot_rikku="coreboot-seabios-rikku-mrchromebox-20160805.rom"
coreboot_tidus="coreboot-seabios-tidus-mrchromebox-20160805.rom"
coreboot_auron_paine="coreboot-seabios-auron-20160109-coolstar.rom"
coreboot_auron_yuna=${coreboot_auron_paine}
coreboot_gandof="coreboot-seabios-gandof-20160309-coolstar.rom"
coreboot_lulu="coreboot-seabios-lulu-20160311-coolstar.rom"
coreboot_samus="coreboot-seabios-samus-20160324-coolstar.rom"

#BayTrail full ROMs
coreboot_candy="coreboot-seabios-candy-mrchromebox-20160805.rom"
coreboot_enguarde="coreboot-seabios-enguarde-mrchromebox-20160805.rom"
coreboot_glimmer="coreboot-seabios-glimmer-mrchromebox-20160805.rom"
coreboot_gnawty="coreboot-seabios-gnawty-mrchromebox-20160805.rom"
coreboot_ninja="coreboot-seabios-ninja-mrchromebox-20160805.rom"
coreboot_quawks="coreboot-seabios-quawks-mrchromebox-20160805.rom"
coreboot_swanky="coreboot-seabios-swanky-mrchromebox-20160805.rom"


#RW_LEGACY payloads
seabios_hswbdw_box="seabios-hswbdw-box-mrchromebox-20160805.bin"
seabios_hsw_book="seabios-hsw-book-mrchromebox-20160805.bin"
seabios_bdw_book="seabios-bdw-book-mrchromebox-20160805.bin"
seabios_baytrail="seabios-byt-mrchromebox-20160805.bin"
seabios_braswell="seabios-bsw-mrchromebox-20160805.bin"
seabios_skylake="seabios-skl-mrchromebox-20160805.bin"

#BOOT_STUB payload
bootstub_payload_baytrail="seabios-byt-bootstub-mrchromebox-20160805.bin"

#hsw/bdw headless VBIOS
hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
pxe_optionrom="10ec8168.rom"

