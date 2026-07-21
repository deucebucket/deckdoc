#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Steam Client Logs]"
sync

SESSION_USER="${DECKDOC_SESSION_USER:-${SUDO_USER:-$(id -un)}}"
if [ "$SESSION_USER" = "root" ]; then
    SESSION_USER=$(loginctl list-users --no-legend 2>/dev/null | awk '$2 != "root" { print $2; exit }')
fi
SESSION_HOME="${DECKDOC_SESSION_HOME:-$(getent passwd "$SESSION_USER" 2>/dev/null | cut -d: -f6)}"
DUMP_DIR="${DECKDOC_DUMP_DIR:-/tmp/dumps}"

if [ -d "$DUMP_DIR" ]; then
    echo "--- Recent crash dumps (${DUMP_DIR}) ---"
    # Steam creates bookkeeping directories and settings.dat here on every
    # healthy boot. Only minidump/core filename classes are crash evidence.
    DUMP_FILES=$(find "$DUMP_DIR" -type f \( -iname '*.dmp' -o -iname '*.mdmp' -o -iname '*.core' -o -iname '*.crash' \) -print 2>/dev/null || true)
    if [ -n "$DUMP_FILES" ]; then DUMP_COUNT=$(printf '%s\n' "$DUMP_FILES" | wc -l); else DUMP_COUNT=0; fi
    echo "  Actual crash dump files: ${DUMP_COUNT}"
    if [ "$DUMP_COUNT" -gt 0 ]; then
        echo "  Last 5 dumps:"
        printf '%s\n' "$DUMP_FILES" | xargs -r stat -c '%Y %y %s %n' 2>/dev/null | sort -nr | head -5 | cut -d' ' -f2-
        RECENT_DUMPS=$(find "$DUMP_DIR" -mmin -60 -type f \( -iname '*.dmp' -o -iname '*.mdmp' -o -iname '*.core' -o -iname '*.crash' \) -print 2>/dev/null | wc -l)
        if [ "$RECENT_DUMPS" -gt 0 ]; then
            echo "  WARNING: ${RECENT_DUMPS} dumps created in the last hour. Active instability."
        fi
    else
        echo "  No crash dump files found; bookkeeping files are ignored."
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
if [ "${DECKDOC_SKIP_JOURNAL:-0}" != "1" ] && command -v journalctl >/dev/null 2>&1; then
    # `-o cat` strips the hostname (`steamdeck`), which otherwise makes an
    # unrelated later word such as i2c `tx_abort` satisfy `steam.*abort`.
    STEAM_ERRORS=$(journalctl -b 0 --priority=err -o cat 2>/dev/null | grep -iE 'steamwebhelper|steam([^[:alnum:]]|$).*(crash|signal|abort)' | tail -10 || true)
    if [ -n "$STEAM_ERRORS" ]; then echo "$STEAM_ERRORS"; else echo "  No Steam runtime errors in journalctl."; fi
fi
sync

echo "--- Proton prefix corruption check ---"
if command -v find >/dev/null 2>&1; then
    # A root DeckDoc run must still inspect the active Deck user's Steam tree,
    # not /root, or a healthy install is falsely reported as missing.
    STEAM_DIR="${SESSION_HOME}/.local/share/Steam/steamapps/compatdata"
    if [ -d "$STEAM_DIR" ]; then
        BROKEN_PREFIXES=$(find "$STEAM_DIR" -name 'drive_c' -prune -o -name '*.lock' -print 2>/dev/null | wc -l)
        echo "  Proton prefixes: $(ls -d "$STEAM_DIR"/*/ 2>/dev/null | wc -l) total"
        echo "  Lock/stall files: ${BROKEN_PREFIXES}"
    else
        echo "  Proton compatdata directory not found at ${STEAM_DIR}."
    fi
fi
sync
