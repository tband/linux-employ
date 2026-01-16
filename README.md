# Linux Employ Project Overview

The **Linux Employ** project is part of the Dutch [**Linux Repair Cafe**](https://www.repaircafe.org/linux-repair-cafe/) initiative, aimed at giving laptops a second life by installing Linux and preventing e-waste. A script adds preseed data to an existing distribution ISO image to speed up the installation.
The preseeded image can be flashed to an USB stick or served from a iPXE server for centralized installation.

### Key Features
- **ISO generator**: Add preseed data and manage packages to be installed (add, remove or update)
- **Centralized Installation Server**: Ideal for multiple installations, reducing the need for USB sticks.
- **Live CD Boot**: Quickly boot into a Live CD without installation.
- **Preseeded Installations**: Automate the installation process with preconfigured settings.
- **No internet needed**: Image is stored on server

## Quick Start Guide

To get started, follow these steps:

1. **Requirements**:
   - A computer with a **Gigabit Ethernet adapter** (any laptop or demo PC will do).
   - A **Debian-based Linux** distribution (Debian or Mint recommended).

2. **Installation Steps**:
   - Create or download an installation ISO image of Linux Mint. See [**make_iso**](https://github.com/tband/make_iso)
   - Install the server components
   ```bash
   # Both a 32-bit and a (standard) 64-bit can be specified
   sudo ./install.sh --iso   linuxmint-22.3-cinnamon-64bit_preseeded.iso \
                     --iso32 lmde-6-cinnamon-32bit.iso \
                     --comment "Linux Mint 22.3"
                     
   ```

 3. **Network Setup**:
    - Connect the Ethernet port to a switch with enough ports.
    - Connect client computers to the switch.
    - Network boot the clients to access the PXE boot menu.


## iPXE Boot menu
The iPXE boot menu is prepared for a Live ISO of Mint.

- After installation, the menu is present at /var/www/html/menu:

<img width="716" height="393" alt="image" src="https://github.com/user-attachments/assets/f71b35d7-f888-4ce6-a781-b7daf4e78493" />

## Setup overview
A DHCP server is setup to deliver an IP address in the range (192.168.5.150 192.168.5.200). The server address is 192.168.5.1. The client computer uses PXE to boot from the network. This needs so be enabled in the BIOS or sometimes by pressing a key like F12.<br/>
The DHCP server lets the client boot a more advanced iPXE bootloader using TFTP<br/>
The iPXE bootloader shows a menu to the client. This menu address is http://192.168.5.1/menu.<br/>
The client chooses an entry from the list.<br/>
The chosen entry is loaded from an NFS share (nfs:/srv/nfs) which the client mounts as /cdrom. As far as the client computer is concerned, it's a local CDROM boot.<br/>
If the "Repair Cafe automated OEM install, NO QUESTIONS - disk overwritten" menu item is chosen, the preseed questions are loaded from /srv/nfs/mint/preseed/seed/linuxmint_custom.seed (/cdrom/preseed/seed/linuxmint_custom.seed) and installation proceeds without having to answer any question.
### commandline help
```
$ ./install.sh -h

install.sh
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
                What text to put in the iPXE menu, default "Linux repair iso"
  --device,-d <eth>
                ethernet device to use if there are more than one
  --nat <device>
                setup nat to this device. Clients will have internet from this device
                (Wifi adapter). Only set this up if you indeed have internet!
  --nonat       Disable NAT (default). Clients will not have internet.
  --ip,-n <ip>
                Server IP addres (default 192.168.5.1)
  --check       Check the status of the running services (dhcpd tftpd apache nfs)
                and exit
  --help,-h     This help

Configure a Linux system to become a IPXE server for Linux installation on
clients. Most arguments are optional, but you need at least to specify the iso
location or the Cubic project directory.
  
Examples:
  sudo ./install.sh -d enp2s0 -i linuxmint.iso -c "Linux Mint"
  sudo ./install.sh -nat wlp2s0
  sudo ./install.sh -nonat

```

## Update
Use make_iso.sh --update to create an ISO with the latest updates. Just repeat the installation with the updated ISO.
## Multiple installation images (ISOs)
The default PXE menu is setup for two ISO images. One 64-bit (default) and one 32-bit for old computers. If more images need to be served place the content in a separate folder under `/srv/nfs` (e.g., `/srv/nfs/mint` and `/srv/nfs/ubuntu`). Either unpack the ISO to this location or better use a loop mount following the existing examples in /etc/fstab. Then reboot. As a last step edit the iPXE menu at `/var/www/html/menu` to add menu entries for the extra ISOs.
The iPXE menu already has an entry for 32-bit Mint installation (lmde). The lmde ISO of Mint cannot be preseeded so it will always start as Live.

## Boot Options: EFI vs. BIOS
Both EFI and BIOS boot options are supported, but EFI boot tends to be a bit slower. And if EFI is chosen you need to disable secure boot!
## Internet access
The 192.168.5.1/24 network does not provide internet unless specifically enabled.
This is done such that the Mint installation can be done from repair cafe locations that do not have unlimited internet access.<br/>
Simple static websites can be served from http://191.168.1.5 .<br/>
A copy of a website placed under /var/www/html gives a working site at 
for instance "http://191.168.1.5/Linux_Repair_Café_geeft_laptops_een_langer_leven.html".
### Enabling internet
The --nat option can be added to the install.sh script to enable a nat network. Only enable if you have internet as otherwise installation will be slow.
## Uninstall
In case you get stuck you can uninstall :
```
   sudo ./uninstall.sh
```
## Wiki
See https://github.com/tband/linux-employ/wiki for more details.
