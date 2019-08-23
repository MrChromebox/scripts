#!/bin/bash
#


#misc globals
usb_devs=""
num_usb_devs=0
usb_device=""
isChromeOS=true
isChromiumOS=false
isCloudready=false
flashromcmd=""
cbfstoolcmd=""
gbbutilitycmd=""
preferUSB=false
useHeadless=false
addPXE=false
pxeDefault=false
isHswBox=false
isBdwBox=false
isHswBook=false
isBdwBook=false
isBaytrail=false
isBraswell=false
isSkylake=false
isSnbIvb=false
isApl=false
isKbl=false
isGlk=false
isStr=false
isUnsupported=false
firmwareType=""
isStock=true
isFullRom=false
isBootStub=false
isUEFI=false
hasRwLegacy=false
unlockMenu=false
hasUEFIoption=false
hasLegacyOption=false
hasShellball=false
wpEnabled=false
hasLAN=false
hasCR50=false
useRwlMulti=false

hsw_boxes=('mccloud' 'panther' 'tricky' 'zako')
hsw_books=('falco' 'leon' 'monroe' 'peppy' 'wolf')
bdw_boxes=('guado' 'rikku' 'tidus')
bdw_books=('auron_paine' 'auron_yuna' 'buddy' 'gandof' 'lulu' 'samus')
baytrail=('banjo' 'candy' 'clapper' 'enguarde' 'glimmer' 'gnawty' 'heli' \
    'kip' 'ninja' 'orco' 'quawks' 'squawks' 'sumo' 'swanky' 'winky')
braswell=('banon' 'celes' 'cyan' 'edgar' 'kefka' 'reks' 'relm' \
    'setzer' 'terra' 'ultima' 'wizpig')
skylake=('asuka' 'caroline' 'cave' 'chell' 'lars' 'lili' 'sentry')
snb_ivb=('butterfly' 'link' 'lumpy' 'parrot' 'stout' 'stumpy')
apl=('astronaut' 'babymega' 'blacktip' 'coral' 'electro' 'epaulette' 'lava' \
    'nasher'  'pyro' 'rabbid'  'reef'  'robo' 'sand' 'santa' 'snappy')
kbl_boxes=('bleemo' 'fizz' 'kench' 'sion' 'teemo' 'wukong')
kbl=($(printf "%s " "${kbl_boxes[@]}") 'akali' 'eve' 'nami' 'nautilus' \
    'nocturne' 'pantheon' 'rammus' 'shyvana' 'sona' 'soraka' 'syndra' 'vayne')
purism=('librem13v1' 'librem13v2' 'librem13v4' 'librem15v2' 'librem15v3' 'librem15v4');
glk=('ampton' 'apel' 'bobba' 'bobba360' 'bobba' 'meep' 'mimrock' 'octopus' \
    'phaser' 'phaser360' 'phaser360s' 'sparky' 'sparky360')
str=('aleena' 'barla' 'careena' 'grunt' 'katsumi' 'liara')
LegacyROMs=($(printf "%s " "${hsw_boxes[@]}" "${bdw_boxes[@]}" "stumpy"));
UEFI_ROMS=($(printf "%s " "${hsw_boxes[@]}" "${hsw_books[@]}" "${bdw_boxes[@]}" \
    "${bdw_books[@]}" "${baytrail[@]}" "${snb_ivb[@]}" "${braswell[@]}" \
    "${skylake[@]}" "${kbl_boxes[@]}" "${purism[@]}" 'eve' 'nami' 'soraka'))
shellballs=($(printf "%s " "${hsw_boxes[@]}" "${hsw_books[@]}" "${bdw_boxes[@]}" \
    "${bdw_books[@]}" "${baytrail[@]}" "${snb_ivb[@]}" "${braswell[@]}" \
    "${skylake[@]}" 'eve'))

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
    read -ep "Press [Enter] to return to the main menu."
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
#list available drives, excluding internal storage and root/boot device
if [[ -b /dev/mmcblk0 ]]; then
	intStor="/dev/mmcblk0"
elif [[ -b /dev/nvme0n1 ]]; then
	intStor="/dev/nvme0n1"
else intStor="/dev/sda"
fi

rootdev=${intStor}
if [ "$(which rootdev)" ]; then
    rootdev=$(rootdev -d -s)
fi
eval usb_devs="($(fdisk -l 2> /dev/null | grep -v "Disk ${intStor}" \
    | grep -v "Disk $rootdev" | grep 'Disk /dev/sd' | awk -F"/dev/sd|:" '{print $2}'))"
#ensure at least 1 drive available
[ "$usb_devs" != "" ] || return 1
echo -e "\nDevices available:\n"
num_usb_devs=0
for dev in "${usb_devs[@]}"
do
let "num_usb_devs+=1"
vendor=$(udevadm info --query=all --name=sd${dev} | grep -E "ID_VENDOR=" | awk -F"=" '{print $2}')
model=$(udevadm info --query=all --name=sd${dev} | grep -E "ID_MODEL=" | awk -F"=" '{print $2}')
sz=$(fdisk -l 2> /dev/null | grep "Disk /dev/sd${dev}" | awk '{print $3}')
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
        #have to use partition 12 (27 for cloudready) on rootdev due to noexec restrictions
        rootdev=$(rootdev -d -s)
        [[ "$isCloudready" = true ]] && part_num="27" || part_num="12"
        [[ "${rootdev}" =~ "mmcblk" || "${rootdev}" =~ "nvme" ]] && part_num="p${part_num}"
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
        #create util dir
        mkdir /tmp/boot/util 2>/dev/null
        cd /tmp/boot/util
    fi

    #echo_yellow "Downloading cbfstool utility"
    curl -sLO "${util_source}cbfstool.tar.gz"
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
if [ ! -f ${flashromcmd} ]; then
    working_dir=`pwd`
 
    if [[ "$isChromeOS" = false && "$isChromiumOS" = false ]]; then
        cd /tmp
    else
        #have to use partition 12 (27 for cloudready) on rootdev due to noexec restrictions
        rootdev=$(rootdev -d -s)
        [[ "$isCloudready" = true ]] && part_num="27" || part_num="12"
        [[ "${rootdev}" =~ "mmcblk" || "${rootdev}" =~ "nvme" ]] && part_num="p${part_num}"
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
        #create util dir
        mkdir /tmp/boot/util 2>/dev/null
        cd /tmp/boot/util
    fi

    curl -sLO "${util_source}flashrom.tar.gz"
    if [ $? -ne 0 ]; then
        echo_red "Error downloading flashrom; cannot proceed."
        #restore working dir
        cd ${working_dir}
        return 1
    fi
    tar -zxf flashrom.tar.gz --no-same-owner
    if [ $? -ne 0 ]; then
        echo_red "Error extracting flashrom; cannot proceed."
        #restore working dir
        cd ${working_dir}
        return 1
    fi
    #set +x
    chmod +x flashrom
    #restore working dir
    cd ${working_dir}
fi
return 0
}


###################
# Get gbb_utility #
###################
function get_gbb_utility()
{
if [ ! -f ${gbbutilitycmd} ]; then
    working_dir=`pwd`
    cd /tmp

    curl -sLO "${util_source}gbb_utility.tar.gz"
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
    cat /etc/lsb-release | grep "Chrome OS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        isChromeOS=false
    fi
    cat /etc/lsb-release | grep "neverware" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        isCloudready=true
    fi
    cat /etc/lsb-release | grep "Chromium OS" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
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
    ${flashromcmd} -V -o /dev/null > /dev/null 2>&1
    [[ $? -ne 0 ]] && flashromcmd=/tmp/boot/util/flashrom  
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
get_flashrom
if [ $? -ne 0 ]; then
    echo_red "Unable to download flashrom utility; cannot continue"
    return 1
fi
get_cbfstool
if [ $? -ne 0 ]; then
    echo_red "Unable to download cbfstool utility; cannot continue"
    return 1
fi
get_gbb_utility
if [ $? -ne 0 ]; then
    echo_red "Unable to download gbb_utility utility; cannot continue"
    return 1
fi

#get full device info
if [[ "$isChromeOS" = true ]]; then
    _hwid=$(crossystem hwid | sed 's/ /_/g')
    boardName=$(crossystem hwid | awk 'NR==1{print $1}')
else
    _hwid=${device^^}
    boardName=${device^^}
fi

case "${_hwid}" in
    ACER_ZGB*)              _x='PNV|Acer AC700 Chromebook' ;;
    AKALI*)                 _x='KBL|Acer Chromebook 13 / Spin 13' ; device="nami";;
    ALEENA*)                _x='STR|Acer Chromebook 315' ; device="grunt";;
    AMPTON*)                _x='GLK|Asus Chromebook Flip C214' ; device="octopus";;
    APEL*)                  _x='GLK|Asus Chromebook Flip C204' ; device="octopus";;
    ASTRONAUT*)             _x='APL|Acer Chromebook 11 (C732*)' ;;
    ASUKA*)                 _x='SKL|Dell Chromebook 13 (3380)' ;;
    AURON_PAINE*)           _x='BDW|Acer Chromebook 11 (C740)' ;;
    AURON_YUNA*)            _x='BDW|Acer Chromebook 15 (CB5-571, C910)' ;;
    BABYMEGA*)              _x='APL|Asus Chromebook C223NA' ;;
    BANJO*)                 _x='BYT|Acer Chromebook 15 (CB3-531)' ;;
    BANON*)                 _x='BSW|Acer Chromebook 15 (CB3-532)' ;;
    BARLA*)                 _x='STR|HP Chromebook 11A G6 EE' ; device="grunt";;
    BLACKTIP*)              _x='APL|White Label Chrombook' ;;
    BLEEMO*)                _x='KBL|Asus Chromebox 3 / CN65 (Core i7)' ; device="fizz";;
    BOBBA360*)              _x='GLK|Acer Chromebook Spin 511' ;;
    BOBBA*)                 _x='GLK|Acer Chromebook 311' ;;
    BUDDY*)                 _x='BDW|Acer Chromebase 24' ;;
    BUTTERFLY*)             _x='SNB|HP Pavilion Chromebook 14' ;;
    CANDY*)                 _x='BYT|Dell Chromebook 11' ;;
    CAREENA*)               _x='STR|HP Chromebook 14' ; device="grunt";;
    CAROLINE*)              _x='SKL|Samsung Chromebook Pro' ;;
    CAVE*)                  _x='SKL|ASUS Chromebook Flip C302' ;;
    CELES*)                 _x='BSW|Samsung Chromebook 3' ;;
    CHELL*)                 _x='SKL|HP Chromebook 13 G1' ;;
    CLAPPER*)               _x='BYT|Lenovo N20/N20P Chromebook' ;;
    CYAN*)                  _x='BSW|Acer Chromebook R11 (C738T)' ;;
    EDGAR*)                 _x='BSW|Acer Chromebook 14 (CB3-431)' ;;
    ENGUARDE_???-???-??A*)  _x='BYT|CTL N6 Education Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??B*)  _x='BYT|M&A Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??C*)  _x='BYT|Senkatel C1101 Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??D*)  _x='BYT|Edxis Education Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??E*)  _x='BYT|Lenovo N21 Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??F*)  _x='BYT|RGS Education Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??G*)  _x='BYT|Crambo Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??H*)  _x='BYT|True IDC Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??I*)  _x='BYT|Videonet Chromebook' ; device="enguarde";;
    ENGUARDE_???-???-??J*)  _x='BYT|eduGear Chromebook R' ; device="enguarde";;
    ENGUARDE_???-???-??K*)  _x='BYT|ASI Chromebook' ; device="enguarde";;
    ENGUARDE*)              _x='BYT|(multiple device matches)' ;;
    EPAULETTE*)             _x='APL|UNK Acer Chromebook ' ;;
    EVE*)                   _x='KBL|Google Pixelbook' ;;
    FALCO*)                 _x='HSW|HP Chromebook 14' ;;
    FIZZ)                   _x='KBL|TBD KBL Chromebox' ;;
    GANDOF*)                _x='BDW|Toshiba Chromebook 2 (2015) CB30/CB35' ;;
    GLIMMER*)               _x='BYT|Lenovo ThinkPad 11e/Yoga Chromebook' ;;
    GNAWTY*)                _x='BYT|Acer Chromebook 11 (CB3-111/131,C730/C730E/C735)' ;;
    GUADO*)                 _x='BDW|ASUS Chromebox 2 / CN62' ;;
    HELI*)                  _x='BYT|Haier Chromebook G2' ;;
    IEC_MARIO)              _x='PNV|Google Cr-48' ;;
    KASUMI*)                _x='STR|Acer Chromebook 311' ; device="grunt";;
    KEFKA*)                 _x='BSW|Dell Chromebook 11 (3180,3189)' ;;
    KENCH*)                 _x='KBL|HP Chromebox G2' ; device="fizz";;
    KIP*)                   _x='BYT|HP Chromebook 11 G3/G4, 14 G4' ;;
    LARS*)                  _x='SKL|Acer Chromebook 14 for Work' ;;
    LAVA*)                  _x='APL|Acer Chromebook Spin 11 CP311' ;;
    LEON*)                  _x='HSW|Toshiba CB30/CB35 Chromebook' ;;
    LIARA*)                 _x='STR|Lenovo 14e Chromebook' ; device="grunt";;
    LIBREM_13_V1)           _x='BDW|Purism Librem 13 v1' ; device="librem13v1";;
    LIBREM13V1)             _x='BDW|Purism Librem 13 v1' ;;
    LIBREM_13_V2)           _x='SKL|Purism Librem 13 v2' ; device="librem13v2";;
    LIBREM13V2)             _x='SKL|Purism Librem 13 v2' ;;
    LIBREM_13_V3)           _x='SKL|Purism Librem 13 v3' ; device="librem13v2";;
    LIBREM13V3)             _x='SKL|Purism Librem 13 v3' ;;
    LIBREM_13_V4)           _x='KBL|Purism Librem 13 v4' ; device="librem13v4";;
    LIBREM13V4)             _x='KBL|Purism Librem 13 v4' ;;
    LIBREM_15_V2)           _x='BDW|Purism Librem 15 v2' ; device="librem15v2";;
    LIBREM15V2)             _x='BDW|Purism Librem 15 v2' ;;
    LIBREM_15_V3)           _x='SKL|Purism Librem 15 v3' ; device="librem15v3";;
    LIBREM15V3)             _x='SKL|Purism Librem 15 v3' ;;
    LIBREM_15_V4)           _x='KBL|Purism Librem 15 v4' ; device="librem15v4";;
    LIBREM15V4)             _x='KBL|Purism Librem 15 v4' ;;
    LILI*)                  _x='SKL|Acer Chromebook 11 (C771, C771T)' ;;
    LINK*)                  _x='IVB|Google Chromebook Pixel 2013' ;;
    LULU*)                  _x='BDW|Dell Chromebook 13 (7310)' ;;
    LUMPY*)                 _x='SNB|Samsung Chromebook Series 5 550' ;;
    MCCLOUD*)               _x='HSW|Acer Chromebox CXI' ;;
    MEEP*)                  _x='GLK|HP Chromebook x360 11 G2 EE' ; device="octopus";;
    MIMROCK*)               _x='GLK|HP Chromebook 11 G7 EE' ; device="octopus";;
    MONROE*)                _x='HSW|LG Chromebase' ;;
    NAUTILUS*)              _x='KBL|Samsung Chromebook Plus V2' ;;
    NASHER360*)             _x='APL|Dell Chromebook 11 2-in-1 5190' ; device="nasher";;
    NASHER*)                _x='APL|Dell Chromebook 11 5190' ;;
    NINJA*)                 _x='BYT|AOpen Chromebox Commercial' ;;
    NOCTURNE*)              _x='KBL|Google Pixel Slate' ;;
    ORCO*)                  _x='BYT|Lenovo Ideapad 100S Chromebook' ;;
    PAINE*)                 _x='BDW|Acer Chromebook 11 (C740)' ;;
    PANTHEON*)              _x='KBL|Lenovo Yoga Chromebook C630'  ; device="nami";;
    PANTHER*)               _x='HSW|ASUS Chromebox CN60' ;;
    PARROT*)                _x='SNB|Acer C7/C710 Chromebook' ;;
    PEPPY*)                 _x='HSW|Acer C720/C720P Chromebook' ;;
    PHASER360S*)            _x='GLK|Lenovo 500e Chromebook 2nd Gen' ;;
    PHASER360*)             _x='GLK|Lenovo 300e Chromebook 2nd Gen' ;;
    PHASER*)                _x='GLK|Lenovo 100e Chromebook 2nd Gen' ;;
    PYRO*)                  _x='APL|Lenovo Thinkpad 11e/Yoga Chromebook (G4)' ;;
    QUAWKS*)                _x='BYT|ASUS Chromebook C300' ;;
    RABBID*)                _x='APL|ASUS Chromebook C423' ;;
    REEF_???-C*)            _x='APL|ASUS Chromebook C213NA' ; device="reef";;
    REEF*)                  _x='APL|Acer Chromebook Spin 11 (R751T)' ; device="reef";;
    REKS_???-???-???-B*)    _x='BSW|2016|Lenovo N42 Chromebook' ; device="reks";;
    REKS_???-???-???-C*)    _x='BSW|2017|Lenovo N23 Chromebook (Touch)' device="reks";;
    REKS_???-???-???-D*)    _x='BSW|2017|Lenovo N23 Chromebook' device="reks";;
    REKS_???-???-???-*)     _x='BSW|2016|Lenovo N22 Chromebook' device="reks";;
    REKS*)                  _x='BSW|2016|(unknown REKS)' ;;
    RELM_???-B*)            _x='BSW|CTL NL61 Chromebook' ; device="relm";;
    RELM_???-C*)            _x='BSW|Edxis Education Chromebook' ; device="relm";;
    RELM_???-F*)            _x='BSW|Mecer V2 Chromebook' ; device="relm";;
    RELM_???-G*)            _x='BSW|HP Chromebook 11 G5 EE' ; device="relm";;
    RELM_???-H*)            _x='BSW|Acer Chromebook 11 N7 (C731)' ; device="relm";;
    RELM_???-Z*)            _x='BSW|Quanta OEM Chromebook' ; device="relm";;
    RELM*)                  _x='BSW|(unknown RELM)' ; device="relm";;
    RIKKU*)                 _x='BDW|Acer Chromebox CXI2' ;;
    ROBO360*)               _x='APL|Lenovo 500e Chromebook' ; device="robo";;
    ROBO*)                  _x='APL|Lenovo 100e Chromebook' ;;
    SAMS_ALEX*)             _x='PNV|Samsung Chromebook Series 5' ;;
    SAMUS*)                 _x='BDW|Google Chromebook Pixel 2015' ;;
    SAND*)                  _x='APL|Acer Chromebook 15 (CB515-1HT)' ;;
    SANTA*)                 _x='APL|Acer Chromebook 11 (CB311-8H)' ;;
    SENTRY*)                _x='SKL|Lenovo Thinkpad 13 Chromebook' ;;
    SETZER*)                _x='BSW|HP Chromebook 11 G5' ;;
    SHYVANA*)               _x='KBL|Asus Chromebook Flip C434' ; device="rammus";;
    SION*)                  _x='KBL|Acer Chromebox CXI3' ; device="fizz";;
    SNAPPY_???-A*)          _x='APL|HP Chromebook x360 11 G1 EE' ; device="snappy";;
    SNAPPY_???-B*)          _x='APL|HP Chromebook 11 G6 EE' device="snappy";;
    SNAPPY_???-C*)          _x='APL|HP Chromebook 14 G5' device="snappy";;
    SNAPPY*)                _x='APL|(unknown SNAPPY)' device="snappy";;
    SPARKY*)                _x='GLK|Acer Chromebook 512 (C851/C851T)' ;;
    SONA*)                  _x='KBL|HP Chromebook x360 14' ;;
    SORAKA*)                _x='KBL|HP Chromebook x2' ;;
    SQUAWKS*)               _x='BYT|ASUS Chromebook C200' ;;
    STOUT*)                 _x='IVB|Lenovo Thinkpad X131e Chromebook' ;;
    STUMPY*)                _x='SNB|Samsung Chromebox Series 3' ;;
    SUMO*)                  _x='BYT|AOpen Chromebase Commercial' ;;
    SWANKY*)                _x='BYT|Toshiba Chromebook 2 (2014) CB30/CB35' ;;
    SYNDRA*)                _x='KBL|HP Chromebook 15 G1' ; device="nami";;
    TEEMO*)                 _x='KBL|Asus Chromebox 3 / CN65' ; device="fizz";;
    TERRA_???-???-???-A*)   _x='BSW|ASUS Chromebook C202SA' ; device="terra";;
    TERRA_???-???-???-B*)   _x='BSW|ASUS Chromebook C300SA/C301SA' ; device="terra";;
    TERRA*)                 _x='BSW|ASUS Chromebook C202SA, C300SA/C301SA' ; device="terra";;
    TIDUS*)                 _x='BDW|Lenovo ThinkCentre Chromebox' ;;
    TRICKY*)                _x='HSW|Dell Chromebox 3010' ;;
    ULTIMA*)                _x='BSW|Lenovo ThinkPad 11e/Yoga Chromebook (G3)' ;;
    VAYNE*)                 _x='KBL|Dell Inspiron Chromebook 14 (7486)'  ; device="nami";;
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
    WUKONG_???-???-???-??C*) _x='KBL|ViewSonic NMP660 Chromebox' ; device="fizz";;
    WUKONG*)                _x='KBL|CTL Chromebox CBx1' ; device="fizz";;
    YUNA*)                  _x='BDW|Acer Chromebook 15 (CB5-571, C910)' ; device="auron_yuna";;
    ZAKO*)                  _x='HSW|HP Chromebox CB1' ;;
esac

deviceCpuType=`echo $_x | cut -d\| -f1`
deviceDesc=`echo $_x | cut -d\| -f2-`

## CPU family, Processor core, other distinguishing characteristic
case "$deviceCpuType" in
ARM) deviceCpuType="ARM" ;;
PNV) deviceCpuType="Intel Pineview" ;;
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
STR) deviceCpuType="AMD StoneyRidge" ;;
#*)   deviceCpuType="(unrecognized)" ;;
esac

[[ "${hsw_boxes[@]}" =~ "$device" ]] && isHswBox=true
[[ "${bdw_boxes[@]}" =~ "$device" ]] && isBdwBox=true
[[ "${hsw_books[@]}" =~ "$device" ]] && isHswBook=true
[[ "${bdw_books[@]}" =~ "$device" ]] && isBdwBook=true
[[ "${baytrail[@]}" =~ "$device" ]] && isBaytrail=true
[[ "${braswell[@]}" =~ "$device" ]] && isBraswell=true
[[ "${skylake[@]}" =~ "$device" ]] && isSkylake=true
[[ "${snb_ivb[@]}" =~ "$device" ]] && isSnbIvb=true
[[ "${apl[@]}" =~ "$device" ]] && isApl=true
[[ "${kbl[@]}" =~ "$device" ]] && isKbl=true
[[ "${glk[@]}" =~ "$device" ]] && isGlk=true
[[ "${str[@]}" =~ "$device" ]] && isStr=true
[[ "${shellballs[@]}" =~ "$device" ]] && hasShellball=true
[[ "${UEFI_ROMS[@]}" =~ "$device" ]] && hasUEFIoption=true
[[ "${LegacyROMs[@]}" =~ "$device" ]] && hasLegacyOption=true
[[ "$isHswBox" = true || "$isBdwBox" = true || "$isHswBook" = true || "$isBdwBook" = true \
    || "$isBaytrail" = true || "$isBraswell" = true || "$isSkylake" = true || "$isSnbIvb" = "true" \
    || "$isApl" = "true" || "$isKbl" = "true" ]] || isUnsupported=true
[[ "$isHswBox" = true || "$isBdwBox" = true || "${kbl_boxes[@]}" =~ "$device" \
    || "$device" = "ninja" || "$device" = "buddy" ]] && hasLAN=true
[[ "$isKbl" = true || "$isApl" = true ]] && hasCR50=true
[[ "$isStr" = true ]] && useRwlMulti=true

#get device firmware info
echo -e "\nGetting device/system info..."
#read entire firmware
${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo_red "\nUnable to read current firmware; cannot continue."
    echo_red "Either add 'iomem=relaxed' to your kernel parameters,\nor trying running from a Live USB with a more permissive kernel (eg, Ubuntu)."
    echo_red "See https://www.flashrom.org/FAQ for more info."
    return 1;
fi
#break out BOOT_STUB and RW_LEGACY pieces, check for validity
${cbfstoolcmd} bios.bin read -r BOOT_STUB -f bs.tmp >/dev/null 2>&1
if [ $? -eq 0 ]; then
    #see if BOOT_STUB is stock
    ${cbfstoolcmd} bs.tmp extract -n fallback/vboot -f vb.tmp -m x86 >/dev/null 2>&1
    [[ $? -ne 0 && "${device^^}" != "LINK" ]] && isBootStub=true
    #check RW_LEGACY
    ${cbfstoolcmd} bios.bin read -r RW_LEGACY -f rwl.tmp >/dev/null 2>&1
    [[ $? -eq 0 ]] && hasRwLegacy=true
else
    # check 'coreboot' for SKL/KBL/APL
    ${cbfstoolcmd} bios.bin read -r COREBOOT -f cb.tmp >/dev/null 2>&1
    if [[ $? -eq 0 && ( "$isSkylake" = true || "$isApl" = true || "$isKbl" = true) ]]; then
        #check for verstage
        ${cbfstoolcmd} bios.bin extract -n fallback/verstage -f /dev/null -m x86 >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            hasRwLegacy=true
        else
            #non-stock firmware
            isStock=false
            isFullRom=true
        fi
    else
        if [ "$isChromeOS" = false ]; then
        #non-stock firmware
            isStock=false
            isFullRom=true
        fi
    fi
fi
#set firmware type
if [[ "$isChromeOS" = true && "$isStock" = true && "$isBootStub" = false && "$isSkylake" = false ]]; then
    firmwareType="Stock ChromeOS"
elif [[ "$isBootStub" = true ]]; then
    firmwareType="Stock w/modified BOOT_STUB"
elif [[ "$isFullRom" = true ]]; then
    #get more info
    fwVer=$(dmidecode -s bios-version)
    fwDate=$(dmidecode -s bios-release-date)
    if [[ -d /sys/firmware/efi ]]; then
        isUEFI=true
        firmwareType="Full ROM / UEFI ($fwVer $fwDate)"
    else
        firmwareType="Full ROM / Legacy ($fwVer $fwDate)"
    fi
elif [[ "$isChromeOS" = false && "$hasRwLegacy" = true ]]; then
    firmwareType="Stock w/RW_LEGACY support"
elif [[ "$isChromeOS" = true && "$isBaytrail" = true && "$hasRwLegacy" = true ]]; then
    firmwareType="Stock w/RW_LEGACY support"
elif [[ "$isSkylake" = true || "$isKbl" = true ]]; then
    firmwareType="Stock w/RW_LEGACY support"
fi

#check WP status

#save SW WP state
${flashromcmd} --wp-status 2>&1 | grep enabled >/dev/null
[[ $? -eq 0 ]] && swWp="enabled" || swWp="disabled"
#test disabling SW WP to see if HW WP enabled
${flashromcmd} --wp-disable > /dev/null 2>&1
[[ $? -ne 0 ]] && wpEnabled=true
#restore previous SW WP state
[[ ${swWp} = "enabled" ]] && ${flashromcmd} --wp-enable > /dev/null 2>&1

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
