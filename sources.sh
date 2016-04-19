#!/bin/bash
#


#define these here for easy updating
script_date="[2016-04-19]"

#where the stuff is
firmware_source_main="https://dl.dropboxusercontent.com/u/98309225/"
firmware_source_coolstar="https://dl.dropboxusercontent.com/u/59964215/chromebook/ROM/"

#OE sources
OE_url_official="http://releases.openelec.tv/"
OE_url_EGL="https://dl.dropboxusercontent.com/u/98309225/"
OE_url=${OE_url_EGL}
chrx_url="https://chrx.org/go"

#OE version
OE_version_base="OpenELEC-Generic.x86_64"
OE_version_stable="6.0.398-Intel_EGL"
OE_version_latest="6.95.2"

#SBIB full ROMs
coreboot_stumpy="coreboot-seabios-stumpy-20160418-mattdevo.rom"

#Haswell full ROMs
coreboot_hsw_box="coreboot-seabios-hsw_chromebox-20160418-mattdevo.rom"
coreboot_peppy="coreboot-seabios-peppy-20160108-coolstar.rom"
coreboot_peppy_elan="coreboot-seabios-peppy-20160108-coolstar-elan.rom"
coreboot_falco="coreboot-seabios-falco-20160108-coolstar.rom"
coreboot_wolf="coreboot-seabios-wolf-20160108-coolstar.rom"
coreboot_leon="coreboot-seabios-leon-20160108-coolstar.rom"
coreboot_monroe="coreboot-seabios-monroe-20160108-coolstar.rom"

#Broadwell full ROMs
coreboot_guado="coreboot-seabios-guado-20160418-mattdevo.rom"
coreboot_rikku="coreboot-seabios-rikku-20160418-mattdevo.rom"
coreboot_tidus="coreboot-seabios-tidus-20160418-mattdevo.rom"
coreboot_auron_paine="coreboot-seabios-auron-20160109-coolstar.rom"
coreboot_auron_yuna=${coreboot_auron_paine}
coreboot_gandof="coreboot-seabios-gandof-20160309-coolstar.rom"
coreboot_lulu="coreboot-seabios-lulu-20160311-coolstar.rom"
coreboot_samus="coreboot-seabios-samus-20160324-coolstar.rom"

#RW_LEGACY payloads
seabios_hswbdw_box="seabios-hswbdw-box-20160418-mattdevo.bin"
seabios_hsw_book="seabios-hsw-book-20160418-mattdevo.bin"
seabios_bdw_book="seabios-bdw-book-20160418-mattdevo.bin"
seabios_baytrail="seabios-baytrail-20160419-mattdevo.bin"

#BOOT_STUB payload
bootstub_payload_baytrail="seabios-payload-20160419-mattdevo.bin"

#hsw/bdw headless VBIOS
hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
pxe_optionrom="10ec8168.rom"

