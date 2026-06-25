#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Display Blackout Detection]"
sync

echo "--- DRM connector status ---"
for conn in /sys/class/drm/*/status; do
    [ -f "$conn" ] || continue
    name=$(echo "$conn" | cut -d/ -f5)
    status=$(cat "$conn")
    echo "  ${name}: ${status}"
done
sync

echo "--- eDP panel connected check ---"
EDP_CONNECTED=false
for conn in /sys/class/drm/*/status; do
    [ -f "$conn" ] || continue
    if echo "$conn" | grep -qi 'edp' && [ "$(cat "$conn")" = "connected" ]; then
        EDP_CONNECTED=true
        echo "  eDP panel is connected."
        break
    fi
done
if [ "$EDP_CONNECTED" = false ]; then
    echo "  WARNING: eDP panel NOT detected as connected. Display may not initialize."
fi
sync

echo "--- eDP modes / resolution ---"
for edid in /sys/class/drm/*/edid; do
    [ -f "$edid" ] || continue
    name=$(echo "$edid" | cut -d/ -f5)
    size=$(wc -c < "$edid" 2>/dev/null || echo 0)
    if [ "$size" -gt 0 ]; then
        echo "  ${name}: EDID present (${size} bytes) — panel should be initialized."
    else
        echo "  WARNING: ${name}: EDID empty — panel not communicating."
    fi
done
if ! ls /sys/class/drm/*/edid 2>/dev/null | grep -q .; then
    echo "  WARNING: No EDID files found — DRM may not have initialized the panel."
fi
sync

echo "--- Backlight state ---"
for bl in /sys/class/backlight/*; do
    [ -d "$bl" ] || continue
    name=$(basename "$bl")
    max=$(cat "$bl/max_brightness" 2>/dev/null || echo 0)
    cur=$(cat "$bl/brightness" 2>/dev/null || echo 0)
    echo "  ${name}: ${cur}/${max}"
    if [ "$max" -gt 0 ] && [ "$cur" -eq 0 ]; then
        echo "  WARNING: Backlight at 0 — screen may appear black."
    fi
done
sync

echo "--- DPMS / connector power state ---"
if command -v xrandr >/dev/null 2>&1; then
    xrandr --query 2>/dev/null | grep -E ' connected| disconnected|HDMI|eDP|DP|Screen' || echo "  xrandr query unavailable (no X server)."
else
    echo "  xrandr not found (Wayland-only session). Checking DRM properties..."
    for prop in /sys/class/drm/*/dpms; do
        [ -f "$prop" ] || continue
        name=$(echo "$prop" | cut -d/ -f5)
        val=$(cat "$prop" 2>/dev/null || echo "unknown")
        echo "  ${name} DPMS: ${val}"
    done
fi
sync

echo "--- GPU display pipe health ---"
if [ -d /sys/kernel/debug/dri ]; then
    for pipe in /sys/kernel/debug/dri/*/state; do
        [ -f "$pipe" ] || continue
        echo "  DRM state ($pipe):"
        grep -E 'plane|CRTC|connector|active|fb_id' "$pipe" 2>/dev/null | head -15
    done
else
    echo "  debugfs not available (no /sys/kernel/debug)."
fi
sync

echo "--- Modesetting / display errors (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    DISP_ERRORS=$(journalctl -k -b 0 --priority=err 2>/dev/null | grep -iE 'drm.*fail|amdgpu.*display|edp.*error|modeset.*fail|panel.*power|backlight.*fail|dpms' | head -15 || true)
    if [ -n "$DISP_ERRORS" ]; then
        echo "  Display-related errors detected:"
        echo "$DISP_ERRORS"
    else
        echo "  No display errors in current boot."
    fi
    sync

    echo "--- GPU display engine errors ---"
    GPU_DISP_ERRS=$(journalctl -k -b 0 --priority=err 2>/dev/null | grep -iE 'amdgpu:.*dce|drm:.*hw_done.*not|flip.*timeout|page_flip.*fail|cursor.*fail' | head -10 || true)
    if [ -n "$GPU_DISP_ERRS" ]; then
        echo "  GPU display engine errors:"
        echo "$GPU_DISP_ERRS"
    else
        echo "  No GPU display engine errors in current boot."
    fi
fi
sync

echo "--- Available ACPI sleep states ---"
if [ -f /sys/power/state ]; then
    STATES=$(cat /sys/power/state 2>/dev/null)
    echo "  Supported: ${STATES}"
    if echo "$STATES" | grep -q 'mem'; then
        if [ -f /sys/power/mem_sleep ]; then
            MEM_SLEEP=$(cat /sys/power/mem_sleep 2>/dev/null)
            echo "  mem_sleep: ${MEM_SLEEP}"
            if echo "$MEM_SLEEP" | grep -qv 's2idle'; then
                echo "  WARNING: s2idle not the default/active sleep state. System may enter S3 (deeper sleep) instead of s2idle."
            fi
        fi
    fi
fi
sync

echo "--- Panel power control ---"
for pwr in /sys/class/drm/*/device/power_control; do
    [ -f "$pwr" ] || continue
    val=$(cat "$pwr" 2>/dev/null || echo "unknown")
    echo "  ${pwr}: ${val}"
done
for aux in /sys/class/drm/*/device/aux_power_control; do
    [ -f "$aux" ] || continue
    val=$(cat "$aux" 2>/dev/null || echo "unknown")
    echo "  ${aux}: ${val}"
done
if ! ls /sys/class/drm/*/device/power_control 2>/dev/null | grep -q .; then
    echo "  No panel power control entries found (not exposed by driver)."
fi
sync

echo "--- Display idle / sleep transitions ---"
if command -v journalctl >/dev/null 2>&1; then
    IDLE_EVENTS=$(journalctl -b 0 2>/dev/null | grep -iE 'drm.*dpms.*off|screen.*off|display.*sleep|backlight.*off|powersave.*display|idle.*display' | tail -10 || true)
    if [ -n "$IDLE_EVENTS" ]; then
        echo "  Display sleep/idle transitions detected:"
        echo "$IDLE_EVENTS"
    else
        echo "  No display sleep/idle transitions in log."
    fi
fi
sync
