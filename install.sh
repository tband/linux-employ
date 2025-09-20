#!/usr/bin/env bash
# Add check for iso on encrypted home directory
VERSION=1.1.2
# ISO is the image locally available
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

# Parse command-line options
prog_name=$(basename $0)
# Define help message
help="
${prog_name}
  --iso,-i      <file> distro.iso
  --iso32       <file> distro32.iso (for the 32 bit PXE menu)
  --rw          Make the /srv/nfs mount writable. The iso will be unpacked
                instead of mounted
  --cubic <project directory>
                Instead of an iso use the project directory from which cubic
                makes a custom iso. This allows to edit the preseed files
                without recreating the iso
  --install_cubic
                Install Cubic according to the instructions on the Cubic 
                github page: (https://github.com/PJ-Singh-001/Cubic)
  -c, --comment <text>
                What text to put in the iPXE menu, default \"$COMMENT\"
  --device,-d <eth>
                ethernet device to use if there are more than one
  --nat <device>
                setup nat to this device. Clients will have internet from this device
                (Wifi adapter). Only set this up if you indeed have internet!
  --nonat       Disable NAT (default). Clients will not have internet.
  --ip,-n <ip>
                Server IP addres (default $IPADDRESS)
  --check       Check the status of the running services (dhcpd tftpd apache nfs)
                and exit
  --help,-h     This help

Configure a Linux system to become a IPXE server for Linux installation on
clients. Most arguments are optional, but you need at least to specify the iso
location or the Cubic project directory.
  
Examples:
  sudo ./${prog_name} -d $DEVICE -i linuxmint.iso -c \"Linux Mint\"
  sudo ./${prog_name} -nat wlp2s0
  sudo ./${prog_name} -nonat
"

if [ $# == 0 ]; then
  echo "$help"
  exit 1
fi
# Parse long options
OPTIONS=$(getopt -o i:c:d:n:wvhH --long iso:,iso32:,cubic:,install_cubic,comment:,device:,nat:,nonatt,ip:,rw,version,check,help -- "$@")

# Check if getopt returned an error
if [ $? -ne 0 ]; then
    echo "Error: Invalid options." >&2
    exit 1
fi
eval set -- "$OPTIONS"

function install_cubic () {
  apt-add-repository universe
  apt-add-repository ppa:cubic-wizard/release
  apt update
  apt install --no-install-recommends cubic
}

function check_services () {
  systemctl status isc-dhcp-server tftpd-hpa apache2|grep -C1 "Loaded"
  systemctl status nfs-kernel-server|grep -E "●|Loaded|Active"
}

# Initialize variables
DEVICE_OK=""
NAT_DEVICE=""
ISO32=""

while true; do
  case "$1" in
    -i|--iso) ISO="$2"; shift 2;;
    --iso32) ISO32="$2"; shift 2;;
    --cubic)CUBIC="$2"; shift 2;;
    --install_cubic)install_cubic; exit 0;;
    -c|--comment) COMMENT="$2"; shift 2;;
    -d|--device) DEVICE="$2"; DEVICE_OK="t"; shift 2;;
    --nat) NAT_DEVICE="$2"; shift 2;;
    --nonatt) shift 1;;
    -n|--ip) IPADDRESS="$2"; shift 2;;
    -w|--rw) RW_MOUNT="y"; shift;;
    -v|--version)echo Linux-employ version $VERSION; exit 0;;
    --check) check_services;exit 0;;
    -h|--help) echo "$help"; exit 1;;
    --) shift; break;;
    *) echo "$help"; exit 1;;
  esac
done

function remove_mint_mount () {
    umount -l /srv/nfs/mint 2>/dev/null
    mkdir -p /srv/nfs/mint
    sed -i '/\/srv\/nfs\/mint/d' /etc/fstab
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

function source_iso_ro32 () {
    if [[ ! -r $ISO32 ]] then
      echo -e "ERROR: cannot read $ISO32"
      exit 1
    fi
    # Remove existing mount point from previous install
    umount -l /srv/nfs/mint32 2>/dev/null
    mkdir -p /srv/nfs/mint32
    sed -i '/\/srv\/nfs\/mint32/d' /etc/fstab
    echo "$ISO32   /srv/nfs/mint32    auto  x-systemd.requires=/,ro    0  0" >> /etc/fstab
}

function source_iso_rw () {
    check_iso
    remove_mint_mount
    # One time mount to copy data
    mkdir -p /mnt/iso
    mount -o loop,ro $ISO /mnt/iso
    rsync -ai --delete /mnt/iso/ /srv/nfs/mint/
    rsync -ai --delete preseed /srv/nfs/mint/
    umount /mnt/iso
}

function check_adapters () {
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
}

function install_packages () {
  # update the repo first
  apt update
  # install packages
  apt install -y isc-dhcp-server tftpd-hpa apache2 nfs-kernel-server bridge-utils libarchive-tools
  # optionally
  apt install -y openssh-server iptables iptables-persistent net-tools vim

  # A bridge allows the dhcp server to start up

  # Make bridge br0
  nmcli con delete br0 br0-slave if_server 2>/dev/null
  nmcli con add con-name br0 type bridge ifname br0 
  nmcli con modify br0 ipv4.addr "${IPADDRESS}/24" ipv4.method manual
  # add at least one interface to the bridge, but more are ok as well. But don't add an interface
  # that is already connected to an existing network (with dhcp server)
  nmcli c add con-name br0-slave type bridge-slave ifname ${DEVICE} master br0
  nmcli con up br0
}

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


if [ ! -z $ISO32 ]
then
  ISO32=$(readlink -f $ISO32)
  source_iso_ro32
fi

ISO=$(readlink -f $ISO)
if [[ ! -z $CUBIC  && -d "$CUBIC" ]] then
  if [[ -r $ISO ]] then
    echo -e "ERROR: Either specify an ISO or a CUBIC project folder, not both"
    exit 1
  fi
fi

function make_menu () {
  # First determine the init ramdisk file name as Cubic changes the extention depending on the compression used (lz/gz)
  #INITRD=/casper/initrd.lz
  INITRD=$(awk '/initrd/ {print $2;exit}' /srv/nfs/mint/boot/grub/grub.cfg)
  [ -r /var/www/html/demo_index.html ] || mv /var/www/html/index.html /var/www/html/demo_index.html
  sed "s/__IP__/${IPADDRESS}/g" var/www/html/menu  > /var/www/html/menu
  sed -i "s/__DESCRIPTION__/${COMMENT}/g" /var/www/html/menu
  sed -i "s%__INITRD__%${INITRD}%g" /var/www/html/menu
}

if [[ -d "$CUBIC" || -r $ISO ]] then
  check_adapters
  install_packages
  # tftp config is ok, just add the data
  # see also https://ipxe.org/howto/chainloading
  # note that this version has NFS support added, so don't download directly from ipxe.org
  cp srv/tftp/undionly.kpxe srv/tftp/ipxe.efi /srv/tftp/

  #nfs
  # Define nfs exports:
  mkdir -p /srv/nfs
  grep -E "^/srv/nfs"      /etc/exports >/dev/null || cp etc/exports /etc/exports
fi

# what kind of source?
if [ -n "$ISO" ] && [ -r "$ISO" ]; then
  if [ "$RW_MOUNT" == "y" ]; then
    source_iso_rw
  else
    source_iso_ro
  fi
elif [ -d "$CUBIC" ]; then
  source_cubic
fi

# dhcpd config
NET=${IPADDRESS%\.*} # 192.168.5
[ -r /etc/dhcp/dhcpd.conf.org ] || mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.org
sed "s/__NET__/${NET}/g" etc/dhcp/dhcpd.conf > /etc/dhcp/dhcpd.conf

# NAT?
if [ ! -z $NAT_DEVICE ]; then
  netfilter-persistent flush
  enable_nat $NAT_DEVICE $DEVICE
  netfilter-persistent save
else
  sed -i "/^\s*net.ipv4.ip_forward=1/      {s/^/#/}" /etc/sysctl.conf
  sed -i '/^\s*option routers/             {s/^/#/}' /etc/dhcp/dhcpd.conf
  sed -i '/^\s*option domain-name-servers/ {s/^/#/}' /etc/dhcp/dhcpd.conf
  netfilter-persistent flush
  netfilter-persistent save
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
