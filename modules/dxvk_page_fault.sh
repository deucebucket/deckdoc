#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: DXVK/VKD3D GPU Page Fault Analysis]"
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

        [ "$CB_FAULTS" -gt 0 ] && echo "  Color Buffer (CB) faults: ${CB_FAULTS} — likely game/DXVK memory access issue"
        [ "$DB_FAULTS" -gt 0 ] && echo "  Depth Buffer (DB) faults: ${DB_FAULTS} — likely game/DXVK depth-stencil issue"
        [ "$CPF_FAULTS" -gt 0 ] && echo "  Command Processor (CPF) faults: ${CPF_FAULTS} — CRITICAL: may indicate driver or hardware fault"
        [ "$CPD_FAULTS" -gt 0 ] && echo "  Command Processor Data (CPD) faults: ${CPD_FAULTS} — CRITICAL: may indicate driver or hardware fault"

        echo "--- Page fault severity ---"
        MAPPING_ERRORS=$(echo "$PAGE_FAULTS" | grep -c 'MAPPING_ERROR' || true)
        WALKER_ERRORS=$(echo "$PAGE_FAULTS" | grep -c 'WALKER_ERROR' || true)
        PERM_FAULTS=$(echo "$PAGE_FAULTS" | grep -c 'PERMISSION_FAULTS' || true)

        [ "$MAPPING_ERRORS" -gt 0 ] && echo "  MAPPING_ERROR detected — VRAM mapping lost. GPU state compromised."
        [ "$WALKER_ERRORS" -gt 0 ] && echo "  WALKER_ERROR detected — page table walk failed. Likely hardware or driver bug."
        [ "$PERM_FAULTS" -gt 0 ] && echo "  PERMISSION_FAULTS detected — attempted access to protected GPU memory region."
    else
        echo "  No GPU page faults in current boot."
    fi
fi
sync

echo "--- Process attribution ---"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -k -b 0 2>/dev/null | grep -E 'page fault|amdgpu_job_timedout' | grep -oP '(?<=process )\S+(?= pid|$)' | sort | uniq -c | sort -rn | head -5 || echo "  No process attribution available for GPU faults."
fi
sync

echo "--- Ring timeout correlation ---"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -k -b 0 2>/dev/null | grep -iE 'ring gfx.*timeout|ring sdma0.*timeout|ring comp.*timeout' | head -10 || echo "  No ring timeouts. Page faults are standalone (likely DXVK/VKD3D bug, not driver crash)."
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
        fi
    else
        echo "  No GPU resets in current boot."
    fi
fi
sync
