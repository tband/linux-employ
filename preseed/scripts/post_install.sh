#!/usr/bin/env bash

# NOTE: Script will be run at end of install inside a chroot

apt update
for pkg in /etc/pkgs/*.deb
do
  apt install $pkg
done

# Packages to be removed, one per line. Wildcards allowed
TOBEREMOVED="
libreoffice-base-core
libreoffice-l10n-en-gb
"
for pkg in $TOBEREMOVED
do
  apt remove --yes $pkg
done
# Set automatic updates
mintupdate-automation upgrade enable

# Setup firewall
ufw enable
ufw default deny incoming

# Next boot will show OEM user configuration
oem-config-prepare --quiet
