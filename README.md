# linux-employ
This script is for employing (or should I say deploying..) Linux. It's part of the Dutch [Linux Repair Cafe](https://www.repaircafe.org/linux-repair-cafe/) initiative where interested users are helped to give their laptop a second life by installing Linux.

This project creates a server for decentralized installation using network boot (IPXE). As the Repair Cafe locations not always have internet the image to install has already been created and is available on the server. The image itself can be downloaded here : https://sourceforge.net/projects/linux-iso/files

## Quick start
1. A computer that has a Gigabit ethernet adaptor. Any laptop is fine.
2. Install a Debian based version of Linux (as apt is used). I've tested it with Debian and Mint
3. Logon to your server as root and issue these commands (you need internet)
   git clone https://github.com/tband/linux-employ.git
   cd linux-employ/
   \# Edit INTERFACE and ISO in the next script then start
   \# determine INTERFACE by looking at the DEVICE column of the output of "nmcli device"
   ./install.sh

The INTERFACE (or ethernet device) on a laptop is normally not used unless you plug in a cable. More likely you use a wireless interface.
## Overview of setup
A DHCP server is setup to deliver an IP address in the range (192.168.5.150 192.168.5.200) to the chosen ethernet adapter. The server address is 192.168.5.1. The client computer uses PXE to boot from the network (this can be enable in the BIOS). 
The DHCP server lets the client boot from a more advanced IPXE bootloader (TFTP)
The IPXE bootloader shows a menu to the client. This menu comes from http:192.168.5.1/menu
The client chooses an entry from the list.
The chosen entry is loaded from an NFS share (nfs:/srv/mnt) which the client mounts as /cdrom. As far as the client is concerned, it's a local CDROM boot.
