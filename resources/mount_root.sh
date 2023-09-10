#!/bin/bash
# This file is part of the 64-bit ramdisk tool by meowcat454

# If not a ramdisk, exit
if ! [ -d /mnt2 ]; then
  echo "Not a ramdisk, exiting..."
  exit 1
fi

usage() {
  echo "Usage: mount_root [-h]"
  echo "Mount the root filesystem with APFS (default) or HFS if -h is specified (for devices using iOS 10.2.1 or below)"
}

if [ "$1" == "-h" ]; then
  if [ "$2" == "-r" ]; then
    echo "Mounting root filesystem as HFS read-only..."
    /sbin/mount_hfs -o ro /dev/disk0s1s1 /mnt1
  else
    echo "Mounting root filesystem as HFS..."
    /sbin/mount_hfs /dev/disk0s1s1 /mnt1
  fi
else
  if [ -b /dev/disk1s1 ]; then
    # The files may have different names on iOS 16
    echo "iOS 16 ramdisk detected!"
    filename=/dev/disk1s1
  else
    filename=/dev/disk0s1s1
  fi
  if [ "$1" == "-r" ]; then
    echo "Mounting root filesystem as APFS read-only..."
    /System/Library/Filesystems/apfs.fs/mount_apfs -o ro $filename /mnt1
  else
    echo "Mounting root filesystem as APFS..."
    /System/Library/Filesystems/apfs.fs/mount_apfs $filename /mnt1
  fi
fi
