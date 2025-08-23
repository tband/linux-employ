# linux-employ
This project is for employing (or should I say deploying..) Linux. It's part of the Dutch [Linux Repair Cafe](https://www.repaircafe.org/linux-repair-cafe/) initiative where interested users are supported to give their laptop a second life by installing Linux. The main goal is to prevent e-waste.

This project creates a server for decentralized installation using network boot (IPXE). As the Repair Cafe locations not always have internet access the image to install has already been created and is available on the server. The image itself can be downloaded here : https://sourceforge.net/projects/linux-iso/files<br/>
If only a few computers need to be installed, creating a bootable USB stick is easier. If the amount of installations is larger, a centralized server is more convient.
Apart from installation the server also let's you quickly boot into a Live CD without installation.

## Quick start
1. A computer that has a Gigabit ethernet adaptor. Any laptop is fine.
2. Install a Debian based version of Linux (as apt is used). I've tested it with Debian and Mint
3. Logon to your server and issue these commands (you do need internet)
```
   git clone https://github.com/tband/linux-employ.git 
   cd linux-employ/
   wget -O linuxmint-repair-2025-08-05.iso https://sourceforge.net/projects/linux-iso/files/linuxmint-repair-2025-08-05.iso/download
   wget -O linuxmint-repair-2025-08-05.md5 https://sourceforge.net/projects/linux-iso/files/linuxmint-repair-2025-08-05.md5/download
   md5sum -c linuxmint-repair-2025-08-05.md5
   #     linuxmint-repair-2025-08-05.iso: OK
   sudo ./install.sh -i linuxmint-repair-2025-08-05.iso
```

The ethernet device on a laptop is normally not used unless you plug in a cable. More likely you use a wireless interface. The script uses your ethernet port for the wired network. Connect the ethernet port to a switch with sufficient ports and connect the client computers to this switch. Finally network boot the clients and you should be greeted by the PXE boot menu.
## iPXE Boot menu
This script is prepared for a Live ISO of Mint (which is supplied with the -i argument). It can be downloaded from https://sourceforge.net/projects/linux-iso/files/ <br/>
You can also download from https://www.linuxmint.com/download.php but in that case the OEM install will not contain preseeded answers to the installer questions. The --rw option makes the ISO writable by first unpacking it and then adding all preseed data. The result is similar to using the ISO from sourceforge.net/projects/linux-iso/files, except that this version has already received a recent package update. The vanilla Mint images have slightly outdated packages that will be updated when the user boots the first time (at home).
After installation you can customize the boot menu at /var/www/html/menu to add you own boot options.
<img width="716" height="395" alt="image" src="https://github.com/user-attachments/assets/a6e7441b-237c-4adb-91e2-2eb7c7fe14ca" />

## Overview of setup
A DHCP server is setup to deliver an IP address in the range (192.168.5.150 192.168.5.200). The server address is 192.168.5.1. The client computer uses PXE to boot from the network. This needs so be enabled in the BIOS or sometimes by pressing a key like F12.<br/>
The DHCP server lets the client boot a more advanced IPXE bootloader by TFTP<br/>
The IPXE bootloader shows a menu to the client. This menu comes from http://192.168.5.1/menu.<br/>
The client chooses an entry from the list.<br/>
The chosen entry is loaded from an NFS share (nfs:/srv/mnt) which the client mounts as /cdrom. As far as the client computer is concerned, it's a local CDROM boot.<br/>
If the "Repair Cafe automated OEM install, NO QUESTIONS - disk overwritten" menu item is chosen, the preseed questions are loaded from /srv/nfs/mint/preseed/seed/linuxmint_custom.seed (/cdrom/preseed/seed/linuxmint_custom.seed) and installation proceeds without having to answer any question.
### commandline help
```
$ ./install.sh -h

install.sh [--iso <ISO> --comment <COMMENT> --device <DEVICE> --ip <IPADDRESS> --rw --help]
  --iso,-i      <file> distro.iso
  --rw          Make the /srv/nfs mount writable. The iso will be unpacked
                instead of mounted
  --cubic <project directory>
                Instead of an iso use the project directory from which cubic
                makes a custom iso. This allows to edit the preseed files
                without recreating the iso
  -c, --comment <text> What text to put in the iPXE menu, default Linux repair iso
  --device,-d   <eth>  device to use if there are more than one
  --nat         setup nat to this device. Internet from this device (Wifi adapter) is shared
  --ip          <ip>   Server IP addres (default 192.168.5.1)
  --h,-h        This help

Configure a Linux system to become a IPXE server for Linux installation on
clients. All arguments are optinal, but you want at least to specify the iso
location or the Cubic project directory.
  
Example:
  sudo ./install.sh -i linuxmint.iso -c "Linux Mint"

```

## Update
Download a new iso and repeat the installation. That's the easiest way to do it and means only one iso will be available for install.
If you want to have multiple isos available, you have to put the content of each in a folder under /srv/nfs. For example /srv/nfs/mint and /srv/nfs/ubuntu. In that case you add IPXE menu entries by editing /var/www/htlm/menu
## EFI or BIOS boot?
Both will work but EFI boot tends to be a bit slower.
## Internet access
The 192.168.5.1/24 network does not provide internet. 
This is done such that the Mint installation speeds up. This setup is suited for repair cafes that do not have unlimited free internet access.<br/>
There is one exception and that is http://191.168.1.5 .<br/>
You can store a copy of a website under /var/www/html to create a working site at 
for instance "http://191.168.1.5/Linux_Repair_Café_geeft_laptops_een_langer_leven.html"
### Enabling internet
The --nat option can be given to enable a nat network. Only enable if you have internet as otherwise installation will be slower.
## Uninstall
In case you get stuck you can uninstall :
```
   sudo ./uninstall.sh
```
## Wiki
See https://github.com/tband/linux-employ/wiki for even more details.
