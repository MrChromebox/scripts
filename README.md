# scripts
Collection of scripts for setup/install/firmware update for supported ChromeOS devices

**setup-kodi.sh** facilitates the installation of Kodi on supported ChromeOS devices.

It allows the user to install a dual-boot setup with either OpenELEC or Ubuntu
(with or without Kodi), to set the default OS, and to set the boot timeout on the 
developer mode splash screen.  It also provides for the installation of an updated
Legacy BIOS for devices that need it.

The script also allows the user to flash custom firmware, turning a ChromeBox into a regular PC,
and provides for the creation of installation media for OpenELEC and a custom build of
KodiBuntu (optimized for Haswell-based ChromeOS devices), though any off-the-shelf OS can be
installed (including Windows 8/8.1/10).

setup-kodi.sh will run on any system with a full bash shell, though the dual-boot related functions 
are restricted to ChromeOS.  

To download and run this script, from a terminal shell: `curl -L -O https://goo.gl/FdvHF6; sudo bash FdvHF6`

More details and support for this script can be found at http://forum.kodi.tv/showthread.php?tid=194362


**setup-firmware.sh** is a slimmed-down version of the above, without the kodi-related parts, and has
the same requirements/restrictions as well.  

It also includes functionality to restore the stock firmware on a Haswell ChromeBox, either 
from a backup file or from a generic recovery image firmware file.  If the latter is used, the 
device-specific VPD (vital product data) is extracted from the running firmware and merged with 
the generic firmware file, to ensure the device's unique MAC address, serial #, etc are maintained. 

To download and run this script, from a terminal shell: `curl -L -O https://goo.gl/1hFfO3; sudo bash 1hFfO3`

**cbox-firmware-update.sh** exists solely to update the custom firmware on Haswell ChromeBoxes running
OpenELEC, which cannot run the above scripts due to lack of a full Bash shell.

To download and run this script, from a ssh shell: `curl -L -O https://goo.gl/SoCQtG; bash SoCQtG`
