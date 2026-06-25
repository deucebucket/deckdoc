#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Audio DSP (SOF)]"
sync

if command -v journalctl >/dev/null 2>&1; then
    echo "--- Current boot SOF DSP errors ---"
    SOF_ERRORS=$(journalctl -k -b 0 --priority=err 2>/dev/null | grep -iE 'snd_sof|DSP panic|ipc tx.*failed|ipc.*timed out' || true)
    if [ -n "$SOF_ERRORS" ]; then
        echo "$SOF_ERRORS"
        sync
        if echo "$SOF_ERRORS" | grep -q 'DSP panic'; then
            echo "CRITICAL: DSP firmware panicked. Requires full reboot to recover."
        fi
        if echo "$SOF_ERRORS" | grep -q 'ipc tx.*failed.*-22'; then
            echo "CRITICAL: IPC error -22 detected. Audio subsystem in unrecoverable state."
        fi
        if echo "$SOF_ERRORS" | grep -q 'acp_sof_ipc_send_msg: Failed to acquire HW lock'; then
            echo "CRITICAL: DSP hardware lock contention. Suspend/resume cycle likely cause."
        fi
    else
        echo "No SOF DSP errors in current boot."
    fi
    sync

    echo "--- DSP firmware state ---"
    FW_STATE=$(journalctl -k -b 0 2>/dev/null | grep -i 'fw_state' | tail -1 || true)
    if [ -n "$FW_STATE" ]; then
        echo "$FW_STATE"
        if echo "$FW_STATE" | grep -q 'SOF_FW_BOOT_COMPLETE'; then
            echo "DSP firmware boot completed successfully."
        fi
    else
        echo "No DSP firmware state information available."
    fi
    sync

    echo "--- Resume pipeline restoration ---"
    journalctl -k -b 0 2>/dev/null | grep -iE 'Failed to restore pipeline after resume|Failed to setup widget' | head -5 || echo "No pipeline restoration errors."
    sync
fi

echo "--- Audio device presence ---"
if [ -d /proc/asound ]; then
    cat /proc/asound/cards 2>/dev/null || echo "Cannot read audio card list."
    sync
    if command -v aplay >/dev/null 2>&1; then
        aplay -l 2>/dev/null | grep -i 'card' || echo "No playback devices found."
    fi
else
    echo "/proc/asound not available — audio subsystem may not be initialized."
fi
sync

if command -v pw-cli >/dev/null 2>&1; then
    echo "--- PipeWire audio sinks ---"
    pw-cli list-objects 2>/dev/null | grep -iE 'node.*Audio|alsa_output|alsa_input' | head -10 || echo "No PipeWire audio sinks detected."
fi
sync
