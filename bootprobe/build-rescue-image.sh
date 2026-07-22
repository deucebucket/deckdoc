#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run the ArchISO build with sudo on an Arch Linux build host." >&2
    exit 1
fi
if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "mkarchiso is required. Install the official Arch Linux archiso package." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELENG_PROFILE="${DECKDOC_ARCHISO_PROFILE:-/usr/share/archiso/configs/releng}"
OUTPUT_DIR="${1:-${SOURCE_DIR}/out}"
if [ ! -d "$RELENG_PROFILE" ]; then
    echo "ArchISO releng profile not found: ${RELENG_PROFILE}" >&2
    exit 1
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(readlink -f "$OUTPUT_DIR")
BUILD_ROOT=$(mktemp -d -p /var/tmp deckdoc-rescue-build.XXXXXX)
case "$BUILD_ROOT" in /var/tmp/deckdoc-rescue-build.*) ;; *) exit 1 ;; esac
trap 'rm -rf -- "$BUILD_ROOT"' EXIT
PROFILE="${BUILD_ROOT}/profile"
cp -a "$RELENG_PROFILE" "$PROFILE"

install -d -m 755 "${PROFILE}/airootfs/usr/local/bin" "${PROFILE}/airootfs/root"
install -m 755 "${SOURCE_DIR}/deckdoc-rescue-collect.sh" "${PROFILE}/airootfs/usr/local/bin/deckdoc-rescue-collect"
install -m 644 "${SOURCE_DIR}/README.md" "${PROFILE}/airootfs/root/DeckDoc-Rescue-README.md"

for package in smartmontools nvme-cli btrfs-progs e2fsprogs usbutils pciutils iw ethtool openssh; do
    if ! grep -qx "$package" "${PROFILE}/packages.x86_64"; then printf '%s\n' "$package" >> "${PROFILE}/packages.x86_64"; fi
done

echo "Building unsigned DeckDoc Rescue alpha image with the current Arch repositories."
echo "The resulting ISO is not a Valve recovery image and must not be presented as one."
mkarchiso -v -r -w "${BUILD_ROOT}/work" -o "$OUTPUT_DIR" "$PROFILE"
echo "Image written under ${OUTPUT_DIR}. Verify its checksum and boot-test both LCD and OLED before release."
