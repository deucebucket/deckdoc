#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: GPU & APU]"
sync

if command -v journalctl >/dev/null 2>&1; then
    echo "--- Current boot amdgpu errors (journalctl -b 0 --priority=err) ---"
    journalctl -k -b 0 --priority=err | grep -iE 'ring gfx.*timeout|amdgpu_job_timedout|VRAM is lost|amdgpu.*fail' || echo "No amdgpu errors in current boot."
    sync

    echo "--- Current boot GPU reset outcomes ---"
    if journalctl -k -b 0 | grep -q 'gpu reset'; then
        journalctl -k -b 0 | grep -i 'gpu reset' | tail -5
        sync
        if journalctl -k -b 0 | grep -q 'gpu reset succeeded'; then
            echo "NOTE: GPU reset was recoverable (soft)."
        fi
        if journalctl -k -b 0 | grep -q 'gpu reset failed\|GPU reset skipped'; then
            echo "CRITICAL: GPU reset was NON-recoverable (hard lock)."
        fi
    else
        echo "No GPU resets in current boot."
    fi
    sync
fi

if command -v dmesg >/dev/null 2>&1; then
    echo "--- Full dmesg (historical) amdgpu panics ---"
    dmesg | grep -iE 'ring gfx.*timeout|amdgpu_job_timedout|gpu reset|VRAM is lost|amdgpu.*fail' || echo "No critical amdgpu panics found in dmesg."
    sync
fi

CPU_FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
GPU_FREQ_FILE="${DECKDOC_DRM_CARD_PATH:-/sys/class/drm/card0}/device/pp_dpm_sclk"

if [ -f "$CPU_FREQ_FILE" ]; then
    CPU_FREQ=$(cat "$CPU_FREQ_FILE")
    echo "CPU0 Current Freq: ${CPU_FREQ} kHz"
    if [ "$CPU_FREQ" -le 405000 ]; then
        echo "WARNING: CPU scaling abnormally low (Possible 400MHz Lock Bug)."
    fi
fi
sync

if [ -f "$GPU_FREQ_FILE" ]; then
    echo "GPU SCLK States:"
    cat "$GPU_FREQ_FILE" | grep '\*' || echo "Unable to read active GPU SCLK."
fi
sync
