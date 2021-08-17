#!/bin/bash
#========================
set -u
cd /home/pi/Baton
git pull
echo "pip 3 installing requirements"
sudo pip3 install -r requirements.txt