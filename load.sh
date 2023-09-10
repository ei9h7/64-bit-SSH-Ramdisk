#!/bin/bash
set -e

echo "64-bit Ramdisk Loader v0.17.1 by meowcat454"
echo "-----------------------------------------"

usage() {
echo "Usage: load.sh [devicetype]"
echo "  devicetype: specify device model"
echo "Examples: "
echo "'bash load.sh iPhone9,2'"
}

if [ -z "$1" ]; then
  usage
  exit
fi

device=$1

if [ "$2" == "-b" ]; then
  boot=1
  dirprefix=bootchain
else
  boot=0
  dirprefix=SSH-Ramdisk
fi

if ! [ -d "$dirprefix-$device" ]; then
echo "Ramdisk folder not found, run create.sh to create one."
exit 1
fi

cd $dirprefix-$device

if ! [ -e iBoot.img4 ]; then
  if ! [ -f iBSS.img4 ]; then echo "ERROR: iBSS not found!"; exit 1; fi
  if ! [ -f iBEC.img4 ]; then echo "ERROR: iBEC not found!"; exit 1; fi
fi
if ! [ -f bootlogo.img4 ]; then echo "ERROR: Boot logo not found!"; exit 1; fi
if ! [ -f devicetree.img4 ]; then echo "ERROR: Device tree not found!"; exit 1; fi
if [ "$2" != "-b" ] && ! [ -f ramdisk ]; then echo "ERROR: Ramdisk not found!"; exit 1; fi
if ! [ -f kernelcache.img4 ]; then echo "ERROR: Kernelcache not found!"; exit 1; fi

#read -p "Enter pwned DFU mode, then press Enter to continue." -n1 -s

if [ -e iBoot.img4 ]; then # A10/A11 device
  echo "Sending iBoot..."
  ../resources/bin/irecovery -f iBoot.img4
  sleep 2
  ../resources/bin/irecovery -f iBoot.img4
else
  echo "Sending iBSS..."
  ../resources/bin/irecovery -f iBSS.img4
  sleep 2
  ../resources/bin/irecovery -f iBSS.img4

  sleep 2
  echo "Sending iBEC..."
  ../resources/bin/irecovery -f iBEC.img4
fi

sleep 3
../resources/bin/irecovery -c "bgcolor 11 45 113"
echo "Sending logo..."
../resources/bin/irecovery -f bootlogo.img4
../resources/bin/irecovery -c "setpicture 5"

sleep 1
echo "Sending device tree..."
../resources/bin/irecovery -f devicetree.img4
../resources/bin/irecovery -c devicetree

sleep 2
if [ "$2" != "-b" ]; then
  echo "Sending ramdisk..."
  ../resources/bin/irecovery -f ramdisk
  ../resources/bin/irecovery -c ramdisk
fi

# iOS 11 and later need trustcache files
if [ -e trustcache ]; then
  echo "Sending trustcache..."
  ../resources/bin/irecovery -f trustcache
  ../resources/bin/irecovery -c firmware
fi

sleep 1
echo "Sending kernelcache..."
../resources/bin/irecovery -f kernelcache.img4
echo "Booting device now..."
../resources/bin/irecovery -c bootx

echo "Finished! If all the progress bars are 100%, you should see a verbose boot then the apple logo."

cd ..
