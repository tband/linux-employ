#!/usr/bin/env bash
# Parse command-line options
prog_name=$(basename $0)
VERSION=$(cat .version)
# Define help message
help="
${prog_name}
  -i           <file> input.iso
  -o           <file> output.iso
  --update,-u  Update the packages.
  --chroot,-c  This option gives a root shell in the ISO to make modifications. Things you can
               do is adding, removing packages with apt-get.
  --version,-v Show version
  --help,-h    This help

Create a new ISO with preseed embedded
Examples:
  ./${prog_name} -i linuxmint.iso -o linuxmint_preseeded.iso
  ./${prog_name} -i linuxmint.iso -o linuxmint_updated.iso --update
"

# Parse long options
OPTIONS=$(getopt -o i:o:cudvhH --long chroot,update,version,debug -- "$@")

# Check if getopt returned an error
if [ $? -ne 0 ]; then
    echo "$help" >&2
    exit 1
fi
eval set -- "$OPTIONS"

# Initialize variables
unset UNSQUASH CHROOT DEBUG UPDATE
while true; do
  case "$1" in
    -i) ISO_IN="$2"; shift 2;;
    -o) ISO_OUT="$2"; shift 2;;
    -h|--help) echo "$help"; exit 1;;
    -c|--chroot) UNSQUASH=1; CHROOT=1;shift 1;;
    -u|--update) UNSQUASH=1; UPDATE=1;shift 1;;
    -v|--version)echo Linux-employ version $VERSION; exit 0;;
    -d|--debug) DEBUG=1;shift 1;;
    --) shift; break;;
    *) echo "$help"; exit 1;;
  esac
done

# All commands available?
command -v xorriso > /dev/null || sudo apt-get -y install xorriso isolinux
command -v bsdtar  > /dev/null || sudo apt-get -y install libarchive-tools

if [[ ! -r $ISO_IN ]] then
  echo -e "ERROR: cannot read $ISO_IN from -i argument"
  exit 1
fi

if [[ -z $ISO_OUT ]] then
  # remove the extension
  ISO_OUT=${ISO_IN%.*}
  # remove the date if the standard format yyyy-mm-dd is used
  ISO_OUT=${ISO_OUT%-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]}
  ISO_OUT=${ISO_OUT}-$(date +%F).iso
  echo -e "Output ISO=$ISO_OUT"
  ISO_OUT=$(basename $ISO_OUT)
fi

[ -r $ISO_OUT ] && echo "ERROR: target $ISO_OUT already exists" && exit 1

ISO_IN_NAME=$(basename ${ISO_IN%.*})
# iso name must be <= 32 characters
ISO_IN_NAME=${ISO_IN_NAME:0:32}
TMPFS_SIZE=$(df --output=avail /dev/shm|tail -1)
ISO_DIR=/tmp/iso
# If more than 6G ava
ISO_SIZE=$(stat -L --format=%s $ISO_IN)
if [ ! -z $UNSQUASH ]
then
    ISO_SIZE=$(($ISO_SIZE/2**10*40/10))
else
    ISO_SIZE=$(($ISO_SIZE/2**10*11/10))
fi
if [ $TMPFS_SIZE -gt $ISO_SIZE ];
then
  ISO_DIR=/dev/shm/iso
fi

ISO_FILES=$ISO_DIR/$ISO_IN_NAME

# print command when in debug
[ -z $DEBUG ] || set -x

mkdir -p $ISO_DIR
mkdir -p $ISO_FILES

bsdtar -C $ISO_FILES --acls -xf $ISO_IN
find $ISO_FILES -type f -exec chmod +w \{} \;
find $ISO_FILES -type d -exec chmod +w \{} \;
cp -pr preseed/ $ISO_FILES/

# Check if the Repar Cafe menu item has already been added and if not add them to isolinux and grub
if ! grep -q "Repair Cafe" $ISO_FILES/boot/grub/grub.cfg
then
  INITRD=$(awk '/initrd/ {print $2;exit}' $ISO_FILES/boot/grub/grub.cfg)
  # $ISO_FILES/boot/grub/grub.cfg
  splash="insmod png jpg all_video
background_image -m stretch /boot/grub/splash.png"
  awk -vsplash="$splash" '/set color_normal/ {print splash} ; {print}' $ISO_FILES/boot/grub/grub.cfg > $ISO_FILES/boot/grub/grub.cfg_new
  mv $ISO_FILES/boot/grub/grub.cfg_new $ISO_FILES/boot/grub/grub.cfg
  unattendedOEM=\
"menuentry \"Repair Cafe OEM install, NO QUESTIONS - disk overwritten\" --class linuxmint {
	linux	/casper/vmlinuz file=/cdrom/preseed/seed/linuxmint_custom.seed boot=casper -- auto noprompt automatic-ubiquity
	initrd	${INITRD}
}
menuentry \"Repair Cafe OEM install, One question: Setup disk\" --class linuxmint {
	linux	/casper/vmlinuz file=/cdrom/preseed/seed/linuxmint_custom_nodisk.seed boot=casper -- auto noprompt automatic-ubiquity
	initrd	${INITRD}
}
"
  awk -vunattendedOEM="$unattendedOEM" '/OEM install/ {print unattendedOEM} ; {print}' $ISO_FILES/boot/grub/grub.cfg > $ISO_FILES/boot/grub/grub.cfg_new
  mv $ISO_FILES/boot/grub/grub.cfg_new $ISO_FILES/boot/grub/grub.cfg

  #  $ISO_FILES/isolinux/live.cfg
  unattendedOEM="\
label unattendedOEM
  menu label Repair Cafe OEM install, NO Questions - disk overwritten
  kernel /casper/vmlinuz
  append  DEBCONF_DEBUG=5 file=/cdrom/preseed/seed/linuxmint_custom.seed oem-config/enable=true boot=casper initrd=/casper/initrd.lz -- auto noprompt automatic-ubiquity
label unattendedOEMnodisk
  menu label Repair Cafe OEM install, One question: Setup disk
  kernel /casper/vmlinuz
  append  DEBCONF_DEBUG=5 file=/cdrom/preseed/seed/linuxmint_custom_nodisk.seed oem-config/enable=true boot=casper initrd=/casper/initrd.lz -- auto noprompt automatic-ubiquity
"
  awk -vunattendedOEM="$unattendedOEM" '/label oem/ {print unattendedOEM} ; {print}' $ISO_FILES/isolinux/live.cfg > $ISO_FILES/isolinux/live.cfg_new
  mv $ISO_FILES/isolinux/live.cfg_new $ISO_FILES/isolinux/live.cfg

  cp misc/splash.png $ISO_FILES/isolinux/
  cp misc/splash.png $ISO_FILES/boot/grub/

  # Don't remove nl, en, de, fr, es language packs
  cp casper/filesystem.manifest-remove $ISO_FILES/casper

#language packages not to be removed, created like this:
#  for i in -nl -de -es -fr -gb -en
#  do
#    sed -i "/$i\$/d" $ISO_FILES/casper/filesystem.manifest-remove
#    sed -i "/$i-/d" $ISO_FILES/casper/filesystem.manifest-remove
#  done

fi


if [ ! -z $UNSQUASH ]
then
  # and extra unmount just to be sure :-)
  sudo umount $ISO_DIR/squashfs/dev/ $ISO_DIR/squashfs/proc/ 2>/dev/null
  sudo rm -rf $ISO_DIR/squashfs/
  sudo unsquashfs -d $ISO_DIR/squashfs $ISO_FILES/casper/filesystem.squashfs
  sudo mount -o bind /dev/ $ISO_DIR/squashfs/dev/
  sudo mount -o bind /proc/ $ISO_DIR/squashfs/proc/
  sudo mv $ISO_DIR/squashfs/etc/resolv.conf $ISO_DIR/squashfs/etc/resolv.conf.org
  sudo cp -L /etc/resolv.conf $ISO_DIR/squashfs/etc/
  sudo cp preseed/etc/apt/sources.list.d/official-package-repositories.list \
          $ISO_DIR/squashfs/etc/apt/sources.list.d/official-package-repositories.list
  if [ ! -z $UPDATE ]
  then
    sudo cp preseed/scripts/update.sh $ISO_DIR/squashfs/tmp
    sudo chroot $ISO_DIR/squashfs /tmp/update.sh
  fi
  if [ ! -z $CHROOT ]
  then
    echo ""
    echo "Entering chroot environment of $ISO_IN_NAME"
    echo "Please make modification as needed and continue with 'exit'"
    sudo chroot $ISO_DIR/squashfs
  fi
  sudo mv $ISO_DIR/squashfs/etc/resolv.conf.org $ISO_DIR/squashfs/etc/resolv.conf
  sudo umount $ISO_DIR/squashfs/dev/ $ISO_DIR/squashfs/proc/

  sudo rm $ISO_FILES/casper/filesystem.squashfs
  # this takes 90s seconds on a 8 core i7-4790K 4GHz CPU
  sudo mksquashfs $ISO_DIR/squashfs $ISO_FILES/casper/filesystem.squashfs -quiet -comp gzip
fi


if [ ! -z $DEBUG ]; then
  set|grep ISO_ ;
  exit
fi

# I can't get UEFI boot with dd to work
if false;then
  mkisofs -U -r -v -T -J -joliet-long -V "$ISO_IN_NAME" -volset "$ISO_IN_NAME" -A "$ISO_IN_NAME" -p "linux-employ"\
  -input-charset iso8859-1 \
  -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -eltorito-platform 0xEF -eltorito-boot boot/grub/efi.img -no-emul-boot \
  -o $ISO_OUT -quiet $ISO_FILES
  isohybrid --uefi $ISO_OUT
fi

if true;then
  [ -r /usr/lib/ISOLINUX/isohdpfx.bin ] && ISOHDPFX=/usr/lib/ISOLINUX/isohdpfx.bin
  [ -r /usr/lib/syslinux/bios/isohdpfx.bin ] && ISOHDPFX=/usr/lib/syslinux/bios/isohdpfx.bin
  [ -z $ISOHDPFX ] && echo "ERROR: Cannot find isohdpfx.bin" && exit 1
  xorriso -as mkisofs -isohybrid-mbr $ISOHDPFX -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o $ISO_OUT -quiet $ISO_FILES
fi

if [ -z $DEBUG ]
then
  if [ ! -z $UNSQUASH ]
  then
    sudo rm -rf $ISO_DIR
  else
    rm -rf $ISO_DIR
  fi
fi

sha256sum $ISO_OUT > ${ISO_OUT%.*}.sha256sum
echo "$ISO_OUT has been created"
ls -l $ISO_OUT ${ISO_OUT%.*}.sha256sum

echo
echo "To make a bootable pendrive:"
echo "list block devices and umount if auto mounted"
echo " lsblk # (find <X>)"
echo " sudo umount /dev/sd<X> or /dev/sd1<X>"
echo " sudo dd if=$ISO_OUT of=/dev/sd<X> oflag=direct bs=4M status=progress"
