#! /bin/sh

VERSION="[Chipsee BBBlack Expansion]"

execute ()
{
    $* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "ERROR: executing $*"
        echo
        exit 1
    fi
}

version ()
{
  echo
  echo "`basename $1` version $VERSION"
  echo "Script to create bootable SD card for Beagleboard-XM"
  echo

  exit 0
}

usage ()
{
  echo "
Usage: `basename $1` <options>

Mandatory options:
  --device              SD block device node (e.g /dev/sdc)
  --display             Display device (DVI or LCD)

Optional options:
  --version             Print version.
  --help                Print this help message.
"
  exit 1
}

# Process command line...
while [ $# -gt 0 ]; do
  case $1 in
    --help | -h)
      usage $0
      ;;
    --device) shift; device=$1; shift; ;;
    --version) version $0;;
  esac
done

test -z $device && usage $0

if [ ! -b $device ]; then
   echo "ERROR: $device is not a block device file"
   exit 1;
fi

echo "************************************************************"
echo "*         THIS WILL DELETE ALL THE DATA ON $device        *"
echo "*                                                          *"
echo "*         WARNING! Make sure your computer does not go     *"
echo "*                  in to idle mode while this script is    *"
echo "*                  running. The script will complete,      *"
echo "*                  but your SD card may be corrupted.      *"
echo "*                                                          *"
echo "*         Press <ENTER> to confirm....                     *"
echo "************************************************************"
read junk

for i in `ls -1 $device?`; do
 echo "unmounting device '$i'"
 umount $i 2>/dev/null
done

execute "dd if=/dev/zero of=$device bs=1024 count=1024"

# get the partition information.
total_size=`fdisk -l $device | grep Disk | awk '{print $5}'`
total_cyln=`echo $total_size/255/63/512 | bc`

# default number of cylinder for first parition
pc1=5

{
echo ,$pc1,0x0C,*
echo ,,,-
} | sfdisk -D -H 255 -S 63 -C $total_cyln $device

if [ $? -ne 0 ]; then
    echo ERROR
    exit 1;
fi

echo "Formating ${device}1 ..."
execute "mkfs.vfat -F 32 -n "boot" ${device}1"
echo "Formating ${device}2 ..."
execute "mkfs.ext3 -j -L "rootfs" ${device}2"

execute "mkdir -p /tmp/sdk"

echo "Copying u-boot/MLO/uImage on ${device}1"
execute "mkdir -p /tmp/sdk/$$"
execute "mount ${device}1 /tmp/sdk/$$"
execute "cp boot/MLO /tmp/sdk/$$/MLO"
execute "cp boot/u-boot.img /tmp/sdk/$$/u-boot.img"
execute "cp boot/uImage /tmp/sdk/$$/uImage"
execute "cp boot/uEnv.txt /tmp/sdk/$$/uEnv.txt"


sync
echo "unmounting ${device}1"
execute "umount /tmp/sdk/$$"

execute "mkdir -p /tmp/sdk/$$"
execute "mount ${device}2 /tmp/sdk/$$"
echo "Extracting filesystem on ${device}2 ..."
#execute "cp filesystem/* /tmp/sdk/$$ -a"
#execute "cp ../../.././ti-sdk-am335x-evm-06.00.00.00/filesystem/tisdk-rootfs-image-am335x-evm/* /tmp/sdk/$$ -R"
execute "cp ../../.././ti-sdk-am335x-evm-06.00.00.00/filesystem/arago-base-tisdk-image-am335x-evm/* /tmp/sdk/$$ -R"

sync
echo "unmounting ${device}2"
execute "umount /tmp/sdk/$$"

echo "Done"

