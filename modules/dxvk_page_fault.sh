#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: GPU VM Page Fault Analysis (DXVK/VKD3D correlation)]"
sync

echo "--- GPU page fault analysis (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    PAGE_FAULTS=$(journalctl -k -b 0 2>/dev/null | grep -iE 'page fault|GCVM_L2_PROTECTION|UTCL2' | head -20 || true)
    if [ -n "$PAGE_FAULTS" ]; then
        echo "  GPU page faults detected:"
        echo "$PAGE_FAULTS"
        sync

        echo "--- Fault classification ---"
        CB_FAULTS=$(echo "$PAGE_FAULTS" | grep -c 'CB (0x0)' || true)
        DB_FAULTS=$(echo "$PAGE_FAULTS" | grep -c 'DB (0x4)' || true)
        CPF_FAULTS=$(echo "$PAGE_FAULTS" | grep -c 'CPF (0x5)' || true)
        CPD_FAULTS=$(echo "$PAGE_FAULTS" | grep -c 'CPD (0x6)' || true)

        [ "$CB_FAULTS" -gt 0 ] && echo "  Color Buffer (CB) faults: ${CB_FAULTS} — GPU client classification; correlate process/API and reset state"
        [ "$DB_FAULTS" -gt 0 ] && echo "  Depth Buffer (DB) faults: ${DB_FAULTS} — GPU client classification; correlate process/API and reset state"
        [ "$CPF_FAULTS" -gt 0 ] && echo "  Command Processor (CPF) faults: ${CPF_FAULTS} — CRITICAL: command-path fault; driver, workload, and hardware remain candidates"
        [ "$CPD_FAULTS" -gt 0 ] && echo "  Command Processor Data (CPD) faults: ${CPD_FAULTS} — CRITICAL: command-path fault; driver, workload, and hardware remain candidates"

        echo "--- Page fault severity ---"
        MAPPING_ERRORS=$(echo "$PAGE_FAULTS" | grep -c 'MAPPING_ERROR' || true)
        WALKER_ERRORS=$(echo "$PAGE_FAULTS" | grep -c 'WALKER_ERROR' || true)
        PERM_FAULTS=$(echo "$PAGE_FAULTS" | grep -c 'PERMISSION_FAULTS' || true)

        [ "$MAPPING_ERRORS" -gt 0 ] && echo "  MAPPING_ERROR detected — the VM mapping failed; root cause is not identified by this bit alone."
        [ "$WALKER_ERRORS" -gt 0 ] && echo "  WALKER_ERROR detected — page-table walk failed; correlate driver, workload, memory pressure, and recurrence."
        [ "$PERM_FAULTS" -gt 0 ] && echo "  PERMISSION_FAULTS detected — attempted access to protected GPU memory region."
    else
        echo "  No GPU page faults in current boot."
    fi
fi
sync

echo "--- Process attribution ---"
if command -v journalctl >/dev/null 2>&1; then
    ATTRIBUTION=$(journalctl -k -b 0 2>/dev/null | grep -E 'page fault|amdgpu_job_timedout' | grep -oP '(?<=process )\S+(?= pid|$)' | sort | uniq -c | sort -rn | head -5 || true)
    if [ -n "$ATTRIBUTION" ]; then echo "$ATTRIBUTION"; else echo "  No process attribution available for GPU faults."; fi
fi
sync

echo "--- Ring timeout correlation ---"
if command -v journalctl >/dev/null 2>&1; then
    RING_TIMEOUTS=$(journalctl -k -b 0 2>/dev/null | grep -iE 'ring gfx.*timeout|ring sdma0.*timeout|ring comp.*timeout' | head -10 || true)
    if [ -n "$RING_TIMEOUTS" ]; then
        echo "$RING_TIMEOUTS"
        echo "  HIGH: GPU page-fault and ring-timeout evidence must be correlated by timestamp."
    else
        echo "  No ring timeouts. A standalone page fault still requires process/API/driver correlation."
    fi
fi
sync

echo "--- GPU reset history ---"
if command -v journalctl >/dev/null 2>&1; then
    RESETS=$(journalctl -k -b 0 2>/dev/null | grep -i 'GPU reset' | head -5 || true)
    if [ -n "$RESETS" ]; then
        echo "  GPU resets detected in current boot:"
        echo "$RESETS"
        if echo "$RESETS" | grep -q 'failed'; then
            echo "  CRITICAL: GPU reset failed. System-level instability or hardware fault."
        elif echo "$RESETS" | grep -qi 'succeeded'; then
            echo "  GPU reset succeeded; affected clients may still have terminated."
        fi
    else
        echo "  No GPU resets in current boot."
    fi
fi
sync
