#!/bin/bash
#========================
set -u

abort() {
  printf "%s\n" "$@"
  exit 1
}

if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
if [[ ! -t 0 || -n "${CI-}" ]]; then
  NONINTERACTIVE=1
fi

# First check OS.
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then
  HOMEBREW_ON_LINUX=1
else
  abort "This can only be run on Linux."
fi

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

#======================== SCRIPT START ========================#

have_sudo_access

# Display a menu to ask for direction
whiptail --title "Baton Setup" --checklist \
"Choose some options for setup" 20 78 4 \
"UPDATE" "Update and Upgrade" ON \
"INSTALL" "Install base software packages" ON \
"JUICE" "Configure the PiJuice" ON \
"SSH_KEY" "Setup an SSH key" ON \
"CLONE_REPO" "Clone the Gihub Repo" ON \
"POWER_SAVE" "Power Save (Turn off the HDMI and lights)" ON \

if [ "$UPDATE" == "ON" ] ;then
  sudo apt-get --yes update
  sudo apt-get --yes upgrade
fi

# install software
if [ "$INSTALL" == "ON" ] ;then
  sudo apt-get --yes install vim pijuice-base
fi

# https://github.com/PiSupply/PiJuice
if [ "$JUICE" == "ON" ] ;then
pijuice_cli
fi

# Git clone
if [ "$SSH_KEY" == "ON" ] ;then

# https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent

# setup ssh keygen
EMAIL=$(whiptail --inputbox "Your email address?" 8 39 --title "GitHub Email address" 3>&1 1>&2 2>&3)
ssh-keygen -t ed25519 -C "$EMAIL"
eval "$(ssh-agent -s)"
touch ~/.ssh/config

# add to file
tee -a ~/.ssh/config << END
Host *
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
END

  # Add Github public key  
  whiptail --msgbox "$(cat ~/.ssh/id_ed25519.pub)" 20 38
fi

if [ "$CLONE_REPO" == "ON" ] ;then
  git clone git@github.com:Birmingham-Open-Media/Baton.git
fi

# https://learn.pi-supply.com/make/how-to-save-power-on-your-raspberry-pi/
# if you are running your Raspberry Pi headless or using SSH for remote access then chances
# are you are not using the HDMI port connecting to a monitor. However, even though you do not
# have anything connected to the HDMI port it will still output and power the port, ready for
# when do connect a monitor. Well, it is possible to switch off this output by a simple command. 
# This can save you up to 30mA in total, which isn’t too much but overall it can make a big
# difference when combined with other power saving options.
if [ "$POWER_SAVE" == "ON" ] ;then
sudo /opt/vc/bin/tvservice -o
# If you really want to save as much power as possible then it
# is possible to disable the on-board LEDs on the Raspberry Pi.
# This can be done by editing the /boot/config.txt
# file and adding the following lines:
# echo "# Added by setup script" >> /boot/config.txt
# echo "dtparam=act_led_trigger=none" >> /boot/config.txt
# echo "dtparam=act_led_activelow=on" >> /boot/config.txt
fi

# setup multiple networks
# ohai "[INACTIVE] Set up Wifi Networks"
# sleep 3
# https://mikestreety.medium.com/use-a-raspberry-pi-with-multiple-wifi-networks-2eda2d39fdd6
# vim /etc/network/interfaces
# vim /etc/wpa_supplicant/wpa_supplicant.conf