#!/usr/bin/env bash
set -uo pipefail

SYS_ROOT="${DECKDOC_SYS_ROOT:-/sys}"
DEBUG_ROOT="${DECKDOC_DEBUGFS_ROOT:-${SYS_ROOT}/kernel/debug}"
DISPLAY_BLACK_REPORTED="${DECKDOC_DISPLAY_BLACK_REPORTED:-false}"

read_value() {
    local path="$1" fallback="${2:-unknown}"
    if [ -r "$path" ]; then cat "$path" 2>/dev/null || echo "$fallback"; else echo "$fallback"; fi
}

echo "[MODULE: Display Blackout Detection]"
echo "  Physical-black symptom explicitly reported: ${DISPLAY_BLACK_REPORTED}"
sync

echo "--- DRM connector status ---"
EDP_DIR=""
for conn in "${SYS_ROOT}"/class/drm/*/status; do
    [ -f "$conn" ] || continue
    connector_dir=$(dirname "$conn")
    name=$(basename "$connector_dir")
    status=$(read_value "$conn")
    enabled=$(read_value "${connector_dir}/enabled" "not-exposed")
    echo "  ${name}: status=${status}, enabled=${enabled}"
    if [ "$status" = "connected" ] && echo "$name" | grep -qi 'edp'; then
        EDP_DIR="$connector_dir"
    fi
done

echo "--- eDP panel link ---"
EDP_EDID_BYTES=0
if [ -n "$EDP_DIR" ]; then
    EDP_EDID_BYTES=$(wc -c < "${EDP_DIR}/edid" 2>/dev/null || echo 0)
    echo "  ${EDP_DIR##*/}: connected, EDID=${EDP_EDID_BYTES} bytes"
    if [ -r "${EDP_DIR}/modes" ]; then sed 's/^/  mode: /' "${EDP_DIR}/modes"; fi
    if [ "$EDP_EDID_BYTES" -eq 0 ]; then echo "  WARNING: Connected eDP panel has an empty EDID."; fi
else
    echo "  WARNING: eDP panel is not connected."
fi
# Empty EDIDs on disconnected dock connectors are normal and intentionally ignored.
sync

echo "--- Backlight state (read-only) ---"
BACKLIGHT_LIT=false
for bl in "${SYS_ROOT}"/class/backlight/*; do
    [ -d "$bl" ] || continue
    name=$(basename "$bl")
    max=$(read_value "$bl/max_brightness" 0)
    requested=$(read_value "$bl/brightness" 0)
    actual=$(read_value "$bl/actual_brightness" "$requested")
    bl_power=$(read_value "$bl/bl_power" "not-exposed")
    echo "  ${name}: requested=${requested}/${max}, actual=${actual}/${max}, bl_power=${bl_power}"
    if [ "$max" -gt 0 ] && [ "$actual" -gt 0 ] && { [ "$bl_power" = "0" ] || [ "$bl_power" = "not-exposed" ]; }; then
        BACKLIGHT_LIT=true
    elif [ "$max" -gt 0 ] && [ "$actual" -eq 0 ]; then
        echo "  WARNING: Backlight is at 0."
    fi
done
sync

echo "--- GPU display pipe health ---"
CRTC_ACTIVE=false
ACTIVE_PLANES=0
SEEN_STATES="|"
if [ -d "${DEBUG_ROOT}/dri" ]; then
    for state in "${DEBUG_ROOT}"/dri/*/state; do
        [ -r "$state" ] || continue
        # debugfs exposes the same DRM device by card index, render index, and PCI
        # symlinks; count each underlying state file once.
        resolved_state=$(readlink -f "$state" 2>/dev/null || echo "$state")
        case "$SEEN_STATES" in *"|${resolved_state}|"*) continue ;; esac
        SEEN_STATES="${SEEN_STATES}${resolved_state}|"
        echo "  DRM state: ${state}"
        awk '
            /^crtc\[/ { section="crtc"; label=$0 }
            /^plane\[/ { section="plane"; label=$0 }
            /^[[:space:]]*active=1/ && section == "crtc" { print "    " label " active=1" }
            /^[[:space:]]*mode:/ && section == "crtc" { print "    " $0 }
            /^[[:space:]]*crtc=/ && section == "plane" && $0 !~ /crtc=\(null\)/ { print "    " label " " $0 }
            /^[[:space:]]*fb=/ && section == "plane" && $0 !~ /fb=0/ { print "    " $0 }
            /^[[:space:]]*crtc-pos=/ && section == "plane" { print "    " $0 }
        ' "$state" 2>/dev/null | head -40
        if grep -qE '^[[:space:]]*active=1' "$state" 2>/dev/null; then CRTC_ACTIVE=true; fi
        pipe_planes=$(awk '
            /^plane\[/ { in_plane=1; active=0 }
            in_plane && /^[[:space:]]*crtc=/ && $0 !~ /crtc=\(null\)/ { active=1 }
            in_plane && /^[[:space:]]*fb=/ && $0 !~ /fb=0/ && active { count++; in_plane=0 }
            END { print count+0 }
        ' "$state" 2>/dev/null)
        ACTIVE_PLANES=$((ACTIVE_PLANES + pipe_planes))
    done
else
    echo "  debugfs not available. Run as root for plane/CRTC evidence."
fi
echo "  Active hardware planes with framebuffers: ${ACTIVE_PLANES}"
sync

echo "--- Gamescope composition state ---"
if [ "${DECKDOC_SKIP_GAMESCOPE:-0}" = "1" ]; then
    echo "  Skipped by test environment."
elif command -v gamescopectl >/dev/null 2>&1; then
    gamescopectl backend_info 2>/dev/null | sed 's/^/  /' || echo "  gamescopectl could not query the active session."
else
    echo "  gamescopectl not installed."
fi
sync

if [ "${DECKDOC_SKIP_JOURNAL:-0}" != "1" ] && command -v journalctl >/dev/null 2>&1; then
    echo "--- Display/GPU errors (current boot) ---"
    errors=$(journalctl -k -b 0 2>/dev/null | grep -iE 'amdgpu.*(reset|ring.*timeout|display.*fail)|drm.*(flip.*timeout|modeset.*fail)|edp.*error|backlight.*fail' | tail -20 || true)
    if [ -n "$errors" ]; then echo "$errors"; else echo "  No matching reset, timeout, modeset, eDP, or backlight errors."; fi

    echo "--- Display-path warnings across recent boots ---"
    warnings=$(journalctl -k --since='7 days ago' 2>/dev/null | grep -iE 'async flip with non-fast update|Fence fallback timer expired|display topology.*not initialized' | tail -20 || true)
    if [ -n "$warnings" ]; then echo "$warnings"; else echo "  No matching historical display-path warnings."; fi
fi
sync

echo "--- Sleep mode (read-only) ---"
if [ -r "${SYS_ROOT}/power/state" ]; then echo "  Supported: $(cat "${SYS_ROOT}/power/state")"; fi
if [ -r "${SYS_ROOT}/power/mem_sleep" ]; then
    mem_sleep=$(cat "${SYS_ROOT}/power/mem_sleep")
    echo "  mem_sleep: ${mem_sleep}"
    if ! echo "$mem_sleep" | grep -q '\[s2idle\]'; then echo "  NOTE: s2idle is not the active sleep mode."; fi
fi
sync

echo "--- Display-path assessment ---"
if [ "$DISPLAY_BLACK_REPORTED" = "true" ] && [ -n "$EDP_DIR" ] && [ "$EDP_EDID_BYTES" -gt 0 ] && [ "$BACKLIGHT_LIT" = "true" ] && [ "$CRTC_ACTIVE" = "true" ]; then
    echo "  BLACKOUT_SIGNATURE: LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP"
    echo "  eDP link/EDID, backlight, and CRTC remain live while the physical panel is reported black."
    if [ "$ACTIVE_PLANES" -gt 1 ]; then
        echo "  Multi-plane scanout is active (${ACTIVE_PLANES} planes); test forced composition with --fix-display-blackout."
    else
        echo "  Single-plane composition is already active; continue panel-link/kernel investigation."
    fi
elif [ "$DISPLAY_BLACK_REPORTED" = "true" ]; then
    echo "  BLACKOUT_SIGNATURE: PANEL_OR_MODESET_STATE_INCOMPLETE"
    echo "  A panel-link, EDID, backlight, or CRTC check failed; forced composition is not automatically indicated."
else
    echo "  No physical-black symptom was declared. Use --display-black while it is present."
fi
sync
