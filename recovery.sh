#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIRMWARE_DIR="$SCRIPT_DIR/firmware"
TMP_DIR="$SCRIPT_DIR/tmp"
RKDEVELOPTOOL="$TMP_DIR/rkdeveloptool/rkdeveloptool"
U1_TOOLS="$TMP_DIR/u1-firmware-tools/apps/firmware-packing"

DRY_RUN=false

EXTENDED_FIRMWARE_URL="https://github.com/paxx12-snapmaker-u1/SnapmakerU1-Extended-Firmware/releases/latest"
STOCK_FIRMWARE_URL="https://wiki.snapmaker.com/en/snapmaker_u1"
EXTENDED_FIRMWARE_DL="https://github.com/paxx12-snapmaker-u1/SnapmakerU1-Extended-Firmware/releases/download/v1.3.0-paxx12-17/U1_extended_1.3.0-paxx12-17_upgrade.bin"
STOCK_FIRMWARE_DL="https://public.resource.snapmaker.com/firmware/U1/U1_1.4.0.246_20260522180235_upgrade.bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
error()   { echo -e "${RED}ERROR: $*${NC}"; exit 1; }

require() {
    command -v "$1" &>/dev/null || error "$1 is required — run: sudo apt install $2"
}

rk() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] $RKDEVELOPTOOL $*"
    else
        "$RKDEVELOPTOOL" "$@"
    fi
}

build_rkdeveloptool() {
    [[ "$DRY_RUN" == true ]] && return
    [[ -x "$RKDEVELOPTOOL" ]] && return
    info "Building rkdeveloptool..."
    info "Dependencies: sudo apt install build-essential git pkg-config autoconf libtool libusb-1.0-0-dev"
    require git git
    require make build-essential
    require g++ build-essential
    require pkg-config pkg-config
    require autoconf autoconf
    require libtoolize libtool
    mkdir -p "$TMP_DIR"
    [[ -d "$TMP_DIR/rkdeveloptool" ]] || \
        git clone https://github.com/rockchip-linux/rkdeveloptool "$TMP_DIR/rkdeveloptool"
    cd "$TMP_DIR/rkdeveloptool"
    autoreconf -i || true
    ./configure
    make -j"$(nproc)"
    cd "$SCRIPT_DIR"
    success "rkdeveloptool built."
}

clone_u1_firmware_tools() {
    [[ -d "$TMP_DIR/u1-firmware-tools" ]] && return
    info "Cloning u1-firmware-tools..."
    require python3 python3
    require git git
    mkdir -p "$TMP_DIR"
    git clone https://github.com/paxx12/u1-firmware-tools "$TMP_DIR/u1-firmware-tools"
    if ! python3 -c "import crcmod" 2>/dev/null; then
        warn "python3-crcmod not found — run: sudo apt install python3-crcmod"
        error "Install python3-crcmod and re-run."
    fi
    success "u1-firmware-tools ready."
}

UNPACK_DIR=""

unpack_firmware() {
    local bin_file="$1"
    UNPACK_DIR="$TMP_DIR/unpack"

    rm -rf "$UNPACK_DIR"
    mkdir -p "$UNPACK_DIR"

    info "Unpacking UPFILE..."
    python3 "$U1_TOOLS/sm_upfile.py" unpack "$bin_file" "$UNPACK_DIR/upfile"

    info "Unpacking RKFW (update.img)..."
    python3 "$U1_TOOLS/rk_update_image.py" unpack "$UNPACK_DIR/upfile/update.img" "$UNPACK_DIR/rkfw"

    info "Unpacking RKAF (rom.img)..."
    python3 "$U1_TOOLS/rk_afptool.py" unpack "$UNPACK_DIR/rkfw/rom.img" "$UNPACK_DIR/rkaf"
}

wait_for_device() {
    info "Waiting for Maskrom device..."
    local attempts=0
    while ! "$RKDEVELOPTOOL" ld 2>/dev/null | grep -q "Maskrom"; do
        sleep 1
        attempts=$((attempts + 1))
        [[ $attempts -lt 60 ]] || error "No Maskrom device detected after 60 seconds."
    done
    success "Maskrom device detected."
}

FIRMWARE_BIN=""

fetch_file() {
    local url="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        info "Already downloaded: $(basename "$dest")"
        return
    fi
    mkdir -p "$(dirname "$dest")"
    info "Downloading $(basename "$dest")..."
    if command -v wget &>/dev/null; then
        wget --show-progress -O "$dest" "$url"
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$dest" "$url"
    else
        error "wget or curl required — run: sudo apt install wget"
    fi
    success "Downloaded: $(basename "$dest")"
}

download_firmware() {
    echo
    info "Select firmware:"
    echo "  1) Extended (community) — v1.3.0-paxx12-17"
    echo "  2) Stock (official)     — 1.4.0.246"
    echo "  3) Enter path manually"
    echo
    read -rp "Choice [1-3]: " fw_choice
    case "$fw_choice" in
        1)
            FIRMWARE_BIN="$TMP_DIR/$(basename "$EXTENDED_FIRMWARE_DL")"
            fetch_file "$EXTENDED_FIRMWARE_DL" "$FIRMWARE_BIN"
            ;;
        2)
            FIRMWARE_BIN="$TMP_DIR/$(basename "$STOCK_FIRMWARE_DL")"
            fetch_file "$STOCK_FIRMWARE_DL" "$FIRMWARE_BIN"
            ;;
        3)
            read -rp "Enter path to .bin file: " FIRMWARE_BIN
            [[ -f "$FIRMWARE_BIN" ]] || error "File not found: $FIRMWARE_BIN"
            ;;
        *)
            warn "Skipping firmware download."
            FIRMWARE_BIN=""
            ;;
    esac
}

flash_full() {
    echo
    warn "FULL FLASH: flashes all partitions except misc."
    read -rp "Continue? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; return; }

    if [[ -n "$FIRMWARE_BIN" ]]; then
        clone_u1_firmware_tools
        unpack_firmware "$FIRMWARE_BIN"
        local loader="$UNPACK_DIR/rkfw/loader.img"
        local parts_dir="$UNPACK_DIR/rkaf"
        local pkg_file="$parts_dir/package-file"

        [[ -f "$pkg_file" ]] || error "package-file not found in unpacked firmware."

        info "Initialising loader from firmware..."
        rk db "$loader"
        [[ "$DRY_RUN" == true ]] || sleep 2

        info "Flashing partitions (skipping misc and bootloader)..."
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            local name path
            read -r name path <<< "$line"
            [[ "$path" != *.img ]] && continue
            [[ "$name" == "misc" || "$name" == "bootloader" ]] && { warn "Skipping $name."; continue; }
            local img="$parts_dir/$path"
            [[ -f "$img" ]] || { warn "Missing $img, skipping."; continue; }
            info "  Flashing $name..."
            rk wlx "$name" "$img"
        done < "$pkg_file"
    else
        info "Initialising loader..."
        rk db "$FIRMWARE_DIR/MiniLoaderAll.bin"
        [[ "$DRY_RUN" == true ]] || sleep 2
        info "Flashing oem..."
        rk wlx oem "$FIRMWARE_DIR/oem.img"
        info "Flashing userdata..."
        rk wlx userdata "$FIRMWARE_DIR/userdata.img"
    fi

    success "Full flash complete. Reboot the printer."
}

flash_oem_userdata() {
    echo
    warn "OEM + USERDATA FLASH: erases data, flashes oem and userdata only."
    read -rp "Continue? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; return; }

    info "Initialising loader..."
    rk db "$FIRMWARE_DIR/MiniLoaderAll.bin"
    [[ "$DRY_RUN" == true ]] || sleep 2

    info "Erasing data partition..."
    rk ef data 2>/dev/null || warn "ef data not supported, skipping."

    info "Flashing oem..."
    rk wlx oem "$FIRMWARE_DIR/oem.img"
    info "Flashing userdata..."
    rk wlx userdata "$FIRMWARE_DIR/userdata.img"

    success "Flash complete. Reboot the printer."
}

# --- main ---

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help)
            echo "Usage: $0 [--dry-run] [--help]"
            echo
            echo "  --dry-run   Show rkdeveloptool commands without executing them."
            echo "              Skips device detection and build steps."
            echo "  --help      Show this help."
            exit 0
            ;;
        *) error "Unknown option: $arg" ;;
    esac
done

echo
echo "============================================"
echo "  Snapmaker U1 — Maskrom Flash Recovery"
echo "============================================"
[[ "$DRY_RUN" == true ]] && warn "  DRY-RUN MODE — no commands will be executed"
echo

build_rkdeveloptool

if [[ "$DRY_RUN" == false ]]; then
    echo
    info "Put the U1 motherboard into Maskrom mode:"
    echo "  1. Power off the printer and unplug the power cable."
    echo "  2. Locate the MASKROM button on the motherboard."
    echo "  3. Hold MASKROM, then connect a USB-C cable from the USB OTG port"
    echo "     (the hub/toolhead port) to this computer."
    echo "  4. Release the button after ~2 seconds."
    echo "  NOTE: Do NOT connect mains power — the printer is powered via USB."
    echo
    read -rp "Press Enter when ready..."
    wait_for_device
fi

echo
info "What would you like to do?"
echo "  1) Full flash  (unpack .bin, flash all partitions except misc)"
echo "  2) OEM + userdata only  (erase data, re-flash oem & userdata)"
echo "  3) Download firmware .bin file only"
echo "  4) Exit"
echo
read -rp "Choice [1-4]: " action

case "$action" in
    1)
        download_firmware
        flash_full
        ;;
    2)
        flash_oem_userdata
        ;;
    3)
        download_firmware
        ;;
    4)
        info "Bye."
        ;;
    *)
        error "Invalid choice."
        ;;
esac
