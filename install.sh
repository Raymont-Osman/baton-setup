#!/bin/bash
#========================
set -u

#
# Function to Abort the script
#
abort() {
  printf "%s\n" "$@"
  exit 1
}

#
# Check the version of Bash
#
if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
if [[ ! -t 0 || -n "${CI-}" ]]; then
  NONINTERACTIVE=1
fi

# Check the OS. Prevents accidentally knackering a macbook.
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then
  HOMEBREW_ON_LINUX=1
else
  abort "Baton is only supported on Linux."
fi

#
# Show a welcome message box
#
whiptail --msgbox "Welcome to the baton setup script. This script will now ask for your sudo password." --title "Baton Setup Script" 20 60


#
# Function to check and asked for sudo access
#
have_sudo_access() {
  local -a args
  if [[ -n "${SUDO_ASKPASS-}" ]]; then
    args=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]; then
    args=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
    if [[ -n "${args[*]-}" ]]; then
      SUDO="/usr/bin/sudo ${args[*]}"
    else
      SUDO="/usr/bin/sudo"
    fi
    if [[ -n "${NONINTERACTIVE-}" ]]; then
      ${SUDO} -l mkdir &>/dev/null
    else
      ${SUDO} -v && ${SUDO} -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ "$HAVE_SUDO_ACCESS" -ne 0 ]]; then
    abort "Need sudo access (e.g. the user $USER needs to be an Administrator)!"
  fi

  return "$HAVE_SUDO_ACCESS"
}

#
# Check for Sudo access
#
have_sudo_access
#
# Ask to update the system
#
if whiptail --yesno "Update and Upgrade Raspbian?" 20 60 ;then
sudo apt-get --yes update
sudo apt-get --yes upgrade
sudo apt --yes autoremove
fi
#
# Ask to install the base software packages
#
if whiptail --yesno "Install the latest packages? (takes a while)" 20 60 ;then
sudo apt-get --yes install vim pijuice-base libglib2.0-dev supervisor
fi
#
# Ask to set up an SSH key for private GitHub repository access.
# More details can be found here:
# https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
#
if whiptail --yesno "Setup SSH key for private Github?" 20 60 ;then
# setup ssh keygen
EMAIL=$(whiptail --inputbox "Enter your github email" 8 39 --title "Github Email" 3>&1 1>&2 2>&3)
ssh-keygen -t ed25519 -C "$EMAIL"
eval "$(ssh-agent -s)"
# Add to the ssh config file
touch ~/.ssh/config
tee -a ~/.ssh/config << END
Host *
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
END
# Add Github public key
echo "Copy this file to github"
echo "Open https://github.com/settings/keys and add this key..."
echo ""
cat ~/.ssh/id_ed25519.pub
echo ""
read -p "Press enter to continue"
fi

#
# Ask to clone the baton repo (assumes the private key is now active)
#
if whiptail --yesno "Clone the Baton Repo?" 20 60 ;then
cd /home/pi
rm -rf Baton
git clone git@github.com:Birmingham-Open-Media/Baton.git
cd Baton
sudo pip3 install -r requirements.txt
fi

#
# Set up tiny cloud
if whiptail --yesno "Set up TinyCloud PIN?" 20 60 ;then
python /home/pi/Baton/tinycloud/register.py
fi

# enabale spi
if whiptail --yesno "Enable SPI through Raspi Config?" 20 60 ;then
sudo raspi-config
fi

#
# Ask to setup Supervisor (assumes the repo is now cloned)
# 
if whiptail --yesno "Set up Supervisor?" 20 60 ;then
sudo tee -a /etc/supervisor/conf.d/baton.conf << END
[program:baton]
command=/usr/bin/python3 -u /home/pi/Baton/Baton.py -l info
directory=/home/pi/Baton
autostart=true
autorestart=true
startretries=3
stopsignal=TERM
stopwaitsecs=7
stderr_logfile=/var/log/baton.err.log
stdout_logfile=/var/log/baton.out.log
END
sudo tee -a /etc/supervisor/conf.d/server.conf << END
[inet_http_server]
port = *:9001
username = batonuser
password = batonpass
END
echo "Starting Supervisor..."
sudo service supervisor start
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl pid all
fi


# Ask to set up the power saving modifications
# https://learn.pi-supply.com/make/how-to-save-power-on-your-raspberry-pi/
# if you are running your Raspberry Pi headless or using SSH for remote access then chances
# are you are not using the HDMI port connecting to a monitor. However, even though you do not
# have anything connected to the HDMI port it will still output and power the port, ready for
# when do connect a monitor. Well, it is possible to switch off this output by a simple command. 
# This can save you up to 30mA in total, which isn’t too much but overall it can make a big
# difference when combined with other power saving options.
if whiptail --yesno "Setup power savings" 20 60 ;then
sudo /opt/vc/bin/tvservice -o
# If you really want to save as much power as possible then it
# is possible to disable the on-board LEDs on the Raspberry Pi.
# This can be done by editing the /boot/config.txt
# file and adding the following lines:
# echo "# Added by setup script" >> /boot/config.txt
# echo "dtparam=act_led_trigger=none" >> /boot/config.txt
# echo "dtparam=act_led_activelow=on" >> /boot/config.txt
fi

# @todo: setup multiple wifi networks
# https://mikestreety.medium.com/use-a-raspberry-pi-with-multiple-wifi-networks-2eda2d39fdd6
# vim /etc/network/interfaces
# vim /etc/wpa_supplicant/wpa_supplicant.conf

#
# Ask whether to configure the PiJuice battery management
# https://github.com/PiSupply/PiJuice
#
if whiptail --yesno "Setup the Pi Juice?" 20 60 ;then

# reboot
whiptail --msgbox "1) You should manually upgrade the firmware. 2) Sw2 set power on and off" --title "PiJuice Setup" 20 60
pijuice_cli
sudo systemctl enable pijuice.service
sudo systemctl start pijuice.service
ps ax | grep pijuice_sys | grep -v grep
fi

# Nice goodbye
whiptail --msgbox "Setup Done! Have fun." --title "Baton Setup Script" 20 60
