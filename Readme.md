# Baton setup

Script to set up and maintain the raspberry pi correctly on the baton.

## Pre install

We're setting up the pi with the official Raspberry pi Imager.
[https://www.raspberrypi.org/software/](https://www.raspberrypi.org/software/)
There is a hidden menu in this application that makes setting up the image for headless ssh much easier. Use cmd + shift + x to open this panel and set the network and ssh parameters. Once the images is installed, ssh into the pi and run the install script below which will continue to add all the software and code ready for use.

## Install script

Copy and paste the following one-liner to update the Raspberry Pi software and install the repositories:

```console
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/raymont-osman/baton-setup/HEAD/install.sh)"
```

## Update

Once installed, you can keep the software up to date with the following one-liner:

```console
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/raymont-osman/baton-setup/HEAD/update.sh)"
```
