#!/bin/bash
#
# This script offers provides the ability to update the 
# Legacy Boot payload, set boot options, and install
# a custom coreboot firmware for supported
# ChromeOS devices 
#
# Created by Mr.Chromebox <mrchromebox@gmail.com>
#
# May be freely distributed and modified as needed, 
# as long as proper attribution is given.
#

#where the stuff is
script_url="https://raw.githubusercontent.com/MattDevo/scripts/master/"

#set working dir
cd /tmp

#get support scripts
rm -rf firmware.sh >/dev/null &2>1
rm -rf functions.sh >/dev/null &2>1
rm -rf sources.sh >/dev/null &2>1
curl -s -L -O ${script_url}firmware.sh
rc0=$?
curl -s -L -O ${script_url}functions.sh
rc1=$?
curl -s -L -O ${script_url}sources.sh
rc2=$?
if [[ $rc0 -ne 0 || $rc1 -ne 0 || $rc2 -ne 0 ]]; then
	echo -e "Error downloading one or more required files; cannot continue"
	exit 1
fi

source ./sources.sh
source ./firmware.sh
source ./functions.sh

#do setup stuff
prelim_setup
[[ $? -ne 0 ]] && 	exit 1

#show menu
menu_fwupdate
