#!/bin/bash
#

# shellcheck disable=SC2164

#misc globals
usb_devs=""
num_usb_devs=0
usb_device=""
isChromeOS=true
isChromiumOS=false
isCloudready=false
flashromcmd=""
flashrom_params=""
flashrom_programmer="-p internal"
cbfstoolcmd=""
gbbutilitycmd=""
preferUSB=false
isHswBox=false
isBdwBox=false
isHswBook=false
isBdwBook=false
isHsw=false
isBdw=false
isByt=false
isBsw=false
isSkl=false
isSnbIvb=false
isApl=false
isKbl=false
isGlk=false
isStr=false
isWhl=false
isCml=false
isCmlBox=false
isCmlBook=false
isPco=false
isCzn=false
isMdn=false
isJsl=false
isTgl=false
isAdl=false
isAdlN=false
isUnsupported=false
firmwareType=""
isStock=true
isFullRom=false
isBootStub=false
isUEFI=false
hasRwLegacy=false
unlockMenu=false
hasUEFIoption=false
hasShellball=false
wpEnabled=false
hasLAN=false
hasCR50=false
kbl_use_rwl18=false
useAltfwStd=false

snb_ivb=('butterfly' 'link' 'lumpy' 'parrot' 'stout' 'stumpy')
hsw_boxes=('mccloud' 'panther' 'tricky' 'zako')
hsw_books=('falco' 'leon' 'monroe' 'peppy' 'wolf')
bdw_boxes=('guado' 'rikku' 'tidus')
bdw_books=('auron_paine' 'auron_yuna' 'buddy' 'gandof' 'lulu' 'samus')
baytrail=('banjo' 'candy' 'clapper' 'enguarde' 'glimmer' 'gnawty' 'heli' \
	'kip' 'ninja' 'orco' 'quawks' 'squawks' 'sumo' 'swanky' 'winky')
braswell=('banon' 'celes' 'cyan' 'edgar' 'kefka' 'reks' 'relm' \
	'setzer' 'terra' 'ultima' 'wizpig')
skylake=('asuka' 'caroline' 'cave' 'chell' 'lars' 'lili' 'sentry')
apl=('astronaut' 'babymega' 'babytiger' 'blacktip' 'blue' 'bruce' 'coral' \
	'electro' 'epaulette' 'lava' 'nasher' 'nasher360' 'pyro' 'rabbid'  'reef' \
	'robo' 'robo360' 'sand' 'santa' 'snappy' 'whitetip')
kbl_boxes=('bleemo' 'endeavour' 'excelsior' 'fizz' 'jax' 'kench' 'sion' 'teemo' 'wukong')
kbl_rwl_20=('akali' 'bard' 'ekko' 'eve' 'nami' 'nautilus' \
	'pantheon' 'sona' 'soraka' 'syndra' 'vayne')
kbl_rwl_18=('atlas' 'karma' 'leona' 'nocturne' 'rammus' 'shyvana')
kbl=($(printf "%s " "${kbl_boxes[@]}" "${kbl_rwl_20[@]}" "${kbl_rwl_18[@]}"))
glk=('ampton' 'apel' 'apele' 'bloog' 'blooglet' 'blooguard' 'blorb' 'bluebird' 'bobba' \
	'bobba360' 'casta' 'dood' 'droid' 'dorp' 'fleex' 'foob' 'foob360' 'garg' \
	'garg360' 'garfour' 'glk' 'glk360' 'grabbiter' 'laser' 'laser14' 'lick' \
	'meep' 'mimrock' 'nospike' 'octopus' 'orbatrix' 'phaser' 'phaser360' \
	'phaser360s' 'sparky' 'sparky360' 'vorticon' 'vortininja')
whl=('arcada' 'sarien')
cml_boxes=('ambassador' 'dooly' 'duffy' 'faffy' 'kaisa' 'noibat' 'puff' 'wyvern')
cml_books=('akemi' 'dragonair' 'drallion' 'dratini' 'hatch' 'helios' 'jinlon' 'kindred' 'kled' \
		   'kohaku' 'nightfury')
cml=($(printf "%s " "${cml_boxes[@]}" "${cml_books[@]}"))
jsl=('beetley' 'blipper' 'bookem' 'boten' 'botenflex' 'bugzzy' 'cret' 'cret360' \
	 'drawcia' 'drawlat' 'drawman' 'drawper' 'galith' 'galith360' 'gallop' 'galnat' 'galnat360' \
	 'galtic' 'galtic360' 'kracko' 'kracko360' 'landia' 'landrid' 'lantis' 'madoo' 'magister' \
	 'maglet' 'maglia' 'maglith' 'magma' 'magneto' 'magolor' 'magpie' 'metaknight' 'pasara' \
	 'pirette' 'pirika' 'sasuke' 'storo' 'storo360')
tgl=('chronicler' 'collis' 'copano' 'delbin' 'drobit' 'eldrid' 'elemi' 'lillipup' 'lindar' \
	 'voema' 'volet' 'volta' 'voxel')
adl=('anahera' 'brya' 'banshee' 'kano' 'crota' 'crota360' 'felwinter' 'gimble' 'mithrax' \
	 'osiris' 'primus' 'redrix' 'taeko' 'taniks' 'volmar' 'zavala' \
	'constitution' 'gladios' 'kinox' 'kuldax' 'lisbon' 'moli')
adl_n=('craask' 'craaskbowl' 'craaskvin' 'craasneto' 'joxer' 'joxero' 'nereid' 'nirwin' 'nivviks' \
	 'pujjo' 'pujjoflex' 'pujjoteen' 'pujjoteen15w' 'xivu' 'xivu360' 'yaviks' 'yavikso')

str=('aleena' 'barla' 'careena' 'grunt' 'kasumi' 'liara' 'treeya' 'treeya360')
pco=('berknip' 'dirinboz' 'ezkinil' 'gumboz' 'jelboz360' 'morphius' 'vilboz' 'woomax')
czn=('dewatt' 'guybrush' 'nipperkin')
mdn=('crystaldrift' 'frostflow' 'markarth' 'skyrim' 'whiterun')

purism=('librem13v1' 'librem13v2' 'librem13v4' 'librem15v2' 'librem15v3' 'librem15v4' \
		'librem_mini' 'librem_mini_v2' 'librem_14');

UEFI_ROMS=($(printf "%s " "${hsw_boxes[@]}" "${hsw_books[@]}" "${bdw_boxes[@]}" \
	"${bdw_books[@]}" "${baytrail[@]}" "${snb_ivb[@]}" "${braswell[@]}" \
	"${skylake[@]}" "${kbl[@]}" "${purism[@]}" "${str[@]}" "${cml[@]}" \
	"${glk[@]}" "${apl[@]}" "${tgl[@]}" "${jsl[@]}" "${adl[@]}" "${adl_n[@]}" \
	"${pco[@]}" "${czn[@]}" "${mdn[@]}" ))
shellballs=($(printf "%s " \
	"${skylake[@]}" 'atlas' 'eve' 'nautilus' 'nocturne' 'pantheon' 'sona' 'soraka' \
	'teemo' 'sion' 'vayne' 'careena' 'liara' 'akemi' 'kohaku' 'barla' 'babytiger' \
	'dratini' 'rabbid' 'blooglet' 'shyvana' 'leona'))
eol_devices=($(printf "%s " "${hsw_boxes[@]}" "${hsw_books[@]}" "${bdw_boxes[@]}" \
		"${bdw_books[@]}" "${baytrail[@]}" "${snb_ivb[@]}" "${braswell[@]}" "${skylake[@]}"))

#menu text output
NORMAL=$(echo "\033[m")
MENU=$(echo "\033[36m") #Blue
NUMBER=$(echo "\033[33m") #yellow
FGRED=$(echo "\033[41m")
RED_TEXT=$(echo "\033[31m")
GRAY_TEXT=$(echo "\033[1;30m")
GREEN_TEXT=$(echo "\033[1;32m")
ENTER_LINE=$(echo "\033[33m")

function echo_red()
{
echo -e "\E[0;31m$1"
echo -e '\e[0m'
}

function echo_green()
{
echo -e "\E[0;32m$1"
echo -e '\e[0m'
}

function echo_yellow()
{
echo -e "\E[1;33m$1"
echo -e '\e[0m'
}

function exit_red()
{
	echo_red "$@"
	read -rep "Press [Enter] to return to the main menu."
}

function die()
{
	echo_red "$@"
	exit 1
}


####################
# list USB devices #
####################
function list_usb_devices()
{
	stat -c %N /sys/block/sd* 2>/dev/null | grep usb | cut -f1 -d ' ' | sed "s/[']//g;s|/sys/block|/dev|" > /tmp/usb_block_devices
	eval usb_devs="($(cat  /tmp/usb_block_devices))"
	[ "$usb_devs" != "" ] || return 1
	echo -e "\nDevices available:\n"
	num_usb_devs=0
	for dev in "${usb_devs[@]}"
	do
	((num_usb_devs+=1))
	vendor=$(udevadm info --query=all --name=${dev#"/dev/"} | grep -E "ID_VENDOR=" | awk -F"=" '{print $2}')
	model=$(udevadm info --query=all --name=${dev#"/dev/"} | grep -E "ID_MODEL=" | awk -F"=" '{print $2}')
	sz=$(fdisk -l 2> /dev/null | grep "Disk ${dev}" | awk '{print $3}')
	echo -n "$num_usb_devs)"
	if [ -n "${vendor}" ]; then
		echo -n " ${vendor}"
	fi
	if [ -n "${model}" ]; then
		echo -n " ${model}"
	fi
	echo -e " (${sz} GB)"
	done
	echo -e ""
	return 0
}


################
# Get cbfstool #
################
function get_cbfstool()
{
	if [ ! -f ${cbfstoolcmd} ]; then
		working_dir=$(pwd)
		if [[ "$isChromeOS" = false && "$isChromiumOS" = false ]]; then
			cd /tmp
		else
			#have to use partition 12 on rootdev due to noexec restrictions
			rootdev=$(rootdev -d -s)
			[[ "${rootdev}" =~ "mmcblk" || "${rootdev}" =~ "nvme" ]] && part_pfx="p" || part_pfx=""
			part_num="${part_pfx}12"
			boot_mounted=$(mount | grep "${rootdev}""${part_num}")
			if [ "${boot_mounted}" = "" ]; then
				#mount boot
				mkdir /tmp/boot >/dev/null 2>&1
				mount "$(rootdev -d -s)""${part_num}" /tmp/boot
				if [ $? -ne 0 ]; then
					echo_red "Error mounting boot partition; cannot proceed."
					return 1
				fi
			fi
			# clear recovery logs which use valuable space
			rm -rf /tmp/boot/recovery* 2>/dev/null
			#create util dir
			mkdir /tmp/boot/util 2>/dev/null
			cd /tmp/boot/util
		fi

		#echo_yellow "Downloading cbfstool utility"
		$CURL -sLO "${util_source}cbfstool.tar.gz"
		if [ $? -ne 0 ]; then
			echo_red "Error downloading cbfstool; cannot proceed."
			#restore working dir
			cd ${working_dir}
			return 1
		fi
		tar -zxf cbfstool.tar.gz --no-same-owner
		if [ $? -ne 0 ]; then
			echo_red "Error extracting cbfstool; cannot proceed."
			#restore working dir
			cd ${working_dir}
			return 1
		fi
		#set +x
		chmod +x cbfstool
		#restore working dir
		cd ${working_dir}
	fi
	return 0
}


################
# Get flashrom #
################
function get_flashrom()
{
	if [ ! -f "${flashromcmd}" ]; then
		working_dir=$(pwd)
	
		if [[ "$isChromeOS" = false && "$isChromiumOS" = false ]]; then
			cd /tmp
		else
			#have to use partition 12 (27 for cloudready) on rootdev due to noexec restrictions
			rootdev=$(rootdev -d -s)
			[[ "${rootdev}" =~ "mmcblk" || "${rootdev}" =~ "nvme" ]] && part_pfx="p" || part_pfx=""
			[[ "$isCloudready" = "true" && -b ${rootdev}${part_pfx}27 ]] \
					&& part_num="${part_pfx}27" || part_num="${part_pfx}12"
			boot_mounted=$(mount | grep "${rootdev}""${part_num}")
			if [ "${boot_mounted}" = "" ]; then
				#mount boot
				mkdir /tmp/boot >/dev/null 2>&1
				mount "$(rootdev -d -s)""${part_num}" /tmp/boot
				if [ $? -ne 0 ]; then
					echo_red "Error mounting boot partition; cannot proceed."
					return 1
				fi
			fi
			# clear recovery logs which use valuable space
			rm -rf /tmp/boot/recovery* 2>/dev/null
			#create util dir
			mkdir /tmp/boot/util 2>/dev/null
			cd /tmp/boot/util
		fi

		if [[ "$isChromeOS" = true ]]; then
			#needed to avoid dependencies not found on older ChromeOS
			$CURL -sLo "flashrom.tar.gz" "${util_source}flashrom_old.tar.gz"
		else
			$CURL -sLo "flashrom.tar.gz" "${util_source}flashrom_cros_libpci37_20231014.tar.gz"
		fi
		if [[ $? -ne 0 ]]; then
			echo_red "Error downloading flashrom; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		
		if ! tar -zxf flashrom.tar.gz --no-same-owner; then
			echo_red "Error extracting flashrom; cannot proceed."
			#restore working dir
			cd "${working_dir}"
			return 1
		fi
		#set +x
		chmod +x flashrom

		#restore working dir
		cd "${working_dir}"
	fi
	# append programmer type
	flashromcmd="${flashromcmd} ${flashrom_programmer}"
	return 0
}


###################
# Get gbb_utility #
###################
function get_gbb_utility()
{
	if [ ! -f ${gbbutilitycmd} ]; then
		working_dir=$(pwd)
		cd /tmp

		$CURL -sLO "${util_source}gbb_utility.tar.gz"
		if [ $? -ne 0 ]; then
			echo_red "Error downloading gbb_utility; cannot proceed."
			#restore working dir
			cd ${working_dir}
			return 1
		fi
		tar -zxf gbb_utility.tar.gz
		if [ $? -ne 0 ]; then
			echo_red "Error extracting gbb_utility; cannot proceed."
			#restore working dir
			cd ${working_dir}
			return 1
		fi
		#set +x
		chmod +x gbb_utility
		#restore working dir
		cd ${working_dir}
	fi
	return 0
}


################
# Prelim Setup #
################

function prelim_setup()
{

# Must run as root
[ "$(whoami)" = "root" ] || die "You need to run this script as root; use 'sudo bash <script name>'"

# Can't run from a VM/container
[[ "$(cat /etc/hostname 2>/dev/null)" = "penguin" ]] && die "This script cannot be run from a ChromeOS Linux container; you must use a VT2 terminal as directed per https://mrchromebox.tech/#fwscript"

#must be x86_64
[ "$(uname -m)"  = 'x86_64' ] \
	|| die "This script only supports 64-bit OS on Intel-based devices; ARM devices are not supported."

#check for required tools
which dmidecode > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo_red "Required package 'dmidecode' not found; cannot continue.  Please install and try again."
	return 1
fi
which tar > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo_red "Required package 'tar' not found; cannot continue.  Please install and try again."
	return 1
fi
which md5sum > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo_red "Required package 'md5sum' not found; cannot continue.  Please install and try again."
	return 1
fi


#get device name
device=$(dmidecode -s system-product-name | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g' | awk 'NR==1{print $1}')
if [[ $? -ne 0 || "${device}" = "" ]]; then
	echo_red "Unable to determine Chromebox/book model; cannot continue."
	echo_red "It's likely you are using an unsupported ARM-based ChromeOS device,\nonly Intel-based devices are supported at this time."
	return 1
fi

#check if running under ChromeOS / ChromiumOS
if [ -f /etc/lsb-release ]; then
	if ! grep -q "Chrome OS" /etc/lsb-release; then
		isChromeOS=false
	fi
	if grep -q "neverware" /etc/lsb-release; then
		isCloudready=true
	fi
	if grep -q "Chromium OS" /etc/lsb-release; then
		isChromiumOS=true
	fi
else
	isChromeOS=false
	isChromiumOS=false
fi

if [[ "$isChromeOS" = true || "$isChromiumOS" = true ]]; then
	#disable power mgmt
	initctl stop powerd > /dev/null 2>&1
	#set cmds
	#check if we need to use a newer flashrom which supports output to log file (-o)
	flashromcmd=$(which flashrom)
	if ! ${flashromcmd} -V -o /dev/null > /dev/null 2>&1 || [[ -d /sys/firmware/efi ]]; then
		flashromcmd=/tmp/boot/util/flashrom
	fi
	cbfstoolcmd=/tmp/boot/util/cbfstool
	gbbutilitycmd=$(which gbb_utility)
else
	#set cmds
	flashromcmd=/tmp/flashrom
	cbfstoolcmd=/tmp/cbfstool
	gbbutilitycmd=/tmp/gbb_utility
fi

#start with a known good state
cleanup

#get required tools
echo -e "\nDownloading required tools..."

if ! get_cbfstool; then
	echo_red "Unable to download cbfstool utility; cannot continue"
	return 1
fi


if ! get_gbb_utility; then
	echo_red "Unable to download gbb_utility utility; cannot continue"
	return 1
fi


if ! get_flashrom; then
	echo_red "Unable to download flashrom utility; cannot continue"
	return 1
fi

# unload Intel SPI driver if loaded, causes issues with flashrom
rmmod spi_intel_platform >/dev/null 2>&1

#get device firmware info
echo -e "\nGetting device/system info..."
if grep -q -i Intel /proc/cpuinfo; then
	#try reading only BIOS region
	if ${flashromcmd} --ifd -i bios -r /tmp/bios.bin > /tmp/flashrom.log 2>&1; then
		flashrom_params="--ifd -i bios"
	else
		#read entire firmware
		${flashromcmd} -r /tmp/bios.bin > /tmp/flashrom.log 2>&1
	fi
else
	#read entire firmware
	${flashromcmd} -r /tmp/bios.bin > /tmp/flashrom.log 2>&1
fi

if [ $? -ne 0 ]; then
	echo_red "\nFlashrom is unable to read current firmware; cannot continue:"
	if [[ "$isChromeOS" = "false" ]]; then
		if [ -f /tmp/flashrom.log ]; then
			cat /tmp/flashrom.log
			echo ""
		fi
	fi
	echo_red "You may need to add 'iomem=relaxed' to your kernel parameters,\nor trying running from a Live USB with a more permissive kernel (eg, Ubuntu 23.04+)."
	echo_red "See https://www.flashrom.org/FAQ for more info."
	return 1;
fi

# firmware date/version
fwVer=$(dmidecode -s bios-version)
fwDate=$(dmidecode -s bios-release-date)

# check firmware type
if [[ "$fwVer" = "Google_"* ]]; then
  # stock firmware
  isStock=true
  firmwareType="Stock ChromeOS"
  # check BOOT_STUB
  if grep "BOOT_STUB" /tmp/layout >/dev/null 2>&1; then
	if ! ${cbfstoolcmd} /tmp/bios.bin print -r BOOT_STUB 2>/dev/null | grep -e "vboot" >/dev/null 2>&1 ; then
		[[ "${device^^}" != "LINK" ]] && firmwareType="Stock w/modified BOOT_STUB"
	fi
  fi
  # check RW_LEGACY
  if ${cbfstoolcmd} /tmp/bios.bin print -r RW_LEGACY 2>/dev/null | grep -e "payload" -e "altfw" >/dev/null 2>&1 ; then
	firmwareType="Stock ChromeOS w/RW_LEGACY"
  fi
else
	# non-stock firmware
	isStock=false
	isFullRom=true
	if [[ -d /sys/firmware/efi ]]; then
		isUEFI=true
		firmwareType="Full ROM / UEFI"
	else
		firmwareType="Full ROM / Legacy"
	fi
fi

#check WP status
echo -e "\nChecking WP state..."

#save SW WP state
${flashromcmd} --wp-status 2>&1 | grep -i -e "enabled" -e "protection mode: hardware" >/dev/null
[[ $? -eq 0 ]] && swWp="enabled" || swWp="disabled"
#test disabling SW WP to see if HW WP enabled
${flashromcmd} --wp-disable > /dev/null 2>&1
[[ $? -ne 0 && $swWp = "enabled" ]] && wpEnabled=true
#restore previous SW WP state
[[ ${swWp} = "enabled" ]] && ${flashromcmd} --wp-enable > /dev/null 2>&1

# disable SW WP and reboot if needed
if [[ "$isChromeOS" = true &&  "${wpEnabled}" != "true" &&  "${swWp}" = "enabled" ]]; then
	# prompt user to disable swWP and reboot
	echo_yellow "\nWARNING: your device currently has software write-protect enabled.\n
If you plan to flash the UEFI firmware, you must first disable it and reboot before flashing.
Would you like to disable sofware WP and reboot your device?"
	read -rep "Press Y (then enter) to disable software WP and reboot, or just press enter to skip and continue. "
	if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] ; then
		echo -e "\nDisabling software WP..."
		if ! ${flashromcmd} --wp-disable > /dev/null 2>&1; then
			exit_red "\nError disabling software write-protect -- hardware WP is still enabled."; return 1
		fi
		echo -e "\nClearing the WP range(s)..."
		if ! ${flashromcmd} --wp-range 0 0 > /dev/null 2>&1; then
			# use new command format as of commit 99b9550
			if ! ${flashromcmd} --wp-range 0,0 > /dev/null 2>&1; then
   				#re-run to output error
       				${flashromcmd} --wp-range 0,0
				exit_red "\nError clearing software write-protect range."; return 1
			fi
		fi
		echo_green "\nSoftware WP disabled, rebooting in 5s"
		reboot
		# ensure we don't show the main menu while the system processes the reboot signal
		die
	fi
fi

#get full device info
if [[ "$isChromeOS" = true && ! -d /sys/firmware/efi ]]; then
	_hwid=$(crossystem hwid | sed 's/X86//g' | sed 's/ *$//g' | sed 's/ /_/g')
	boardName=$(crossystem hwid | sed 's/X86//g' | sed 's/ *$//g'| awk 'NR==1{print $1}' | cut -f 1 -d'-')
	device=${boardName,,}
elif echo "$firmwareType" | grep -e "Stock" -e "LEGACY"; then
	# Stock + RW_LEGACY: read HWID from GBB
	_hwid=$($gbbutilitycmd --get --hwid /tmp/bios.bin | sed -E 's/X86 ?//g' | cut -f 2 -d' ')
	boardName=${_hwid^^}
 	device=${boardName,,}
else
	_hwid=${device^^}
	boardName=${device^^}
fi

case "${_hwid}" in
	AKALI*)                 _x='KBL|Acer Chromebook 13 / Spin 13' ; device="nami";;
	AKEMI*)                 _x='CML|Lenovo Ideapad Flex 5 Chromebook' ;;
	ALEENA*)                _x='STR|Acer Chromebook 315' ;;
	AMBASSADOR*)            _x='CML|CTL Meet Compute System GQE15C'; device="ambassador";;
	AMPTON*)                _x='GLK|Asus Chromebook Flip C214/C234' ;;
	ANAHERA*)               _x='ADL|HP Elite c640 14 inch G3 Chromebook'; device="anahera" ;;
	APELE*)                 _x='GLK|Asus Chromebook CX1101CMA' ; device="apel";;
	APEL*)                  _x='GLK|Asus Chromebook Flip C204' ;;
	ARCADA*)                _x='WHL|Dell Latitude 5300' ; device="sarien";;
	ASTRONAUT*)             _x='APL|Acer Chromebook 11 (C732*)' ;;
	ASUKA*)                 _x='SKL|Dell Chromebook 13 (3380)' ;;
	ATLAS*)                 _x='KBL|Google Pixelbook Go' ;;
	AURON_PAINE*)           _x='BDW|Acer Chromebook 11 (C740)' ;;
	AURON_YUNA*)            _x='BDW|Acer Chromebook 15 (CB5-571, C910)' ;;
	BABYMEGA*)              _x='APL|Asus Chromebook C223NA' ;;
	BABYTIGER*)             _x='APL|Asus Chromebook C523NA' ;;
	BANJO*)                 _x='BYT|Acer Chromebook 15 (CB3-531)' ;;
	BANON*)                 _x='BSW|Acer Chromebook 15 (CB3-532)' ;;
	BANSHEE*)               _x='ADL|Framework Chromebook' ;;
	BARD*)                  _x='KBL|Acer Chromebook 715 (CB715)' ; device="nami";;
	BARLA*)                 _x='STR|HP Chromebook 11A G6 EE' ;;
	BERKNIP*)               _x='PCO|HP Pro c645 Chromebook Enterprise' ; device='berknip' ;;
	BLACKTIP*)              _x='APL|White Label Chrombook' ; device="blacktip";;
	BLEEMO*)                _x='KBL|Asus Chromebox 3 / CN65 (Core i7)' ; device="fizz";;
	BEETLEY*)               _x='JSL|Lenovo Flex 3i/3i-15 Chromebook' ;;
	BLIPPER*)               _x='JSL|Lenovo 3i-15 Chromebook	';;
	BLOOGLET*)              _x='GLK|HP Chromebook 14a';;
	BLOOGUARD*)             _x='GLK|HP Chromebook x360 14a/14b';;
	BLOOG*)                 _x='GLK|HP Chromebook x360 12b';;
	BLORB*)                 _x='GLK|Acer Chromebook 315';;
	BLUEBIRD*)              _x='GLK|Samsung Chromebook 4' ;;
	BLUE*)                  _x='APL|Acer Chromebook 15 [CB315-1H*]' ;;
	BOBBA360*)              _x='GLK|Acer Chromebook Spin 311/511' ;;
	BOBBA*)                 _x='GLK|Acer Chromebook 311' ;;
	BOOKEM*)                _x='JSL|Lenovo 100e Chromebook Gen 3' ;;
	BOTENFLEX*)             _x='JSL|Lenovo Flex 3i/3i-11 Chromebook' ;;
	BOTEN*)                 _x='JSL|Lenovo 500e Chromebook Gen 3' ;;
	BRUCE*)                 _x='APL|Acer Chromebook Spin 15 [CP315]' ;;
	BUDDY*)                 _x='BDW|Acer Chromebase 24' ;;
	BUGZZY*)                _x='JSL|Samsung Galaxy Chromebook 2 360' ;;
	BUTTERFLY*)             _x='SNB|HP Pavilion Chromebook 14' ;;
	CANDY*)                 _x='BYT|Dell Chromebook 11' ;;
	CAREENA*)               _x='STR|HP Chromebook 14' ;;
	CAROLINE*)              _x='SKL|Samsung Chromebook Pro' ;;
	CASTA*)                 _x='GLK|Samsung Chromebook 4+';;
	CAVE*)                  _x='SKL|ASUS Chromebook Flip C302' ;;
	CELES*)                 _x='BSW|Samsung Chromebook 3' ;;
	CHELL*)                 _x='SKL|HP Chromebook 13 G1' ;;
	CHRONICLER*)            _x='TGL|FMV Chromebook 14F' ;;
	CLAPPER*)               _x='BYT|Lenovo N20/N20P Chromebook' ;;
	COLLIS*)                _x='TGL|AAsus Chromebook Flip CX3' ;;
	CONSTITUTION*)          _x='ADL|Google Meet Series Two' ; device="constitution" ;;
	COPANO*)                _x='TGL|Asus Chromebook Flip CX5 (CX5400)' ;;
	CORAL*)                 _x='APL|Incorrectly identified APL Chromebook' ;;
	CRAASKBOWL-GSKT*)       _x='ADN|Acer Chromebook Spin 511'; device="craaskbowl" ;;
	CRAASKVIN-HOWA*)        _x='ADN|Acer Chromebook 511'; device="craaskvin" ;;
	CRAASK-HULX*)           _x='ADN|Acer Chromebook Spin 512'; device="craask" ;;
	CRAASNETO-VHKG*)        _x='ADN|Acer Chromebook 314'; device="craasneto" ;;
	CRET360*)               _x='JSL|Dell Chromebook 3110 2-in-1' ;;
	CRET*)                  _x='JSL|Dell Chromebook 3110' ;;
	CROTA360*)              _x='ADL|Dell Latitude 5430 2-in-1 Chromebook'; device="crota360" ;;
	CROTA*)                 _x='ADL|Dell Latitude 5430 Chromebook'; device="crota" ;;
	CRYSTALDRIFT*)          _x='MDN|TBD Skyrim Chromebook'; device="crystaldrift" ;;
	CYAN*)                  _x='BSW|Acer Chromebook R11 (C738T)' ;;
	DELBIN*)                _x='TGL|ASUS Chromebook Flip CX55/CX5500/C536' ;;
	DEWATT*)                _x='CZN|Acer Chromebook Spin 514'; device="dewatt" ;;
	DIRINBOZ*)              _x='PCO|HP Chromebook 14a' ; device='dirinboz' ;;
	DOOD*)                  _x='GLK|NEC Chromebook Y2';;
	DOOLY*)                 _x='CML|HP Chromebase 21.5' ;;
	DORP*)                  _x='GLK|HP Chromebook 14 G6';;
	DRAGONAIR*)             _x='CML|HP Chromebook x360 14c' ;;
	DRALLION*)              _x='CML|Dell Latitude 7410 Chromebook Enterprise' ; device="drallion";;
	DRATINI*)               _x='CML|HP Pro c640 Chromebook' ;;
	DRAWCIA*)               _x='JSL|HP Chromebook x360 11 G4 EE' ;;
	DRAWLAT*)               _x='JSL|HP Chromebook 11 G9 EE' ;;
	DRAWMAN*)               _x='JSL|HP Chromebook 14 G7' ;;
	DRAWPER*)               _x='JSL|HP Fortis 14 G10 Chromebook' ;;
	DROBIT*)                _x='TGL|ASUS Chromebook CX9 (CX9400)' ;;
	DROID*)                 _x='GLK|Acer Chromebook 314';;
	DUFFY*)                 _x='CML|ASUS Chromebox 4' ;;
	EDGAR*)                 _x='BSW|Acer Chromebook 14 (CB3-431)' ;;
	EKKO*)                  _x='KBL|Acer Chromebook 714 (CB714)' ; device="nami";;
	ELDRID*)                _x='TGL|HP Chromebook x360 14c' ;;
	ELECTRO*)               _x='APL|Acer Chromebook Spin 11 (R751T)' ;;
	ELEMI*)                 _x='TGL|HP Pro c640 G2 Chromebook' ;;
	ENDEAVOUR*)             _x='KBL|Google Meet Series One' ; device="endeavour";;
	ENGUARDE_???-???-??A*)  _x='BYT|CTL N6 Education Chromebook' ;;
	ENGUARDE_???-???-??B*)  _x='BYT|M&A Chromebook' ;;
	ENGUARDE_???-???-??C*)  _x='BYT|Senkatel C1101 Chromebook' ;;
	ENGUARDE_???-???-??D*)  _x='BYT|Edxis Education Chromebook' ;;
	ENGUARDE_???-???-??E*)  _x='BYT|Lenovo N21 Chromebook' ;;
	ENGUARDE_???-???-??F*)  _x='BYT|RGS Education Chromebook' ;;
	ENGUARDE_???-???-??G*)  _x='BYT|Crambo Chromebook' ;;
	ENGUARDE_???-???-??H*)  _x='BYT|True IDC Chromebook' ;;
	ENGUARDE_???-???-??I*)  _x='BYT|Videonet Chromebook' ;;
	ENGUARDE_???-???-??J*)  _x='BYT|eduGear Chromebook R' ;;
	ENGUARDE_???-???-??K*)  _x='BYT|ASI Chromebook' ;;
	ENGUARDE*)              _x='BYT|(multiple device matches)' ;;
	EPAULETTE*)             _x='APL|UNK Acer Chromebook ' ;;
	EVE*)                   _x='KBL|Google Pixelbook' ;;
	EXCELSIOR-URAR*)        _x='KBL|Asus Google Meet kit (KBL)'; device="fizz" ;;
	EZKINIL*)               _x='PCO|Acer Chromebook Spin 514' ; device='ezkinil' ;;
	FAFFY*)                 _x='CML|ASUS Fanless Chromebox' ;;
	FALCO*)                 _x='HSW|HP Chromebook 14' ;;
	FELWINTER*)             _x='ADL|ASUS Chromebook Flip CX5(CX5601)'; device="felwinter" ;;
	FIZZ)                   _x='KBL|TBD KBL Chromebox' ;;
	FLEEX*)                 _x='GLK|Dell Chromebook 3100';;
	FOOB*)                  _x='GLK|CTL Chromebook VX11/VT11T';;
	FROSTFLOW*)             _x='MDN|ASUS Chromebook CM34 Flip'; device="frostflow" ;;
	GALITH360*)             _x='JSL|ASUS Chromebook CX1500FKA' ;;
	GALITH*)                _x='JSL|ASUS Chromebook CX1500CKA' ;;
	GALLOP*)                _x='JSL|ASUS Chromebook CX1700CKA' ;;
	GALNAT360*)             _x='JSL|ASUS Chromebook Flip CX1102' ;;
	GALNAT*)                _x='JSL|ASUS Chromebook CX1102' ;;
	GALTIC360*)             _x='JSL|ASUS Chromebook CX1400FKA' ;;
	GALTIC*)                _x='JSL|ASUS Chromebook CX1' ;;
	GANDOF*)                _x='BDW|Toshiba Chromebook 2 (2015) CB30/CB35' ;;
	GARFOUR*)               _x='GLK|CTL Chromebook NL81/NL81T';;
	GARG360*)               _x='GLK|CTL Chromebook NL71T/TW/TWB';;
	GARG*)                  _x='GLK|CTL Chromebook NL71/CT/LTE';;
	GIMBLE*)                _x='ADL|HP Chromebook x360 14c-cd0'; device="gimble" ;;
	GLADIOS*)               _x='ADL|HP Chromebox Enterprise G4'; device="gladios" ;;
	GLIMMER*)               _x='BYT|Lenovo ThinkPad 11e/Yoga Chromebook' ;;
	GLK360*)                _x='GLK|Acer Chromebook Spin 311';;
	GLK*)                   _x='GLK|Acer Chromebook 311';;
	GNAWTY*)                _x='BYT|Acer Chromebook 11 (CB3-111/131,C730/C730E/C735)' ;;
	GRABBITER*)             _x='GLK|Dell Chromebook 3100 2-in-1';;
	GUADO*)                 _x='BDW|ASUS Chromebox 2 / CN62' ;;
	GUMBOZ*)                _x='PCO|HP Chromebook x360 14a' ; device='gumboz' ;;
	GUYBRUSH*)              _x='CZN|Guybrush Baseboard Chromebook'; device="guybrush" ;;
	HELIOS*)                _x='CML|ASUS Chromebook Flip C436FA' ;;
	HELI*)                  _x='BYT|Haier Chromebook G2' ;;
	JAX*)                   _x='KBL|AOpen Chromebox Commercial 2' ; device="fizz";;
	JELBOZ360*)             _x='PCO|ASUS Chromebook Flip CM1 (CM1400)'; device="jelboz360" ;;
	JINLON*)                _x='CML|HP Elite c1030 Chromebook / HP Chromebook x360 13c';;
	JOXERO*)                _x='ADN|TBD'; device="joxero" ;;
	JOXER*)                 _x='ADN|TBD'; device="joxer" ;;
	KAISA*)                 _x='CML|Acer Chromebox CXI4' ;;
	KANO*)                  _x='ADL|Acer Chromebook Spin 714 [CP714-1WN]'; device="kano" ;;
	KARMA*)                 _x='KBL|Acer Chromebase 24I2' ;;
	KASUMI*)                _x='STR|Acer Chromebook 311' ; device="kasumi";;
	KEFKA*)                 _x='BSW|Dell Chromebook 11 (3180,3189)' ;;
	KENCH*)                 _x='KBL|HP Chromebox G2' ; device="fizz";;
	KINDRED*)               _x='CML|Acer Chromebook 712 (C871)' ;;
	KINOX*)                 _x='ADL|Lenovo ThinkCentre M60q Chromebox'; device="kinox" ;;
	KIP*)                   _x='BYT|HP Chromebook 11 G3/G4, 14 G4' ;;
	KLED*)                  _x='CML|Acer Chromebook Spin 713 (CP713-2W)' ;;
	KOHAKU*)                _x='CML|Samsung Galaxy Chromebook' ;;
	KRACKO360-BLXA*)        _x='JSL|CTL Chromebook NL72T' ;;
	KRACKO360*)             _x='JSL|LG Chromebook 11TC50Q/11TQ50Q' ;;
	KRACKO*)                _x='JSL|CTL Chromebook NL72' ;;
	KULDAX*)                _x='ADL|ASUS Chromebox 5 [CN67]'; device="kuldax" ;;
	LANDIA*)                _x='JSL|HP Chromebook x360 14a' ;;
	LANDRID*)               _x='JSL|HP Chromebook 15a' ;;
	LANTIS*)                _x='JSL|HP Chromebook 14a' ;;
	LARS_???-???-???-?3?*)  _x='SKL|Acer Chromebook 11 (C771, C771T)' ;;
	LARS*)                  _x='SKL|Acer Chromebook 14 for Work' ;;
	LASER14*)               _x='GLK|Lenovo Chromebook S340 / IdeaPad 3';;
	LASER*)                 _x='GLK|Lenovo Chromebook C340';;
	LAVA*)                  _x='APL|Acer Chromebook Spin 11 CP311' ;;
	LEONA*)                 _x='KBL|Asus Chromebook C425TA' ;;
	LEON*)                  _x='HSW|Toshiba CB30/CB35 Chromebook' ;;
	LIARA*)                 _x='STR|Lenovo 14e Chromebook' ;;
	LIBREM_13_V1)           _x='BDW|Purism Librem 13 v1' ; device="librem13v1";;
	LIBREM13V1)             _x='BDW|Purism Librem 13 v1' ;;
	LIBREM_13_V2)           _x='SKL|Purism Librem 13 v2' ; device="librem13v2";;
	LIBREM13V2)             _x='SKL|Purism Librem 13 v2' ;;
	LIBREM_13_V3)           _x='SKL|Purism Librem 13 v3' ; device="librem13v2";;
	LIBREM13V3)             _x='SKL|Purism Librem 13 v3' ;;
	LIBREM_13_V4)           _x='KBL|Purism Librem 13 v4' ; device="librem13v4";;
	LIBREM13V4)             _x='KBL|Purism Librem 13 v4' ;;
	LIBREM_14)              _x='CML|Purism Librem 14' ; device="librem_14";;
	LIBREM_15_V2)           _x='BDW|Purism Librem 15 v2' ; device="librem15v2";;
	LIBREM15V2)             _x='BDW|Purism Librem 15 v2' ;;
	LIBREM_15_V3)           _x='SKL|Purism Librem 15 v3' ; device="librem15v3";;
	LIBREM15V3)             _x='SKL|Purism Librem 15 v3' ;;
	LIBREM_15_V4)           _x='KBL|Purism Librem 15 v4' ; device="librem15v4";;
	LIBREM15V4)             _x='KBL|Purism Librem 15 v4' ;;
	LIBREM_MINI)            _x='WHL|Purism Librem Mini' ; device="librem_mini";;
	LIBREM_MINI_V2)         _x='CML|Purism Librem Mini v2' ; device="librem_mini_v2";;
	LICK*)                  _x='GLK|Lenovo Ideapad 3 Chromebook' ;;
	LILLIPUP*)              _x='TGL|Lenovo IdeaPad Flex 5i Chromebook' ; device="lillipup";;
	LINDAR-EDFZ*)           _x='TGL|Lenovo 5i-14 Chromebook' ; device="lindar";;
	LINDAR-LCDF*)           _x='TGL|Lenovo Slim 5 Chromebook' ; device="lindar";;
	LINDAR*)                _x='TGL|Lenovo Slim 5/5i/Flex 5i Chromebook' ; device="lindar";;
	LINK*)                  _x='IVB|Google Chromebook Pixel 2013' ;;
	LISBON*)                _x='ADL|CTL Chromebox CBx3'; device="lisbon" ;;
	LULU*)                  _x='BDW|Dell Chromebook 13 (7310)' ;;
	MADOO*)                 _x='JSL|HP Chromebook x360 14b' ;;
	MAGISTER*)              _x='JSL|Acer Chromebook Spin 314' ;;
	MAGLET*)                _x='JSL|Acer Chromebook 512 (C852)' ;;
	MAGLIA*)                _x='JSL|Acer Chromebook Spin 512' ;;
	MAGLITH*)               _x='JSL|Acer Chromebook 511' ;;
	MAGMA*)                 _x='JSL|Acer Chromebook 315' ;;
	MAGNETO-BWYB*)          _x='JSL|Acer Chromebook 314' ; device="magneto" ;;
	MAGNETO-SGGB*)          _x='JSL|Packard Bell Chromebook 314' ; device="magneto" ;;
	MAGOLOR*)               _x='JSL|Acer Chromebook Spin 511 [R753T]' ;;
	MAGPIE*)                _x='JSL|Acer Chromebook 317 [CB317-1H]' ;;
	MARKARTH*)              _x='MDN|Acer Chromebook Plus 514'; device="markarth" ;;
	METAKNIGHT*)            _x='JSL|NEC Chromebook Y3' ;;
	MITHRAX-HKVS*)          _x='ADL|ASUS Chromebook CX34 Flip (CX3401)' ; device="mithrax" ;;
	MITHRAX-ISVS*)          _x='ADL|Asus Chromebook Vibe CX34 Flip (CX3401)' ; device="mithrax" ;;
	LUMPY*)                 _x='SNB|Samsung Chromebook Series 5 550' ;;
	MCCLOUD*)               _x='HSW|Acer Chromebox CXI' ;;
	MEEP*)                  _x='GLK|HP Chromebook x360 11 G2 EE' ;;
	MIMROCK*)               _x='GLK|HP Chromebook 11 G7 EE' ;;
	MOLI*)                  _x='ADL|Acer Chromebox CXI5'; device="moli" ;;
	MONROE*)                _x='HSW|LG Chromebase' ;;
	MORPHIUS*)              _x='PCO|Lenovo ThinkPad C13 Yoga Chromebook'; device='morphius'  ;;
	NAMI*)                  _x='KBL|NAMI Chromebook (multi)' ; device="nami";;
	NAUTILUS*)              _x='KBL|Samsung Chromebook Plus V2' ;;
	NASHER360*)             _x='APL|Dell Chromebook 11 2-in-1 5190' ;;
	NASHER*)                _x='APL|Dell Chromebook 11 5190' ;;
	NEREID*)                _x='ADN|TBD'; device="nereid" ;;
	NIGHTFURY*)             _x='CML|Samsung Galaxy Chromebook 2' ;;
	NINJA*)                 _x='BYT|AOpen Chromebox Commercial' ;;
	NIPPERKIN*)             _x='CZN|HP Elite c645 G2 Chroembook'; device="nipperkin" ;;
	NIRWIN*)                _x='ADN|TBD'; device="nirwin" ;;
	NIVVIKS*)               _x='ADN|TBD'; device="nivviks" ;;
	NOCTURNE*)              _x='KBL|Google Pixel Slate' ;;
	NOIBAT*)                _x='CML|HP Chromebox G3' ;;
	NOSPIKE*)               _x='GLK|ASUS Chromebook C424';;
	ORCO*)                  _x='BYT|Lenovo Ideapad 100S Chromebook' ;;
	ORBATRIX*)              _x='GLK|Dell Chromebook 3400';;
	OSIRIS*)                _x='ADL|Acer Chromebook 516 GE [CBG516-1H]'; device="osiris" ;;
	PAINE*)                 _x='BDW|Acer Chromebook 11 (C740)' ; device="auron_paine";;
	PANTHEON*)              _x='KBL|Lenovo Yoga Chromebook C630'  ; device="nami";;
	PANTHER*)               _x='HSW|ASUS Chromebox CN60' ;;
	PARROT*)                _x='SNB|Acer C7/C710 Chromebook' ;;
	PASARA*)                _x='JSL|Gateway Chromebook 15' ; device=pasara;;
	PEPPY*)                 _x='HSW|Acer C720/C720P Chromebook' ;;
	PHASER360*)             _x='GLK|Lenovo 300e/500e Chromebook 2nd Gen' ;;
	PHASER*)                _x='GLK|Lenovo 100e Chromebook 2nd Gen' ;;
	PIRETTE-LLJI*)          _x='JSL|Axioo Chromebook P11' ; device="pirette" ;;
	PIRETTE-NGVJ*)          _x='JSL|SPC Chromebook Z1 Mini' ; device="pirette" ;;
	PIRETTE-RVKU*)          _x='JSL|CTL Chromebook PX11E' ; device="pirette" ;;
	PIRETTE-UBKE*)          _x='JSL|Zyrex Chromebook M432-2' ; device="pirette" ;;
	PIRETTE*)               _x='JSL|White Label Pirette Chromebook' ; device="pirette" ;;
	PIRIKA-BMAD*)           _x='JSL|CTL Chromebook PX14E/PX14EX/PX14EXT' ; device="pirika" ;;
	PIRIKA-NPXS*)           _x='JSL|Axioo Chromebook P14' ; device="pirika" ;;
	PIRIKA-XAJY*)           _x='JSL|Gateway Chromebook 14' ; device="pirika" ;;
	PRIMUS*)                _x='ADL|Lenovo ThinkPad C14 Gen 1 Chromebook'; device="primus" ;;
	PUJJOFLEX*)             _x='ADN|Lenovo IdeaPad Flex 3i Chromebook'; device="pujjoflex" ;;
	PUJJOTEEN*-CZPM*)       _x='ADN|Lenovo 14e Chromebook Gen 3'; device="pujjoteen" ;;
	PUJJOTEEN*-KCBW*)       _x='ADN|Lenovo Ideapad Slim 3i Chromebook'; device="pujjoteen15w" ;;
	PUJJO-DCCV*)            _x='ADN|Lenovo Flex 3i Chromebook 12"'; device="pujjo" ;;
	PUJJO-KTLR*)            _x='ADN|Lenovo 500e Yoga Chromebook Gen 4'; device="pujjo" ;;
	PYRO*)                  _x='APL|Lenovo Thinkpad 11e/Yoga Chromebook (G4)' ;;
	QUAWKS*)                _x='BYT|ASUS Chromebook C300' ;;
	RABBID*)                _x='APL|ASUS Chromebook C423' ;;
	RAMMUS*)                _x='KBL|Asus Chromebook C425/C433/C434' ;;
	REDRIX*)                _x='ADL|HP Elite Dragonfly Chromebook'; device="redrix" ;;
	REEF_???-C*)            _x='APL|ASUS Chromebook C213NA' ;;
	REEF*)                  _x='APL|Acer Chromebook Spin 11 (R751T)' ; device="electro";;
	REKS_???-???-???-B*)    _x='BSW|2016|Lenovo N42 Chromebook' ;;
	REKS_???-???-???-C*)    _x='BSW|2017|Lenovo N23 Chromebook (Touch)';;
	REKS_???-???-???-D*)    _x='BSW|2017|Lenovo N23 Chromebook' ;;
	REKS_???-???-???-*)     _x='BSW|2016|Lenovo N22 Chromebook' ;;
	REKS*)                  _x='BSW|2016|(unknown REKS)' ;;
	RELM_???-B*)            _x='BSW|CTL NL61 Chromebook' ;;
	RELM_???-C*)            _x='BSW|Edxis Education Chromebook' ;;
	RELM_???-F*)            _x='BSW|Mecer V2 Chromebook' ;;
	RELM_???-G*)            _x='BSW|HP Chromebook 11 G5 EE' ;;
	RELM_???-H*)            _x='BSW|Acer Chromebook 11 N7 (C731)' ;;
	RELM_???-Z*)            _x='BSW|Quanta OEM Chromebook' ;;
	RELM*)                  _x='BSW|(unknown RELM)' ;;
	RIKKU*)                 _x='BDW|Acer Chromebox CXI2' ;;
	ROBO360*)               _x='APL|Lenovo 500e Chromebook' ;;
	ROBO*)                  _x='APL|Lenovo 100e Chromebook' ;;
	SAMUS*)                 _x='BDW|Google Chromebook Pixel 2015' ;;
	SAND*)                  _x='APL|Acer Chromebook 15 (CB515-1HT)' ;;
	SANTA*)                 _x='APL|Acer Chromebook 11 (CB311-8H)' ;;
	SARIEN*)                _x='WHL|Dell Latitude 5400' ;;
	SASUKE*)                _x='JSL|Samsung Galaxy Chromebook Go' ; device='sasuke';;
	SENTRY*)                _x='SKL|Lenovo Thinkpad 13 Chromebook' ;;
	SETZER*)                _x='BSW|HP Chromebook 11 G5' ;;
	SHYVANA*)               _x='KBL|Asus Chromebook Flip C433/C434' ;;
	SION*)                  _x='KBL|Acer Chromebox CXI3' ; device="fizz";;
	SKYRIM*)                _x='MDN|Skyrim Baseboard Chromebook'; device="skyrim" ;;
	SNAPPY_???-A*)          _x='APL|HP Chromebook x360 11 G1 EE' ;;
	SNAPPY_???-B*)          _x='APL|HP Chromebook 11 G6 EE' ;;
	SNAPPY_???-C*)          _x='APL|HP Chromebook 14 G5' ;;
	SNAPPY*)                _x='APL|HP Chromebook x360 11 G1/11 G6/14 G5' ;;
	SPARKY360*)             _x='GLK|Acer Chromebook Spin 512 (R851TN)' ;;
	SPARKY*)                _x='GLK|Acer Chromebook 512 (C851/C851T)' ;;
	SONA*)                  _x='KBL|HP Chromebook x360 14' ; device="nami";;
	SORAKA*)                _x='KBL|HP Chromebook x2' ;;
	SQUAWKS*)               _x='BYT|ASUS Chromebook C200' ;;
	STORO360*)              _x='JSL|ASUS Chromebook Flip CR1100FKA' ;;
	STORO*)                 _x='JSL|ASUS Chromebook CR1100CKA' ;;
	STOUT*)                 _x='IVB|Lenovo Thinkpad X131e Chromebook' ;;
	STUMPY*)                _x='SNB|Samsung Chromebox Series 3' ;;
	SUMO*)                  _x='BYT|AOpen Chromebase Commercial' ;;
	SWANKY*)                _x='BYT|Toshiba Chromebook 2 (2014) CB30/CB35' ;;
	SYNDRA*)                _x='KBL|HP Chromebook 15 G1' ; device="nami";;
	TAEKO*)                 _x='ADL|Lenovo Lenovo Flex 5i Chromebook 14"'; device="taeko" ;;
	TANIKS*)                _x='ADL|Lenovo IdeaPad Gaming Chromebook 16'; device="taniks" ;;
	TEEMO*)                 _x='KBL|Asus Chromebox 3 / CN65' ; device="fizz";;
	TERRA_???-???-???-A*)   _x='BSW|ASUS Chromebook C202SA' ;;
	TERRA_???-???-???-B*)   _x='BSW|ASUS Chromebook C300SA/C301SA' ;;
	TERRA*)                 _x='BSW|ASUS Chromebook C202SA, C300SA/C301SA' ; device="terra";;
	TIDUS*)                 _x='BDW|Lenovo ThinkCentre Chromebox' ;;
	TREEYA360*)             _x='STR|Lenovo 300e Chromebook 2nd Gen AMD' ; device="treeya";;
	TREEYA*)                _x='STR|Lenovo 100e Chromebook 2nd Gen AMD' ; device="treeya";;
	TRICKY*)                _x='HSW|Dell Chromebox 3010' ;;
	ULTIMA*)                _x='BSW|Lenovo ThinkPad 11e/Yoga Chromebook (G3)' ;;
	VAYNE*)                 _x='KBL|Dell Inspiron Chromebook 14 (7486)'  ; device="nami";;
	VILBOZ360*)             _x='PCO|Lenovo 300e Chromebook Gen 3'; device="vilboz" ;;
	VILBOZ14*)              _x='PCO|Lenovo 14e Chromebook Gen 2'; device="vilboz" ;;
	VILBOZ*)                _x='PCO|Lenovo 100e Chromebook Gen 3'; device="vilboz" ;;
	VOEMA*)                 _x='TGL|Acer Chromebook Spin 514 (CB514-2H)' ;;
	VOLET*)                 _x='TGL|Acer Chromebook 515 (CB515-1W, CB515-1WT)' ;;
	VOLMAR*)                _x='ADL|Acer Chromebook Vero 514'; device="volmar" ;;
	VOLTA*)                 _x='TGL|Acer Chromebook 514 (CB514-1W, CB514-1WT)' ;;
	VORTICON*)              _x='GLK|HP Chromebook 11 G8 EE' ;;
	VORTININJA*)            _x='GLK|HP Chromebook x360 11 G3 EE' ;;
	VOXEL*)                 _x='TGL|Acer Chromebook Spin 713 (CP713-3W)' ;;
	WHITERUN*)              _x='MDN|Dell Latitude 3445 Chromebook'; device="whiterun" ;;
	WHITETIP*)              _x='APL|CTL Chromebook J41/J41T' ;;
	WINKY*)                 _x='BYT|Samsung Chromebook 2 (XE500C12)' ;;
	WIZPIG_???-???-??A*)    _x='BSW|CTL Chromebook J5' ;;
	WIZPIG_???-???-??B*)    _x='BSW|Edugear CMT Chromebook' ;;
	WIZPIG_???-???-??C*)    _x='BSW|Haier Convertible Chromebook 11 C' ;;
	WIZPIG_???-???-??D*)    _x='BSW|Viglen Chromebook 360' ;;
	WIZPIG_???-???-??G*)    _x='BSW|Prowise ProLine Chromebook' ;;
	WIZPIG_???-???-??H*)    _x='BSW|PCMerge Chromebook PCM-116T-432B' ;;
	WIZPIG_???-???-??I*)    _x='BSW|Multilaser M11C Chromebook' ;;
	WIZPIG*)                _x='BSW|(unknown WIZPIG)' ;;
	WOLF*)                  _x='HSW|Dell Chromebook 11' ;;
	WOOMAX*)                _x='PCO|ASUS Chromebook Flip CM5' ; device='woomax' ;;
	WUKONG_???-???-???-??C*) _x='KBL|ViewSonic NMP660 Chromebox' ; device="fizz";;
	WUKONG*)                _x='KBL|CTL Chromebox CBx1' ; device="fizz";;
	WYVERN*)                _x='CML|CTL Chromebox CBx2' ;;
	XIVU360-HRQS*)          _x='ADN|Asus Chroembook CR11 [CR1102F]'; device="xivu360" ;;
	XIVU-YAZN*)             _x='ADN|Asus Chromebook CR11 [CR1102C]'; device="xivu" ;;
	YAVIKSO*)               _x='ADN|TBD'; device="yavikso" ;;
	YAVIKS*)                _x='ADN|HP Chromebook 15.6"'; device="yaviks" ;;
	YUNA*)                  _x='BDW|Acer Chromebook 15 (CB5-571, C910)' ; device="auron_yuna";;
	ZAKO*)                  _x='HSW|HP Chromebox CB1' ;;
	ZAVALA*)                _x='ADL|Acer Chromebook Vero 712'; device="zavala" ;;
	*)                      _x='UNK|ERROR: unknown or unidentifiable device' ;; 
esac

deviceCpuType=$(echo $_x | cut -d\| -f1)
deviceDesc=$(echo $_x | cut -d\| -f2-)

## CPU family, Processor core, other distinguishing characteristic
case "$deviceCpuType" in
SNB) deviceCpuType="Intel SandyBridge" ;;
IVB) deviceCpuType="Intel IvyBridge" ;;
HSW) deviceCpuType="Intel Haswell" ;;
BYT) deviceCpuType="Intel BayTrail" ;;
BDW) deviceCpuType="Intel Broadwell" ;;
BSW) deviceCpuType="Intel Braswell" ;;
SKL) deviceCpuType="Intel Skylake" ;;
APL) deviceCpuType="Intel ApolloLake" ;;
KBL) deviceCpuType="Intel KabyLake" ;;
GLK) deviceCpuType="Intel GeminiLake" ;;
WHL) deviceCpuType="Intel WhiskeyLake" ;;
CML) deviceCpuType="Intel CometLake" ;;
JSL) deviceCpuType="Intel JasperLake" ;;
TGL) deviceCpuType="Intel TigerLake" ;;
ADL) deviceCpuType="Intel AlderLake/RaptorLake-U/P" ;;
ADN) deviceCpuType="Intel AlderLake-N" ;;
STR) deviceCpuType="AMD StoneyRidge" ;;
PCO) deviceCpuType="AMD Picasso" ;;
CZN) deviceCpuType="AMD Cezanne" ;;
MDN) deviceCpuType="AMD Mendocino" ;;
*)   deviceCpuType="(unrecognized)" ;;
esac

[[ "${hsw_boxes[@]}" =~ "$device" ]] && isHswBox=true
[[ "${hsw_books[@]}" =~ "$device" ]] && isHswBook=true
[[  "$isHswBox" = true || "$isHswBook" = true ]] && isHsw=true
[[ "${bdw_boxes[@]}" =~ "$device" ]] && isBdwBox=true
[[ "${bdw_books[@]}" =~ "$device" ]] && isBdwBook=true
[[  "$isBdwBox" = true || "$isBdwBook" = true ]] && isBdw=true
[[ "${baytrail[@]}" =~ "$device" ]] && isByt=true
[[ "${braswell[@]}" =~ "$device" ]] && isBsw=true
[[ "${skylake[@]}" =~ "$device" ]] && isSkl=true
[[ "${snb_ivb[@]}" =~ "$device" ]] && isSnbIvb=true
[[ "${apl[@]}" =~ "$device" ]] && isApl=true
[[ "${kbl_rwl_18[@]}" =~ "$device" ]] && kbl_use_rwl18=true
[[ "${kbl[@]}" =~ "$device" ]] && isKbl=true
[[ "${glk[@]}" =~ "$device" ]] && isGlk=true
[[ "${str[@]}" =~ "$device" ]] && isStr=true
[[ "${whl[@]}" =~ "$device" ]] && isWhl=true
[[ "${cml[@]}" =~ "$device" ]] && isCml=true
[[ "${pco[@]}" =~ "$device" ]] && isPco=true
[[ "${czn[@]}" =~ "$device" ]] && isCzn=true
[[ "${mdn[@]}" =~ "$device" ]] && isMdn=true
[[ "${jsl[@]}" =~ "$device" ]] && isJsl=true
[[ "${tgl[@]}" =~ "$device" ]] && isTgl=true
[[ "${adl[@]}" =~ "$device" ]] && isAdl=true
[[ "${adl_n[@]}" =~ "$device" ]] && isAdlN=true
[[ "${cml_boxes[@]}" =~ "$device" ]] && isCmlBox=true
[[ "${cml_books[@]}" =~ "$device" ]] && isCmlBook=true
[[ "${shellballs[@]}" =~ "${boardName,,}" ]] && hasShellball=true
[[ "${UEFI_ROMS[@]}" =~ "$device" ]] && hasUEFIoption=true
[[ "$isHsw" = true || "$isBdw" = true || "$isByt" = true || "$isBsw" = true \
	|| "$isSkl" = true || "$isSnbIvb" = true || "$isApl" = true \
	|| "$isKbl" = true || "$isStr" = true || "$isWhl" = true \
	|| "$isGlk" = true || "$isCml" = true || "$isPco" = true \
	|| "$isJsl" = true || "$isTgl" = true || "$isAdl" = true \
	|| "$isCzn" = true || "$isMdn" = true || "$isAdlN" = true ]] || isUnsupported=true
[[ "$isHswBox" = true || "$isBdwBox" = true || "${kbl_boxes[@]}" =~ "$device" \
	|| "$device" = "ninja" || "$device" = "buddy" ]] && hasLAN=true
[[ "$isApl" = true || "$isKbl" = true || "$isStr" = true || "$isWhl" = true \
	|| "$isGlk" = true || "$isCml" = true || "$isPco" = true \
	|| "$isJsl" = true || "$isTgl" = true || "$isAdl" = true \
	|| "$isCzn" = true || "$isMdn" = true || "$isAdlN" = true ]] && hasCR50=true
[[ "$device" = "rammus" || "$isGlk" = true ]] && useAltfwStd=true
[[ "${eol_devices[@]}" =~ "$device" ]] && isEOL=true || isEOL=false

# set unsupported if the script fails to identify the platform
# force all menu options disabled
if [[ "$deviceCpuType" = "(unrecognized)" ]] ; then
  isUnsupported=true
  hasUEFIoption=false
fi

return 0
}


###########
# Cleanup #
###########
function cleanup()
{
#remove temp files, unmount temp stuff
if [ -d /tmp/boot/util ]; then
	rm -rf /tmp/boot/util > /dev/null 2>&1
fi
umount /tmp/boot > /dev/null 2>&1
umount /tmp/Storage > /dev/null 2>&1
umount /tmp/System > /dev/null 2>&1
umount /tmp/urfs/proc > /dev/null 2>&1
umount /tmp/urfs/dev/pts > /dev/null 2>&1
umount /tmp/urfs/dev > /dev/null 2>&1
umount /tmp/urfs/sys > /dev/null 2>&1
umount /tmp/urfs > /dev/null 2>&1
umount /tmp/usb > /dev/null 2>&1
}
