#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Memory & Swap Pressure]"
sync

echo "--- Memory status ---"
if [ -f /proc/meminfo ]; then
    MEM_TOTAL=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    MEM_AVAIL=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    MEM_FREE=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
    SWAP_TOTAL=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
    SWAP_FREE=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)

    MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1024/1024}")
    MEM_AVAIL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_AVAIL/1024/1024}")
    MEM_USED_PCT=0
    if [ "$MEM_TOTAL" -gt 0 ]; then
        MEM_USED_PCT=$(( (MEM_TOTAL - MEM_AVAIL) * 100 / MEM_TOTAL ))
    fi

    echo "  Total RAM:      ${MEM_TOTAL_GB} GB"
    echo "  Available RAM:  ${MEM_AVAIL_GB} GB"
    echo "  Memory used:    ${MEM_USED_PCT}%"

    if [ "$MEM_AVAIL" -lt 1048576 ]; then
        echo "  CRITICAL: Available memory below 1 GB. System under severe memory pressure."
    elif [ "$MEM_AVAIL" -lt 2097152 ]; then
        echo "  WARNING: Available memory below 2 GB."
    fi

    if [ -n "$SWAP_TOTAL" ] && [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))
        SWAP_PCT=$(( SWAP_USED * 100 / SWAP_TOTAL ))
        SWAP_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $SWAP_TOTAL/1024/1024}")
        echo "  Swap total:     ${SWAP_TOTAL_GB} GB"
        echo "  Swap used:      ${SWAP_PCT}%"
        if [ "$SWAP_PCT" -gt 50 ]; then
            echo "  CRITICAL: Swap usage exceeds 50%. Memory exhaustion likely."
        fi
    else
        echo "  Swap: none configured"
    fi
else
    echo "  /proc/meminfo not found."
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
if [ -f /proc/vmstat ]; then
    SI=$(awk '/^pswpin/ {print $2}' /proc/vmstat)
    SO=$(awk '/^pswpout/ {print $2}' /proc/vmstat)
    echo "  Swap in (pswpin):  ${SI:-0} pages (total since boot)"
    echo "  Swap out (pswpout): ${SO:-0} pages (total since boot)"
    if [ "${SI:-0}" -gt 50000 ] || [ "${SO:-0}" -gt 50000 ]; then
        echo "  WARNING: High cumulative swap I/O. System frequently memory-constrained."
    fi
fi
sync

echo "--- Top memory consumers ---"
if command -v ps >/dev/null 2>&1; then
    ps -eo pid,comm,%mem,rss --sort=-%mem 2>/dev/null | head -8
fi
sync
