#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: SD Card / mmc Storage]"
sync

SYS_ROOT="${DECKDOC_SYS_ROOT:-/sys}"

echo "--- mmc device detection ---"
if command -v lsblk >/dev/null 2>&1; then
    MMC_DEVICES=$(lsblk -dno NAME,TYPE,TRAN 2>/dev/null | grep -i mmc || true)
    if [ -n "$MMC_DEVICES" ]; then
        echo "  mmc devices found:"
        echo "$MMC_DEVICES"
    else
        echo "  No mmc devices detected."
    fi

    if command -v findmnt >/dev/null 2>&1; then
        MMC_MOUNTS=$(findmnt -lo SOURCE,FSTYPE,SIZE 2>/dev/null | grep mmc || true)
        if [ -n "$MMC_MOUNTS" ]; then
            echo "  Mounted mmc partitions:"
            echo "$MMC_MOUNTS"
        fi
    fi
else
    echo "  lsblk not available."
fi
sync

echo "--- mmc driver errors (dmesg) ---"
if command -v dmesg >/dev/null 2>&1; then
    MMC_ERRORS=$(dmesg 2>/dev/null | grep -iE 'mmc[0-9]:|sdhci|card reader' | grep -iE 'error|fail|timeout|cannot verify|corrupt' | head -10 || true)
    if [ -n "$MMC_ERRORS" ]; then
        echo "  HIGH: mmc driver errors detected:"
        echo "$MMC_ERRORS"
    else
        echo "  No mmc driver errors in dmesg."
    fi

    EXT4_MMC_ERRORS=$(dmesg 2>/dev/null | grep -iE 'EXT4-fs error.*mmc' | head -5 || true)
    if [ -n "$EXT4_MMC_ERRORS" ]; then
        echo "  CRITICAL: ext4 errors on mmc device (filesystem corruption likely):"
        echo "$EXT4_MMC_ERRORS"
    fi
fi
sync

echo "--- SD card TRIM status ---"
if command -v journalctl >/dev/null 2>&1; then
    TRIM_ERRORS=$(journalctl -b 0 2>/dev/null | grep -iE 'fstrim|trim.*mmc|mmc.*trim|safe_trim' | grep -iE 'error|fail|unsupported' | head -5 || true)
    if [ -n "$TRIM_ERRORS" ]; then
        echo "  MEDIUM: TRIM errors on mmc/SD:"
        echo "$TRIM_ERRORS"
    else
        echo "  No TRIM errors for mmc devices in current boot."
    fi
fi
sync

echo "--- SD card health indicators ---"
if [ -d "${SYS_ROOT}/block" ] && command -v ls >/dev/null 2>&1; then
    for mmc in "${SYS_ROOT}"/block/mmcblk*; do
        if [ -d "$mmc" ]; then
            DEV=$(basename "$mmc")
            SIZE=$(cat "${mmc}/size" 2>/dev/null || echo 0)
            RO=$(cat "${mmc}/ro" 2>/dev/null || echo 0)
            echo "  ${DEV}: ${SIZE} sectors, read-only=${RO}"
            if [ "$RO" = "1" ]; then
                echo "  CRITICAL: ${DEV} is read-only. Hardware write-protect or imminent failure."
            fi
        fi
    done
fi
sync
