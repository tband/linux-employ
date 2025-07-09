#!/bin/bash

nmcli c delete if_server
# Packages are not removed but services disabled
apt autoremove isc-dhcp-server tftpd-hpa apache2 nfs-kernel-server bridge-utils
rm /etc/dhcp/dhcpd.conf* /etc/default/isc-dhcp-server*
rm -rf /var/www
rm /srv/tftp/*
rm /etc/exports
umount /srv/nfs/mint
rm -rf /srv/nfs
sed -i '/\/srv\/nfs/d' /etc/fstab
ufw enable
