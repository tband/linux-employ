#!/bin/bash

# ISO is the image locally available
ISO=linux_repair_r1.iso
# The interface that is connected to the PXE network. For a laptop this it the ethernet adapter
# see also: nmcli device
adapters=$(nmcli device|awk '/ethernet/ {print $1}')
# pick the last if more than one
DEVICE=$(echo "$adapters"|tail -1)
# The IP address of the network
IPADDRESS=192.168.5.1
NET=${IPADDRESS%\.*} # 192.168.5
# If you want to edit the iso, like adding preseed data, change this to y
RW_MOUNT=n

# Parse command-line options
prog_name=$(basename $0)
help="
${prog_name} [-idnwhH]
  -i  <file>  distro.iso (default $ISO)
  -d  <eth>   device
  -n  <ip>    Server IP addres (default $IPADDRESS)
  -w          Make the /srv/nfs mount writable. The iso will be unpacked instead of mounted
  -h          This help

Configure a Linux system to become a IPXE server for ISO installation on clients
All arguments are optinal, but you want at least to 
  
Example:
  ./${prog_name} -d $DEVICE -i $ISO
"

while getopts i:d:whH opt
do
  case $opt in
    i)ISO=$OPTARG;;
    d)DEVICE=$OPTARG;DEVICE_OK=t;;
    n)IPADDRESS=$OPTARG;;
    w)RW_MOUNT=y;;
  h|H)echo "$help";exit 1;;
    *)echo "$help";exit 1;;
  esac
done

CNT=$(echo $adapters|wc -w)
if [[ -z $DEVICE_OK && $CNT -gt 1 ]]
then
 echo "More than one ethernet device found"
 nmcli device
 echo "Will be using $DEVICE"
 echo "if that is not what you want use -d to specify the correct device"
 read -n 1 -p "continue with $DEVICE? [n]"
  echo
  case $REPLY in
    j|y);;
    *)exit 1
  esac
fi

if [[ ! -r $ISO ]] then
  echo -e "ERROR: cannot read $ISO, use -i argument"
  exit 1
fi

# install packages
apt install -y isc-dhcp-server tftpd-hpa apache2 nfs-kernel-server bridge-utils
# optionally
apt install -y openssh-server iptables net-tools vim
# Disable the Firewall as NFS, SSH, TFTP and HTTP, DHCP all will be served
ufw disable
#Todo figure out all ports that are needed
#ufw allow 22/tcp
#ufw allow 80/tcp
#ufw allow 67/udp
#ufw allow 69/udp
#ufw allow 4011/udp

# dhcpd config
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.org
cat etc/dhcp/dhcpd.conf|sed "s/192.168.3/${NET}/g" > /etc/dhcp/dhcpd.conf
mv /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.org
# This tells only so serve bridge br0. A physical adapter will be added later. 
# This allows the dhcp server to start up
sed "s/br0/${DEVICE}/g" etc/default/isc-dhcp-server > /etc/default/isc-dhcp-server

# Make bridge br0
#nmcli con add con-name br0 type bridge ifname br0 
#nmcli con modify br0 ipv4.addr "${IPADDRESS}/24" ipv4.method manual
# add at least one interface to the bridge, but more are ok as well. But don't add an interface
# that is already connected to an existing network (with dhcp server)
# nmcli c add con-name br0-slave type bridge-slave ifname ${DEVICE} master br0

nmcli con add con-name if_server type ethernet ifname ${DEVICE} ipv4.method manual ipv4.address ${IPADDRESS}/24

#httpd server config
mv /var/www/html/index.html /var/www/html/demo_index.html
sed "s/192.168.3/${NET}/g" var/www/html/menu  > /var/www/html/menu

# tftp config is ok, just add the data
# see also https://ipxe.org/howto/chainloading
# note that this version has NFS support added, so don't download directly from ipxe.org
cp srv/tftp/undionly.kpxe /srv/tftp/

#nfs

#Overlay filesystem creating
# Nice idea, but an overlay filesystem cannot be exported by NFS.
# First make an overlay filesystem such that it's easy to edit the contect of the iso. like adding preseed files
# The actual version of the "iso" is served from /srv/nfs and can be edited

# Define nfs exports:
mkdir -p /srv/nfs
grep -E "^/srv/nfs"      /etc/exports >/dev/null || cp etc/exports /etc/exports
if [[ -n "$ISO" ]] then
  mkdir -p /srv/nfs/mint
  # One time mount to copy data
  #mkdir /mnt/iso
  if [[ "$RW_MOUNT" == "y" ]]; then
    mkdir -p /mnt/iso
    mount -o loop,ro $ISO /mnt/iso
    rsync -ai /mnt/iso/ /srv/nfs/mint/
  else
    grep "/srv/nfs/mint" /etc/fstab || echo "$ISO   /srv/nfs/mint      auto  x-systemd.requires=/,ro    0  0" >> /etc/fstab
    grep -E "^/srv/nfs/mint" /etc/exports >/dev/null || echo "/srv/nfs/mint *(rw,sync,no_subtree_check)"                 >> /etc/exports
  fi
fi

#mkdir -p /mnt/{iso,nfs} # /tmp/{upper,work}
#mount -t overlay overlay -olowerdir=/mnt/iso,upperdir=/tmp/upper,workdir=/tmp/work /srv/nfs
#Add to fstab:
#/mnt/Downloads/linux_repair_r1.iso   /mnt/iso      auto  x-systemd.requires=/,ro    0  0
#overlay                              /srv/nfs   overlay  x-systemd.requires=/mnt/iso,lowerdir=/mnt/iso,upperdir=/tmp/upper,workdir=/tmp/work  0 0

# Restart the services
exportfs -rva
systemctl daemon-reload
systemctl disable isc-dhcp-server6.service
systemctl restart isc-dhcp-server.service
systemctl restart nfs-server
