#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Storage SMART Health]"
sync

NVME_DEV="${DECKDOC_PRIMARY_STORAGE:-/dev/nvme0n1}"

if command -v smartctl >/dev/null 2>&1; then
    if [ -b "$NVME_DEV" ]; then
        echo "Executing fast SMART health check on ${NVME_DEV}..."
        if smartctl -H "$NVME_DEV" 2>/dev/null; then
            :
        elif smartctl -H "$NVME_DEV" 2>&1 | grep -q 'Permission denied'; then
            echo "Permission denied. Retrying with sudo..."
            sudo -n smartctl -H "$NVME_DEV" 2>/dev/null || echo "CRITICAL: smartctl failed (needs root)."
        else
            echo "CRITICAL: smartctl returned a non-zero exit code."
        fi
        smartctl -A "$NVME_DEV" 2>/dev/null | grep -iE 'critical|warning|error' || \
            sudo -n smartctl -A "$NVME_DEV" 2>/dev/null | grep -iE 'critical|warning|error' || true
    else
        echo "CRITICAL: Device ${NVME_DEV} not found."
    fi
else
    echo "WARNING: smartctl command not found. Skipping physical storage check."
fi
sync
