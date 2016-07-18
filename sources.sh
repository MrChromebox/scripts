#!/bin/bash
#


#define these here for easy updating
script_date="[2016-07-16]"

#where the stuff is
firmware_source_main="https://dl.dropboxusercontent.com/u/98309225/"
firmware_source_coolstar="https://dl.dropboxusercontent.com/u/59964215/chromebook/ROM-uefi/"

#LE sources
LE_url_official="http://releases.libreelec.tv/"
#OE_url_EGL="https://dl.dropboxusercontent.com/u/98309225/"
LE_url=${LE_url_official}
chrx_url="https://chrx.org/go"

#LE version
LE_version_base="LibreELEC-Generic.x86_64"
LE_version_stable="7.0.2"
LE_version_latest="7.90.003"

#SBIB full ROMs
coreboot_stumpy="coreboot-seabios-stumpy-mattdevo-20160623.rom"

#Haswell full ROMs
coreboot_hsw_box="coreboot-seabios-hsw_chromebox-mattdevo-20160623.rom"
coreboot_peppy="coreboot-seabios-tianocore-peppy-20160714-coolstar.rom"
coreboot_peppy_elan="coreboot-seabios-tianocore-peppy-20160714-coolstar-elan.rom"
coreboot_falco="coreboot-seabios-tianocore-falco-20160714-coolstar.rom"
coreboot_wolf="coreboot-seabios-tianocore-wolf-20160714-coolstar.rom"
coreboot_leon="coreboot-seabios-tianocore-leon-20160714-coolstar.rom"
coreboot_monroe=""

#Broadwell full ROMs
coreboot_guado="coreboot-seabios-guado-mattdevo-20160623.rom"
coreboot_rikku="coreboot-seabios-rikku-mattdevo-20160623.rom"
coreboot_tidus="coreboot-seabios-tidus-mattdevo-20160623.rom"
coreboot_auron_paine="coreboot-seabios-tianocore-auron_paine-20160715-coolstar.rom"
coreboot_auron_yuna="coreboot-seabios-tianocore-auron_yuna-20160715-coolstar.rom"
coreboot_gandof="coreboot-seabios-tianocore-gandof-20160715-coolstar.rom"
coreboot_lulu="coreboot-seabios-tianocore-lulu-20160715-coolstar.rom"
coreboot_samus="coreboot-seabios-tianocore-samus-20160715-coolstar.rom"

#BayTrail full ROMs
coreboot_ninja="coreboot-seabios-ninja-mattdevo-20160710.rom"

#RW_LEGACY payloads
seabios_hswbdw_box="seabios-hswbdw-box-mattdevo-20160704.bin"
seabios_hsw_book="seabios-hsw-book-mattdevo-20160704.bin"
seabios_bdw_book="seabios-bdw-book-mattdevo-20160704.bin"
seabios_baytrail="seabios-byt-mattdevo-20160704.bin"

#BOOT_STUB payload
bootstub_payload_baytrail="seabios-byt-bootstub-mattdevo-20160704.bin"

#hsw/bdw headless VBIOS
hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
pxe_optionrom="10ec8168.rom"

