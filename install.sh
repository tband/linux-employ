#!/bin/bash
VERSION=1.0
# ISO is the image locally available
ISO=$PWD/linux_repair.iso
COMMENT="Linux repair iso"
# The interface that is connected to the PXE network. For a laptop this it the ethernet adapter
# see also: nmcli device
adapters=$(nmcli device|awk '/ethernet/ {print $1}')
# pick the last if more than one
DEVICE=$(echo "$adapters"|tail -1)
# The IP address of the network
IPADDRESS=192.168.5.1
# If you want to edit the iso, like adding preseed data, change this to y
RW_MOUNT=n

function install_cubic () {
  apt-add-repository universe
  apt-add-repository ppa:cubic-wizard/release
  apt update
  apt install --no-install-recommends cubic
}

# Parse command-line options
prog_name=$(basename $0)
help="
${prog_name} [--iso <ISO> --comment <COMMENT> --device <DEVICE> --ip <IPADDRESS> --rw --help]
  --iso,-i      <file> distro.iso
  --rw          Make the /srv/nfs mount writable. The iso will be unpacked
                instead of mounted
  --cubic <project directory>
                Instead of an iso use the project directory from which cubic
                makes a custom iso. This allows to edit the preseed files
                without recreating the iso
  -c, --comment <text> What text to put in the iPXE menu, default $COMMENT
  --device,-d   <eth>  device to use if there are more than one
  --nat         setup nat to this device. Internet from this device (Wifi adapter) is shared
  --ip          <ip>   Server IP addres (default $IPADDRESS)
  --h,-h        This help

Configure a Linux system to become a IPXE server for Linux installation on
clients. All arguments are optinal, but you want at least to specify the iso
location or the Cubic project directory.
  
Example:
  sudo ./${prog_name} -d $DEVICE -i $ISO -c \"Linux Mint\"
"

#!/bin/bash

# Define help message
#help="Usage: script.sh --iso <ISO> --comment <COMMENT> --device <DEVICE> --ip <IPADDRESS> --rw --help"

# Parse long options
OPTIONS=$(getopt -o i:c:d:n:wvhH --long iso:,cubic:,install_cubic,device:,nat:,ip:,rw,version,help -- "$@")
eval set -- "$OPTIONS"

# Initialize variables
DEVICE_OK=""
NAT_DEVICE=""

while true; do
  case "$1" in
    -i|--iso) ISO="$2"; shift 2;;
    --cubic)CUBIC="$2"; shift 2;;
    --install_cubic)install_cubic; exit 0;;
    -c|--comment) COMMENT="$2"; shift 2;;
    -d|--device) DEVICE="$2"; DEVICE_OK="t"; shift 2;;
    --nat) NAT_DEVICE="$2"; shift 2;;
    -n|--ip) IPADDRESS="$2"; shift 2;;
    -w|--rw) RW_MOUNT="y"; shift;;
    -v|--version)echo Linux-employ version $VERSION; exit 0;;
    -h|--help) echo "$help"; exit 1;;
    --) shift; break;;
    *) echo "$help"; exit 1;;
  esac
done

function remove_mint_mount () {
    umount -l /srv/nfs/mint 2>/dev/null
    mkdir -p /srv/nfs/mint
    sed -i '/\/srv\/nfs/d' /etc/fstab
}

function source_cubic () {
    # Remove existing mount point from previous install
    remove_mint_mount
    echo "${CUBIC}/custom-disk   /srv/nfs/mint      auto  bind,ro    0  0" >> /etc/fstab
    # nfs installer uid is most likely not these same as the uid running Cubic, so make all files world readable.
    # I've seen this go wrong with casper/vmlinux having permission 600 after Cubic updates it.
    # This also means after Cubic image creation, you have to manually open up the files by giving this command:
    find ${CUBIC}/custom-disk/ ! -perm /o=r -exec chmod o+r \{} \;
}

function check_iso () {
  if [[ ! -r $ISO ]] then
    echo -e "ERROR: cannot read $ISO, use -i argument"
    exit 1
  fi
}
function source_iso_ro () {
    check_iso
    # Remove existing mount point from previous install
    remove_mint_mount
    echo "$ISO   /srv/nfs/mint      auto  x-systemd.requires=/,ro    0  0" >> /etc/fstab
}

function source_iso_rw () {
    check_iso
    remove_mint_mount
    # One time mount to copy data
    mkdir -p /mnt/iso
    mount -o loop,ro $ISO /mnt/iso
    rsync -ai --delete /mnt/iso/ /srv/nfs/mint/
    rsync -ai --delete preseed /srv/nfs/mint/
}

if [[ ! -z $CUBIC  && -d "$CUBIC" ]] then
  if [[ -r $ISO ]] then
    echo -e "ERROR: Either specify an ISO or a CUBIC project folder, not both"
    exit 1
  fi
fi

ISO=$(readlink -f $ISO)

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

# update the repo first
apt update
# install packages
apt install -y isc-dhcp-server tftpd-hpa apache2 nfs-kernel-server bridge-utils
# optionally
apt install -y openssh-server iptables iptables-persistent net-tools vim

# dhcpd config
NET=${IPADDRESS%\.*} # 192.168.5
[ -r /etc/dhcp/dhcpd.conf.org ] || mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.org
sed "s/__NET__/${NET}/g" etc/dhcp/dhcpd.conf > /etc/dhcp/dhcpd.conf
#[ -r /etc/default/isc-dhcp-server.org ] || mv /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.org
# This tells only to serve bridge br0. A physical adapter will be added later. 
# This allows the dhcp server to start up
#sed "s/br0/${DEVICE}/g" etc/default/isc-dhcp-server > /etc/default/isc-dhcp-server

# Make bridge br0
nmcli con delete br0 br0-slave if_server 2>/dev/null
nmcli con add con-name br0 type bridge ifname br0 
nmcli con modify br0 ipv4.addr "${IPADDRESS}/24" ipv4.method manual
# add at least one interface to the bridge, but more are ok as well. But don't add an interface
# that is already connected to an existing network (with dhcp server)
nmcli c add con-name br0-slave type bridge-slave ifname ${DEVICE} master br0
nmcli con up br0

function enable_nat () {
  DEV_PUBLIC=$1
  DEV_LAN=$2
  # Your public interface is ${DEV_PUBLIC} and local interface is ${DEV_LAN}

  #1- Enable forwarding on the box
  sysctl -w net.ipv4.ip_forward=1
  sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf

  #2- Set natting the natting rule (symmetic NAT):
  iptables -t nat -A POSTROUTING -o ${DEV_PUBLIC} -j MASQUERADE --random

  #3- Accept traffic from ${DEV_LAN}:
  iptables -A INPUT -i ${DEV_LAN} -j ACCEPT

  #4- Allow established connections from the public interface.
  iptables -A INPUT -i ${DEV_PUBLIC} -m state --state ESTABLISHED,RELATED -j ACCEPT

  #5- Allow outgoing connections:
  iptables -A OUTPUT -j ACCEPT
}

if [ ! -z $NAT_DEVICE ]; then
  netfilter-persistent flush
  enable_nat $NAT_DEVICE $DEVICE
  netfilter-persistent save
else
  sed -i "s/net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/g" /etc/sysctl.conf
  netfilter-persistent flush
fi
#nmcli con delete if_server 2>/dev/null
#nmcli con add con-name if_server type ethernet ifname ${DEVICE} ipv4.method manual ipv4.address ${IPADDRESS}/24
#nmcli con up if_server

#httpd server config

# tftp config is ok, just add the data
# see also https://ipxe.org/howto/chainloading
# note that this version has NFS support added, so don't download directly from ipxe.org
cp srv/tftp/undionly.kpxe srv/tftp/ipxe.efi /srv/tftp/

#nfs
# Define nfs exports:
mkdir -p /srv/nfs
grep -E "^/srv/nfs"      /etc/exports >/dev/null || cp etc/exports /etc/exports

function make_menu () {
  # First determine the init ramdisk file name as Cubic changes the extention depending on the compression used (lz/gz)
  INITRD=/casper/initrd.lz
  INITRD=$(awk '/initrd/ {print $2;exit}' /srv/nfs/mint/boot/grub/grub.cfg)
  [ -r /var/www/html/demo_index.html ] || mv /var/www/html/index.html /var/www/html/demo_index.html
  sed "s/__IP__/${IPADDRESS}/g" var/www/html/menu  > /var/www/html/menu
  sed -i "s/__DESCRIPTION__/${COMMENT}/g" /var/www/html/menu
  sed -i "s%__INITRD__%${INITRD}%g" /var/www/html/menu
}

# what kind of source?
if [ -r $ISO ]; then
  if [ "$RW_MOUNT" == "y" ]; then
    source_iso_rw
  else
    source_iso_ro
  fi
elif [ -d "$CUBIC" ]; then
  source_cubic
fi

# Restart the services
exportfs -rva
systemctl daemon-reload
systemctl disable isc-dhcp-server6.service
systemctl restart isc-dhcp-server.service
systemctl restart nfs-server
mount -a

# Create IPXE menu
make_menu
