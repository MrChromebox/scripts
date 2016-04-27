# ChromeOS firmware and Kodi install scripts
Collection of scripts to install custom firmware (full ROM), update the fimware/legacy boot payload (RW_LEGACY), and install Kodi on supported ChromeOS devices. When run from ChromeOS, these scripts require the Chromebox/book to be in [developer mode](https://www.chromium.org/chromium-os/poking-around-your-chrome-os-device#TOC-Putting-your-Chrome-OS-Device-into-Developer-Mode); some functionality also requires the firmware write-protect screw to be removed, the location of which is [device-specific](https://www.chromium.org/chromium-os/developer-information-for-chrome-os-devices).  Functionality affecting the stock firmware requires these be run from ChromeOS.

&nbsp;

**setup-firmware.sh** allows for the installation of custom firmware (full ROM) and/or an updated legacy boot payload (via either the RW_LEGACY or BOOT_STUB firmware region) on supported ChromeOS devices.

It also includes functionality to set the stock firmware boot flags (via gbb_utility), and to set the device's hardware ID (also via gbb_utility). This script can be used to restore the stock firmware on a Haswell or Broadwell ChromeBox, either from a backup file (on USB) or from a generic recovery image firmware file (which it will download).  If the latter is used, the device-specific VPD (vital product data) is extracted from the running firmware and merged with the generic firmware file, to ensure the device's unique MAC address, serial #, etc are maintained. On Baytrail devices, when flashing the BOOT_STUB, a backup is automatically saved in the (unused) RW_LEGACY region, from which it can later be restored (via this same script).


Supported Devices:

function| Haswell/Broadwell | BayTrail | WP Disable req. |  notes
-----| :-----: | :-----: | :-----: | :-----: | -----
Install/Update RW_LEGACY Payload|:white_check_mark:|:white_check_mark:|
Install/Update BOOT_STUB Payload|:x:|:white_check_mark:|:white_check_mark:|
Install/Update coreboot Firmware (Full ROM)|:white_check_mark:|:x:|:white_check_mark:|Samsung Series 3 ChromeBox also supported; Chromebook support via coolstar's ROMs
Set Firmware Boot Options|:white_check_mark:|:white_check_mark:|:white_check_mark:|All x86 ChromeOS devices supported
Set Hardware ID|:white_check_mark:|:white_check_mark:|:white_check_mark:|All ChromeOS devices supported
Restore Stock BOOT_STUB|:x:|:white_check_mark:|:white_check_mark:|
Restore Stock Firmware|:white_check_mark:|:x:|:white_check_mark:|

To download and run this script, from a terminal shell: `cd ~; curl -L -O http://mrchromebox.tech/firmware-util.sh; sudo bash firmware-util.sh`

&nbsp;

**setup-kodi.sh** facilitates the installation of Kodi on supported ChromeOS devices via the installation of either an updated legacy boot payload (RW_LEGACY) or custom firmware (full ROM).

Supported Devices:

function| Haswell/Broadwell Chromebox | Haswell/Broadwell Chromebook | BayTrail | WP Disable | notes
----- | :-----: | :-----: | :-----: | :-----: |-----
Dual Boot (LibreELEC/GalliumOS)|:white_check_mark:|:white_check_mark:|:white_check_mark:| |automatically updates legacy boot payload (RW_LEGACY) as needed
Update Legacy Boot Payload|:white_check_mark:|:white_check_mark:|:white_check_mark:|
Set Firmware Boot Options|:white_check_mark:|:white_check_mark:|:white_check_mark:|:white_check_mark:|
Install/Update Custom coreboot Firmware|:white_check_mark:|:x:|:x:|:white_check_mark:|Samsung Series 3 ChromeBox also supported
Create LibreELEC boot media|:white_check_mark:|:white_check_mark:| | |added solely for convenience

This script allows the user to install a dual-boot setup with either LibreELEC or GalliumOS
(with or without Kodi), to set the default OS, and to set the boot timeout on the 
developer mode splash screen.  It also provides for the installation of an updated
legacy boot payload (in the RW_LEGACY firmware slot) for devices that need it.

It also allows the user to flash custom firmware (full ROM), turning a ChromeBox into a regular PC, and provides for the creation of installation media for LibreELEC; though with the custom firmware, any off-the-shelf OS can be installed (including Windows 8.1/10).

setup-kodi.sh will run on any Linux system with a full bash shell; the dual-boot functionality is restricted to ChromeOS.

To download and run this script, from a terminal shell: `cd ~; curl -L -O http://mrchromebox.tech/setup-kodi.sh; sudo bash setup-kodi.sh`

More details and support for this script can be found at http://forum.kodi.tv/showthread.php?tid=194362

&nbsp;

**cbox-firmware-update.sh** exists solely to update the custom firmware (full ROM) on Haswell ChromeBoxes running
Open/LibreELEC, which cannot run the above scripts due to lack of a full Bash shell.

Supported Devices:

function| Haswell Chromebox | Haswell/Broadwell Chromebook | BayTrail | notes
----- | :-----: | :-----: | :-----: | -----
Update Custom coreboot Firmware|:white_check_mark:|:x:|:x:|must already be running custom coreboot firmware, not stock

This script will automatically check to see if an updated firmware is available, and if so, prompt the user to update.  Install-time options include ability to boot without a connected display ("headless" option) and ability to set the default device to USB (vs internal ssd). 

To download and run this script, from a ssh shell: `cd ~; curl -L -O http://mrchromebox.tech/cbox-firmware-update.sh; bash cbox-firmware-update.sh`
