#!/usr/bin/env bash

# NOTE: Script will be run during creation of ISO inside a chroot (mkiso.sh --update)

PATH=$PATH:/usr/sbin
#ufw --force enable 2> /dev/null
#ufw default deny incoming
apt-get update
apt-get --yes install wdutch cheese mint-meta-codecs
apt-get --yes upgrade
apt-get clean
