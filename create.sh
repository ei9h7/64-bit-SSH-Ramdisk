#!/bin/bash

# Define script version
ver="v0.17.1"

echo "64-bit Ramdisk Creator $ver by meowcat454"
echo "------------------------------------------"

usage() {
echo "Usage: create.sh [devicetype] [iosversion]"
echo "  devicetype: specify device model"
echo "  iosversion: specify iOS version"
echo "Example: bash create.sh iPhone10,1 14.8"
echo "For beta firmwares, use: create.sh [devicetype] [codename] [build]"
echo "These values can be found on the Apple Wiki."
}

device=$1
version=$2

if [ -z "$device" ] || [ -z "$version" ]; then
  usage
  exit 1
fi

# Check if the device is 32/64 bit
type=$(echo ${device:0:6})
if [ "$type" == "iPhone" ]; then
    number=$(echo ${device:6} | awk -F, '{print $1}')
    if [ "$number" -gt "5" ]; then
        is64bit=1
    else
        is64bit=0
    fi
else
    type=$(echo ${device:0:4})
    number=$(echo ${device:4} | awk -F, '{print $1}')
    if [ "$type" == "iPad" ]; then
        if [ "$number" -gt "3" ]; then
            is64bit=1
        else
            is64bit=0
        fi
    else
        if [ "$type" == "iPod" ]; then
            if [ "$number" -gt "5" ]; then
                is64bit=1
            else
                is64bit=0
            fi
        fi
    fi
fi

# If 32-bit, exit and display a message with a link to the 32-bit tool
if [ "$is64bit" -eq 0 ]; then
  echo "You specified a 32-bit device. To create a 32-bit ramdisk, go to https://redd.it/ub4ypc"
  exit 1
fi

# Get the chip for each device type
case $device in
  iPhone6,1 | iPhone6,2 | iPad4,1 | iPad4,2 | iPad4,3 | iPad4,4 | iPad4,5 | iPad4,6 | iPad4,7 | iPad4,8 | iPad4,9) # iPhone 5s / iPad Air / iPad Mini 2 & 3
    chip="A7";;
  iPhone7,1 | iPhone7,2 | iPad5,1 | iPad5,2 | iPad5,3 | iPad5,4 | iPod7,1) # iPhone 6 / 6 Plus / iPad Air 2 / iPad Mini 4 / iPod 6
    chip="A8";;
  iPhone8,1 | iPhone8,2 | iPhone8,4 | iPad6,3 | iPad6,4 | iPad6,7 | iPad6,8 | iPad6,11 | iPad6,12) # iPhone 6s / 6s Plus / SE1 / iPad 5
    chip="A9";;
  iPhone9,1 | iPhone9,2 | iPhone9,3 | iPhone9,4 | iPad7,1 | iPad7,2 | iPad7,3 | iPad7,4 | iPad7,5 | iPad7,6 | iPad7,11 | iPad7,12 | iPod9,1) # iPhone 7 / 7 Plus / iPad 6 / iPad 7 / iPod 7
    chip="A10";;
  iPhone10,1 | iPhone10,2 | iPhone10,3 | iPhone10,4 | iPhone10,5 | iPhone10,6) # iPhone 8 / 8 Plus / X
    chip="A11";;
esac

if [ -z "$chip" ]; then
  echo "Invalid device type."
  exit 1
fi

# Check if the chip is A10 or higher
a10check() {
  if [ "$chip" == "A10" ] || [ "$chip" == "A11" ]; then
    return 0 # true
  else
    return 1 # false
  fi
}

if ! [ -z "$3" ] && [ "$3" != "-i" ] && [ "$3" != "-t" ] && [ "$3" != "-b" ]; then
  echo "Downloading key page for device $device, codename $2, build $3"
  codename=$2
  build=$3
  extra=$4
  curl -s -o /tmp/firmwarekeys.txt "https://theapplewiki.com/wiki/Keys:$codename"_"$build"_"($device)?action=raw"
  if ! [ -e "/tmp/firmwarekeys.txt" ]; then
    echo "Failed to download the requested key page!"
    exit 1
  fi
  if grep -q "404 Not Found" /tmp/firmwarekeys.txt || ! [ -s /tmp/firmwarekeys.txt ]; then
    echo "No keys were found for build $build for $device!"
    exit 1
  fi
  versionstring=$(grep "| Version" /tmp/firmwarekeys.txt | sed 's/.* = //');
  version=$(echo "$versionstring" | awk '{print $1}')
  ipsw_link=$(grep "| DownloadURL" /tmp/firmwarekeys.txt | sed 's/.* = //')
else
  extra=$3
  # Get the link to the IPSW and build number for the specified version
  ipsw_link=$(curl -s "https://api.ipsw.me/v2.1/$device/$version/url")
  BuildID=$(curl -s "https://api.ipsw.me/v2.1/$device/$version/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)

  if [ -z "$ipsw_link" ]; then
    echo "iOS version $version for device $device not found!"
    exit 1
  fi

  # Get major and minor version (first and second numbers)
  majorversion=$(echo $version | awk -F. '{print $1}')
  minorversion=$(echo $version | awk -F. '{print $2}')

  # Get the codename of the iOS version, as it is needed when downloading the key page
  codename="$((curl -s "https://theapplewiki.com/wiki/Firmware_Keys/$majorversion.x") | grep "$BuildID"_"" |  grep $device -m 1| awk -F_ '{print $1}' | awk -F"wiki" '{print "wiki"$2}')"

  # Get firmware info page - contains filenames and keys
  if ! [ -d .decrypted_$device ] && ! [ -e *-$device/build/decrypted/files_decrypted ]; then
    echo "Downloading firmware keys..."
    curl -s -o /tmp/firmwarekeys.txt "https://theapplewiki.com/$codename"_"$BuildID"_"($device)?action=raw"
    if ! [ -e "/tmp/firmwarekeys.txt" ]; then
      echo "Failed to download firmware keys. If you keep getting this error with multiple iOS versions, update to Big Sur or later."
      exit 1
    fi
    if grep -q "404 Not Found" /tmp/firmwarekeys.txt; then
      echo "Keys for iOS $version for device $device not found!"
      echo "To fix this error, go to https://theapplewiki.com/wiki/Firmware_Keys/$majorversion.x and choose the closest iOS version for your device that has a blue link."
      echo "You can also use decrypt.sh to decrypt the files in pwned DFU mode."
      exit 1
    fi
  fi
fi

# Get major and minor version (first and second numbers)
majorversion=$(echo $version | awk -F. '{print $1}')
minorversion=$(echo $version | awk -F. '{print $2}')

if [ "$extra" == "-b" ]; then
  # Create a boot chain that boots from iOS (beta)
  boot=1
  dirprefix=bootchain
  echo "Creating bootchain for device $device ($chip) with base version $version"
else
  boot=0
  dirprefix=SSH-Ramdisk
  echo "Creating ramdisk for device $device ($chip) with base version $version"
fi

bootcheck() {
  # False if bootchain mode, true if ramdisk mode
  return $boot
}

mkdir -p $dirprefix-$device/build 2> /dev/null
cd $dirprefix-$device/build
mkdir decrypted patched 2> /dev/null

#rdtype=Restore
rdtype=Update

if [ -d ../../.decrypted_$device ] || [ -e decrypted/files_decrypted ]; then
  echo "Using files decrypted by decrypt.sh."
  if [ -d ../../.decrypted_$device ]; then
    mv ../../.decrypted_$device/* decrypted/
    rmdir ../../.decrypted_$device
  fi
  if [ -f ../../custom_blob.bin ]; then
    echo "Using custom SHSH blob."
    shshfile=../../custom_blob.bin
  elif [ "$chip" != "A9" ]; then
    shshfile=shsh_$chip.bin
  fi
else
# iBSS, iBEC, and iBoot are the same on A10/A11 devices so only download the iBEC
if ! bootcheck; then
  if a10check; then
    files="iBEC.DeviceTree.kernelcache"
    range="1 2 3"
  else
    files="iBSS.iBEC.DeviceTree.kernelcache"
    range="1 2 3 4"
  fi
else
  if a10check; then
    files="iBEC.DeviceTree.kernelcache.${rdtype}RamDisk"
    range="1 2 3 4"
  else
    files="iBSS.iBEC.DeviceTree.kernelcache.${rdtype}RamDisk"
    range="1 2 3 4 5"
  fi
fi

# For A9 devices, there are two versions of each device with a different chip, and have different iBSS, iBEC and device tree files
if [ "$device" == "iPhone8,1" ] || [ "$device" == "iPhone8,2" ] || [ "$device" == "iPad6,11" ] || [ "$device" == "iPad6,12" ]; then # iPhone 6s / 6s Plus / iPad 5
  if [ "$extra" == "-t" ]; then
    echo "Downloading files for chip S8003 for A9 device: $device"
    altfile=2
    shshfile=shsh_A9_S8003.bin
  else
    echo "Downloading files for chip S8000 for A9 device: $device"
    altfile=""
  fi
elif [ "$device" == "iPhone8,4" ]; then # iPhone SE 1
  if [ "$extra" == "-t" ]; then
    echo "Downloading files for chip S8003 for A9 device: $device"
    altfile=""
    shshfile=shsh_A9_S8003.bin
  else
    echo "Downloading files for chip S8000 for A9 device: $device"
    altfile=2
  fi
else
  echo "Downloading files..."
fi

if [ -f ../../custom_blob.bin ]; then
  echo "Using custom SHSH blob."
  shshfile=../../custom_blob.bin
elif [ -z "$shshfile" ]; then
  shshfile=shsh_$chip.bin
fi

for i in $range; do
  unset iv key
  filetype="$((echo $files) | awk -v var=$i -F. '{print $var}')"

  # Check for separate files for A9 S8000 and S8003 devices
  # iOS 9: All files separate
  # iOS 10 - 10.2.1: Ramdisk same for both types
  # iOS 10.3+: Ramdisk and kernelcache same for both types
  if [ "$altfile" == "2" ]; then
    if [ "$majorversion" -gt 10 ] || ( [ "$majorversion" -eq 10 ] && [ "$minorversion" -eq 3 ] ); then
      if [ "$filetype" == "kernelcache" ] || [ "$filetype" == "${rdtype}RamDisk" ]; then
        altfile=""
      fi
    elif [ "$majorversion" -eq 10 ] && [ "$minorversion" -ne 3 ]; then
      if [ "$filetype" == "${rdtype}RamDisk" ]; then
        altfile=""
      fi
    fi
  fi

  if [ -f "decrypted/$filetype.dec" ]; then
    #echo "$filetype already downloaded."
    continue
  fi

  iv=$(grep -i "${filetype}${altfile}IV" /tmp/firmwarekeys.txt | sed 's/.* = //')
  if [ "$iv" == "Not Encrypted" ]; then
    iv=""
  elif [ "$iv" == "Unknown" ]; then
    echo "Some required keys are missing!"
    echo "To fix this error, go to https://theapplewiki.com/wiki/Firmware_Keys/$majorversion.x and choose the closest iOS version for your device that has a blue link."
    echo "You can also use decrypt.sh to decrypt the files in pwned DFU mode."
    exit 1
  else
    key=$(grep -i "${filetype}${altfile}Key" /tmp/firmwarekeys.txt | sed 's/.* = //')
  fi

  component=$(grep -i "${filetype}${altfile} " /tmp/firmwarekeys.txt | sed 's/.* = //')
  case $filetype in
    iBSS | iBEC | iBoot)
      componentpath="Firmware/dfu/";;
    applelogo | DeviceTree)
      componentpath="Firmware/all_flash/";;
    kernelcache | ${rdtype}RamDisk)
      componentpath="";;
  esac
  if [ "$filetype" == "${rdtype}RamDisk" ]; then
    component="${component}.dmg"
  fi

  if [ -z "$component" ]; then
    echo "ERROR: Cannot find filename for $filetype!"
    exit 1
  fi

  echo "Downloading ${filetype}${altfile} ($component)..."

  # Device tree is located in all_flash.[device].production on iOS 10.2.1 and below
  if [ "$majorversion" -lt 10 ] || ( [ "$majorversion" -eq 10 ] && [ "$minorversion" -ne 3 ] ); then
    if [ "$filetype" == "DeviceTree" ]; then
      componentpath+="all_flash.$(echo ${component} | sed 's/DeviceTree\.//;s/\.im4p//').production/"
    fi
  fi

  DYLD_LIBRARY_PATH=../../resources/bin/.libs ../../resources/bin/pzb -g "${componentpath}${component}" "$ipsw_link" 2>&1 > /dev/null

  if [ "$filetype" = "${rdtype}RamDisk" ]; then
    ../../resources/bin/img4 -i $component -o decrypted/ramdisk.dec.dmg ${iv}${key} > /dev/null
    if [ "$majorversion" -gt "11" ]; then # Trust cache needed on iOS 12+
      echo "Downloading trustcache ($component.trustcache)..."
      DYLD_LIBRARY_PATH=../../resources/bin/.libs ../../resources/bin/pzb -g Firmware/$component.trustcache $ipsw_link 2>&1 > /dev/null
      mv $component.trustcache decrypted/
    fi
    rm "$component"
  elif [ "$filetype" == "kernelcache" ]; then
    kerneliv=$iv
    kernelkey=$key
    if a10check; then
      # The kernelcache needs to be thin or it will give an error when loading
      ../../resources/bin/img4 -i $filetype* -o kcdec ${iv}${key} > /dev/null
      ../../resources/bin/lipo -thin arm64 kcdec -o kcthin 2> /dev/null
      if [ -f kcthin ]; then
        mv kcthin decrypted/kernelcache.dec
        rm kcdec
      else # If already thinned, kcthin will not be created so move the existing file
        mv kcdec decrypted/kernelcache.dec
      fi
    else
      mv $filetype* decrypted/kernelcacheraw
      ../../resources/bin/img4 -i decrypted/kernelcacheraw -o decrypted/kernelcache.dec ${iv}${key} > /dev/null
    fi
  else
    ../../resources/bin/img4 -i $filetype* -o decrypted/$filetype.dec ${iv}${key} > /dev/null
    rm $filetype*
  fi
done

# Download the trustcache for the root filesystem when in bootchain mode
if ! bootcheck && [ "$majorversion" -gt "11" ]; then
  rootfsname=$(grep -i "RootFS " /tmp/firmwarekeys.txt | sed 's/.* = //')
  echo "Downloading trustcache ($rootfsname.dmg.trustcache)..."
  DYLD_LIBRARY_PATH=../../resources/bin/.libs ../../resources/bin/pzb -g Firmware/$rootfsname.dmg.trustcache $ipsw_link 2>&1 > /dev/null
  mv $rootfsname.dmg.trustcache decrypted/
fi
echo "Download complete!"
fi

if ! a10check && ! [ -f decrypted/iBSS.dec ]; then echo "iBSS not found!"; exit 1; fi
if ! [ -f decrypted/iBEC.dec ]; then echo "iBEC not found!"; exit 1; fi
if ! [ -f decrypted/DeviceTree.dec ]; then echo "Device tree not found!"; exit 1; fi
if ! [ -f decrypted/kernelcache.dec ]; then echo "Kernelcache not found!"; exit 1; fi
if bootcheck && ! [ -f decrypted/ramdisk.dec.dmg ]; then echo "Ramdisk not found!"; exit 1; fi
echo

# Kernel boot-args
if bootcheck && [ "$rdtype" == "Update" ]; then
  bootargs="rd=md0 debug=0x2014e -v wdt=-1 -progress msgbuf=1048576 "
else
  bootargs="-v " # Verbose boot
  if bootcheck; then
    bootargs+="rd=md0 " # Boot from ramdisk
  else
    bootargs+="keepsyms=1 debug=0xfffffffe panic-wait-forever=1 " # Extra debug settings when in boot mode
  fi
  bootargs+="cs_enforcement_disable=1 " # Disable AMFI
  bootargs+="msgbuf=1048576 " # Larger log size for debugging (not working on iOS 15+)
  bootargs+="wdt=-1" # Disable automatic reboot (screen will still go black but connection works)
fi

if bootcheck && ! a10check; then
  bootargs+="-restore " # Fix permission denied error when mounting root partition
  if [ "$majorversion" -lt 13 ]; then
    bootargs+="nand-enable-reformat=1 " # Fixes readonly true and exit code 78 when mounting root partition on iOS 12 - this will not delete any data
  fi
  if [ "$majorversion" -lt 9 ]; then
    bootargs+="cs_enforcement_disable=1 " # Disable AMFI
  fi
fi

# Patch downloaded files
echo "Patching files..."

# iBoot patch tool: kairos or iBoot64Patcher
# Note: Using kairos causes panic when mounting /mnt2 on A10+ devices
#if [ "$device" == "iPhone6,1" ] || [ "$device" == "iPhone6,2" ] || [ "$majorversion" -lt 11 ]; then
if [ "$device" == "iPhone6,1" ] || [ "$device" == "iPhone6,2" ] || ( [ "$chip" == "A9" ] && [ "$majorversion" -eq 9 ] ); then
  patchtool=kairos
else
  patchtool=iBoot64Patcher
fi

if [ "$patchtool" == "iBoot64Patcher" ] && [ "$majorversion" -eq 10 ] && [ "$minorversion" -ne 3 ]; then
  echo "Using patched iBoot64Patcher for iOS 10 to 10.2.1"
  patchtool=iBoot64Patcher10
fi

if ! a10check; then
  echo "Patching iBSS..."
  DYLD_LIBRARY_PATH=../../resources/bin/.libs ../../resources/bin/$patchtool ./decrypted/iBSS.dec ./patched/iBSS.patched #&> /dev/null
fi
echo "Patching iBEC..."
DYLD_LIBRARY_PATH=../../resources/bin/.libs ../../resources/bin/$patchtool ./decrypted/iBEC.dec ./patched/iBEC.patched -b "$bootargs" #&> /dev/null
echo "Patching kernelcache..."
cp ./decrypted/kernelcache.dec /tmp/kerneldump
if [ "$majorversion" -gt 14 ]; then # iOS 15+ kernel patches (disable SSV panic)
  ../../resources/bin/Kernel64Patcher ./decrypted/kernelcache.dec ./patched/kernelcache.patched -a -r -s -p -o -l &> /dev/null
else
  ../../resources/bin/Kernel64Patcher ./decrypted/kernelcache.dec ./patched/kernelcache.patched -a #&> /dev/null
fi

# Custom kernel version string
../../resources/bin/sed -i 's/RELEASE_ARM/iOS_Ramdisk/g' ./patched/kernelcache.patched

if ! a10check; then
  # Create kernelcache patch file for non-A10 devices
  printf '#AMFI\n\n' > kc.bpatch
  cmp -l ./decrypted/kernelcache.dec ./patched/kernelcache.patched | awk 'function oct2dec(oct,dec){for(i=1;i<=length(oct);i++){dec*=8;dec+=substr(oct,i,1)};return dec}{printf "0x%x 0x%x 0x%x\n",$1-1,oct2dec(0$2),oct2dec(0$3)}' >> kc.bpatch
fi

if ! a10check && ! [ -f patched/iBSS.patched ]; then echo "Patched iBSS not found!"; exit 1; fi
if ! [ -f patched/iBEC.patched ]; then echo "Patched iBEC not found!"; exit 1; fi
if ! [ -f patched/kernelcache.patched ]; then echo "Patched kernelcache not found!"; exit 1; fi
if ! a10check && ! [ -f kc.bpatch ]; then echo "Kernelcache patch file not found!"; exit 1; fi
echo "Patching complete!"
echo

# Sign downloaded files
echo "Signing files..."
if a10check; then
  # Set the type for the patched iBoot to 'ibss' and name it iBoot
  ../../resources/bin/img4 -i ./patched/iBEC.patched -o ../iBoot.img4 -T ibss -A -M ../../resources/shsh/$shshfile &> /dev/null
else
  ../../resources/bin/img4 -i ./patched/iBSS.patched -o ../iBSS.img4 -T ibss -A -M ../../resources/shsh/$shshfile &> /dev/null
  ../../resources/bin/img4 -i ./patched/iBEC.patched -o ../iBEC.img4 -T ibec -A -M ../../resources/shsh/$shshfile &> /dev/null
fi
../../resources/bin/img4 -i ../../resources/customlogo.bin -o ../bootlogo.img4 -T rlgo -A -M ../../resources/shsh/$shshfile &> /dev/null
../../resources/bin/img4 -i ./decrypted/devicetree.dec -o ../devicetree.img4 -T rdtr -A -M ../../resources/shsh/$shshfile &> /dev/null
if a10check; then
  if [ "$majorversion" -lt "14" ]; then # Kernelcache needs to be compressed on iOS 13 and below
    echo "Compressing kernelcache..."
    DYLD_LIBRARY_PATH=../../resources/bin/.libs ../../resources/bin/img4tool -c kernelcache.im4p -t rkrn --compression complzss ./patched/kernelcache.patched &> /dev/null
    ../../resources/bin/img4 -i kernelcache.im4p -o ../kernelcache.img4 -M ../../resources/shsh/$shshfile &> /dev/null
  else
    ../../resources/bin/img4 -i ./patched/kernelcache.patched -o ../kernelcache.img4 -T rkrn -A -J -M ../../resources/shsh/$shshfile &> /dev/null
  fi
else
  if [ "$majorversion" -lt 10 ]; then
    # Decrypt the kernel on iOS 9 and below
    ../../resources/bin/img4 -i decrypted/kernelcacheraw -o kernelpatched2.im4p -D ${kerneliv}${kernelkey}
    ../../resources/bin/img4 -i kernelpatched2.im4p -o ../kernelcache.img4 -T rkrn -P ./kc.bpatch -J -M ../../resources/shsh/$shshfile
  else
    ../../resources/bin/img4 -i decrypted/kernelcacheraw -o ../kernelcache.img4 -T rkrn -P ./kc.bpatch -J -M ../../resources/shsh/$shshfile
  fi
fi
if [ "$majorversion" -gt "11" ]; then
  ../../resources/bin/img4 -i ./decrypted/*trustcache -o ../trustcache -M ../../resources/shsh/$shshfile &> /dev/null
  if ! [ -f ../trustcache ]; then echo "Trustcache not found!"; exit 1; fi
  if ! bootcheck; then
    if grep -q trst ../trustcache; then
      sed -i 's/trst/rtsc/' ../trustcache
    fi
  fi
fi
if a10check; then
  if ! [ -f ../iBoot.img4 ]; then echo "iBoot not found!"; exit 1; fi
else
  if ! [ -f ../iBSS.img4 ]; then echo "iBSS not found!"; exit 1; fi
  if ! [ -f ../iBEC.img4 ]; then echo "iBEC not found!"; exit 1; fi
fi
if ! [ -f ../bootlogo.img4 ]; then echo "Boot logo not found!"; exit 1; fi
if ! [ -f ../devicetree.img4 ]; then echo "Device tree not found!"; exit 1; fi
if ! [ -f ../kernelcache.img4 ]; then echo "Kernelcache not found!"; exit 1; fi
if bootcheck && ! [ -f decrypted/ramdisk.dec.dmg ]; then echo "Ramdisk not found!"; exit 1; fi
echo "Signing complete!"
echo

if bootcheck; then
mkdir rootfs
cd rootfs

# Extract binpack and copy some files
echo "Extracting files..."
tar xzf ../../../resources/binpack64-256.tar.gz

mkdir -p ./var/root/
cd ../
cp ../../resources/banner.txt ./rootfs/etc/motd

cp -a ./decrypted/*.dec.dmg ./ramdisk.dmg

if [ "$majorversion" -lt 11 ]; then
  hdiutil resize -size 50MB ./ramdisk.dmg
fi

# Create an info file in the ramdisk root containing instructions and version info
info="This is a ramdisk used for SSH access to the device $device over USB.
To use it, you need to be in pwned DFU mode.
Tutorial: https://old.reddit.com/r/setupapp/comments/w1irgx/how_to_boot_a_ssh_ramdisk_on_64bit_devices/

Created at $(date) using 64-bit ramdisk creator $ver by meowcat454
Base iOS version: $version"

echo "Copying files to ramdisk... (might ask for sudo password)"
mkdir ./mnt/
if [ "$majorversion" -gt 16 ] || ( [ "$majorversion" -eq 16 ] && [ "$minorversion" -gt 0 ] ); then
  if grep -q NXSB ramdisk.dmg; then
    echo "Converting APFS ramdisk to HFS... This may take a minute."
    mkdir ./apfs/
    mv ramdisk.dmg hfsconvert.dmg
    hdiutil attach -mountpoint ./apfs/ -owners on ./hfsconvert.dmg &> /dev/null
    hdiutil create -size 100M -layout none -fs HFS+ ramdisk.dmg
    hdiutil attach -mountpoint ./mnt/ -owners on ./ramdisk.dmg
    cd ./apfs/
    sudo tar -cf - * | (cd ../mnt/; sudo tar -xf -)
    cd ../
    hdiutil detach ./apfs/
  else
    hdiutil attach -mountpoint ./mnt/ -owners on ./ramdisk.dmg &> /dev/null
  fi
else
  hdiutil attach -mountpoint ./mnt/ -owners on ./ramdisk.dmg &> /dev/null
fi

# Remove some large files that are not needed in the ramdisk (like firmware)
sudo rm -r ./mnt/usr/standalone/ ./mnt/usr/lib/libUSBCfwflasher.dylib ./mnt/usr/lib/libAppleHIDSWDFlash.dylib ./mnt/usr/lib/PN548_API.dylib ./mnt/usr/local/share/astris 2> /dev/null

if [ "$rdtype" == "Update" ]; then
  daemon=update
else
  daemon=external
fi

sudo plutil -insert ProgramArguments -string -server -append ./mnt/System/Library/LaunchDaemons/com.apple.restored_${daemon}.plist 2> /dev/null # Errors from this can be ignored
sudo cp ../../resources/mount_root.sh ./mnt/usr/bin/mount_root
sudo cp ../../resources/mount_data.sh ./mnt/usr/bin/mount_data
sudo chmod +x ./mnt/usr/bin/mount_*

echo "$info" | sudo tee ./mnt/info.txt > /dev/null

echo "Creating ramdisk..."
# Copy the rootfs dir to the ramdisk
sudo rsync --ignore-existing -ahuK ./rootfs/ ./mnt/

# dropbear.plist needs to be owned by root or launchd will not load it causing SSH not to work
sudo chown 0:0 ./mnt/System/Library/LaunchDaemons/com.apple.dropbear.plist

if [ "$majorversion" -lt 11 ]; then
  sudo mv ./mnt/usr/local/bin/restored_${daemon} ./mnt/usr/local/bin/restored_${daemon}.real
  sudo cp ../../resources/setup.sh ./mnt/usr/local/bin/restored_${daemon}
  sudo chmod +x ./mnt/usr/local/bin/restored_${daemon}
fi

hdiutil detach ./mnt/ &> /dev/null
rmdir ./mnt/
../../resources/bin/img4 -i ./ramdisk.dmg -o ../ramdisk -T rdsk -A -M ../../resources/shsh/$shshfile &> /dev/null
fi

cd ..
rm -r build
echo "Done!"
if ! bootcheck; then
  echo "To boot your device, enter pwned DFU mode using pwndfu.sh, then run 'bash load.sh $device -b'."
else
  echo "To load the ramdisk, enter pwned DFU mode using pwndfu.sh, then run 'bash load.sh $device'."
fi
