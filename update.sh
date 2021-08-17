#!/bin/bash
# pulls the latest changes from the repository
# and install the python requirements
#==================================
cd /home/pi/Baton
git pull
echo "pip 3 installing requirements"
sudo pip3 install -r requirements.txt