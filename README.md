# scripts
Scripts for setup/install/firmware update for ChromeOS devices

setup-kodi.sh facilitates the installation of Kodi on supported ChromeOS devices.

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


setup-firmware.sh is a slimmed-down version of the above, without the kodi-related parts, and has
the same requirements/restrictions as well.


cbox-firmware-update.sh exists solely to update the custom firmware on Haswell ChromeBoxes running
OpenELEC, which cannot run the above scripts due to lack of a full Bash shell.