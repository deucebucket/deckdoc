#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: WiFi / Wireless Firmware]"
sync

KERNEL_LOG=""
if command -v journalctl >/dev/null 2>&1; then
    KERNEL_LOG=$(journalctl -k -b 0 -o short-monotonic --no-pager 2>/dev/null || true)
fi
if [ -z "$KERNEL_LOG" ] && command -v dmesg >/dev/null 2>&1; then
    KERNEL_LOG=$(dmesg 2>/dev/null || true)
fi

echo "--- Network interface status ---"
if command -v ip >/dev/null 2>&1; then
    WLAN_IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^(wlan[0-9]+|wl[^:]+)$/ {print $2; exit}' || true)
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
if [ -n "$KERNEL_LOG" ]; then
    FW_ERRORS=$(printf '%s\n' "$KERNEL_LOG" | grep -iE '(^|[^[:alnum:]_])(ath11k(_pci)?|ath12k(_pci)?|iwlwifi|rtw_88|rtw88|b43|brcmfmac)([^[:alnum:]_]|$)' | grep -iE 'fail|error|crash|crashed|timeout' | head -10 || true)
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
    FW_VERSION=$(printf '%s\n' "$KERNEL_LOG" | grep -iE '(ath11k|ath12k).*(fw_version|fw_build|firmware)|iwlwifi.*loaded firmware|rtw_88.*firmware|rtw88.*firmware' | tail -3 || true)
    if [ -n "$FW_VERSION" ]; then echo "$FW_VERSION"; else echo "  Firmware version info not available."; fi
else
    echo "  Kernel log unavailable. Run as root for firmware evidence."
fi
sync

echo "--- Coupled resume-device failure check ---"
SOF_FATAL=""
if [ -n "$KERNEL_LOG" ]; then
    SOF_FATAL=$(printf '%s\n' "$KERNEL_LOG" | grep -iE 'snd_sof.*ipc.*(-22|timed out)|DSP panic|Failed to restore pipeline after resume|Failed to acquire HW lock' | tail -5 || true)
fi
if [ -n "${FW_ERRORS:-}" ] && [ -n "$SOF_FATAL" ]; then
    echo "  RESUME_SIGNATURE: WIFI_AND_SOF_FAILURES_IN_CURRENT_BOOT"
    echo "  Wireless firmware and SOF audio failures both appear in this boot; compare their timestamps with the same resume window."
elif [ -z "${WLAN_IFACE:-}" ] && [ -n "$SOF_FATAL" ]; then
    echo "  RESUME_SIGNATURE: WIFI_MISSING_WITH_SOF_FAILURE_IN_CURRENT_BOOT"
    echo "  No wireless interface is visible and a SOF failure is retained; timestamp correlation is still required."
else
    echo "  No coupled Wi-Fi/SOF failure signature in the current boot."
fi
sync

echo "--- PCI device presence ---"
if command -v lspci >/dev/null 2>&1; then
    lspci 2>/dev/null | grep -iE 'Network|WiFi|Wireless' | head -5 || echo "  No wireless PCI device found."
fi
sync
