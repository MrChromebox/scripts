#!/bin/bash
#


#define these here for easy updating
script_date="[2016-06-23]"

#where the stuff is
firmware_source_main="https://dl.dropboxusercontent.com/u/98309225/"
firmware_source_coolstar="https://dl.dropboxusercontent.com/u/59964215/chromebook/ROM/"

#LE sources
LE_url_official="http://releases.libreelec.tv/"
#OE_url_EGL="https://dl.dropboxusercontent.com/u/98309225/"
LE_url=${LE_url_official}
chrx_url="https://chrx.org/go"

#LE version
LE_version_base="LibreELEC-Generic.x86_64"
LE_version_stable="7.0.1"
LE_version_latest="7.0.1"

#SBIB full ROMs
coreboot_stumpy="coreboot-seabios-stumpy-20160623-mattdevo.rom"

#Haswell full ROMs
coreboot_hsw_box="coreboot-seabios-hsw_chromebox-mattdevo-20160623.rom"
coreboot_peppy="coreboot-seabios-peppy-20160108-coolstar.rom"
coreboot_peppy_elan="coreboot-seabios-peppy-20160108-coolstar-elan.rom"
coreboot_falco="coreboot-seabios-falco-20160108-coolstar.rom"
coreboot_wolf="coreboot-seabios-wolf-20160108-coolstar.rom"
coreboot_leon="coreboot-seabios-leon-20160108-coolstar.rom"
coreboot_monroe="coreboot-seabios-monroe-20160108-coolstar.rom"

#Broadwell full ROMs
coreboot_guado="coreboot-seabios-guado-mattdevo-20160623.rom"
coreboot_rikku="coreboot-seabios-rikku-mattdevo-20160623.rom"
coreboot_tidus="coreboot-seabios-tidus-mattdevo-20160623.rom"
coreboot_auron_paine="coreboot-seabios-auron-20160109-coolstar.rom"
coreboot_auron_yuna=${coreboot_auron_paine}
coreboot_gandof="coreboot-seabios-gandof-20160309-coolstar.rom"
coreboot_lulu="coreboot-seabios-lulu-20160311-coolstar.rom"
coreboot_samus="coreboot-seabios-samus-20160324-coolstar.rom"

#BayTrail full ROMs
coreboot_ninja="coreboot-seabios-ninja-mattdevo-20160623.rom"

#RW_LEGACY payloads
seabios_hswbdw_box="seabios-hswbdw-box-mattdevo-20160623.bin"
seabios_hsw_book="seabios-hsw-book-mattdevo-20160623.bin"
seabios_bdw_book="seabios-bdw-book-mattdevo-20160623.bin"
seabios_baytrail="seabios-byt-mattdevo-20160623.bin"

#BOOT_STUB payload
bootstub_payload_baytrail="seabios-byt-bootstub-mattdevo-20160623.bin"

#hsw/bdw headless VBIOS
hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
pxe_optionrom="10ec8168.rom"

