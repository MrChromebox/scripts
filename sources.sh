#!/bin/bash
#


#define these here for easy updating
script_date="[2019-08-25]"

#where the stuff is
util_source="https://www.mrchromebox.tech/files/util/"
rwlegacy_source="https://www.mrchromebox.tech/files/firmware/rw_legacy/"
bootstub_source="https://www.mrchromebox.tech/files/firmware/boot_stub/"
fullrom_source="https://www.mrchromebox.tech/files/firmware/full_rom/"
shellball_source="https://www.mrchromebox.tech/files/firmware/shellball/"
cbfs_source="https://www.mrchromebox.tech/files/firmware/cbfs/"

#LE sources
LE_url_official="http://releases.libreelec.tv/"
LE_url=${LE_url_official}
chrx_url="https://chrx.org/go"

#LE version
LE_version_base="LibreELEC-Generic.x86_64"
LE_version_stable="9.0.2"
LE_version_latest="9.1.002"

#syslinux version
syslinux_version="syslinux-6.04-pre1"

#UEFI Full ROMs
#SNB/IVB
coreboot_uefi_butterfly="coreboot_tiano-butterfly-mrchromebox_20190822.rom"
coreboot_uefi_lumpy="coreboot_tiano-lumpy-mrchromebox_20190822.rom"
coreboot_uefi_link="coreboot_tiano-link-mrchromebox_20190824.rom"
coreboot_uefi_parrot="coreboot_tiano-parrot-mrchromebox_20190822.rom"
coreboot_uefi_stout="coreboot_tiano-stout-mrchromebox_20190822.rom"
coreboot_uefi_stumpy="coreboot_tiano-stumpy-mrchromebox_20190822.rom"
#Haswell
coreboot_uefi_falco="coreboot_tiano-falco-mrchromebox_20190822.rom"
coreboot_uefi_leon="coreboot_tiano-leon-mrchromebox_20190822.rom"
coreboot_uefi_mccloud="coreboot_tiano-mccloud-mrchromebox_20190822.rom"
coreboot_uefi_monroe="coreboot_tiano-monroe-mrchromebox_20190822.rom"
coreboot_uefi_panther="coreboot_tiano-panther-mrchromebox_20190822.rom"
coreboot_uefi_peppy="coreboot_tiano-peppy-mrchromebox_20190822.rom"
coreboot_uefi_peppy_elan="coreboot_tiano-peppy_elan-mrchromebox_20190822.rom"
coreboot_uefi_tricky="coreboot_tiano-tricky-mrchromebox_20190822.rom"
coreboot_uefi_wolf="coreboot_tiano-wolf-mrchromebox_20190822.rom"
coreboot_uefi_zako="coreboot_tiano-zako-mrchromebox_20190822.rom"
#Broadwell
coreboot_uefi_auron_paine="coreboot_tiano-auron_paine-mrchromebox_20190822.rom"
coreboot_uefi_auron_yuna="coreboot_tiano-auron_yuna-mrchromebox_20190822.rom"
coreboot_uefi_buddy="coreboot_tiano-buddy-mrchromebox_20190822.rom"
coreboot_uefi_gandof="coreboot_tiano-gandof-mrchromebox_20190822.rom"
coreboot_uefi_guado="coreboot_tiano-guado-mrchromebox_20190822.rom"
coreboot_uefi_lulu="coreboot_tiano-lulu-mrchromebox_20190822.rom"
coreboot_uefi_rikku="coreboot_tiano-rikku-mrchromebox_20190822.rom"
coreboot_uefi_samus="coreboot_tiano-samus-mrchromebox_20190822.rom"
coreboot_uefi_tidus="coreboot_tiano-tidus-mrchromebox_20190822.rom"
#Baytrail
coreboot_uefi_banjo="coreboot_tiano-banjo-mrchromebox_20190822.rom"
coreboot_uefi_candy="coreboot_tiano-candy-mrchromebox_20190822.rom"
coreboot_uefi_clapper="coreboot_tiano-clapper-mrchromebox_20190822.rom"
coreboot_uefi_enguarde="coreboot_tiano-enguarde-mrchromebox_20190822.rom"
coreboot_uefi_glimmer="coreboot_tiano-glimmer-mrchromebox_20190822.rom"
coreboot_uefi_gnawty="coreboot_tiano-gnawty-mrchromebox_20190822.rom"
coreboot_uefi_heli="coreboot_tiano-heli-mrchromebox_20190822.rom"
coreboot_uefi_kip="coreboot_tiano-kip-mrchromebox_20190822.rom"
coreboot_uefi_ninja="coreboot_tiano-ninja-mrchromebox_20190822.rom"
coreboot_uefi_orco="coreboot_tiano-orco-mrchromebox_20190822.rom"
coreboot_uefi_quawks="coreboot_tiano-quawks-mrchromebox_20190822.rom"
coreboot_uefi_squawks="coreboot_tiano-squawks-mrchromebox_20190822.rom"
coreboot_uefi_sumo="coreboot_tiano-sumo-mrchromebox_20190822.rom"
coreboot_uefi_swanky="coreboot_tiano-swanky-mrchromebox_20190822.rom"
coreboot_uefi_winky="coreboot_tiano-winky-mrchromebox_20190822.rom"
#Braswell
coreboot_uefi_banon="coreboot_tiano-banon-mrchromebox_20190822.rom"
coreboot_uefi_celes="coreboot_tiano-celes-mrchromebox_20190822.rom"
coreboot_uefi_cyan="coreboot_tiano-cyan-mrchromebox_20190822.rom"
coreboot_uefi_edgar="coreboot_tiano-edgar-mrchromebox_20190822.rom"
coreboot_uefi_kefka="coreboot_tiano-kefka-mrchromebox_20190822.rom"
coreboot_uefi_reks="coreboot_tiano-reks-mrchromebox_20190822.rom"
coreboot_uefi_relm="coreboot_tiano-relm-mrchromebox_20190822.rom"
coreboot_uefi_setzer="coreboot_tiano-setzer-mrchromebox_20190822.rom"
coreboot_uefi_terra="coreboot_tiano-terra-mrchromebox_20190822.rom"
coreboot_uefi_ultima="coreboot_tiano-ultima-mrchromebox_20190822.rom"
coreboot_uefi_wizpig="coreboot_tiano-wizpig-mrchromebox_20190822.rom"
#Skylake
coreboot_uefi_asuka="coreboot_tiano-asuka-mrchromebox_20190825.rom"
coreboot_uefi_caroline="coreboot_tiano-caroline-mrchromebox_20190825.rom"
coreboot_uefi_cave="coreboot_tiano-cave-mrchromebox_20190825.rom"
coreboot_uefi_chell="coreboot_tiano-chell-mrchromebox_20190825.rom"
coreboot_uefi_lars="coreboot_tiano-lars-mrchromebox_20190825.rom"
coreboot_uefi_sentry="coreboot_tiano-sentry-mrchromebox_20190825.rom"
#KabyLake
coreboot_uefi_eve="coreboot_tiano-eve-mrchromebox_20190825.rom"
coreboot_uefi_fizz="coreboot_tiano-fizz-mrchromebox_20190825.rom"
coreboot_uefi_nami="coreboot_tiano-nami-mrchromebox_20190825.rom"
coreboot_uefi_soraka="coreboot_tiano-soraka-mrchromebox_20190825.rom"

#Legacy Full ROMs (deprecated)
#SNB/IVB
coreboot_stumpy="coreboot_seabios-stumpy-mrchromebox_20180204.rom"
#Haswell
coreboot_mccloud="coreboot_seabios-mccloud-mrchromebox_20180204.rom"
coreboot_panther="coreboot_seabios-panther-mrchromebox_20180204.rom"
coreboot_tricky="coreboot_seabios-tricky-mrchromebox_20180204.rom"
coreboot_zako="coreboot_seabios-zako-mrchromebox_20180204.rom"
#Broadwell
coreboot_guado="coreboot_seabios-guado-mrchromebox_20180204.rom"
coreboot_rikku="coreboot_seabios-rikku-mrchromebox_20180204.rom"
coreboot_tidus="coreboot_seabios-tidus-mrchromebox_20180204.rom"

#RW_LEGACY payloads
seabios_link="seabios-link-mrchromebox_20180912.bin"
seabios_hswbdw_box="seabios-hswbdw_box-mrchromebox_20180912.bin"
seabios_hswbdw_book="seabios-hswbdw_book-mrchromebox_20180912.bin"
seabios_baytrail="seabios-byt-mrchromebox_20180912.bin"
seabios_braswell="seabios-bsw-mrchromebox_20180912.bin"
seabios_skylake="seabios-skl-mrchromebox_20180912.bin"
seabios_apl="seabios-apl-mrchromebox_20180912.bin"
seabios_kbl="seabios-kbl-mrchromebox_20180912.bin"

rwlegacy_multi="rwlegacy_multi-mrchromebox_20190822.bin"

#BOOT_STUB payloads
bootstub_payload_baytrail="seabios-byt_bootstub-mrchromebox_20180912.bin"


#hsw/bdw headless VBIOS
hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
pxe_optionrom="10ec8168.rom"

#Non-ChromeOS devices
coreboot_uefi_librem13v1="coreboot_tiano-librem13v1-mrchromebox_20190822.rom"
coreboot_uefi_librem13v2="coreboot_tiano-librem13v2-mrchromebox_20190825.rom"
coreboot_uefi_librem13v4="coreboot_tiano-librem13v4-mrchromebox_20190825.rom"
coreboot_uefi_librem15v2="coreboot_tiano-librem15v2-mrchromebox_20190822.rom"
coreboot_uefi_librem15v3="coreboot_tiano-librem15v3-mrchromebox_20190825.rom"
coreboot_uefi_librem15v4="coreboot_tiano-librem15v4-mrchromebox_20190825.rom"
