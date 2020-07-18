#!/bin/bash
#


#define these here for easy updating
script_date="[2020-07-18]"

#where the stuff is
util_source="https://www.mrchromebox.tech/files/util/"
rwlegacy_source="https://www.mrchromebox.tech/files/firmware/rw_legacy/"
bootstub_source="https://www.mrchromebox.tech/files/firmware/boot_stub/"
fullrom_source="https://www.mrchromebox.tech/files/firmware/full_rom/"
shellball_source="https://www.mrchromebox.tech/files/firmware/shellball/"
cbfs_source="https://www.mrchromebox.tech/files/firmware/cbfs/"
other_source="https://www.mrchromebox.tech/files/firmware/other/"

#LE sources
LE_url_official="http://releases.libreelec.tv/"
LE_url=${LE_url_official}
chrx_url="https://chrx.org/go"

#LE version
LE_version_base="LibreELEC-Generic.x86_64"
LE_version_stable="9.2.3"
LE_version_latest="9.2.3"

#syslinux version
syslinux_version="syslinux-6.04-pre1"

#UEFI Full ROMs
#SNB/IVB
coreboot_uefi_butterfly="coreboot_tiano-butterfly-mrchromebox_20200604.rom"
coreboot_uefi_lumpy="coreboot_tiano-lumpy-mrchromebox_20200604.rom"
coreboot_uefi_link="coreboot_tiano-link-mrchromebox_20200604.rom"
coreboot_uefi_parrot="coreboot_tiano-parrot-mrchromebox_20200604.rom"
coreboot_uefi_stout="coreboot_tiano-stout-mrchromebox_20200604.rom"
coreboot_uefi_stumpy="coreboot_tiano-stumpy-mrchromebox_20200604.rom"
#Haswell
coreboot_uefi_falco="coreboot_tiano-falco-mrchromebox_20200604.rom"
coreboot_uefi_leon="coreboot_tiano-leon-mrchromebox_20200604.rom"
coreboot_uefi_mccloud="coreboot_tiano-mccloud-mrchromebox_20200618.rom"
coreboot_uefi_monroe="coreboot_tiano-monroe-mrchromebox_20200604.rom"
coreboot_uefi_panther="coreboot_tiano-panther-mrchromebox_20200618.rom"
coreboot_uefi_peppy="coreboot_tiano-peppy-mrchromebox_20200604.rom"
coreboot_uefi_peppy_elan="coreboot_tiano-peppy_elan-mrchromebox_20200604.rom"
coreboot_uefi_tricky="coreboot_tiano-tricky-mrchromebox_20200618.rom"
coreboot_uefi_wolf="coreboot_tiano-wolf-mrchromebox_20200604.rom"
coreboot_uefi_zako="coreboot_tiano-zako-mrchromebox_20200618.rom"
#Broadwell
coreboot_uefi_auron_paine="coreboot_tiano-auron_paine-mrchromebox_20200604.rom"
coreboot_uefi_auron_yuna="coreboot_tiano-auron_yuna-mrchromebox_20200604.rom"
coreboot_uefi_buddy="coreboot_tiano-buddy-mrchromebox_20200604.rom"
coreboot_uefi_gandof="coreboot_tiano-gandof-mrchromebox_20200604.rom"
coreboot_uefi_guado="coreboot_tiano-guado-mrchromebox_20200604.rom"
coreboot_uefi_lulu="coreboot_tiano-lulu-mrchromebox_20200604.rom"
coreboot_uefi_rikku="coreboot_tiano-rikku-mrchromebox_20200604.rom"
coreboot_uefi_samus="coreboot_tiano-samus-mrchromebox_20200604.rom"
coreboot_uefi_tidus="coreboot_tiano-tidus-mrchromebox_20200604.rom"
#Baytrail
coreboot_uefi_banjo="coreboot_tiano-banjo-mrchromebox_20200604.rom"
coreboot_uefi_candy="coreboot_tiano-candy-mrchromebox_20200604.rom"
coreboot_uefi_clapper="coreboot_tiano-clapper-mrchromebox_20200604.rom"
coreboot_uefi_enguarde="coreboot_tiano-enguarde-mrchromebox_20200604.rom"
coreboot_uefi_glimmer="coreboot_tiano-glimmer-mrchromebox_20200604.rom"
coreboot_uefi_gnawty="coreboot_tiano-gnawty-mrchromebox_20200604.rom"
coreboot_uefi_heli="coreboot_tiano-heli-mrchromebox_20200604.rom"
coreboot_uefi_kip="coreboot_tiano-kip-mrchromebox_20200604.rom"
coreboot_uefi_ninja="coreboot_tiano-ninja-mrchromebox_20200604.rom"
coreboot_uefi_orco="coreboot_tiano-orco-mrchromebox_20200604.rom"
coreboot_uefi_quawks="coreboot_tiano-quawks-mrchromebox_20200604.rom"
coreboot_uefi_squawks="coreboot_tiano-squawks-mrchromebox_20200604.rom"
coreboot_uefi_sumo="coreboot_tiano-sumo-mrchromebox_20200604.rom"
coreboot_uefi_swanky="coreboot_tiano-swanky-mrchromebox_20200604.rom"
coreboot_uefi_winky="coreboot_tiano-winky-mrchromebox_20200604.rom"
#Braswell
coreboot_uefi_banon="coreboot_tiano-banon-mrchromebox_20200606.rom"
coreboot_uefi_celes="coreboot_tiano-celes-mrchromebox_20200606.rom"
coreboot_uefi_cyan="coreboot_tiano-cyan-mrchromebox_20200606.rom"
coreboot_uefi_edgar="coreboot_tiano-edgar-mrchromebox_20200606.rom"
coreboot_uefi_kefka="coreboot_tiano-kefka-mrchromebox_20200606.rom"
coreboot_uefi_reks="coreboot_tiano-reks-mrchromebox_20200606.rom"
coreboot_uefi_relm="coreboot_tiano-relm-mrchromebox_20200606.rom"
coreboot_uefi_setzer="coreboot_tiano-setzer-mrchromebox_20200606.rom"
coreboot_uefi_terra="coreboot_tiano-terra-mrchromebox_20200606.rom"
coreboot_uefi_ultima="coreboot_tiano-ultima-mrchromebox_20200606.rom"
coreboot_uefi_wizpig="coreboot_tiano-wizpig-mrchromebox_20200606.rom"
#Skylake
coreboot_uefi_asuka="coreboot_tiano-asuka-mrchromebox_20200604.rom"
coreboot_uefi_caroline="coreboot_tiano-caroline-mrchromebox_20200604.rom"
coreboot_uefi_cave="coreboot_tiano-cave-mrchromebox_20200604.rom"
coreboot_uefi_chell="coreboot_tiano-chell-mrchromebox_20200604.rom"
coreboot_uefi_lars="coreboot_tiano-lars-mrchromebox_20200604.rom"
coreboot_uefi_sentry="coreboot_tiano-sentry-mrchromebox_20200604.rom"
#KabyLake
coreboot_uefi_atlas="coreboot_tiano-atlas-mrchromebox_20200604.rom"
coreboot_uefi_eve="coreboot_tiano-eve-mrchromebox_20200604.rom"
coreboot_uefi_fizz="coreboot_tiano-fizz-mrchromebox_20200604.rom"
coreboot_uefi_nami="coreboot_tiano-nami-mrchromebox_20200604.rom"
coreboot_uefi_nautilus="coreboot_tiano-nautilus-mrchromebox_20200604.rom"
coreboot_uefi_nocturne="coreboot_tiano-nocturne-mrchromebox_20200604.rom"
coreboot_uefi_rammus="coreboot_tiano-rammus-mrchromebox_20200604.rom"
coreboot_uefi_soraka="coreboot_tiano-soraka-mrchromebox_20200604.rom"

#Stoneyridge
coreboot_uefi_aleena="coreboot_tiano-aleena-mrchromebox_20200604.rom"
coreboot_uefi_barla="coreboot_tiano-barla-mrchromebox_20200604.rom"
coreboot_uefi_careena="coreboot_tiano-careena-mrchromebox_20200604.rom"
coreboot_uefi_kasumi="coreboot_tiano-kasumi-mrchromebox_20200604.rom"
coreboot_uefi_liara="coreboot_tiano-liara-mrchromebox_20200604.rom"
coreboot_uefi_treeya="coreboot_tiano-treeya-mrchromebox_20200707.rom"


#RW_LEGACY payloads
seabios_link="seabios-link-mrchromebox_20180912.bin"
seabios_hswbdw_box="seabios-hswbdw_box-mrchromebox_20180912.bin"
seabios_hswbdw_book="seabios-hswbdw_book-mrchromebox_20180912.bin"
seabios_baytrail="seabios-byt-mrchromebox_20180912.bin"
seabios_braswell="seabios-bsw-mrchromebox_20180912.bin"
seabios_skylake="seabios-skl-mrchromebox_20180912.bin"
seabios_apl="seabios-apl-mrchromebox_20180912.bin"
seabios_kbl="seabios-kbl-mrchromebox_20200223.bin"
seabios_kbl_18="seabios-kbl_18-mrchromebox_20200223.bin"
rwl_altfw_stoney="rwl_altfw_stoney-mrchromebox_20200107.bin"
#rwl_altfw="rwl_altfw-mrchromebox_20200223.bin"


#hsw/bdw headless VBIOS
hswbdw_headless_vbios="hswbdw_vgabios_1040_cbox_headless.dat"

#PXE ROM for Chromeboxes w/RTL81xx ethernet
pxe_optionrom="10ec8168.rom"

#Non-ChromeOS devices
coreboot_uefi_librem13v1="coreboot_tiano-librem13v1-mrchromebox_20200604.rom"
coreboot_uefi_librem13v2="coreboot_tiano-librem13v2-mrchromebox_20200604.rom"
coreboot_uefi_librem13v4="coreboot_tiano-librem13v4-mrchromebox_20200604.rom"
coreboot_uefi_librem15v2="coreboot_tiano-librem15v2-mrchromebox_20200604.rom"
coreboot_uefi_librem15v3="coreboot_tiano-librem15v3-mrchromebox_20200604.rom"
coreboot_uefi_librem15v4="coreboot_tiano-librem15v4-mrchromebox_20200604.rom"
coreboot_uefi_librem_mini="coreboot_tiano-librem_mini-mrchromebox_20200718.rom"

# other
touchpad_eve_fw="rose_v1.1.8546-ee1861e9e.bin"
