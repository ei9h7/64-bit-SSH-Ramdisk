# decrypt.sh - decrypt iBoot files on-device to use for a ramdisk
# This file is part of the 64-bit ramdisk tool by meowcat454 (version 0.17.1)
set -e

if [ -z $1 ] || [ -z $2 ]; then
  echo "Usage: decrypt.sh [device] [ios]"
  exit
fi

device=$1
version=$2

echo "Waiting for device in DFU mode..."
deviceinfo=$(./resources/bin/irecovery -q)
cpid=$(echo "$deviceinfo" | grep CPID | sed 's/CPID: //')
model=$(echo "$deviceinfo" | grep MODEL | sed 's/MODEL: //')
deviceid=$(echo "$deviceinfo" | grep PRODUCT | sed 's/PRODUCT: //')

if [ "$deviceid" != "$device" ]; then
  echo "ERROR: The specified device ($device) does not match the connected device ($deviceid)."
  echo "You can only decrypt files if you have a matching device."
  exit 1
fi

# This section copied from create.sh

# Get the link to the IPSW and build number for the specified version
ipsw_link=$(curl -s "https://api.ipsw.me/v2.1/$device/$version/url")
BuildID=$(curl -s "https://api.ipsw.me/v2.1/$device/$version/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)

if [ -z "$ipsw_link" ]; then
  echo "iOS version $version for device $device not found!"
  exit 1
fi

# Get major version (first number)
majorversion=$(echo $version | awk -F. '{print $1}')

# Get the codename of the iOS version, as it is needed when downloading the key page
{
  codename="$((curl "https://www.theiphonewiki.com/wiki/Firmware_Keys/$majorversion.x") | grep "$BuildID"_"" |  grep $device -m 1| awk -F_ '{print $1}' | awk -F"wiki" '{print "wiki"$2}')"
} &> /dev/null

# Downloading files, and decrypting iBSS/iBEC
if ! [ -d .decrypted_"$device" ]; then
  mkdir .decrypted_"$device"
fi
cd .decrypted_"$device"

echo "To decrypt files for iOS versions without firmware keys, you must be in pwned DFU mode."
echo "Entering pwned DFU mode now..."
echo
../resources/bin/gaster pwn
echo

# Code from https://github.com/palera1n/palera1n/blob/2eb578fdd0f147039de2b54dc6c4b449f0ed5140/palera1n.sh#L183

echo "[*] Downloading BuildManifest"
../resources/bin/pzb -g BuildManifest.plist "$ipsw_link" > /dev/null

echo "[*] Downloading and decrypting iBSS"
../resources/bin/pzb -g "$(awk "/""$cpid""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipsw_link" > /dev/null
../resources/bin/gaster decrypt "$(awk "/""$cpid""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" iBSS.dec > /dev/null

echo "[*] Downloading and decrypting iBEC"
../resources/bin/pzb -g "$(awk "/""$cpid""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipsw_link" > /dev/null
../resources/bin/gaster decrypt "$(awk "/""$cpid""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" iBEC.dec > /dev/null

echo "[*] Downloading DeviceTree"
../resources/bin/pzb -g Firmware/all_flash/DeviceTree."$model".im4p "$ipsw_link" > /dev/null
../resources/bin/img4 -i DeviceTree."$model".im4p -o DeviceTree.dec > /dev/null

if [ "$3" == "-b" ]; then
  echo "[*] Downloading trustcache"
  ../resources/bin/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."StaticTrustCache"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1)" "$ipsw_link" > /dev/null
else
  echo "[*] Downloading ramdisk"
  ../resources/bin/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1)" $ipsw_link > /dev/null
  ../resources/bin/img4 -i *.dmg -o ramdisk.dec.dmg ${iv}${key} > /dev/null
  echo "[*] Downloading trustcache"
  ../resources/bin/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreTrustCache"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1)" "$ipsw_link" > /dev/null
fi
echo "[*] Downloading kernelcache"
../resources/bin/pzb -g "$(awk "/""$cpid""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipsw_link" > /dev/null
mv kernelcache* kernelcacheraw
../resources/bin/img4 -i kernelcacheraw -o kernelcache.dec ${iv}${key} > /dev/null

touch files_decrypted
echo "iBoot files for device $device with iOS $version have been decrypted."
echo "Running create.sh to finish creating ramdisk..."
echo

cd ..
bash create.sh $@
