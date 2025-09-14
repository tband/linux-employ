#!/usr/bin/env bash

# NOTE: Script will be run during creating of ISO inside a chroot (mkiso.sh --chroot)

PATH=$PATH:/usr/sbin
apt-get update
apt-get --yes upgrade
ufw enable
ufw default deny incoming
