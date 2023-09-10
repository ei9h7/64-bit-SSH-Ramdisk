#!/bin/bash
set -x

echo "SSH Ramdisk Tool by meowcat454"
echo "--------------------------------"
echo "Kernel Version: $(uname -a)"
echo
echo "RAMDISK SETUP: STARTING" > /dev/console

echo "Cleaning up /dev"
rm /dev/pty* || true
rm /dev/tty?? || true

# remount r/w
echo "RAMDISK SETUP: REMOUNTING ROOTFS" > /dev/console
mount -o rw,union,update /

# free space
#rm /usr/local/standalone/firmware/*
#rm /usr/standalone/firmware/*
#mv /sbin/reboot /sbin/reboot_bak

# Fix the auto-boot
#echo "RAMDISK SETUP: SETTING AUTOBOOT" > /dev/console
#nvram auto-boot=1

# Start SSHD
echo "RAMDISK SETUP: STARTING SSHD" > /dev/console
/sbin/sshd
/usr/local/bin/dropbear -i --shell /bin/bash -r /etc/dropbear/id_rsa

echo "RAMDISK SETUP: WAITING 5S" > /dev/console
sleep 5

# Run restored_external
echo "RAMDISK SETUP: STARTING UI" > /dev/console
sleep 1
if [ -e "/usr/local/bin/restored_update.real" ]; then
  echo "Running in Update Ramdisk!"
  exec /usr/local/bin/restored_update.real -server
else
  exec /usr/local/bin/restored_external.real -server
fi
