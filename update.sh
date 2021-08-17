#!/bin/bash
#========================
set -u

if whiptail --yesno "Update the Baton Repo?" 20 60 ;then
cd /home/pi/Baton
git pull
pip3 install -r requirements.txt
fi