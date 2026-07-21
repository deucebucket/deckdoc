#!/usr/bin/env bash
set -uo pipefail

SESSION_USER="${DECKDOC_SESSION_USER:-${SUDO_USER:-$(id -un)}}"
SESSION_UID=$(id -u "$SESSION_USER" 2>/dev/null || echo "")

run_user() {
    if [ "$(id -un)" = "$SESSION_USER" ]; then
        XDG_RUNTIME_DIR="/run/user/${SESSION_UID}" "$@"
    else
        runuser -u "$SESSION_USER" -- env XDG_RUNTIME_DIR="/run/user/${SESSION_UID}" "$@"
    fi
}

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

echo "--- Steam Deck overlay crash signature ---"
MANGOAPP_DUMPS=$(coredumpctl list 2>/dev/null | grep -c '/mangoapp' || true)
echo "  MangoApp dumps: ${MANGOAPP_DUMPS}"
if command -v journalctl >/dev/null 2>&1; then
    FDINFO_ABORT=$(run_user journalctl --user -b 0 -u gamescope-mangoapp.service 2>/dev/null | grep -E "Permission denied: '/proc/[0-9]+/fdinfo'" | tail -5 || true)
    if [ -n "$FDINFO_ABORT" ]; then
        echo "$FDINFO_ABORT"
        echo "  CRASH_SIGNATURE: MANGOAPP_FDINFO_PERMISSION_ABORT"
        echo "  Inspect clients that set PR_SET_DUMPABLE=0; this can restrict /proc/<pid>/fdinfo even for the same user."
    fi
fi
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
