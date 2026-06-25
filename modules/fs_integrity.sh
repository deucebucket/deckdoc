#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Filesystem Integrity]"
sync

echo "--- BTRFS Stats Check ---"
if command -v btrfs >/dev/null 2>&1; then
    if mount | grep -q 'btrfs'; then
        BTRFS_MOUNTS=$(mount | grep 'btrfs' | awk '{print $3}')
        for mnt in $BTRFS_MOUNTS; do
            echo "Checking btrfs device stats for $mnt:"
            btrfs device stats "$mnt" 2>/dev/null || \
                sudo -n btrfs device stats "$mnt" 2>/dev/null || \
                echo "CRITICAL: btrfs device stats failed on $mnt (needs root)."
            sync
        done
    else
        echo "No btrfs mounts detected."
    fi
else
    echo "btrfs command not found."
fi
sync

echo "--- EXT4 Status Check ---"
if mount | grep -q 'ext4'; then
    EXT4_MOUNTS=$(mount | grep 'ext4' | awk '{print $1}' | sort -u)
    for dev in $EXT4_MOUNTS; do
        echo "Checking ext4 flags for $dev:"
        dumpe2fs -h "$dev" 2>/dev/null | grep -i 'Filesystem state' || \
            sudo -n dumpe2fs -h "$dev" 2>/dev/null | grep -i 'Filesystem state' || \
            echo "Failed to read state for $dev (needs root)."
        sync
    done
else
    echo "No ext4 mounts detected."
fi
sync
