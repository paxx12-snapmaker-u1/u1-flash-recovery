# Snapmaker U1 — Flash Recovery

> [!WARNING]
> **For experienced users only — last resort.**
> This tool performs low-level flash operations directly on the motherboard.
> Only use this when all other recovery options have failed and you understand what you are doing.

Recovers a bricked Snapmaker U1 via the motherboard **Maskrom** mode using [rkdeveloptool](https://github.com/rockchip-linux/rkdeveloptool) and [u1-firmware-tools](https://github.com/paxx12/u1-firmware-tools).

## Requirements

- Linux host with USB — laptop, PC, Raspberry Pi, or any SBC running Linux
- `build-essential`, `git`, `pkg-config`, `autoconf`, `libtool`, `libusb-1.0-0-dev`, `python3-crcmod`
- USB-C cable (connects to the USB OTG / hub port on the motherboard)

```
sudo apt install build-essential git pkg-config autoconf libtool libusb-1.0-0-dev python3-crcmod
```

## Usage

```bash
./recovery.sh
```

The script will:

1. Build `rkdeveloptool` automatically (cloned into `tmp/`, not committed)
2. Clone `u1-firmware-tools` automatically when a `.bin` firmware file is used
3. Walk you through entering **Maskrom mode**
4. Detect the device over USB
5. Present recovery options

## Recovery options

| Option | What it does |
|--------|-------------|
| **Full flash** | Downloads firmware, unpacks the `.bin` (UPFILE → RKFW → RKAF), flashes loader + all partitions except `misc` |
| **OEM + userdata only** | Erases `data`, re-flashes bundled `oem` and `userdata` — fastest recovery for a corrupted OS |
| **Download firmware** | Opens the firmware download page in a browser |

> [!CAUTION]
> Never flash or erase the `misc` partition. It stores the device serial number and certificate required by Snapmaker Cloud — overwriting it will permanently deregister the printer from your account.

### Firmware unpack chain (full flash)

```
firmware.bin  →  sm_upfile.py     →  update.img  +  MCU bins
update.img    →  rk_update_image.py  →  loader.img  +  rom.img
rom.img       →  rk_afptool.py    →  Image/<partition>.img  (all flashed except misc)
```

## Firmware

| Type | Source |
|------|--------|
| Extended (community) | https://github.com/paxx12-snapmaker-u1/SnapmakerU1-Extended-Firmware/releases/latest |
| Stock (official) | https://wiki.snapmaker.com/en/snapmaker_u1 |

## Maskrom mode

1. Power off the printer
2. Locate the **MASKROM** pad on the motherboard
3. Short the **MASKROM** pad to **GND** (use tweezers or a wire)
4. Connect a **USB-C cable** from the **USB OTG port** (hub/toolhead port) to this computer
5. Power on the printer
6. Wait ~2 seconds, then remove the short
7. Run `./recovery.sh` — it will confirm device detection

## Files

```
firmware/
  MiniLoaderAll.bin   Rockchip first-stage loader (used for oem+userdata recovery)
  oem.img             Factory OEM partition image
  userdata.img        Factory userdata partition image
tmp/                  Auto-generated, git-ignored — built tools and unpacked firmware live here
recovery.sh           Interactive recovery script
```

## Example output

This is what a successful run looks like:

```text
$ ./recovery.sh

============================================
  Snapmaker U1 — Maskrom Flash Recovery
============================================

Building rkdeveloptool...
Dependencies: sudo apt install build-essential git pkg-config autoconf libtool libusb-1.0-0-dev
Cloning into '/opt/u1-flash-recovery/tmp/rkdeveloptool'...
...
g++  -g -O2   -o rkdeveloptool main.o crc.o RKBoot.o RKComm.o RKDevice.o RKImage.o RKLog.o RKScan.o -lusb-1.0  
make[1]: Leaving directory '/opt/u1-flash-recovery/tmp/rkdeveloptool'
rkdeveloptool built.

Put the U1 motherboard into Maskrom mode:
  1. Power off the printer.
  2. Locate the MASKROM pad on the motherboard.
  3. Short the MASKROM pad to GND (use tweezers or a wire).
  4. Connect a USB-C cable from the USB OTG port (hub/toolhead port) to this computer.
  5. Power on the printer.
  6. Wait ~2 seconds, then remove the short.

Press Enter when ready...
Waiting for Maskrom device...
Maskrom device detected.

What would you like to do?
  1) Full flash  (unpack .bin, flash all partitions except misc)
  2) OEM + userdata only  (erase data, re-flash oem & userdata)
  3) Download firmware .bin file only
  4) Exit

Choice [1-4]: 1

Select firmware:
  1) Extended (community) — v1.3.0-paxx12-17
  2) Stock (official)     — 1.4.0.246
  3) Enter path manually

Choice [1-3]: 1
Downloading U1_extended_1.3.0-paxx12-17_upgrade.bin...
...
Downloaded: U1_extended_1.3.0-paxx12-17_upgrade.bin

FULL FLASH: flashes all partitions except misc.
Continue? [y/N]: y
Cloning u1-firmware-tools...
Cloning into '/opt/u1-flash-recovery/tmp/u1-firmware-tools'...
...
u1-firmware-tools ready.
Unpacking UPFILE...
UPFILE Header:
  Magic:	SNMK
  Magic Ver:	0x0001
  Version:	1.3.0.168fea4715
  Build Date:	20260414155825
  Checksum:	0x07c5
  Files:	4
Extracted UPFILE_VERSION (16 bytes)
Extracted UPFILE_BUILD_DATE (14 bytes)
File Entry 0:
  Type:		0
  Offset:	0x00000000000000c0
  Size:		293179978
  Checksum:	0x0a70
  MD5:		9abe6fa0ac3b13520574fa20f07ba2f7
Extracted update.img (293179978 bytes)
File Entry 1:
  Type:		1
  Offset:	0x000000001179930a
  Size:		47004
  Checksum:	0x0a79
  MD5:		becf658f8013a1e11e19a87c5261aab0
Extracted at32f403a.bin (47004 bytes)
File Entry 2:
  Type:		2
  Offset:	0x00000000117a4aa6
  Size:		45452
  Checksum:	0x0b02
  MD5:		645b9419e8d5bb6358f2a3493481b066
Extracted at32f415.bin (45452 bytes)
File Entry 3:
  Type:		3
  Offset:	0x00000000117afc32
  Size:		26
  Checksum:	0x08e4
  MD5:		31aaf9765c0e659251cb0fce134d9773
Extracted MCU_DESC (26 bytes)
Unpacking RKFW (update.img)...
rom version: 1.0.0
build time: 2026-05-17 08:31:59
chip: 80
loader offset/len: 102/469440
image offset/len: 469542/292710404
Unpacking RKAF (rom.img)...
Check file...OK
------- UNPACK -------
Unpacking: name=package-file filename=package-file	nand_addr=4294967295/0	pos=2048/251/1
Unpacking: name=parameter filename=parameter.txt	nand_addr=0/16384	pos=4096/541/1
Unpacking: name=bootloader filename=MiniLoaderAll.bin	nand_addr=4294967295/0	pos=6144/469440/230
Unpacking: name=uboot_a filename=uboot.img	nand_addr=16384/8192	pos=477184/4194304/2048
Unpacking: name=uboot_b filename=uboot.img	nand_addr=24576/8192	pos=477184/4194304/2048
Unpacking: name=misc filename=misc.img	nand_addr=32768/8192	pos=4671488/49152/24
Unpacking: name=boot_a filename=boot.img	nand_addr=40960/65536	pos=4720640/17320960/8458
Unpacking: name=boot_b filename=boot.img	nand_addr=106496/65536	pos=4720640/17320960/8458
Unpacking: name=system_a filename=rootfs.img	nand_addr=172032/614400	pos=22042624/253890560/123970
Unpacking: name=system_b filename=rootfs.img	nand_addr=786432/614400	pos=22042624/253890560/123970
Unpacking: name=oem filename=oem.img	nand_addr=1400832/2097152	pos=275933184/8388608/4096
Unpacking: name=userdata filename=userdata.img	nand_addr=3497984/4294967295	pos=284321792/8388608/4096
UnPack OK!
Initialising loader from firmware...
Downloading bootloader succeeded.
Flashing partitions (skipping misc and bootloader)...
  Flashing uboot_a...
Write LBA from file (100%)
  Flashing uboot_b...
Write LBA from file (100%)
Skipping misc.
  Flashing boot_a...
Write LBA from file (100%)
  Flashing boot_b...
Write LBA from file (100%)
  Flashing system_a...
Write LBA from file (100%)
  Flashing system_b...
Write LBA from file (100%)
  Flashing oem...
Write LBA from file (100%)
  Flashing userdata...
Write LBA from file (100%)
Full flash complete. Reboot the printer.
```
