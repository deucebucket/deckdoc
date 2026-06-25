#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Gamescope Session Health]"
sync

echo "--- Gamescope core dumps ---"
if command -v coredumpctl >/dev/null 2>&1; then
    GAMESCOPE_DUMPS=$(coredumpctl list 2>/dev/null | grep -iE 'gamescope' | tail -10 || true)
    if [ -n "$GAMESCOPE_DUMPS" ]; then
        echo "$GAMESCOPE_DUMPS"
        GAMESCOPE_COUNT=$(coredumpctl list 2>/dev/null | grep -ic 'gamescope' || true)
        echo "  Total gamescope crashes: ${GAMESCOPE_COUNT}"
        if [ "${GAMESCOPE_COUNT:-0}" -gt 3 ]; then
            echo "  CRITICAL: Gamescope crash rate elevated (>3). Multiple session restarts likely."
        fi
    else
        echo "  No gamescope crashes recorded."
    fi
else
    echo "  coredumpctl not available."
fi
sync

echo "--- Gamescope session errors (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    SESSION_LOG=$(journalctl -u gamescope-session --priority=err -n 30 2>/dev/null)
    if [ -z "$SESSION_LOG" ]; then
        SESSION_LOG=$(journalctl --user -u gamescope-session --priority=err -n 30 2>/dev/null)
    fi
    if [ -n "$SESSION_LOG" ]; then
        echo "$SESSION_LOG" | grep -iE 'error|warn|fail|core dump|terminate|abort' | head -10 || true
    else
        echo "  No gamescope session errors in current boot."
    fi

    sync
    echo "--- Session restart count ---"
    SESSION_STARTS=$(journalctl -u gamescope-session 2>/dev/null | grep -c 'Started\|Starting' || true)
    if [ -z "$SESSION_STARTS" ] || [ "$SESSION_STARTS" -eq 0 ]; then
        SESSION_STARTS=$(journalctl --user -u gamescope-session 2>/dev/null | grep -c 'Started\|Starting' || true)
    fi
    RESTART_COUNT="${SESSION_STARTS:-0}"
    echo "  Gamescope session starts: ${RESTART_COUNT} (1 = normal, >1 indicates restarts)"
    if [ "${RESTART_COUNT:-0}" -gt 1 ]; then
        echo "  WARNING: Gamescope session restarted ${RESTART_COUNT} times. Possible compositor instability."
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
