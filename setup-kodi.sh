#!/bin/bash
#
# This script will prep Haswell/Broadwell-based
# ChromeOS devices for Kodi installation via
# OpenELEC or Ubuntu/Kodibuntu
#
# Created by Matt DeVillier	<matt.devillier@gmail.com>
#
# May be freely distributed and modified as needed, 
# as long as proper attribution is given.
#

#where the stuff is
script_url="https://raw.githubusercontent.com/MattDevo/scripts/master/"
dropbox_url="https://dl.dropboxusercontent.com/u/98309225/"

#set working dir
cd /tmp

#get functions script
rm -rf functions.sh >/dev/null &2>1
curl -s -L -O ${script_url}/functions.sh
. ./functions.sh

#do setup stuff
prelim_setup
if [ $? -ne 0 ]; then
	exit 1
fi

#show menu
menu_kodi
