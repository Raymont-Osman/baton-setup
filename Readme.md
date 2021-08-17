# Baton setup

Script to set up and maintain the raspberry pi correctly on the baton.

## Pre install

We've set up the boards with the official Raspberry pi Imager.
[https://www.raspberrypi.org/software/](https://www.raspberrypi.org/software/)
There's a hidden menu ```cmd + shift + x``` in this application that makes setting up for headless ssh much easier by giving each image an individual hostname. Once the images is installed, ssh into the pi and run the one line install script below which will continue to add all the software and code ready for use.

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
