#!/bin/bash

nmcli c delete br0 br0-slave if_server 2> /dev/null
apt purge -y isc-dhcp-server tftpd-hpa apache2 nfs-kernel-server bridge-utils libarchive-tools squashfs-tools xorriso isolinux
apt remove openssh-server
rm -f /etc/dhcp/dhcpd.conf* /etc/default/isc-dhcp-server*
rm -rf /var/www
rm /etc/exports
umount -l /srv/nfs/mint
rm -rf /srv/
sed -i '/\/srv\/nfs/d' /etc/fstab
apt install -y ufw
ufw --force reset
ufw enable
ufw default deny incoming

