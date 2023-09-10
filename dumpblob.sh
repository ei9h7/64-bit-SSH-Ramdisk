#!/bin/bash
# This file is part of the 64-bit ramdisk tool by meowcat454
echo "Dumping SHSH blob from device..."
echo "Enter alpine as the password when asked."
./resources/tcprelay.py -t 22:2222 &
sleep 2
if [ "$1" == "16" ]; then
  env -i ssh -o StrictHostKeyChecking=no -p2222 root@localhost "dd if=/dev/disk2 bs=256 count=$((0x4000))" > /tmp/blobdump.bin
else
  env -i ssh -o StrictHostKeyChecking=no -p2222 root@localhost "dd if=/dev/disk1 bs=256 count=$((0x4000))" > /tmp/blobdump.bin
fi
DYLD_LIBRARY_PATH=./resources/bin/.libs ./resources/bin/img4tool --convert -s /tmp/blobdump.shsh /tmp/blobdump.bin
bash resources/addblob.sh /tmp/blobdump.shsh
killall Python
