#!/bin/bash
# to run copy and paste the following into a terminal
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/raymont-osman/baton-setup/HEAD/install.sh)"
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
git checkout v1.x
sudo pip3 install -r requirements.txt
fi

#
# Set up tiny cloud
if whiptail --yesno "Set up TinyCloud PIN?" 20 60 ;then
python3 /home/pi/Baton/tinycloud/register.py
fi

# enabale spi
if whiptail --yesno "Enable SPI through Raspi Config?" 20 60 ;then
# sudo raspi-config
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_spi 0
fi

#
# Ask to setup Supervisor (assumes the repo is now cloned)
# 
if whiptail --yesno "Set up Supervisor?" 20 60 ;then
sudo tee /etc/supervisor/conf.d/baton.conf << END
[program:baton]
command=/usr/bin/python3 -u /home/pi/Baton/Baton.py -l info
directory=/home/pi/Baton
autostart=true
autorestart=true
startretries=3
stopsignal=TERM
stopwaitsecs=7
END
sudo tee /etc/supervisor/conf.d/server.conf << END
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


if whiptail --yesno "Fix Bluetooth Service?" 20 60 ;then
sudo tee /etc/systemd/system/bluetooth.target.wants/bluetooth.service << END
[Unit]
Description=Bluetooth service
Documentation=man:bluetoothd(8)
ConditionPathIsDirectory=/sys/class/bluetooth

[Service]
Type=dbus
BusName=org.bluez
ExecStart=/usr/lib/bluetooth/bluetoothd -P battery
NotifyAccess=main
#WatchdogSec=10
#Restart=on-failure
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
LimitNPROC=1
ProtectHome=true
ProtectSystem=full

[Install]
WantedBy=bluetooth.target
Alias=dbus-org.bluez.service
END
sudo systemctl daemon-reload
sudo systemctl restart bluetooth
fi

# Ask to set up the power saving modifications
# https://learn.pi-supply.com/make/how-to-save-power-on-your-raspberry-pi/
# if you are running your Raspberry Pi headless or using SSH for remote access then chances
# are you are not using the HDMI port connecting to a monitor. However, even though you do not
# have anything connected to the HDMI port it will still output and power the port, ready for
# when do connect a monitor. Well, it is possible to switch off this output by a simple command. 
# This can save you up to 30mA in total, which isn???t too much but overall it can make a big
# difference when combined with other power saving options.
if whiptail --yesno "Setup power savings" 20 60 ;then
sudo /opt/vc/bin/tvservice -o
fi

# @note, you'll need the PSKs for each network
# https://mikestreety.medium.com/use-a-raspberry-pi-with-multiple-wifi-networks-2eda2d39fdd6
if whiptail --yesno "Setup multiple WIFI networks?" 20 60 ;then
read -p "Enter PSK for CWG_A_HUB: " PSK_CWG_A_HUB
read -p "Enter PSK for CWG_B_HUB: " PSK_CWG_B_HUB
sudo tee /etc/wpa_supplicant/wpa_supplicant.conf << END
country=GB
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
ap_scan=1

update_config=1
network={
    id_str="CWG_A_HUB"
    ssid="CWG_A_HUB"
    psk=${PSK_CWG_A_HUB}
}

network={
    id_str="CWG_B_HUB"
    ssid="CWG_B_HUB"
    psk=${PSK_CWG_B_HUB}
}
END
fi

if whiptail --yesno "Setup Fast Start LEDs" 20 60 ;then
sudo tee /etc/systemd/system/welcome.service << END
[Unit]
Description=Fast Boot LED Light Service
DefaultDependencies=no

[Service]
Type=simple
ExecStart=sudo python3 /home/pi/Baton/welcome.py

[Install]
WantedBy=sysinit.target
END
sudo systemctl enable welcome
sudo systemctl start welcome
fi

if whiptail --yesno "Setup the SSH Tunnel Service?" 20 60 ;then

whiptail --msgbox "First, you must also copy the BatonHub.pem file to /home/pi/.ssh and update /home/pi/authorized_keys with the server's public key." --title "SSH Key Notice" 20 60

read -p "Enter the remote port [23233]: " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-23233}
sudo tee /etc/systemd/system/sshtunnel.service << END
[Unit]
Description=SSH Tunnel
After=network.target

[Service]
Restart=always
RestartSec=180
User=pi
ExecStart=/bin/ssh -NT -o ServerAliveInterval=60 -i /home/pi/.ssh/BatonHub.pem -p 23232 -R ${REMOTE_PORT}:localhost:22 ubuntu@52.210.249.162

[Install]
WantedBy=multi-user.target
END

sudo systemctl enable sshtunnel
sudo systemctl start sshtunnel

whiptail --msgbox "We'll now try to connect to the server to check it works." --title "Baton Setup Script" 20 60

/bin/ssh -NT -o ServerAliveInterval=60 -i /home/pi/.ssh/BatonHub.pem -p 23232 -R 23229:localhost:22 ubuntu@52.210.249.162

fi

#
# Ask whether to configure the PiJuice battery management
# https://github.com/PiSupply/PiJuice
#
if whiptail --yesno "Setup the Pi Juice?" 20 60 ;then
whiptail --msgbox "1) You should manually upgrade the firmware. 2) Sw2 set power on and off" --title "PiJuice Setup" 20 60
pijuice_cli
sudo systemctl enable pijuice.service
sudo systemctl start pijuice.service
ps ax | grep pijuice_sys | grep -v grep
fi

if whiptail --yesno "Setup the Pi Juice RTC?" 20 60 ;then
i2cdetect -y 1
read -p "0x68 Should be UU. If not press Y to update Boot Config:" SHOULD_UPDATE
if [ "$SHOULD_UPDATE" == "Y" ]; then
sudo tee -a /boot/config.txt << END

# Enable system to control the pijuice zero RTC
dtoverlay=i2c-rtc,ds1339
END
sudo hwclock -r
else
echo "Skipped Boot Update"
sudo hwclock -r
fi
fi

# Nice goodbye
whiptail --msgbox "Setup Done! Have fun." --title "Baton Setup Script" 20 60
