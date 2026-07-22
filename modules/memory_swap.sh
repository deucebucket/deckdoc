#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Memory & Swap Pressure]"
sync

PROC_ROOT="${DECKDOC_PROC_ROOT:-/proc}"

echo "--- Memory status ---"
if [ -f "${PROC_ROOT}/meminfo" ]; then
    MEM_TOTAL=$(awk '/^MemTotal:/ {print $2}' "${PROC_ROOT}/meminfo")
    MEM_AVAIL=$(awk '/^MemAvailable:/ {print $2}' "${PROC_ROOT}/meminfo")
    MEM_FREE=$(awk '/^MemFree:/ {print $2}' "${PROC_ROOT}/meminfo")
    SWAP_TOTAL=$(awk '/^SwapTotal:/ {print $2}' "${PROC_ROOT}/meminfo")
    SWAP_FREE=$(awk '/^SwapFree:/ {print $2}' "${PROC_ROOT}/meminfo")

    MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1024/1024}")
    MEM_AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_AVAIL/1024/1024}")
    MEM_USED_PCT=0
    if [ "$MEM_TOTAL" -gt 0 ]; then
        MEM_USED_PCT=$(( (MEM_TOTAL - MEM_AVAIL) * 100 / MEM_TOTAL ))
    fi

    echo "  Total RAM:      ${MEM_TOTAL_GB} GB"
    echo "  Available RAM:  ${MEM_AVAIL_GB} GB"
    echo "  Memory used:    ${MEM_USED_PCT}%"

    if [ "$MEM_AVAIL" -lt 524288 ]; then
        echo "  CRITICAL: Available memory below 512 MB. System under severe memory pressure."
    elif [ "$MEM_AVAIL" -lt 1048576 ]; then
        echo "  WARNING: Available memory below 1 GB."
    fi

    if [ -n "$SWAP_TOTAL" ] && [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))
        SWAP_PCT=$(( SWAP_USED * 100 / SWAP_TOTAL ))
        SWAP_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $SWAP_TOTAL/1024/1024}")
        echo "  Swap total:     ${SWAP_TOTAL_GB} GB"
        echo "  Swap used:      ${SWAP_PCT}%"
        if [ "$SWAP_PCT" -gt 50 ]; then
            echo "  HIGH: Swap usage exceeds 50%. Check live swap I/O and OOM history."
        fi
    else
        echo "  Swap: none configured"
    fi
else
    echo "  ${PROC_ROOT}/meminfo not found."
fi
sync

echo "--- OOM events (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    OOM_EVENTS=$(journalctl -b 0 --priority=err 2>/dev/null | grep -iE 'oom-killer|Out of memory|page allocation failure|invoked oom-killer' | tail -10 || true)
    if [ -n "$OOM_EVENTS" ]; then
        echo "  CRITICAL: OOM events detected in current boot:"
        echo "$OOM_EVENTS"
    else
        echo "  No OOM events in current boot."
    fi
fi
sync

echo "--- Page swap activity ---"
if [ -f "${PROC_ROOT}/vmstat" ]; then
    SI=$(awk '/^pswpin/ {print $2}' "${PROC_ROOT}/vmstat")
    SO=$(awk '/^pswpout/ {print $2}' "${PROC_ROOT}/vmstat")
    echo "  Swap in (pswpin):  ${SI:-0} pages (total since boot)"
    echo "  Swap out (pswpout): ${SO:-0} pages (total since boot)"
    if [ "${SI:-0}" -gt 50000 ] || [ "${SO:-0}" -gt 50000 ]; then
        echo "  NOTE: Cumulative swap I/O is high, but it does not establish current pressure; use the live sample and incident time."
    fi
fi
sync


echo "--- Live vmstat sample ---"
if command -v vmstat >/dev/null 2>&1; then
    VMSTAT_SAMPLE=$(vmstat 1 "${DECKDOC_VMSTAT_SAMPLES:-3}" 2>/dev/null | tail -1 || true)
    if [ -n "$VMSTAT_SAMPLE" ]; then
        echo "  ${VMSTAT_SAMPLE}"
        LIVE_SI=$(printf '%s\n' "$VMSTAT_SAMPLE" | awk '{print $7+0}')
        LIVE_SO=$(printf '%s\n' "$VMSTAT_SAMPLE" | awk '{print $8+0}')
        if [ "$LIVE_SI" -gt 0 ] || [ "$LIVE_SO" -gt 0 ]; then
            echo "  WARNING: Live swap I/O observed (si=${LIVE_SI}, so=${LIVE_SO} KiB/s)."
        else
            echo "  No live swap I/O in this short sample."
        fi
    else
        echo "  vmstat returned no sample."
    fi
else
    echo "  vmstat not available."
fi
sync

echo "--- Top memory consumers ---"
if command -v ps >/dev/null 2>&1; then
    ps -eo pid,comm,%mem,rss --sort=-%mem 2>/dev/null | head -8
fi
sync
