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

echo "[MODULE: Gamescope Session Health]"
sync

echo "--- Gamescope and MangoApp core dumps ---"
if command -v coredumpctl >/dev/null 2>&1; then
    BOOT_START=$(uptime -s 2>/dev/null || true)
    HISTORICAL_DUMPS=$(coredumpctl list --no-legend --no-pager 2>/dev/null | grep -iE '/(gamescope|mangoapp)([[:space:]]|$)' || true)
    CURRENT_DUMPS=""
    if [ -n "$BOOT_START" ]; then
        CURRENT_DUMPS=$(coredumpctl list --no-legend --no-pager --since "$BOOT_START" 2>/dev/null | grep -iE '/(gamescope|mangoapp)([[:space:]]|$)' || true)
    fi
    HISTORICAL_GAMESCOPE_COUNT=$(printf '%s\n' "$HISTORICAL_DUMPS" | grep -ic '/gamescope' || true)
    HISTORICAL_MANGOAPP_COUNT=$(printf '%s\n' "$HISTORICAL_DUMPS" | grep -ic '/mangoapp' || true)
    CURRENT_GAMESCOPE_COUNT=$(printf '%s\n' "$CURRENT_DUMPS" | grep -ic '/gamescope' || true)
    CURRENT_MANGOAPP_COUNT=$(printf '%s\n' "$CURRENT_DUMPS" | grep -ic '/mangoapp' || true)
    echo "  Historical Gamescope crashes:   ${HISTORICAL_GAMESCOPE_COUNT}"
    echo "  Historical MangoApp crashes:    ${HISTORICAL_MANGOAPP_COUNT}"
    echo "  Current-boot Gamescope crashes: ${CURRENT_GAMESCOPE_COUNT}"
    echo "  Current-boot MangoApp crashes:  ${CURRENT_MANGOAPP_COUNT}"
    if [ -n "$CURRENT_DUMPS" ]; then echo "  Raw coredump rows are omitted; fixed Gamescope/MangoApp counts are retained."; fi
    if [ "${CURRENT_GAMESCOPE_COUNT:-0}" -gt 0 ]; then
        echo "  CRITICAL: Gamescope itself crashed in the current boot."
    fi
    if [ "${HISTORICAL_MANGOAPP_COUNT:-0}" -gt 3 ] && [ "${CURRENT_MANGOAPP_COUNT:-0}" -eq 0 ]; then
        echo "  NOTE: Historical MangoApp abort records are retained; none occurred in the current boot."
    fi
else
    echo "  coredumpctl not available."
fi
sync

echo "--- Gamescope session errors (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    SESSION_LOG=$(journalctl -b 0 -u gamescope-session --priority=err -n 30 2>/dev/null)
    if [ -z "$SESSION_LOG" ]; then
        SESSION_LOG=$(run_user journalctl --user -b 0 -u gamescope-session.service --priority=err -n 30 2>/dev/null)
    fi
    SESSION_MATCHES=$(printf '%s\n' "$SESSION_LOG" | grep -iE 'error|warn|fail|core dump|terminate|abort' | head -10 || true)
    if [ -n "$SESSION_MATCHES" ]; then
        echo "$SESSION_MATCHES"
    else
        echo "  No gamescope session errors in current boot."
    fi

    sync
    echo "--- Session restart count ---"
    ACTIVE_STATE=$(run_user systemctl --user show gamescope-session.service --property=ActiveState --value 2>/dev/null || true)
    SYSTEMD_RESTARTS=$(run_user systemctl --user show gamescope-session.service --property=NRestarts --value 2>/dev/null || true)
    SESSION_SOURCE="journal"
    case "$SYSTEMD_RESTARTS" in ''|*[!0-9]*) SYSTEMD_RESTARTS="" ;; esac
    if [ -n "$SYSTEMD_RESTARTS" ] && [ "$ACTIVE_STATE" = "active" ]; then
        SESSION_STARTS=$((SYSTEMD_RESTARTS + 1))
        SESSION_SOURCE="systemd NRestarts + active invocation"
    else
        SESSION_STARTS=$(journalctl -b 0 -u gamescope-session 2>/dev/null | grep -c 'Started Gamescope' || true)
        if [ -z "$SESSION_STARTS" ] || [ "$SESSION_STARTS" -eq 0 ]; then
            SESSION_STARTS=$(run_user journalctl --user -b 0 -u gamescope-session.service 2>/dev/null | grep -c 'Started Gamescope Session' || true)
        fi
    fi
    RESTART_COUNT="${SESSION_STARTS:-0}"
    echo "  Gamescope session starts: ${RESTART_COUNT} (source: ${SESSION_SOURCE}; 1 = normal)"
    if [ "${RESTART_COUNT:-0}" -gt 3 ]; then
        echo "  CRITICAL: Gamescope session started ${RESTART_COUNT} times in one boot. Repeated compositor instability."
    elif [ "${RESTART_COUNT:-0}" -gt 1 ]; then
        echo "  WARNING: Gamescope session restarted ${RESTART_COUNT} times. Possible compositor instability."
    fi
fi
sync

echo "--- MangoApp overlay health (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    MANGO_LOG=$(run_user journalctl --user -b 0 -u gamescope-mangoapp.service 2>/dev/null | tail -80 || true)
    FDINFO_ABORT=$(echo "$MANGO_LOG" | grep -E "Permission denied: '/proc/[0-9]+/fdinfo'" | tail -5 || true)
    MANGO_ACTIVE=false
    if run_user systemctl --user is-active --quiet gamescope-mangoapp.service 2>/dev/null; then
        MANGO_ACTIVE=true
    fi
    if [ "$MANGO_ACTIVE" = "true" ]; then
        echo "  MangoApp service is active."
        if [ -n "$FDINFO_ABORT" ]; then
            echo "  NOTE: This boot contains an earlier fdinfo permission abort, but the service has recovered."
        fi
    elif [ -n "$FDINFO_ABORT" ]; then
        echo "$FDINFO_ABORT"
        echo "  MANGOAPP_SIGNATURE: FDINFO_PERMISSION_ABORT"
        echo "  A nondumpable client made /proc/<pid>/fdinfo unreadable and MangoApp aborted instead of skipping it."
    elif echo "$MANGO_LOG" | grep -qiE 'Main process exited.*ABRT|Start request repeated too quickly|Failed with result'; then
        echo "  WARNING: gamescope-mangoapp.service failed for another reason:"
        echo "$MANGO_LOG" | grep -iE 'Main process exited|Start request repeated|Failed with result' | tail -10
    else
        echo "  MangoApp service is inactive; no fdinfo permission signature was found."
    fi
fi
sync

echo "--- Vulkan descriptor status ---"
if command -v journalctl >/dev/null 2>&1; then
    VK_ERRORS=$(journalctl -b 0 --priority=err 2>/dev/null | grep -iE 'vkAllocateDescriptorSets|VK_ERROR|Vulkan.*fail' | head -5 || true)
    if [ -n "$VK_ERRORS" ]; then
        echo "  Vulkan errors detected:"
        echo "$VK_ERRORS"
        if echo "$VK_ERRORS" | grep -q 'vkAllocateDescriptorSets'; then
            echo "  CRITICAL: Vulkan descriptor allocation failure. Gamescope may crash on session start."
        fi
    else
        echo "  No Vulkan descriptor errors."
    fi
fi
sync

echo "--- Wayland protocol errors ---"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -b 0 2>/dev/null | grep -iE 'wp_color_manager|scRGB not supported|Wayland.*error|xdg_wm_base' | head -5 || echo "  No Wayland protocol errors."
fi
sync
