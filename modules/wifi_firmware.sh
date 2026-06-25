#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: WiFi / Wireless Firmware]"
sync

echo "--- Network interface status ---"
if command -v ip >/dev/null 2>&1; then
    WLAN_IFACE=$(ip link show 2>/dev/null | grep -oE 'wlan[0-9]' | head -1 || true)
    if [ -n "$WLAN_IFACE" ]; then
        WLAN_STATE=$(ip link show "$WLAN_IFACE" 2>/dev/null | grep -oE 'state (UP|DOWN|UNKNOWN)' || echo "state UNKNOWN")
        echo "  Interface: ${WLAN_IFACE} ${WLAN_STATE}"
        if echo "$WLAN_STATE" | grep -q 'DOWN'; then
            echo "  WARNING: ${WLAN_IFACE} is DOWN."
        fi
    else
        echo "  CRITICAL: No wireless interface detected."
    fi
else
    echo "  WARNING: ip command not found."
fi
sync

if command -v iw >/dev/null 2>&1 && [ -n "${WLAN_IFACE:-}" ]; then
    echo "--- Wireless link info ---"
    iw dev "${WLAN_IFACE}" link 2>/dev/null | head -10 || echo "  Not connected to any network."
fi
sync

echo "--- Firmware errors (current boot) ---"
if command -v dmesg >/dev/null 2>&1; then
    FW_ERRORS=$(dmesg 2>/dev/null | grep -iE 'ath11k|ath12k|iwlwifi|b43|brcmfmac' | grep -iE 'fail|error|crash|firmware|crashed' | head -10 || true)
    if [ -n "$FW_ERRORS" ]; then
        echo "$FW_ERRORS"
        sync
        if echo "$FW_ERRORS" | grep -q 'firmware crashed'; then
            echo "CRITICAL: Wireless firmware crashed. Recovery may require modprobe cycle or reboot."
        fi
    else
        echo "  No wireless firmware errors in current boot."
    fi

    echo "--- Firmware version ---"
    dmesg 2>/dev/null | grep -iE 'ath11k.*firmware|iwlwifi.*loaded firmware' | tail -3 || echo "  Firmware version info not available."
else
    echo "  dmesg not available."
fi
sync

echo "--- PCI device presence ---"
if command -v lspci >/dev/null 2>&1; then
    lspci 2>/dev/null | grep -iE 'Network|WiFi|Wireless' | head -5 || echo "  No wireless PCI device found."
fi
sync
