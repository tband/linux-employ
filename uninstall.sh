#!/bin/bash

nmcli c delete br0 br0-slave if_server 2> /dev/null
apt purge isc-dhcp-server tftpd-hpa apache2 nfs-kernel-server bridge-utils
rm /etc/dhcp/dhcpd.conf* /etc/default/isc-dhcp-server*
rm -rf /var/www
rm /srv/tftp/*
rm /etc/exports
umount /srv/nfs/mint
rm -rf /srv/nfs
sed -i '/\/srv\/nfs/d' /etc/fstab
ufw enable
