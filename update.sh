#!/bin/bash
#========================
set -u

if whiptail --yesno "Update the Baton Repo?" 20 60 ;then
cd ~
git pull origin master
cd Baton
pip3 install -r requirements.txt
fi