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
# OS="$(uname)"
# if [[ "$OS" == "Linux" ]]; then
#   HOMEBREW_ON_LINUX=1
# else
#   abort "Baton is only supported on Linux."
# fi

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

ring_bell() {
  # Use the shell's audible bell.
  if [[ -t 1 ]]; then
    printf "\a"
  fi
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

getc() {
  local save_state
  save_state=$(/bin/stty -g)
  /bin/stty raw -echo
  IFS= read -r -n 1 -d '' "$@"
  /bin/stty "$save_state"
}

wait_for_user() {
  local c
  echo
  echo "Press RETURN to continue or any other key to abort"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "$c" == $'\r' || "$c" == $'\n' ]]; then
    exit 1
  fi
}

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

# update the system
ohai "Updating and Upgrading"
apt-get --yes update
apt-get --yes upgrade

# install software
ohai "Installing Software"
apt-get --yes install vim pijuice-base nginx
# google cloud

# https://github.com/PiSupply/PiJuice
pijuice_cli

# Git clone
ohai "Cloning the Repository"

# https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
# soluions
# 1: public
# 2: local network pull
# 3: public release
# 4: new github user with ssh key

# setup ssh keygen
read -p "Enter email: " EMAIL
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

ohai "Add the following to Github"
cat ~/.ssh/id_ed25519.pub
ohai "END"

read -p "Add to github and clone repo: " REPO
git clone $REPO

# https://learn.pi-supply.com/make/how-to-save-power-on-your-raspberry-pi/
# if you are running your Raspberry Pi headless or using SSH for remote access then chances
# are you are not using the HDMI port connecting to a monitor. However, even though you do not
# have anything connected to the HDMI port it will still output and power the port, ready for
# when do connect a monitor. Well, it is possible to switch off this output by a simple command. 
# This can save you up to 30mA in total, which isn’t too much but overall it can make a big
# difference when combined with other power saving options.
ohai "Turning off HDMI"
opt/vc/bin/tvservice -o

# If you really want to save as much power as possible then it
# is possible to disable the on-board LEDs on the Raspberry Pi.
# This can be done by editing the /boot/config.txt
# file and adding the following lines:
ohai "[INACTIVE] Turning off Power Lights"
sleep 3
# echo "# Added by setup script" >> /boot/config.txt
# echo "dtparam=act_led_trigger=none" >> /boot/config.txt
# echo "dtparam=act_led_activelow=on" >> /boot/config.txt

# setup multiple networks
ohai "[INACTIVE] Set up Wifi Networks"
sleep 3
# https://mikestreety.medium.com/use-a-raspberry-pi-with-multiple-wifi-networks-2eda2d39fdd6
# vim /etc/network/interfaces
# vim /etc/wpa_supplicant/wpa_supplicant.conf

if [[ -z "${NONINTERACTIVE-}" ]]; then
  ring_bell
  wait_for_user
fi