#!/bin/bash
# This file is part of the 64-bit ramdisk tool by meowcat454
echo "The device will now attempt to enter pwned DFU mode."

if [ "$1" == "-l" ]; then
  echo "If you do not see a 'pwned!' message after running, reboot the device and try again."
  echo "------------------------------------------------------------------------------------"
elif [ "$1" == "-l2" ]; then
  echo "If you do not see a 'checkmate!' message, or if the process gets stuck for least 60 seconds, press Ctrl-C, reboot the device and try again."
  echo "-------------------------------------------------------------------------------------------------------------------------------------------"
else
  echo "If you do not see a 'Now you can boot untrusted images' message, reboot the device and try again."
  echo "-------------------------------------------------------------------------------------------------"
fi

cd ./resources/bin/
if [ "$1" == "-l" ]; then
  ./ipwnder_lite -p
elif [ "$1" == "-l2" ]; then
  ./ipwnder_lite2
elif [ "$1" == "-e" ]; then
  ./eclipsa
else
  ./gaster pwn
fi
