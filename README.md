# Linux Employ Project Overview

The **Linux Employ** project is part of the Dutch [**Linux Repair Cafe**](https://www.repaircafe.org/linux-repair-cafe/) initiative, aimed at giving laptops a second life by installing Linux and preventing e-waste. This project sets up a server for centralized installation using network boot (iPXE), allowing users to install Linux even in locations without internet access.

### Key Features
- **Centralized Installation Server**: Ideal for multiple installations, reducing the need for USB sticks.
- **Live CD Boot**: Quickly boot into a Live CD without installation.
- **Preseeded Installations**: Automate the installation process with preconfigured settings.
- **No internet needed**": Image is stored on server

## Quick Start Guide

To get started, follow these steps:

1. **Requirements**:
   - A computer with a **Gigabit Ethernet adapter** (any laptop or demo PC will do).
   - A **Debian-based Linux** distribution (Debian or Mint recommended).

2. **Installation Steps**:
   - Log in to your server and run the following commands (internet access required):
   ```bash
   git clone https://github.com/tband/linux-employ.git 
   cd linux-employ/
   wget -O linuxmint-repair-2025.08.28.iso https://sourceforge.net/projects/linux-iso/files/linuxmint-repair-2025.08.28.iso/download
   wget -O linuxmint-repair-2025.08.28.md5 https://sourceforge.net/projects/linux-iso/files/linuxmint-repair-2025.08.28.md5/download
   md5sum -c linuxmint-repair-2025.08.28.md5
     #  linuxmint-repair-2025.08.28.iso: OK
   sudo ./install.sh --iso linuxmint-repair-2025.08.28.iso

 3. **Network Setup**:
    - Connect the Ethernet port to a switch with enough ports.
    - Connect client computers to the switch.
    - Network boot the clients to access the PXE boot menu.


## iPXE Boot menu
The iPXE boot menu is prepared for a Live ISO of Mint. It can be downloaded from [SourceForge](https://sourceforge.net/projects/linux-iso/files/) or
[Linux Mint](https://www.linuxmint.com/download.php). Note that using the latter does not include preseeded answers. 

- The `--rw` option makes the ISO writable, and preseed data will be added (in case the ISO is not preseeded)
- After installation, customize the boot menu at /var/www/html/menu

<img width="716" height="395" alt="image" src="https://github.com/user-attachments/assets/a6e7441b-237c-4adb-91e2-2eb7c7fe14ca" />

## Setup overview
A DHCP server is setup to deliver an IP address in the range (192.168.5.150 192.168.5.200). The server address is 192.168.5.1. The client computer uses PXE to boot from the network. This needs so be enabled in the BIOS or sometimes by pressing a key like F12.<br/>
The DHCP server lets the client boot a more advanced IPXE bootloader by TFTP<br/>
The IPXE bootloader shows a menu to the client. This menu comes from http://192.168.5.1/menu.<br/>
The client chooses an entry from the list.<br/>
The chosen entry is loaded from an NFS share (nfs:/srv/mnt) which the client mounts as /cdrom. As far as the client computer is concerned, it's a local CDROM boot.<br/>
If the "Repair Cafe automated OEM install, NO QUESTIONS - disk overwritten" menu item is chosen, the preseed questions are loaded from /srv/nfs/mint/preseed/seed/linuxmint_custom.seed (/cdrom/preseed/seed/linuxmint_custom.seed) and installation proceeds without having to answer any question.
### commandline help
```
$ ./install.sh -h

install.sh
  --iso,-i      <file> distro.iso
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
                device to use if there are more than one
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
  sudo ./install.sh -d vboxnet0 -i linuxmint.iso -c "Linux Mint"
  sudo ./install.sh -nat wlp2s0
  sudo ./install.sh -nonat

```

## Update
To update the ISO, download a new one and repeat the installation. For multiple ISOs, place each in a separate folder under `/srv/nfs` (e.g., `/srv/nfs/mint` and `/srv/nfs/ubuntu`) and edit the iPXE menu at `/var/www/html/menu`.

## Boot Options: EFI vs. BIOS
Both EFI and BIOS boot options are supported, but EFI boot tends to be a bit slower.
## Internet access
The 192.168.5.1/24 network does not provide internet. 
This is done such that the Mint installation speeds up. This setup is suited for repair cafes that do not have unlimited free internet access.<br/>
There is one exception and that is http://191.168.1.5 .<br/>
You can store a copy of a website under /var/www/html to create a working site at 
for instance "http://191.168.1.5/Linux_Repair_Café_geeft_laptops_een_langer_leven.html"
### Enabling internet
The --nat option can be given to enable a nat network. Only enable if you have internet as otherwise installation will be slow.
## Uninstall
In case you get stuck you can uninstall :
```
   sudo ./uninstall.sh
```
## Wiki
See https://github.com/tband/linux-employ/wiki for even more details.
