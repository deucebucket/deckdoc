#!/usr/bin/env bash
set -uo pipefail

echo "[REMEDIATION: Display Blackout / Forced Composition]"
SYS_ROOT="${DECKDOC_SYS_ROOT:-/sys}"
DEBUG_ROOT="${DECKDOC_DEBUGFS_ROOT:-${SYS_ROOT}/kernel/debug}"
DECKDOC_DIR="${DECKDOC_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PERSIST="${DECKDOC_PERSIST_DISPLAY_STABILITY:-false}"
REPORTED="${DECKDOC_DISPLAY_BLACK_REPORTED:-false}"

SESSION_USER="${DECKDOC_SESSION_USER:-${SUDO_USER:-$(id -un)}}"
if [ "$SESSION_USER" = "root" ]; then
    SESSION_USER=$(loginctl list-users --no-legend 2>/dev/null | awk '$2 != "root" { print $2; exit }')
fi
SESSION_UID=$(id -u "$SESSION_USER" 2>/dev/null || echo "")
SESSION_HOME=$(getent passwd "$SESSION_USER" 2>/dev/null | cut -d: -f6)

run_session() {
    if [ "$(id -un)" = "$SESSION_USER" ]; then
        XDG_RUNTIME_DIR="/run/user/${SESSION_UID}" "$@"
    else
        runuser -u "$SESSION_USER" -- env XDG_RUNTIME_DIR="/run/user/${SESSION_UID}" "$@"
    fi
}

gamescope_active() {
    # SteamOS names the compositor task gamescope-wl even though argv[0] is
    # gamescope; accept both without matching helper or portal processes.
    pgrep -x gamescope-wl >/dev/null 2>&1 || pgrep -f '^gamescope([[:space:]]|$)' >/dev/null 2>&1
}

echo "--- PRE_CHECK ---"
if [ "$REPORTED" != "true" ]; then
    echo "SKIPPED: Physical-black symptom was not explicitly reported."
    echo "REMEDIATION_OUTCOME: SKIPPED (symptom not declared)"
    exit 0
fi
if [ -z "$SESSION_USER" ] || [ -z "$SESSION_UID" ] || [ -z "$SESSION_HOME" ]; then
    echo "FAILED: Could not resolve the active non-root Gamescope user."
    echo "REMEDIATION_OUTCOME: FAILED (session user unresolved)"
    exit 1
fi
if ! command -v gamescopectl >/dev/null 2>&1 || ! gamescope_active; then
    echo "SKIPPED: No controllable Gamescope session is active."
    echo "REMEDIATION_OUTCOME: SKIPPED (Gamescope inactive)"
    exit 0
fi

EDP_DIR=""
for status_path in "${SYS_ROOT}"/class/drm/*eDP*/status; do
    [ -r "$status_path" ] || continue
    if [ "$(cat "$status_path" 2>/dev/null)" = "connected" ]; then EDP_DIR=$(dirname "$status_path"); break; fi
done
EDID_BYTES=0
[ -n "$EDP_DIR" ] && EDID_BYTES=$(wc -c < "${EDP_DIR}/edid" 2>/dev/null || echo 0)
BACKLIGHT_LIT=false
for bl in "${SYS_ROOT}"/class/backlight/*; do
    [ -d "$bl" ] || continue
    actual=$(cat "$bl/actual_brightness" 2>/dev/null || cat "$bl/brightness" 2>/dev/null || echo 0)
    if [ "${actual:-0}" -gt 0 ]; then BACKLIGHT_LIT=true; fi
done
if [ -z "$EDP_DIR" ] || [ "$EDID_BYTES" -eq 0 ] || [ "$BACKLIGHT_LIT" != "true" ]; then
    echo "SKIPPED: Internal panel is not connected/initialized with a nonzero backlight."
    echo "REMEDIATION_OUTCOME: SKIPPED (panel precheck failed)"
    exit 0
fi
echo "PASS: eDP connected, EDID readable (${EDID_BYTES} bytes), backlight nonzero, Gamescope active."

echo "--- BACKUP ---"
BACKUP_DIR="${DECKDOC_DIR}/remediation_backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="${BACKUP_DIR}/display_pre_$(date +%s).txt"
{
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Session user: ${SESSION_USER}"
    echo "eDP connector: ${EDP_DIR##*/}"
    echo "EDID bytes: ${EDID_BYTES}"
    for state in "${DEBUG_ROOT}"/dri/*/state; do [ -r "$state" ] && { echo "--- ${state} ---"; cat "$state"; }; done
} > "$BACKUP_FILE"
echo "Saved pre-change display state: ${BACKUP_FILE}"

echo "--- EXECUTE ---"
# This convar changes plane selection only. It does not change panel power,
# brightness, refresh, TDP, GPU clocks, charging behavior, or firmware.
if ! run_session gamescopectl composite_force 1; then
    echo "FAILED: Gamescope rejected composite_force."
    echo "REMEDIATION_OUTCOME: FAILED (gamescopectl)"
    exit 1
fi
echo "Applied session-only forced composition (direct scanout disabled)."

if [ "$PERSIST" = "true" ]; then
    echo "--- PERSIST ---"
    CONFIG_DIR="${SESSION_HOME}/.config/gamescope"
    CONFIG_FILE="${CONFIG_DIR}/99-deckdoc-display-stability.lua"
    TEMPLATE="${DECKDOC_DIR}/config/99-deckdoc-display-stability.lua"
    if [ ! -r "$TEMPLATE" ]; then
        echo "FAILED: Persistence template missing: ${TEMPLATE}"
        echo "REMEDIATION_OUTCOME: PARTIAL (live only; template missing)"
        exit 1
    fi
    mkdir -p "$CONFIG_DIR"
    if [ -e "$CONFIG_FILE" ]; then cp -a "$CONFIG_FILE" "${BACKUP_DIR}/99-deckdoc-display-stability.lua.$(date +%s).bak"; fi
    install -m 0644 "$TEMPLATE" "$CONFIG_FILE"
    if [ "$(id -u)" -eq 0 ]; then chown -R "$SESSION_USER":"$(id -gn "$SESSION_USER")" "$CONFIG_DIR"; fi
    echo "Installed next-session user policy: ${CONFIG_FILE}"
fi

echo "--- VERIFY ---"
sleep 1
if ! gamescope_active || ! run_session gamescopectl backend_info >/dev/null 2>&1; then
    echo "FAILED: Gamescope or its control socket stopped responding."
    echo "REMEDIATION_OUTCOME: FAILED (session health)"
    exit 1
fi
echo "PASS: Gamescope and its control socket remain responsive."
echo "NOTE: Software cannot observe emitted LCD pixels; confirm the physical panel is visible."
echo "REMEDIATION_OUTCOME: PARTIAL (composition policy applied; physical confirmation required)"
