#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Steam Client Logs]"
sync

DUMP_DIR="/tmp/dumps"

if [ -d "$DUMP_DIR" ]; then
    echo "--- Recent crash dumps (${DUMP_DIR}) ---"
    DUMP_COUNT=$(ls -1 "$DUMP_DIR" 2>/dev/null | wc -l)
    echo "  Total dumps in /tmp/dumps/: ${DUMP_COUNT}"
    if [ "$DUMP_COUNT" -gt 0 ]; then
        echo "  Last 5 dumps:"
        ls -lt "$DUMP_DIR" 2>/dev/null | head -6
        RECENT_DUMPS=$(find "$DUMP_DIR" -mmin -60 -type f 2>/dev/null | wc -l)
        if [ "$RECENT_DUMPS" -gt 0 ]; then
            echo "  WARNING: ${RECENT_DUMPS} dumps created in the last hour. Active instability."
        fi
    fi
else
    echo "  ${DUMP_DIR} not found. No Steam crash dumps available."
fi
sync

echo "--- Steam stdout log ---"
STDOUT_LOG="${DUMP_DIR}/steam_stdout.txt"
if [ -f "$STDOUT_LOG" ]; then
    LOG_SIZE=$(stat -c%s "$STDOUT_LOG" 2>/dev/null || echo 0)
    echo "  steam_stdout.txt size: ${LOG_SIZE} bytes"
    if [ "$LOG_SIZE" -gt 10485760 ]; then
        echo "  Log exceeds 10MB. Scanning last 1000 lines only."
        ERROR_LINES=$(tail -1000 "$STDOUT_LOG" 2>/dev/null | grep -ciE 'error|crash|fail|assert' || echo 0)
    else
        ERROR_LINES=$(grep -ciE 'error|crash|fail|assert' "$STDOUT_LOG" 2>/dev/null || echo 0)
    fi
    echo "  Error/crash/fail references: ${ERROR_LINES}"
    if [ "$ERROR_LINES" -gt 0 ]; then
        if [ "$LOG_SIZE" -gt 10485760 ]; then
            tail -1000 "$STDOUT_LOG" 2>/dev/null | grep -iE 'error|crash|fail|assert' | tail -10
        else
            grep -iE 'error|crash|fail|assert' "$STDOUT_LOG" 2>/dev/null | tail -10
        fi
    fi
else
    echo "  steam_stdout.txt not found."
fi
sync

echo "--- Steam runtime status ---"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -b 0 --priority=err 2>/dev/null | grep -iE 'steamwebhelper|steam.*crash|steam.*signal|steam.*abort' | tail -10 || echo "  No Steam runtime errors in journalctl."
fi
sync

echo "--- Proton prefix corruption check ---"
if command -v find >/dev/null 2>&1; then
    STEAM_DIR="${HOME}/.local/share/Steam/steamapps/compatdata"
    if [ -d "$STEAM_DIR" ]; then
        BROKEN_PREFIXES=$(find "$STEAM_DIR" -name 'drive_c' -prune -o -name '*.lock' -print 2>/dev/null | wc -l)
        echo "  Proton prefixes: $(ls -d "$STEAM_DIR"/*/ 2>/dev/null | wc -l) total"
        echo "  Lock/stall files: ${BROKEN_PREFIXES}"
    else
        echo "  Proton compatdata directory not found at ${STEAM_DIR}."
    fi
fi
sync
