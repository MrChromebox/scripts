#!/bin/bash
#


#####################
# Select LE Version #
#####################
function select_le_version()
{
	LE_version="${LE_version_base}-${LE_version_latest}"
	if [ "$LE_version_latest" != "$LE_version_stable" ]; then
		read -ep "Do you want to install a LibreELEC 9.0 beta version (${LE_version_latest}) ?
It is based on Kodi 18-RC, is reasonably stable, and is the recommended version, but some issues may remain.

If N, the latest stable version of LibreELEC 8.0 ($LE_version_stable) based on Kodi 17.6 will be used. [Y/n] "
		if [[ "$REPLY" == "n" || "$REPLY" == "N" ]]; then
			LE_version="${LE_version_base}-${LE_version_stable}"
			#LE_url=${LE_url_official}
		fi
		echo -e "\n"
	fi	
}


###########################
# Create LE Install Media #
###########################
function create_le_install_media()
{
echo_green "\nCreate LibreELEC Installation Media"
trap le_fail INT TERM EXIT

#check free space on /tmp
free_spc=`df -m /tmp | awk 'FNR == 2 {print $4}'`
[ "$free_spc" > "500" ] || { exit_red "Temp directory has insufficient free space to create LibreELEC install media."; return 1; }

#Install beta version?
select_le_version

read -ep "Connect the USB/SD device (min 512MB) to be used as LibreELEC installation media and press [Enter] to continue.
This will erase all contents of the USB/SD device, so be sure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || { exit_red "No USB devices available to create LibreELEC install media."; return 1; }
read -ep "Enter the number for the device to be used to install LibreELEC: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || { exit_red "Error: Invalid option selected."; return 1; }
usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"

#get LibreELEC
echo_yellow "\nDownloading LibreELEC installer image..."
img_file="${LE_version}.img"
img_url="${LE_url}${img_file}.gz"

cd /tmp
$CURL -Lo ${img_file}.gz $img_url
if [ $? -ne 0 ]; then
	exit_red "Failed to download LibreELEC; check your Internet connection and try again"; return 1
fi

echo_yellow "\nDownload complete; creating install media..."

gunzip -f ${img_file}.gz >/dev/null 2>&1
if [ $? -ne 0 ]; then
	exit_red "Failed to extract LibreELEC download; check your Internet connection and try again"; return 1
fi

dd if=$img_file of=${usb_device} bs=1M conv=fdatasync >/dev/null 2>&1; sync
if [ $? -ne 0 ]; then
	exit_red "Error creating LibreELEC install media."; return 1
fi
trap - INT TERM EXIT
echo_green "
Creation of LibreELEC install media is complete.
Upon reboot, press [ESC] at the boot menu prompt, then select your USB/SD device from the list."

echo_yellow "If you have not already done so, run the 'Install/update: Custom coreboot Firmware' option before reboot."

read -ep "Press [Enter] to return to the main menu."
}

function le_fail() {
trap - INT TERM EXIT
exit_red "\nLibreELEC installation media creation failed; retry with different USB/SD media"; return 1
}


##########################
# Install LE (dual boot) #
##########################
function chrLibreELEC() 
{
echo_green "\nLibreELEC / Dual Boot Install"

target_disk="`rootdev -d -s`"
# Do partitioning (if we haven't already)
ckern_size="`cgpt show -i 6 -n -s -q ${target_disk}`"
croot_size="`cgpt show -i 7 -n -s -q ${target_disk}`"
state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"

max_libreelec_size=$(($state_size/1024/1024/2))
rec_libreelec_size=$(($max_libreelec_size - 1))
# If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]; then
	echo_green "Stage 1: Repartitioning the internal HDD"
	
	# prevent user from booting into legacy until install complete
	crossystem dev_boot_usb=0 dev_boot_legacy=0 > /dev/null 2>&1
	
	while :
	do
		echo "Enter the size in GB you want to reserve for LibreELEC Storage."
		read -ep "Acceptable range is 2 to $max_libreelec_size but $rec_libreelec_size is the recommended maximum: " libreelec_size
		if [ $libreelec_size -ne $libreelec_size 2>/dev/null ]; then
			echo_red "\n\nWhole numbers only please...\n\n"
			continue
		elif [ $libreelec_size -lt 2 -o $libreelec_size -gt $max_libreelec_size ]; then
			echo_red "\n\nThat number is out of range. Enter a number 2 through $max_libreelec_size\n\n"
			continue
		fi
		break
	done
	# We've got our size in GB for ROOT-C so do the math...

	#calculate sector size for rootc
	rootc_size=$(($libreelec_size*1024*1024*2))

	#kernc is always 512mb
	kernc_size=1024000

	#new stateful size with rootc and kernc subtracted from original
	stateful_size=$(($state_size - $rootc_size - $kernc_size))

	#start stateful at the same spot it currently starts at
	stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"

	#start kernc at stateful start plus stateful size
	kernc_start=$(($stateful_start + $stateful_size))

	#start rootc at kernc start plus kernc size
	rootc_start=$(($kernc_start + $kernc_size))

	#Do the real work

	echo_yellow "\n\nModifying partition table to make room for LibreELEC." 
	umount -f /mnt/stateful_partition > /dev/null 2>&1

	# stateful first
	cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}

	# now kernc
	cgpt add -i 6 -b $kernc_start -s $kernc_size -l KERN-C -t "kernel" ${target_disk}

	# finally rootc
	cgpt add -i 7 -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}

	echo_green "Stage 1 complete; after reboot, press CTRL-D and ChromeOS will \"repair\" itself."
	echo_yellow "Afterwards, you must re-download/re-run this script to complete LibreELEC setup."

	read -ep "Press [Enter] to reboot..."
	reboot
	exit
fi

echo_yellow "Stage 1 / repartitioning completed, moving on."
echo_green "\nStage 2: Installing LibreELEC"

#Install beta version?
select_le_version

#target partitions
if [[ "${target_disk}" =~ "mmcblk" ]]; then
  target_rootfs="${target_disk}p7"
  target_kern="${target_disk}p6"
else
  target_rootfs="${target_disk}7"
  target_kern="${target_disk}6"
fi

if mount|grep ${target_rootfs}
then
  LE_install_error "Refusing to continue since ${target_rootfs} is formatted and mounted. Try rebooting"
fi

#format partitions, disable journaling, set labels
mkfs.ext4 -v -m0 -O ^has_journal -L KERN-C ${target_kern} > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to format LE partition(s); reboot and try again"
fi
mkfs.ext4 -v -m0 -O ^has_journal -L ROOT-C ${target_rootfs} > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to format LE partition(s); reboot and try again"
fi
 
#mount partitions
if [ ! -d /tmp/System ]
then
  mkdir /tmp/System
fi
mount -t ext4 ${target_kern} /tmp/System > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to mount LE System partition; reboot and try again"
fi

if [ ! -d /tmp/Storage ]
then
  mkdir /tmp/Storage
fi
mount -t ext4 ${target_rootfs} /tmp/Storage > /dev/null
if [ $? -ne 0 ]; then
	LE_install_error "Failed to format LE Storage partition; reboot and try again"
fi

echo_yellow "\nPartitions formatted and mounted"

echo_yellow "Updating bootloader"

#get/extract syslinux
tar_file="${util_source}${syslinux_version}.tar.bz2"
$CURL -sLo /tmp/Storage/syslinux.tar.bz2 $tar_file 
if [ $? -ne 0 ]; then
	LE_install_error "Failed to download syslinux; check your Internet connection and try again"
fi
cd /tmp/Storage
tar -xpjf syslinux.tar.bz2
if [ $? -ne 0 ]; then
	LE_install_error "Failed to extract syslinux download; reboot and try again"
fi

#install extlinux on LibreELEC kernel partition
cd /tmp/Storage/${syslinux_version}/extlinux/
./extlinux -i /tmp/System/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to install extlinux; reboot and try again"
fi

#create extlinux.conf
echo -e "DEFAULT linux\nPROMPT 0\nLABEL linux\nKERNEL /KERNEL\nAPPEND boot=LABEL=KERN-C disk=LABEL=ROOT-C tty quiet" > /tmp/System/extlinux.conf

#Upgrade/modify existing syslinux install
boot_partition=""
if [[ "${target_disk}" =~ "mmcblk" ]]; then
  boot_partition="${target_disk}p12"
else
  boot_partition="${target_disk}12"
fi


if [ ! -d /tmp/boot ]
then
  mkdir /tmp/boot
fi
if  ! mount | grep /tmp/boot > /dev/null ; then
	mount $boot_partition /tmp/boot > /dev/null
fi
if [ $? -ne 0 ]; then
	LE_install_error "Failed to mount boot partition; reboot and try again"
fi

#create syslinux.cfg
rm -f /tmp/boot/syslinux/* 2>/dev/null
echo -e "DEFAULT LibreELEC\nPROMPT 0\nLABEL LibreELEC\nCOM32 chain.c32\nAPPEND label=KERN-C" > /tmp/boot/syslinux/syslinux.cfg

#copy chain loader files
cp /tmp/Storage/${syslinux_version}/com32/chain/chain.c32 /tmp/boot/syslinux/chain.c32
cp /tmp/Storage/${syslinux_version}/com32/lib/libcom32.c32 /tmp/boot/syslinux/libcom32.c32
cp /tmp/Storage/${syslinux_version}/com32/libutil/libutil.c32 /tmp/boot/syslinux/libutil.c32

#install/update syslinux
cd /tmp/Storage/${syslinux_version}/linux/
rm -f /tmp/boot/ldlinux.* 1>/dev/null 2>&1
./syslinux -i -f $boot_partition -d syslinux
if [ $? -ne 0 ]; then
	LE_install_error "Failed to install syslinux; reboot and try again"
fi

echo_yellow "Downloading LibreELEC"

#get LibreELEC
tar_file="${LE_version}.tar"
tar_url="${LE_url}${tar_file}"
cd /tmp/Storage
$CURL -Lo $tar_file $tar_url
if [ $? -ne 0 ]; then
	LE_install_error "Failed to download LibreELEC; check your Internet connection and try again"
fi
echo_yellow "\nLibreELEC download complete; installing..."
tar -xpf $tar_file
if [ $? -ne 0 ]; then
	LE_install_error "Failed to extract LibreELEC download; check your Internet connection and try again"
fi

#install
cp /tmp/Storage/${LE_version}/target/KERNEL /tmp/System/
cp /tmp/Storage/${LE_version}/target/SYSTEM /tmp/System/

#sanity check file sizes
[ -s /tmp/System/KERNEL ] || LE_install_error "LE KERNEL has file size 0"
[ -s /tmp/System/SYSTEM ] || LE_install_error "LE SYSTEM has file size 0"

#update legacy BIOS
flash_rwlegacy skip_prompt > /dev/null

echo_green "LibreELEC Installation Complete"
read -ep "Press [Enter] to return to the main menu."
}


###################################
# Install GaOS/Ubuntu (dual boot) #
###################################
function chrx() 
{
echo_green "\nUbuntu / Dual Boot Install"
echo_green "Now using reynhout's chrx script - www.chrx.org"

target_disk="`rootdev -d -s`"
# Do partitioning (if we haven't already)
ckern_size="`cgpt show -i 6 -n -s -q ${target_disk}`"
croot_size="`cgpt show -i 7 -n -s -q ${target_disk}`"
state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"

max_ubuntu_size=$(($state_size/1024/1024/2))
rec_ubuntu_size=$(($max_ubuntu_size - 1))
# If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]; then
	
	#update legacy BIOS
	flash_rwlegacy skip_prompt > /dev/null
	
	echo_green "Stage 1: Repartitioning the internal HDD"
	
	while :
	do
		echo "Enter the size in GB you want to reserve for Ubuntu."
		read -ep "Acceptable range is 6 to $max_ubuntu_size  but $rec_ubuntu_size is the recommended maximum: " ubuntu_size
		if [ $ubuntu_size -ne $ubuntu_size 2> /dev/null]; then
			echo_red "\n\nWhole numbers only please...\n\n"
			continue
		elif [ $ubuntu_size -lt 6 -o $ubuntu_size -gt $max_ubuntu_size ]; then
			echo_red "\n\nThat number is out of range. Enter a number 6 through $max_ubuntu_size\n\n"
			continue
		fi
		break
	done
	# We've got our size in GB for ROOT-C so do the math...

	#calculate sector size for rootc
	rootc_size=$(($ubuntu_size*1024*1024*2))

	#kernc is always 512mb
	kernc_size=1024000

	#new stateful size with rootc and kernc subtracted from original
	stateful_size=$(($state_size - $rootc_size - $kernc_size))

	#start stateful at the same spot it currently starts at
	stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"

	#start kernc at stateful start plus stateful size
	kernc_start=$(($stateful_start + $stateful_size))

	#start rootc at kernc start plus kernc size
	rootc_start=$(($kernc_start + $kernc_size))

	#Do the real work

	echo_green "\n\nModifying partition table to make room for Ubuntu." 

	umount -f /mnt/stateful_partition > /dev/null 2>&1

	# stateful first
	cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}

	# now kernc
	cgpt add -i 6 -b $kernc_start -s $kernc_size -l KERN-C -t "kernel" ${target_disk}

	# finally rootc
	cgpt add -i 7 -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}
	
	echo_green "Stage 1 complete; after reboot, press CTRL-D and ChromeOS will \"repair\" itself."
	echo_yellow "Afterwards, you must re-download/re-run this script to complete Ubuntu setup."
	read -ep "Press [Enter] to reboot and continue..."

	cleanup
	reboot
	exit
fi
echo_yellow "Stage 1 / repartitioning completed, moving on."
echo_green "Stage 2: Installing Ubuntu via chrx"

#init vars
ubuntu_package="galliumos"
ubuntu_version="latest"

#select Ubuntu metapackage
validPackages=('<galliumos>' '<ubuntu>' '<kubuntu>' '<lubuntu>' '<xubuntu>' '<edubuntu>');
echo -e "\nEnter the Ubuntu (or Ubuntu-derivative) to install.  Valid options are `echo ${validPackages[*]}`.
If no (valid) option is entered, 'galliumos' will be used."
read -ep "" ubuntu_package	

packageValid=$(echo ${validPackages[*]} | grep "<$ubuntu_package>")
if [[ "$ubuntu_package" = "" || "$packageValid" = "" ]]; then
	ubuntu_package="galliumos"
fi

#select Ubuntu version
useBeta=""
if [ "$ubuntu_package" != "galliumos" ]; then
	validVersions=('<lts>' '<latest>' '<dev>' '<15.10>' '<15.04>' '<14.10>' '<14.04>');
	echo -e "\nEnter the Ubuntu version to install. Valid options are `echo ${validVersions[*]}`. 
If no (valid) version is entered, 'latest' will be used."
	read -ep "" ubuntu_version	

	versionValid=$(echo ${validVersions[*]} | grep "<$ubuntu_version>")
	if [[ "$ubuntu_version" = "" || "$versionValid" = "" ]]; then
		ubuntu_version="latest"
	fi
else
	read -ep "Do you wish use the latest beta version? [Y/n] "
	[[ "$REPLY" != "n" && "$REPLY" != "N" ]] && useBeta="-r nightly"
fi



#Install Kodi?
kodi_install=""
read -ep "Do you wish to install Kodi ? [Y/n] "
if [[ "$REPLY" != "n" && "$REPLY" != "N" ]]; then
	kodi_install="-p kodi"
fi

echo_green "\nInstallation is ready to begin.\nThis is going to take some time, so be patient."

read -ep "Press [Enter] to continue..."
echo -e ""

#Install via chrx
export CHRX_NO_REBOOT=1
$CURL -sLo chrx ${chrx_url}
sh ./chrx -d ${ubuntu_package} -r ${ubuntu_version} -H ChromeBox -y $kodi_install $useBeta

#chrx will end with prompt for user to press enter to reboot
read -ep ""
cleanup;
reboot;
}


####################
# Install LE (USB) #
####################
function LibreELEC_USB() 
{
echo_green "\nLibreELEC / USB Install"

#check free space on /tmp
free_spc=$(df -m /tmp | awk 'FNR == 2 {print $4}')
[ "$free_spc" > "500" ] || { exit_red "Temp directory has insufficient free space to create LibreELEC install media."; return 1; }

#Install beta version?
select_le_version

read -ep "Connect the USB/SD device (min 4GB) to be used and press [Enter] to continue.
This will erase all contents of the USB/SD device, so be sure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || { exit_red "No USB devices available onto which to install LibreELEC."; return 1; }
read -ep "Enter the number for the device to be used for LibreELEC: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || { exit_red "Error: Invalid option selected."; return 1; }
target_disk="/dev/sd${usb_devs[${usb_dev_index}-1]}"

echo_yellow "\nSetting up and formatting partitions..."

# Do partitioning (if we haven't already)
echo -e "o\nn\np\n1\n\n+512M\nn\np\n\n\n\na\n1\nw" | fdisk ${target_disk} >/dev/null 2>&1
partprobe > /dev/null 2>&1

LE_System=${target_disk}1
LE_Storage=${target_disk}2

#format partitions, disable journaling, set labels
mkfs.ext4 -v -m0 -O ^has_journal -L System $LE_System > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to format LE partition(s); reboot and try again"
fi
e2label $LE_System System > /dev/null 2>&1
mkfs.ext4 -v -m0 -O ^has_journal -L Storage $LE_Storage > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to format LE partition(s); reboot and try again"
fi
e2label $LE_Storage Storage > /dev/null 2>&1
 
#mount partitions
if [ ! -d /tmp/System ]; then
  mkdir /tmp/System
fi
mount -t ext4 $LE_System /tmp/System > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to mount LE System partition; reboot and try again"
fi

if [ ! -d /tmp/Storage ]; then
  mkdir /tmp/Storage
fi
mount -t ext4 $LE_Storage /tmp/Storage > /dev/null
if [ $? -ne 0 ]; then
	LE_install_error "Failed to format LE Storage partition; reboot and try again"
fi

echo_yellow "Partitions formatted and mounted; installing bootloader"

#get/extract syslinux
tar_file="${util_source}${syslinux_version}.tar.bz2"
$CURL -sLo /tmp/Storage/syslinux.tar.bz2 $tar_file > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to download syslinux; check your Internet connection and try again"
fi
cd /tmp/Storage
tar -xpjf syslinux.tar.bz2
if [ $? -ne 0 ]; then
	LE_install_error "Failed to extract syslinux download; reboot and try again"
fi

#write MBR
cd /tmp/Storage/${syslinux_version}/mbr/
dd if=./mbr.bin of=${target_disk} bs=440 count=1 > /dev/null 2>&1

#install extlinux on LibreELEC System partition
cd /tmp/Storage/${syslinux_version}/extlinux/
./extlinux -i /tmp/System/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
	LE_install_error "Failed to install extlinux; reboot and try again"
fi

#create extlinux.conf
echo -e "DEFAULT linux\nPROMPT 0\nLABEL linux\nKERNEL /KERNEL\nAPPEND boot=LABEL=System disk=LABEL=Storage tty quiet ssh" > /tmp/System/extlinux.conf

echo_yellow "Downloading LibreELEC"

#get LibreELEC
tar_file="${LE_version}.tar"
tar_url="${LE_url}${tar_file}"
cd /tmp/Storage
$CURL -Lo $tar_file $tar_url
if [ $? -ne 0 ]; then
	LE_install_error "Failed to download LibreELEC; check your Internet connection and try again"
fi
echo_yellow "\nLibreELEC download complete; installing..."
tar -xpf $tar_file
if [ $? -ne 0 ]; then
	LE_install_error "Failed to extract LibreELEC download; check your Internet connection and try again"
fi

#install
cp /tmp/Storage/${LE_version}/target/KERNEL /tmp/System/
cp /tmp/Storage/${LE_version}/target/SYSTEM /tmp/System/

#sanity check file sizes
[ -s /tmp/System/KERNEL ] || LE_install_error "LE KERNEL has file size 0"
[ -s /tmp/System/SYSTEM ] || LE_install_error "LE SYSTEM has file size 0"

#cleanup storage
rm -rf /tmp/Storage/*

#update legacy BIOS
if [ "$isChromeOS" = true ]; then
	flash_rwlegacy skip_prompt #> /dev/null
fi
	
echo_green "LibreELEC USB Installation Complete"
read -ep "Press [Enter] to return to the main menu."
}

function LE_install_error()
{
rm -rf /tmp/Storage > /dev/null 2>&1
rm -rf /tmp/System > /dev/null 2>&1
cleanup
die "Error: $@"

}


#############
# Kodi Menu #
#############
function menu_kodi() {
	clear
	echo -e "${NORMAL}\n ChromeBox Kodi E-Z Setup Script ${script_date} ${NORMAL}"
	echo -e "${NORMAL} (c) Mr Chromebox <mrchromebox@gmail.com> ${NORMAL}"
	echo -e "${MENU}******************************************************${NORMAL}"
	echo -e "${MENU}**${NUMBER}   Device: ${NORMAL}${deviceDesc} (${device^^})"
	echo -e "${MENU}**${NUMBER} CPU Type: ${NORMAL}$deviceCpuType"
	echo -e "${MENU}**${NUMBER}  Fw Type: ${NORMAL}$firmwareType"
	if [ "$wpEnabled" = true ]; then
		echo -e "${MENU}**${NUMBER}    Fw WP: ${RED_TEXT}Enabled${NORMAL}"
	else
		echo -e "${MENU}**${NUMBER}    Fw WP: ${NORMAL}Disabled"
	fi
	echo -e "${MENU}******************************************************${NORMAL}"
	if [ "$isChromeOS" = false ]; then
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}     Dual Boot  (only available in ChromeOS)${NORMAL}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  1)${GRAY_TEXT} Install: ChromeOS + GalliumOS/Ubuntu ${NORMAL}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  2)${GRAY_TEXT} Install: ChromeOS + LibreELEC ${NORMAL}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  3)${GRAY_TEXT} Install: LibreELEC on USB ${NORMAL}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  4)${GRAY_TEXT} Set Boot Options ${NORMAL}"
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  5)${GRAY_TEXT} Update Legacy BIOS (SeaBIOS)${NORMAL}"
		echo -e "${GRAY_TEXT}**${NORMAL}"
	else
		echo -e "${MENU}**${NORMAL}     Dual Boot ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  1)${MENU} Install: ChromeOS + GalliumOS/Ubuntu ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  2)${MENU} Install: ChromeOS + LibreELEC ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  3)${MENU} Install: LibreELEC on USB ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  4)${MENU} Set Boot Options ${NORMAL}"
		echo -e "${MENU}**${NUMBER}  5)${MENU} Update Legacy BIOS (SeaBIOS)${NORMAL}"
		echo -e "${MENU}**${NORMAL}"
	fi
	echo -e "${MENU}**${NORMAL}     Standalone ${NORMAL}"
	if [[ "$hasUEFIoption" = true ]]; then
		echo -e "${MENU}**${NUMBER}  6)${MENU} Install/Update: Custom UEFI Firmware ${NORMAL}"
	else
		echo -e "${GRAY_TEXT}**${GRAY_TEXT}  6)${GRAY_TEXT} Install/Update: Custom UEFI Firmware ${NORMAL}"
	fi
	echo -e "${MENU}**${NUMBER}  7)${MENU} Create LibreELEC Install Media ${NORMAL}"
	echo -e "${MENU}******************************************************${NORMAL}"
	echo -e "${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"
	
	read opt
	
	while [ opt != '' ]
		do
		if [[ $opt = "q" ]]; then 
				exit;
		else
			if [ "$isChromeOS" = true ]; then
				case $opt in
					1)	clear;
						chrx;
						menu_kodi;
						;;
					2)  clear;
						chrLibreELEC;
						menu_kodi;
						;;
					3)	clear;
						LibreELEC_USB;
						menu_kodi;
						;;
					4)	clear;
						set_boot_options Kodi;
						menu_kodi;
						;;
					5)	clear;
						flash_rwlegacy;	
						menu_kodi;
						;;
					*)
						;;
				esac
			fi
			
			case $opt in
				
			6)	clear;
				if [[ "$hasUEFIoption" = true ]]; then
					flash_coreboot useUEFI;
				fi
				menu_kodi;
				;;		
			7) 	clear;
				create_le_install_media;
				menu_kodi;
				;;				
			[rR])  echo -e "\nRebooting...\n";
				cleanup;
				reboot;
				exit;
				;;
				
			[pP])  echo -e "\nPowering off...\n";
				cleanup;
				poweroff;
				exit;
				;;
				
			[qQ])  cleanup;
				exit;
				;;
			\n)	cleanup;
				exit;
				;;
			*)	clear;
				menu_kodi;
				;;
		esac
	fi
	done
}
