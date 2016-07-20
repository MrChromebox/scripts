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
isUnsupported=false
bayTrailHasFullROM=false
firmwareType=""
isStock=true
isFullRom=false
isBootStub=false
hasRwLegacy=false
unlockMenu=false
hasShellball=false

hsw_boxes=('<mccloud>' '<monroe>' '<panther>' '<tricky>' '<zako>');
hsw_books=('<falco>' '<leon>' '<peppy>' '<wolf>');
bdw_boxes=('<guado>' '<rikku>' '<tidus>');
bdw_books=('<auron_paine>' '<auron_yuna>' '<gandof>' '<lulu>' '<samus>');
baytrail=('<banjo>' '<candy>' '<clapper>' '<enguarde>' '<glimmer>' '<gnawty>' '<heli>' '<kip>' '<ninja>' '<orco>' '<quawks>' '<squawks>' '<sumo>' '<swanky>' '<winky>');
baytrail_full_rom=('<enguarde>' '<glimmer>' '<gnawty>' '<ninja>' '<quawks>' '<swanky>');
braswell=('<celes>' '<cyan>' '<edgar>' '<reks>' '<terra>' '<ultima>');
skylake=('<chell>');
 
shellballs=($(printf "%s %s %s %s %s " "${hsw_boxes[@]}" "${hsw_books[@]}" "${bdw_boxes[@]}" "${bdw_books[@]}" "${baytrail[@]}"));

#menu text output
NORMAL=$(echo "\033[m")
MENU=$(echo "\033[36m") #Blue
NUMBER=$(echo "\033[33m") #yellow
FGRED=$(echo "\033[41m")
RED_TEXT=$(echo "\033[31m")
GRAY_TEXT=$(echo "\033[1;30m")
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
    read -p "Press [Enter] to return to the main menu."
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
#list available drives, excluding internal HDD and root device
rootdev="/dev/sda"
if [ "$(which rootdev)" ]; then
    rootdev=$(rootdev -d -s)
fi  
eval usb_devs="($(fdisk -l 2> /dev/null | grep -v 'Disk /dev/sda' | grep -v "Disk $rootdev" | grep 'Disk /dev/sd' | awk -F"/dev/sd|:" '{print $2}'))"
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
        [[ "${rootdev}" =~ "mmcblk" ]] && part_num="p${part_num}"  
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
    curl -s -L -O "${util_source}"/cbfstool.tar.gz
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
    cd /tmp

    curl -s -L -O "${util_source}"/flashrom.tar.gz
    if [ $? -ne 0 ]; then 
        echo_red "Error downloading flashrom; cannot proceed."
        #restore working dir
        cd ${working_dir}
        return 1
    fi
    tar -zxf flashrom.tar.gz
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

    curl -s -L -O "${util_source}"/gbb_utility.tar.gz
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
device=$(dmidecode -s system-product-name | tr '[:upper:]' '[:lower:]' | awk 'NR==1{print $1}')
if [[ $? -ne 0 || "${device}" = "" ]]; then
    echo_red "Unable to determine Chromebox/book model; cannot continue."
    return 1
fi
[[ "${hsw_boxes[@]}" =~ "$device" ]] && isHswBox=true
[[ "${bdw_boxes[@]}" =~ "$device" ]] && isBdwBox=true
[[ "${hsw_books[@]}" =~ "$device" ]] && isHswBook=true
[[ "${bdw_books[@]}" =~ "$device" ]] && isBdwBook=true
[[ "${baytrail[@]}" =~ "$device" ]] && isBaytrail=true
[[ "${braswell[@]}" =~ "$device" ]] && isBraswell=true
[[ "${skylake[@]}" =~ "$device" ]] && isSkylake=true
[[ "${baytrail_full_rom[@]}" =~ "$device" ]] && bayTrailHasFullROM=true
[[ "${shellballs[@]}" =~ "$device" ]] && hasShellball=true
[[ "$isHswBox" = true || "$isBdwBox" = true || "$isHswBook" = true || "$isBdwBook" = true || "$isBaytrail" = true \
    || "$isBraswell" = true || "$isSkylake" = true || "$device" = "stumpy" ]] || isUnsupported=true

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
    flashromcmd=/usr/sbin/flashrom
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

#get device firmware info
echo -e "\nGetting device/system info..."
#read entire firmware
${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
if [ $? -ne 0 ]; then 
    echo_red "Failure reading current firmware; cannot proceed."
    return 1;
fi
#break out BOOT_STUB and RW_LEGACY pieces, check for validity
${cbfstoolcmd} bios.bin read -r BOOT_STUB -f bs.tmp >/dev/null 2>&1
if [ $? -ne 0 ]; then
    #non-stock firmware
    isStock=false
    isFullRom=true
else
    #see if BOOT_STUB is stock
    ${cbfstoolcmd} bs.tmp extract -n fallback/vboot -f vb.tmp -m x86 >/dev/null 2>&1
    [[ $? -ne 0 ]] && isBootStub=true
    #check RW_LEGACY
    ${cbfstoolcmd} bios.bin read -r RW_LEGACY -f rwl.tmp >/dev/null 2>&1
    [[ $? -eq 0 ]] && hasRwLegacy=true
fi
#set firmware type
if [[ "$isChromeOS" = true && "$isStock" = true && "$isBootStub" = false  ]]; then
    firmwareType="Stock ChromeOS"
elif [[ "$isBootStub" = true ]]; then
    firmwareType="Stock w/modified BOOT_STUB"
elif [[ "$isFullRom" = true ]]; then
    #get more info
    fwVer=$(dmidecode -s bios-version)
    fwDate=$(dmidecode -s bios-release-date)
    firmwareType="Full ROM ($fwVer $fwDate)"
elif [[ "$isChromeOS" = false && "$hasRwLegacy" = true ]]; then
    firmwareType="Stock w/modified RW_LEGACY"
elif [[ "$isChromeOS" = true && "$isBaytrail" = true && "$hasRwLegacy" = true ]]; then
    firmwareType="Stock w/modified RW_LEGACY"
fi

#get full device info
[ "$isChromeOS" = true ] && _hwid=$(crossystem hwid) || _hwid=${device^^}
case "${_hwid}" in
    #TBD*)           _x='...|Dell 11P' ;;
    ACER_ZGB*)      _x='PNV|Acer AC700 Chromebook||' ;;
    ARKHAM*)        _x='ARM|ASUS OnHub SRT-AC1900 Router||' ;;
    AURON_PAINE*)   _x='BDW|Acer Chromebook 11 (C740)||' ;;
    AURON_YUNA*)    _x='BDW|Acer Chromebook 15 (CB5-571, C910)||' ;;
    BANJO*)         _x='BYT|Acer Chromebook 15 (CB3-531)||' ;;
    BIG*)           _x='ARM|Acer Chromebook 13 (CB5-311)||' ;;
    BLAZE*)         _x='ARM|HP Chromebook 14 G3||' ;;
    BUDDY*)         _x='BDW|Acer Chromebase 24||' ;;
    BUTTERFLY*)     _x='SDB|HP Pavilion Chromebook 14||' ;;
    CANDY*)         _x='BYT|Dell Chromebook 11||' ;;
    CELES*)         _x='BSW|Samsung Chromebook 3||' ;;
    CHELL*)         _x='SKL|HP Chromebook 13 G1||' ;;
    CLAPPER*)       _x='BYT|Lenovo N20/N20P Chromebook||' ;;
    CYAN*)          _x='BSW|OriginsT / Acer Chromebook R11 (C738T)||' ;;
    EDGAR*)         _x='BSW|Acer Chromebook 14 (CB3-431)||' ;;
    ENGUARDE_???-???-??A*)  _x='BYT|CTL N6 Education Chromebook||' ;;
    ENGUARDE_???-???-??B*)  _x='BYT|M&A Chromebook||' ;;
    ENGUARDE_???-???-??C*)  _x='BYT|Senkatel C1101 Chromebook||' ;;
    ENGUARDE_???-???-??D*)  _x='BYT|Edxis Education Chromebook||' ;;
    ENGUARDE_???-???-??E*)  _x='BYT|Lenovo N21 Chromebook||' ;;
    ENGUARDE_???-???-??F*)  _x='BYT|RGS Education Chromebook||' ;;
    ENGUARDE_???-???-??G*)  _x='BYT|Crambo Chromebook||' ;;
    ENGUARDE_???-???-??H*)  _x='BYT|True IDC Chromebook||' ;;
    ENGUARDE_???-???-??I*)  _x='BYT|Videonet Chromebook||' ;;
    ENGUARDE_???-???-??J*)  _x='BYT|eduGear Chromebook R||' ;;
    ENGUARDE_???-???-??K*)  _x='BYT|ASI Chromebook||' ;;
    ENGUARDE*)              _x='BYT|201x|(unknown ENGUARDE)||' ;;
    EXPRESSO_???-???-??A*)  _x='ARM|HEXA Chromebook Pi||' ;;
    EXPRESSO_???-???-??B*)  _x='ARM|Bobicus Chromebook 11||' ;;
    EXPRESSO_???-???-??C*)  _x='ARM|Edxis Chromebook||' ;;
    EXPRESSO*)              _x='ARM|201x|(unknown EXPRESSO)||' ;;
    FALCO*)         _x='HSW|HP Chromebook 14||' ;;
    GANDOF*)        _x='BDW|Toshiba Chromebook 2 CB30/CB35||' ;;
    GLIMMER*)       _x='BYT|Lenovo ThinkPad 11e/Yoga Chromebook||' ;;
    GNAWTY_???-???-??B*) _x='BYT|Acer Chromebook 11/Olay (C735)|0xd091f000|0xd091c000' ;;
    GNAWTY_???-???-??A*) _x='BYT|Acer Chromebook 11 (CB3-111,C730,C730E)|0xd091f000|0xd091c000' ;;
    GNAWTY_???-???-???)  _x='BYT|Acer Chromebook 11 (CB3-111,C730,C730E)|0xd091f000|0xd091c000' ;;
    GNAWTY*)  _x='BYT|Acer Chromebook 11 (CB3-111/131,C730/C730E/C735)|0xd091f000|0xd091c000' ;;
    GUADO*)         _x='BDW|ASUS Chromebox CN62||' ;;
    HELI*)          _x='BYT|Haier Chromebook G2||' ;;
    IEC_MARIO)     _x='PNV|Google Cr-48||' ;;
    JAQ_???-???-???-A*) _x='ARM|Haier Chromebook 11||' ;;
    JAQ_???-???-???-B*) _x='ARM|True IDC Chromebook 11||' ;;
    JAQ_???-???-???-C*) _x='ARM|Xolo Chromebook||' ;;
    JAQ_???-???-???-D*) _x='ARM|Medion Akoya S2013 Chromebook||' ;;
    JAQ*)               _x='ARM|(unknown JAQ)||' ;;
    JERRY_???-???-???-A*) _x='ARM|HiSense Chromebook 11||' ;;
    JERRY_???-???-???-B*) _x='ARM|CTL J2/J4 Chromebook for Education||' ;;
    JERRY_???-???-???-C*) _x='ARM|Poin2 Chromebook 11||' ;;
    JERRY_???-???-???-D*) _x='ARM|eduGear Chromebook K Series||' ;;
    JERRY_???-???-???-E*) _x='ARM|NComputing Chromebook CX100||' ;;
    JERRY*)               _x='ARM|201x|(unknown JERRY)||' ;;
    KIP*)     _x='BYT|HP Chromebook 11 G3/G4||' ;;
    KITTY*)         _x='ARM|Acer Chromebase' ;;
    LEON*)          _x='HSW|Toshiba CB30/CB35 Chromebook||' ;;
    LINK*)          _x='IVB|Google Chromebook Pixel||' ;;
    LULU*)          _x='BDW|Dell Chromebook 13 7310||' ;;
    LUMPY*)         _x='SDB|Samsung Chromebook Series 5 550||' ;;
    MCCLOUD*)       _x='HSW|Acer Chromebox CXI||' ;;
    MICKEY*)        _x='ARM|ASUS Chromebit CS10||' ;;
    MIGHTY_???-???-???-A*) _x='ARM|Haier Chromebook 11e||' ;;
    MIGHTY_???-???-???-B*) _x='ARM|Nexian Chromebook||' ;;
    MIGHTY_???-???-???-D*) _x='ARM|eduGear Chromebook M Series||' ;;
    MIGHTY_???-???-???-E*) _x='ARM|Sector 5 E1 Rugged Chromebook||' ;;
    MIGHTY_???-???-???-F*) _x='ARM|Viglen Chromebook 11||' ;;
    MIGHTY_???-???-???-G*) _x='ARM|PCmerge Chromebook PCM-116E||' ;;
    MIGHTY_???-???-???-H*) _x='ARM|Lumos Education Chromebook||' ;;
    MIGHTY_???-???-???-I*) _x='ARM|MEDION Chromebook S2015||' ;;
    MIGHTY*)               _x='ARM|(unknown MIGHTY)||' ;;
    MINNIE*)        _x='ARM|ASUS Chromebook Flip C100PA||' ;;
    MONROE*)        _x='HSW|LG Chromebase||' ;;
    NINJA*)         _x='BYT|AOpen Chromebox Commercial|0xd081f000|0xd081c000' ;;
    ORCO*)          _x='BYT|Lenovo Ideapad 100S Chromebook||' ;;
    PAINE*)         _x='BDW|Acer Chromebook 11 (C740)||' ;;
    PANTHER*)       _x='HSW|ASUS Chromebox CN60||' ;;
    PARROT*)        _x='SDB|Acer C7 / C710 Chromebook||' ;;
    PEPPY*)         _x='HSW|Acer C720, C720P Chromebook||' ;;
    PIT*)           _x='ARM|Samsung Chromebook 2 (XE503C12)||' ;;
    PI*)            _x='ARM|Samsung Chromebook 2 (XE503C32)||' ;;
    QUAWKS*)        _x='BYT|ASUS Chromebook C300||' ;;
    REKS*)          _x='BSW|Lenovo N22 Chromebook||' ;;
    RIKKU*)         _x='BDW|Acer Chromebox CXI2||' ;;
    SAMS_ALEX*)     _x='PNV|Samsung Chromebook Series 5||' ;;
    SAMUS*)         _x='BDW|Google Chromebook Pixel||' ;;
    SKATE*)         _x='ARM|HP Chromebook 11 G2||' ;;
    SNOW*)          _x='ARM|Samsung Chromebook||' ;;
    SPEEDY*)        _x='ARM|ASUS Chromebook C201||' ;;
    SPRING*)        _x='ARM|HP Chromebook 11 G1||' ;;
    SQUAWKS*)       _x='BYT|ASUS Chromebook C200||' ;;
    STOUT*)         _x='IVB|Lenovo Thinkpad X131e Chromebook||' ;;
    STUMPY*)        _x='SDB|Samsung Chromebox Series 3||' ;;
    SUMO*)          _x='BYT|AOpen Chromebase Commercial||' ;;
    SWANKY*)        _x='BYT|Toshiba Chromebook 2 CB30/CB35|0xd071f000|0xd071c000' ;;
    TERRA13*)       _x='BSW|ASUS Chromebook C300SA||' ;;
    TERRA*)         _x='BSW|ASUS Chromebook C202SA||' ;;
    TIDUS*)         _x='BDW|Lenovo ThinkCentre Chromebox||' ;;
    TRICKY*)        _x='HSW|Dell Chromebox||' ;;
    ULTIMA*)        _x='BSW|Lenovo ThinkPad 11e/Yoga Chromebook (G3)||' ;;
    WHIRLWIND*)     _x='ARM|TP-Link OnHub TGR1900 Router||' ;;
    WINKY*)         _x='BYT|Samsung Chromebook 2 (XE500C12)||' ;;
    WOLF*)          _x='HSW|Dell Chromebook 11||' ;;
    YUNA*)          _x='BDW|Acer Chromebook 15 (CB5-571, C910)||' ;;
    ZAKO*)          _x='HSW|HP Chromebox CB1/G1/for Meetings||' ;;
    #*)              _='|||' ;;
esac

deviceCpuType=`echo $_x | cut -d\| -f1`
deviceDesc=`echo $_x | cut -d\| -f2`
emmcAddr=`echo $_x | cut -d\| -f3`
sdcardAddr=`echo $_x | cut -d\| -f4-`

## CPU family, Processor core, other distinguishing characteristic
case "$deviceCpuType" in
ARM) deviceCpuType="ARM" ;;
PNV) deviceCpuType="Intel Pineview" ;;
SDB) deviceCpuType="Intel SandyBridge" ;;
IVB) deviceCpuType="Intel IvyBridge" ;;
HSW) deviceCpuType="Intel Haswell" ;;
BYT) deviceCpuType="Intel BayTrail" ;;
BDW) deviceCpuType="Intel Broadwell" ;;
BSW) deviceCpuType="Intel Braswell" ;;
SKL) deviceCpuType="Intel Skylake" ;;
#*)   deviceCpuType="(unrecognized)" ;;
esac

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
