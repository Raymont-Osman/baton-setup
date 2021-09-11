#!/bin/bash
# pulls the latest changes from the repository
# and install the python requirements
#==================================
cd /home/pi/Baton
git pull
git checkout v1.x
sudo pip3 install -r requirements.txt