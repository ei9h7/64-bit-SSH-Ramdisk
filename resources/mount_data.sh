#!/bin/bash
# This file is part of the 64-bit ramdisk tool by meowcat454

# If not a ramdisk, exit
if ! [ -d /mnt2 ]; then
  echo "Not a ramdisk, exiting..."
  exit 1
fi

usage() {
  echo "Usage: mount_data [-h]"
  echo "Mount the data partition with APFS (default) or HFS if -h is specified (for devices using iOS 10.2.1 or below)"
}

if ! [ -d /mnt1/System ]; then
  echo "The root filesystem must be mounted before mounting the data partition."
  echo "To mount the root filesystem, run 'bash /usr/bin/mount_root'"
  exit 1
fi

if [ -b /dev/disk1s1 ]; then
  # The files may have different names on iOS 16
  echo "iOS 16 ramdisk detected!"
  diskprefix=/dev/disk1
else
  diskprefix=/dev/disk0s1
fi

if [ "$1" == "-h" ]; then
  echo "Mounting data partition (/mnt2) as HFS..."
  /sbin/mount_hfs ${diskprefix}s2 /mnt2
else
  # Mount the XART partition, which exists on iOS 13+ and contains a single file with a .gl extension
  if [ -e ${diskprefix}s3 ]; then
    echo "Mounting XART partition..."
    /System/Library/Filesystems/apfs.fs/mount_apfs -R ${diskprefix}s3 /mnt7
    if [ -f /mnt7/*.gl ]; then # Do not try to load the XART file if it does not exist, as on iOS 12 disk0s1s3 can be something else, or it could not be there at all
      echo "Loading XART file..."
      /usr/libexec/seputil --gigalocker-init
    else
      echo "disk0s1s3 exists but does not contain XART file"
    fi
  else
    echo "XART partition does not exist"
  fi

  if [ -e /mnt1/usr/standalone/firmware/sep-firmware.img4 ]; then
    echo "Loading SEP firmware..."
    /usr/libexec/seputil --wait --load /mnt1/usr/standalone/firmware/sep-firmware.img4
  else
    # SEP firmware on iOS 14 and up is on the preboot partition (disk0s1s5)
    for i in ${diskprefix}s*; do
      type=$(/System/Library/Filesystems/apfs.fs/apfs.util -p $i)
      if [ "$type" == "Preboot" ]; then
        preboot=$i
        break
      fi
    done
    if [ -z "$preboot" ]; then
      echo "ERROR: SEP firmware does not exist and preboot partition not found!"
      exit 1
    elif [ -e "$preboot" ]; then
      echo "Mounting preboot partition..."
      mount_apfs -o ro $preboot /mnt6
      if [ $? -ne 0 ]; then echo "ERROR: Failed to mount the preboot partition!"; exit 1; fi
      sepfwpath=/mnt6/$(cat /mnt6/active)/usr/standalone/firmware/sep-firmware.img4
      if [ -e "$sepfwpath" ]; then
        echo "Loading SEP firmware from preboot partition..."
        /usr/libexec/seputil --wait --load "$sepfwpath"
      else
        echo "ERROR: SEP firmware not found in preboot partition!"
        exit 1
      fi
    else
      echo "ERROR: SEP firmware not found and preboot partition does not exist!"
      exit 1
    fi
  fi
  #sleep 2 # wait for above to complete, if it succeeds

  # Try to mount the data partition - this might panic the device
  echo "Mounting data partition (/mnt2) as APFS..."
  #echo "If this fails and reboots the device, try running mount_data2 instead"
  /System/Library/Filesystems/apfs.fs/mount_apfs ${diskprefix}s2 /mnt2
  if [ $? -eq 0 ]; then echo "Done!"; fi
fi
