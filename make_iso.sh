#!/usr/bin/env bash
# Parse command-line options
prog_name=$(basename $0)
# Define help message
help="
${prog_name}
  -i      <file> input.iso
  -o      <file> output.iso
  --chroot This option gives a root shell in the ISO to make modifications. Things you can
           do is adding, removing packages with apt-get. Note this part will run with sudo.
  --help,-h     This help

Create a new ISO with preseed embedded
Examples:
  ./${prog_name} -i linuxmint-22.2-cinnamon-64bit.iso -o linuxmint-22.2-cinnamon-64bit_preseeded.iso
"

# Parse long options
OPTIONS=$(getopt -o i:o:hH --long chroot -- "$@")

# Check if getopt returned an error
if [ $? -ne 0 ]; then
    echo "Error: Invalid options." >&2
    exit 1
fi
eval set -- "$OPTIONS"

# Initialize variables
unset CHROOT
while true; do
  case "$1" in
    -i) ISO_IN="$2"; shift 2;;
    -o) ISO_OUT="$2"; shift 2;;
    -h|--help) echo "$help"; exit 1;;
    --chroot) CHROOT=1; shift 1;;
    --) shift; break;;
    *) echo "$help"; exit 1;;
  esac
done

if [[ ! -r $ISO_IN ]] then
  echo -e "ERROR: cannot read $ISO_IN, use -i argument"
  exit 1
fi

if [[ -z $ISO_OUT ]] then
  echo -e "ISO OUT leeg"
  ISO_OUT=${ISO_IN%.*}_modified.iso
  ISO_OUT=$(basename $ISO_OUT)
fi

ISO_IN_NAME=$(basename ${ISO_IN%.*})
# iso name must be <= 32 characters
ISO_IN_NAME=${ISO_IN_NAME:0:32}
TMPFS_SIZE=$(df /dev/shm|awk '/tmpfs/ {print $4}')
ISO_DIR=/tmp/iso
# If more than 6G ava
ISO_SIZE=$(stat -L --format=%s $ISO_IN)
if [ ! -z $CHROOT ]
then
    ISO_SIZE=$(($ISO_SIZE/2**10*33/10))
else
    ISO_SIZE=$(($ISO_SIZE/2**10*11/10))
fi
if [ $TMPFS_SIZE -gt $ISO_SIZE ];
then
  ISO_DIR=/dev/shm/iso
fi

ISO_FILES=$ISO_DIR/$ISO_IN_NAME
mkdir -p $ISO_DIR
mkdir -p $ISO_FILES
#cd $ISO_DIR
#rtorrent https://www.linuxmint.com/torrents/linuxmint-22.2-cinnamon-64bit.iso.torrent
if ! command -v bsdtar > /dev/null
then
  apt install libarchive-tools
fi
bsdtar -C $ISO_FILES --acls -xf $ISO_IN
find $ISO_FILES -type f -exec chmod +w \{} \;
find $ISO_FILES -type d -exec chmod +w \{} \;
cp -pr preseed/ $ISO_FILES/

# Check if the Repar Cafe menu item has already been added and if not add them to isolinux and grub
if ! grep -q "Repair Cafe" $ISO_FILES/boot/grub/grub.cfg
then
  INITRD=$(awk '/initrd/ {print $2;exit}' $ISO_FILES/boot/grub/grub.cfg)
  # $ISO_FILES/boot/grub/grub.cfg
  unattendedOEM="menuentry \"Repair Cafe automated OEM install, NO QUESTIONS - disk overwritten\" --class linuxmint {
	linux	/casper/vmlinuz file=/cdrom/preseed/seed/linuxmint_custom.seed boot=casper -- auto noprompt automatic-ubiquity
	initrd	${INITRD}
}
"
  awk -vunattendedOEM="$unattendedOEM" '/OEM install/ {print unattendedOEM} ; {print}' $ISO_FILES/boot/grub/grub.cfg > $ISO_FILES/boot/grub/grub.cfg_new
  mv $ISO_FILES/boot/grub/grub.cfg_new $ISO_FILES/boot/grub/grub.cfg

  #  $ISO_FILES/isolinux/live.cfg
  unattendedOEM="label unattendedOEM
  menu label Repair Cafe OEM install, NO Questions - disk overwritten
  kernel /casper/vmlinuz
  append  DEBCONF_DEBUG=5 file=/cdrom/preseed/seed/linuxmint_custom.seed oem-config/enable=true boot=casper initrd=/casper/initrd.lz -- auto noprompt automatic-ubiquity
"
awk -vunattendedOEM="$unattendedOEM" '/label oem/ {print unattendedOEM} ; {print}' $ISO_FILES/isolinux/live.cfg > $ISO_FILES/isolinux/live.cfg_new
mv $ISO_FILES/isolinux/live.cfg_new $ISO_FILES/isolinux/live.cfg

  cp misc/splash.png $ISO_FILES/isolinux/
fi

#set|grep ISO_ ; exit

if [ ! -z $CHROOT ]
then
  # and extra unmount just to be sure :-)
  sudo umount $ISO_DIR/squashfs/dev/ $ISO_DIR/squashfs/proc/ 2>/dev/null
  sudo rm -rf $ISO_DIR/squashfs/
  sudo unsquashfs -d $ISO_DIR/squashfs $ISO_FILES/casper/filesystem.squashfs
  sudo mount -o bind /dev/ $ISO_DIR/squashfs/dev/
  sudo mount -o bind /proc/ $ISO_DIR/squashfs/proc/
  sudo cp -L /etc/resolv.conf $ISO_DIR/squashfs/etc/
  sudo cp $ISO_FILES/preseed/etc/apt/sources.list.d/official-package-repositories.list \
          $ISO_DIR/squashfs/etc/apt/sources.list.d/official-package-repositories.list
  sudo cp $ISO_FILES/preseed/scripts/chroot.sh $ISO_DIR/squashfs/tmp
  sudo chroot $ISO_DIR/squashfs /tmp/chroot.sh
  echo ""
  echo "Entering chroot environment of $ISO_IN_NAME"
  echo "Please make modification as needed and continue with 'exit'"
  sudo chroot $ISO_DIR/squashfs
  sudo rm $ISO_DIR/squashfs/etc/resolv.conf
  sudo umount $ISO_DIR/squashfs/dev/ $ISO_DIR/squashfs/proc/

  sudo rm $ISO_FILES/casper/filesystem.squashfs
  # this take 90s seconds on a 8 core i7-4790K 4GHz CPU
  sudo mksquashfs $ISO_DIR/squashfs $ISO_FILES/casper/filesystem.squashfs
fi

genisoimage -U -r -v -T -J -joliet-long -V "$ISO_IN_NAME" -volset "$ISO_IN_NAME" -A "$ISO_IN_NAME" \
  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -eltorito-boot efi.img -no-emul-boot -o $ISO_OUT -quiet $ISO_FILES

if [ ! -z $CHROOT ]
then
  sudo rm -rf $ISO_DIR
else
  rm -rf $ISO_DIR
fi

echo "$ISO_OUT has been created"
sha256sum $ISO_OUT > ${ISO_OUT%.*}.sha256sum
ls -l $ISO_OUT ${ISO_OUT%.*}.sha256sum
