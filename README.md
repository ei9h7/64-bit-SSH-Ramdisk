## Booting SSH ramdisk on 64-bit iOS devices (A7-A11)

### Part 1: Creating the ramdisk
1. Download and unzip the ramdisk files
2. Open a terminal and drag the ramdisk folder into it
3. Run `bash create.sh [devicetype] [version]`
  * Replace `[devicetype]` with your device type (like iPhone9,2)
  * For all devices on iOS 12 and above, replace `[version]` with the iOS version that is installed on your device
  * Use 12.0 for devices on iOS 11 and below
  * If you get a "Failed to download firmware keys" error, update to Big Sur or later
  * A9 devices have two different chips, the S8000 and S8003. The S8000 version is downloaded by default, if your device has the S8003 chip run create.sh with `-t` at the end, like this: `bash create.sh iPhone8,1 14.8 -t`

### Part 2: Loading the ramdisk
1. Connect your device and enter DFU mode
2. Run `bash pwndfu.sh` to enter pwned DFU mode (this might take a few tries)
3. Run `bash load.sh [devicetype]`
4. Once the ramdisk has loaded and you see the apple logo with a gray bar, run `./resources/tcprelay.py -t 22:2222` to start the SSH proxy
  * If you get an error, download and open Sliver from appletech752 website and install python when it asks
5. Open a new terminal window and connect to the device by typing `ssh root@localhost -p 2222` (password is alpine)
6. Once connected, run `bash /usr/bin/mount_root` to mount the root filesystem on /mnt1
7. Run `bash /usr/bin/mount_data` to mount the data partition on /mnt2

This tool has been tested on these devices using all ramdisk versions from 12.0 to 16.1 beta:
- iPad7,5 on 14.8
- iPhone10,1 on 13.3
- iPhone9,2 on 12.0
- iPad5,3 on 15.5 and 15.7

### Common errors
**Black screen**
- If you see no progress bar below iBoot or iBSS when running load.sh, press Ctrl+C and run load.sh again.

**Missing firmware keys**
- If the script tells you that firmware keys are not found, open the wiki link and choose the closest version for your device that has a blue link.
- If all of the links are red, you will need to put your device in pwned DFU mode and run `bash decrypt.sh [devicetype] [version]` (replacing with the same values as above) to decrypt the boot files.
- The decrypt.sh script will automatically run create.sh after decrypting, so you can run load.sh right after.

**Kernel panic in boot mode (`-b` option)**
- If the device panics with a message 'boot task failed', or is stuck at the boot logo, you need to use a SHSH blob dumped from your device. The included blob or a saved one will not work.
- To dump the installed SHSH blob, boot into ramdisk mode (without `-b` option) and run `bash dumpblob.sh`, recreate the bootchain, and boot again.
- If you get a SEP panic, disable the passcode and try booting again.

### Update history

#### Version 0.17.1 (2023-04-11)
- Fix iBoot64Patcher10 binary

#### Version 0.17 (2023-04-11)
- Add beta support for iOS 9-11 ramdisks
- Add support for update ramdisk (instead of restore ramdisk)
- Begin fixing iOS 16 ramdisks (still not working)

#### Version 0.16 (2023-03-18)
- Switch to The Apple Wiki for keys by default

#### Version 0.15.1 (2023-02-07)
- Change iBoot patcher for iPhone 5s

#### Version 0.15 (2022-09-28)
- Fix exit code 78 when mounting /mnt1 with iOS 12 ramdisk
- Add error message when trying to use a version lower than iOS 12

#### Version 0.14 (2022-09-28)
- Fix sed error and kernelcache not found error when creating ramdisk

#### Version 0.13 (2022-09-27)
- Fix iBoot getting stuck when loading by sending it twice
- Add livefs kernel patch for iOS 15+

#### Version 0.12 (2022-09-26)
- Add decrypt.sh to create ramdisks for iOS versions without firmware keys
- Add support for booting the device into iOS with the -b option to create.sh (A10+ devices must have passcode disabled or the device will panic)
- Add support for using a custom SHSH blob which is required for the boot feature, and dumping it from the device
- Fix permission denied error when mounting /mnt1 on A9 and lower devices

#### Version 0.11 (2022-09-23)
- Fix bug with S8003 A9 devices not working

#### Version 0.10 (2022-09-19)
- Switch to iBoot64Patcher instead of kairos (fixes reboot on /mnt2 mounting)
- Fix iOS 16 ramdisks not loading
- Only load one iBoot file on A10/A11 devices
- Add support for beta firmwares (requires codename and build number)
- Add gaster tool for pwned DFU mode
