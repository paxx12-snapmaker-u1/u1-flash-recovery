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
