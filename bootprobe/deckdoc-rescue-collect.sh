#!/usr/bin/env bash
set -uo pipefail

umask 077

OUTPUT_ROOT="/tmp"
INSTALLED_DISK="/dev/nvme0n1"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output-dir)
            [ "$#" -ge 2 ] || { echo "--output-dir requires a path" >&2; exit 2; }
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --installed-disk)
            [ "$#" -ge 2 ] || { echo "--installed-disk requires a block device" >&2; exit 2; }
            INSTALLED_DISK="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'EOF'
Usage: deckdoc-rescue-collect.sh [--output-dir PATH] [--installed-disk /dev/DEVICE]

Collects live rescue-environment evidence and attempts read-only journal extraction from the installed
disk through journalctl --image. It never mounts, repairs, unlocks, or writes the installed disk.
The resulting archive is private and unredacted. /tmp is volatile; copy it before powering off.
EOF
            exit 0
            ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

case "$OUTPUT_ROOT" in ''|/|/dev|/dev/*|/proc|/proc/*|/sys|/sys/*) echo "Unsafe output directory: ${OUTPUT_ROOT}" >&2; exit 2 ;; esac
if [ ! -d "$OUTPUT_ROOT" ] || [ ! -w "$OUTPUT_ROOT" ]; then
    echo "Output directory must already exist and be writable: ${OUTPUT_ROOT}" >&2
    exit 1
fi
if [ ! -b "$INSTALLED_DISK" ]; then
    echo "Installed disk is not a block device: ${INSTALLED_DISK}" >&2
    exit 1
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
CASE_DIR="${OUTPUT_ROOT%/}/deckdoc-rescue-${STAMP}"
ARCHIVE="${CASE_DIR}.tar.gz"
mkdir -m 700 "$CASE_DIR" || exit 1

run_section() {
    local title="$1"
    shift
    echo "--- ${title} ---"
    "$@" 2>&1 || echo "INACCESSIBLE_OR_FAILED: $*"
}

{
    echo "DeckDoc Rescue evidence manifest"
    echo "capture_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "rescue_boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo inaccessible)"
    echo "installed_disk=${INSTALLED_DISK}"
    echo "collection_policy=read-only-no-mount-no-repair"
    echo "privacy=private-unredacted"
    echo "transport=copy archive to removable media or transfer over authenticated docked Ethernet"
} > "${CASE_DIR}/manifest.txt"

{
    run_section "kernel" uname -a
    if [ -r /etc/os-release ]; then run_section "rescue OS" grep -E '^(NAME|VERSION|BUILD_ID|ID)=' /etc/os-release; fi
    echo "--- Deck/model capability ---"
    for field in product_name product_version board_name board_vendor bios_version; do
        [ -r "/sys/devices/virtual/dmi/id/${field}" ] && echo "${field}=$(cat "/sys/devices/virtual/dmi/id/${field}")"
    done
    run_section "PCI devices and drivers" lspci -nnk
    run_section "USB topology" lsusb -t
    run_section "block topology" lsblk -o NAME,PATH,TYPE,TRAN,SIZE,RO,FSTYPE,FSVER,LABEL,MOUNTPOINTS
    run_section "mounts" findmnt -lo SOURCE,TARGET,FSTYPE,OPTIONS

    echo "--- Type-C and PD exports ---"
    for port in /sys/class/typec/port[0-9]*; do
        [ -d "$port" ] || continue
        echo "port=$(basename "$port")"
        for field in data_role power_role port_type power_operation_mode orientation usb_power_delivery_revision; do
            [ -r "${port}/${field}" ] && echo "  ${field}=$(cat "${port}/${field}")"
        done
    done
    for supply in /sys/class/power_supply/*; do
        [ -d "$supply" ] || continue
        echo "supply=$(basename "$supply")"
        for field in type status online capacity voltage_now current_now power_now usb_type; do
            [ -r "${supply}/${field}" ] && echo "  ${field}=$(cat "${supply}/${field}")"
        done
    done

    echo "--- DRM connectors ---"
    for connector in /sys/class/drm/card*-*; do
        [ -d "$connector" ] || continue
        echo "$(basename "$connector") status=$(cat "${connector}/status" 2>/dev/null || echo inaccessible) edid_bytes=$(wc -c < "${connector}/edid" 2>/dev/null || echo inaccessible)"
    done
    echo "--- hwmon ---"
    for input in /sys/class/hwmon/hwmon*/temp*_input /sys/class/hwmon/hwmon*/fan*_input; do
        [ -r "$input" ] && echo "${input}=$(cat "$input")"
    done
    run_section "network link inventory" ip -details -brief link
    run_section "USB Ethernet candidates" sh -c 'for n in /sys/class/net/*; do [ -d "$n" ] || continue; printf "%s driver=%s state=%s\n" "$(basename "$n")" "$(basename "$(readlink -f "$n/device/driver" 2>/dev/null || echo unknown)")" "$(cat "$n/operstate" 2>/dev/null || echo inaccessible)"; done'
} > "${CASE_DIR}/live-hardware.log" 2>&1

{
    run_section "rescue current-boot journal" journalctl -b 0 -o short-iso-precise --no-pager
    run_section "rescue kernel ring" dmesg -T
    if [ -d /sys/fs/pstore ]; then run_section "pstore inventory" find /sys/fs/pstore -maxdepth 1 -type f -printf '%f %s bytes\n'; fi
} > "${CASE_DIR}/live-journal.log" 2>&1

{
    run_section "NVMe smartctl" smartctl -x "$INSTALLED_DISK"
    if command -v nvme >/dev/null 2>&1; then run_section "NVMe smart log" nvme smart-log "$INSTALLED_DISK"; fi
    run_section "block read-only flags" lsblk -o NAME,PATH,RO,SIZE,FSTYPE,MOUNTPOINTS "$INSTALLED_DISK"
} > "${CASE_DIR}/storage-health.log" 2>&1

{
    echo "DeckDoc uses systemd's image reader; it does not mount or repair the installed filesystems."
    run_section "installed boot index" journalctl --image="$INSTALLED_DISK" --list-boots --no-pager
} > "${CASE_DIR}/installed-boot-index.log" 2>&1

{
    run_section "installed previous boot" journalctl --image="$INSTALLED_DISK" -b -1 -o short-iso-precise --no-pager
    run_section "installed current/last boot" journalctl --image="$INSTALLED_DISK" -b 0 -o short-iso-precise --no-pager
} > "${CASE_DIR}/installed-journals.log" 2>&1

if command -v efibootmgr >/dev/null 2>&1; then efibootmgr -v > "${CASE_DIR}/uefi-boot-entries.log" 2>&1 || true; fi

(
    cd "$CASE_DIR" || exit 1
    sha256sum ./*.log manifest.txt > SHA256SUMS
)
tar -C "$OUTPUT_ROOT" -czf "$ARCHIVE" "$(basename "$CASE_DIR")"
chmod 600 "$ARCHIVE"
sha256sum "$ARCHIVE" > "${ARCHIVE}.sha256"

echo "DeckDoc Rescue capture complete: ${ARCHIVE}"
echo "This archive is unredacted. Review it before sharing, and copy it out of /tmp before shutdown."
