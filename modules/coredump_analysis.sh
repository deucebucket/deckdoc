#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Core Dump / Crash Analysis]"
sync

if ! command -v coredumpctl >/dev/null 2>&1; then
    echo "WARNING: coredumpctl not found. systemd-coredump may not be installed."
    sync
    exit 0
fi

echo "--- Crash count by binary ---"
coredumpctl list 2>/dev/null | awk 'NR>1 {for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' 2>/dev/null | \
    sed 's/ ([^)]*)//g' | awk '{count[$0]++} END {for (bin in count) printf "  %-40s %d crashes\n", bin, count[bin]}' 2>/dev/null | \
    sort -rn -k2 || echo "No core dumps recorded."
sync

echo "--- Recent crashes (last 10) ---"
coredumpctl list 2>/dev/null | tail -10 || echo "No core dumps recorded."
sync

echo "--- Signal analysis ---"
SIGTRAP_COUNT=$(coredumpctl list 2>/dev/null | grep -c 'SIGTRAP' || true)
SIGABRT_COUNT=$(coredumpctl list 2>/dev/null | grep -c 'SIGABRT' || true)
SIGSEGV_COUNT=$(coredumpctl list 2>/dev/null | grep -c 'SIGSEGV' || true)
echo "  SIGTRAP (steamwebhelper expected): ${SIGTRAP_COUNT}"
echo "  SIGABRT (application abort):       ${SIGABRT_COUNT}"
echo "  SIGSEGV (segmentation fault):      ${SIGSEGV_COUNT}"
if [ "$SIGABRT_COUNT" -gt 5 ] || [ "$SIGSEGV_COUNT" -gt 5 ]; then
    echo "CRITICAL: Elevated crash rate detected. Investigate SIGABRT/SIGSEGV sources."
fi
sync

echo "--- Disk usage ---"
if [ -d /var/lib/systemd/coredump ]; then
    DUMP_SIZE=$(du -sh /var/lib/systemd/coredump/ 2>/dev/null | cut -f1)
    TOTAL_DUMPS=$(coredumpctl list 2>/dev/null | wc -l)
    echo "  Total dumps stored: ${TOTAL_DUMPS}"
    echo "  Total disk usage:   ${DUMP_SIZE}"
    if [ -n "$TOTAL_DUMPS" ] && [ "$TOTAL_DUMPS" -gt 100 ]; then
        echo "WARNING: Large number of accumulated core dumps (>100). Consider cleanup."
    fi
else
    echo "  Core dump directory not found."
fi
sync

echo "--- Desktop environment stability ---"
coredumpctl list 2>/dev/null | grep -iE 'kwin_wayland|plasmashell|plasma_session' | tail -5 || echo "No desktop environment crashes recorded."
sync
