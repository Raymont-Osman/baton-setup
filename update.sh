#!/bin/bash
# pulls the latest changes from the repository
# and install the python requirements
#==================================
cd /home/pi/Baton
sudo supervisorctl stop baton
git pull
git checkout v1.x
git pull
git status
sudo pip3 install -r requirements.txt 
sudo supervisorctl start baton
sudo supervisorctl tail baton