# This file is part of the 64-bit ramdisk tool by meowcat454

usage() {
  echo "This script installs a custom SHSH blob to be used when creating ramdisks. This can fix problems when booting."
  echo "Usage: addblob.sh path/to/blob.shsh"
  exit 1
}

if [ "$1" == "-d" ] || [ "$1" == "clean" ]; then
  if [ -e custom_blob.bin ]; then
    rm custom_blob.bin
    echo "Custom SHSH blob has been removed. A generic blob will now be used when creating ramdisks."
    exit
  else
    echo "No custom SHSH blob is saved!"
    exit 1
  fi
elif [ -z "$1" ]; then
  usage
elif [ -e "$1" ]; then
  if grep -q ApImg4Ticket $1; then
    DYLD_LIBRARY_PATH=./resources/bin/.libs ./resources/bin/img4tool -e -s $1 -m custom_blob.bin &> /dev/null
    if grep -q IM4M custom_blob.bin; then
      echo "Custom SHSH blob has been saved. This blob will now be used when creating ramdisks."
    else
      echo "Failed to convert blob!"
      rm custom_blob.bin
    fi
  else
    echo "Input file does not appear to be a SHSH blob!"
    exit 1
  fi
else
  echo "Blob file does not exist."
  usage
fi
