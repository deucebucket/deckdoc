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

BOOT_START=$(uptime -s 2>/dev/null || true)
ALL_DUMPS=$(coredumpctl list --no-legend --no-pager 2>/dev/null || true)
LAST_24H_DUMPS=$(coredumpctl list --no-legend --no-pager --since "24 hours ago" 2>/dev/null || true)
if [ -n "$BOOT_START" ]; then
    BOOT_DUMPS=$(coredumpctl list --no-legend --no-pager --since "$BOOT_START" 2>/dev/null || true)
else
    BOOT_DUMPS=""
fi

count_signal() {
    local records="$1" signal="$2"
    printf '%s\n' "$records" | awk -v wanted="$signal" '
        { for (i=1; i<=NF; i++) if ($i == wanted) count++ }
        END { print count+0 }
    '
}

count_executable() {
    local records="$1" pattern="$2"
    printf '%s\n' "$records" | awk -v wanted="$pattern" '
        {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^SIG[A-Z0-9]+$/ && $(i+2) ~ wanted) count++
            }
        }
        END { print count+0 }
    '
}

count_signal_for_executable() {
    local records="$1" pattern="$2" signal="$3"
    printf '%s\n' "$records" | awk -v wanted="$pattern" -v wanted_signal="$signal" '
        {
            for (i=1; i<=NF; i++) {
                if ($i == wanted_signal && $(i+2) ~ wanted) count++
            }
        }
        END { print count+0 }
    '
}

count_records() {
    local records="$1"
    printf '%s\n' "$records" | awk '
        { for (i=1; i<=NF; i++) if ($i ~ /^SIG[A-Z0-9]+$/) { count++; break } }
        END { print count+0 }
    '
}

echo "--- Historical crash count by executable (retained records) ---"
# coredumpctl's executable is two fields after the signal regardless of the
# localized date/time prefix. Aggregate that field only; the previous parser
# accidentally treated every whole row as a unique executable.
COUNTS=$(printf '%s\n' "$ALL_DUMPS" | awk '
    {
        for (i=1; i<=NF; i++) {
            if ($i ~ /^SIG[A-Z0-9]+$/ && $(i+2) != "") { count[$(i+2)]++; break }
        }
    }
    END { for (exe in count) printf "  %-52s %d crashes\n", exe, count[exe] }
' | sort -k2,2nr)
if [ -n "$COUNTS" ]; then echo "$COUNTS"; else echo "  No retained core dumps."; fi
sync

echo "--- Current-boot crashes ---"
BOOT_DUMP_COUNT=$(count_records "$BOOT_DUMPS")
echo "  Current-boot core dumps: ${BOOT_DUMP_COUNT}"
if [ "$BOOT_DUMP_COUNT" -gt 0 ]; then
    printf '%s\n' "$BOOT_DUMPS" | tail -10
else
    echo "  No core dumps in the current boot."
fi
sync

echo "--- Crash activity in the last 24 hours ---"
LAST_24H_COUNT=$(count_records "$LAST_24H_DUMPS")
STEAMWEBHELPER_24H=$(count_executable "$LAST_24H_DUMPS" '/steamwebhelper$')
GAMESCOPE_24H=$(count_executable "$LAST_24H_DUMPS" '/gamescope(-wl)?$')
WINE_PROTON_24H=$(count_executable "$LAST_24H_DUMPS" '/(wine[^/]*|proton[^/]*)$')
STEAMWEBHELPER_TRAPS_24H=$(count_signal_for_executable "$LAST_24H_DUMPS" '/steamwebhelper$' SIGTRAP)
GAMESCOPE_ABORTS_24H=$(count_signal_for_executable "$LAST_24H_DUMPS" '/gamescope(-wl)?$' SIGABRT)
GAMESCOPE_SEGV_24H=$(count_signal_for_executable "$LAST_24H_DUMPS" '/gamescope(-wl)?$' SIGSEGV)
echo "  All crashes:             ${LAST_24H_COUNT}"
echo "  steamwebhelper crashes:  ${STEAMWEBHELPER_24H} (${STEAMWEBHELPER_TRAPS_24H} SIGTRAP)"
echo "  Gamescope crashes:       ${GAMESCOPE_24H} (${GAMESCOPE_ABORTS_24H} SIGABRT, ${GAMESCOPE_SEGV_24H} SIGSEGV)"
echo "  Wine/Proton crashes:     ${WINE_PROTON_24H}"
if [ "$LAST_24H_COUNT" -gt 10 ]; then
    echo "  HIGH: More than 10 crashes were recorded in the last 24 hours."
fi
if [ "$STEAMWEBHELPER_TRAPS_24H" -gt 0 ]; then
    echo "  NOTE: steamwebhelper SIGTRAP records need incident-time correlation; they are not equivalent to a compositor crash."
fi
if [ $((GAMESCOPE_ABORTS_24H + GAMESCOPE_SEGV_24H)) -gt 0 ]; then
    echo "  HIGH: Gamescope SIGABRT/SIGSEGV records occurred in the last 24 hours."
fi
sync

echo "--- Steam Deck overlay crash signature ---"
MANGOAPP_DUMPS=$(count_executable "$ALL_DUMPS" '/mangoapp$')
MANGOAPP_BOOT_DUMPS=$(count_executable "$BOOT_DUMPS" '/mangoapp$')
echo "  Historical MangoApp dumps:   ${MANGOAPP_DUMPS}"
echo "  Current-boot MangoApp dumps: ${MANGOAPP_BOOT_DUMPS}"
if [ "${DECKDOC_SKIP_JOURNAL:-0}" != "1" ] && command -v journalctl >/dev/null 2>&1; then
    FDINFO_ABORT=$(run_user journalctl --user -b 0 -u gamescope-mangoapp.service 2>/dev/null | grep -E "Permission denied: '/proc/[0-9]+/fdinfo'" | tail -5 || true)
    if [ -n "$FDINFO_ABORT" ]; then
        echo "$FDINFO_ABORT"
        echo "  CRASH_SIGNATURE: MANGOAPP_FDINFO_PERMISSION_ABORT"
        echo "  Inspect clients that set PR_SET_DUMPABLE=0; this can restrict /proc/<pid>/fdinfo even for the same user."
    fi
fi
sync

echo "--- Signal analysis ---"
SIGTRAP_COUNT=$(count_signal "$BOOT_DUMPS" SIGTRAP)
SIGABRT_COUNT=$(count_signal "$BOOT_DUMPS" SIGABRT)
SIGSEGV_COUNT=$(count_signal "$BOOT_DUMPS" SIGSEGV)
echo "  Current-boot SIGTRAP (steamwebhelper often expected): ${SIGTRAP_COUNT}"
echo "  Current-boot SIGABRT (application abort):             ${SIGABRT_COUNT}"
echo "  Current-boot SIGSEGV (segmentation fault):            ${SIGSEGV_COUNT}"
if [ "$SIGABRT_COUNT" -gt 5 ] || [ "$SIGSEGV_COUNT" -gt 5 ]; then
    echo "CRITICAL: Elevated current-boot crash rate detected. Investigate SIGABRT/SIGSEGV sources."
fi
sync

echo "--- Disk usage ---"
if [ -d /var/lib/systemd/coredump ]; then
    DUMP_SIZE=$(du -sh /var/lib/systemd/coredump/ 2>/dev/null | cut -f1)
    TOTAL_DUMPS=$(count_records "$ALL_DUMPS")
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
DESKTOP_DUMPS=$(printf '%s\n' "$ALL_DUMPS" | grep -iE 'kwin_wayland|plasmashell|plasma_session' | tail -5 || true)
if [ -n "$DESKTOP_DUMPS" ]; then echo "$DESKTOP_DUMPS"; else echo "No desktop environment crashes recorded."; fi
sync
