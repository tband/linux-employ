# linux-employ
This script is for employing (or should I say deploying..) Linux. It's part of the Dutch [Linux Repair Cafe](https://www.repaircafe.org/linux-repair-cafe/) initiative where interested users are supported to give their laptop a second life by installing Linux. The main goal is prevent e-waste.

This project creates a server for decentralized installation using network boot (IPXE). As the Repair Cafe locations not always have internet access the image to install has already been created and is available on the server. The image itself can be downloaded here : https://sourceforge.net/projects/linux-iso/files<br/>
If only a few computers need to be installed, creating a bootable USB stick is easier. If the amount of installations is larger, a centralized server is more convient.

## Quick start
1. A computer that has a Gigabit ethernet adaptor. Any laptop is fine.
2. Install a Debian based version of Linux (as apt is used). I've tested it with Debian and Mint
3. Logon to your server and issue these commands (you do need internet)
```
   git clone https://github.com/tband/linux-employ.git 
   cd linux-employ/ 
   sudo ./install.sh -i <path_to_iso>
```

The ethernet device on a laptop is normally not used unless you plug in a cable. More likely you use a wireless interface. The script uses your ethernet port for the wired network.
## iPXE Boot menu
This script is prepared for a Live ISO of Mint (which is supplied with the -i argument). It can be downloaded from https://sourceforge.net/projects/linux-iso/files/ <br/>
You can also download from https://www.linuxmint.com/download.php but that will not contain the preseeded installer questions.
After installation you can customize the boot menu at /var/www/html/menu to add you own boot options.
## Overview of setup
A DHCP server is setup to deliver an IP address in the range (192.168.5.150 192.168.5.200). The server address is 192.168.5.1. The client computer uses PXE to boot from the network (this needs so be enabled in the BIOS).<br/>
The DHCP server lets the client boot a more advanced IPXE bootloader (TFTP)<br/>
The IPXE bootloader shows a menu to the client. This menu comes from http://192.168.5.1/menu.<br/>
The client chooses an entry from the list.<br/>
The chosen entry is loaded from an NFS share (nfs:/srv/mnt) which the client mounts as /cdrom. As far as the client is concerned, it's a local CDROM boot.
### commandline help
```
$ ./install.sh -h

./install.sh [-idnwhH]
  -i  <file>  distro.iso (default linux_repair_r1.iso)
  -d  <eth>   device
  -n  <ip>    Server IP addres (default 192.168.5.1)
  -w          Make the /srv/nfs mount writable. The iso will be unpacked instead of mounted
  -h          This help

Configure a Linux system to become a IPXE server for ISO installation on clients
All arguments are optinal, but you want at least to specify the iso location
  
Example:
  ./install.sh -d enp2s0 -i linux_repair_r1.iso
```

## Uninstall
In case you get stuck you can uninstall :
```
   sudo ./uninstall.sh
```
