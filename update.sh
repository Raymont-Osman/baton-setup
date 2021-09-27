#!/bin/bash
# pulls the latest changes from the repository
# and install the python requirements
#==================================
cd /home/pi/Baton
sudo supervisorctl stop baton
cd /home/pi/Baton
git pull
# git checkout v1.x
git checkout 90b6777
sudo pip3 install -r requirements.txt 
sudo supervisorctl start baton