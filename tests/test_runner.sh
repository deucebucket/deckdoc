#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ENV="$(mktemp -d /tmp/deckdoc-test.XXXXXX)"
cleanup() { rm -rf -- "${TEST_ENV}"; }
trap cleanup EXIT

echo "========================================="
echo "DeckDoc v3.1.0 — Test Runner"
echo "========================================="

# === Test 1: Mock sysfs structure ===
echo ""
echo "--- Test 1: Mock sysfs structure ---"
mkdir -p "${TEST_ENV}/sys/class/power_supply/BAT1"
echo "Charging" > "${TEST_ENV}/sys/class/power_supply/BAT1/status"
echo "7700000" > "${TEST_ENV}/sys/class/power_supply/BAT1/voltage_now"
echo "10000" > "${TEST_ENV}/sys/class/power_supply/BAT1/current_now"
echo "4000000" > "${TEST_ENV}/sys/class/power_supply/BAT1/energy_now"
echo "40000000" > "${TEST_ENV}/sys/class/power_supply/BAT1/energy_full"
echo "40000000" > "${TEST_ENV}/sys/class/power_supply/BAT1/energy_full_design"
echo "50" > "${TEST_ENV}/sys/class/power_supply/BAT1/capacity"

if [ -f "${TEST_ENV}/sys/class/power_supply/BAT1/status" ]; then
    echo "  PASS: Mock sysfs structure creation successful."
else
    echo "  FAIL: Mock sysfs structure creation failed."
    exit 1
fi

# === Test 2: Battery telemetry parsing ===
echo ""
echo "--- Test 2: Battery telemetry readback ---"
echo "  status: $(cat ${TEST_ENV}/sys/class/power_supply/BAT1/status)"
echo "  voltage: $(cat ${TEST_ENV}/sys/class/power_supply/BAT1/voltage_now) uV"

VOLTS=$(awk "BEGIN {print $(cat ${TEST_ENV}/sys/class/power_supply/BAT1/voltage_now)/1000000}")
echo "  calculated: ${VOLTS} V"
awk "BEGIN {if ($VOLTS < 6.6) exit 1; exit 0}" && echo "  PASS: Voltage threshold check" || echo "  FAIL: Voltage threshold check"

# === Test 3: All module files executable ===
echo ""
echo "--- Test 3: Module permissions ---"
MISSING=0
for mod in "${DECKDOC_DIR}"/modules/*.sh; do
    if [ ! -x "$mod" ]; then
        echo "  FAIL: ${mod} not executable"
        MISSING=$((MISSING + 1))
    fi
done
if [ "$MISSING" -eq 0 ]; then
    echo "  PASS: All $(ls -1 "${DECKDOC_DIR}"/modules/*.sh | wc -l) module files executable."
else
    echo "  FAIL: ${MISSING} modules missing executable permission."
    exit 1
fi

# === Test 4: deckdoc.sh entrypoint ===
echo ""
echo "--- Test 4: Entrypoint validation ---"
if [ -x "${DECKDOC_DIR}/deckdoc.sh" ]; then
    echo "  PASS: deckdoc.sh is executable."
else
    echo "  FAIL: deckdoc.sh not executable."
    exit 1
fi

chmod +x "${DECKDOC_DIR}/deckdoc.sh" "${DECKDOC_DIR}"/modules/*.sh "${DECKDOC_DIR}"/tests/*.sh
echo "  PASS: All permissions validated."

# === Test 5: Module count ===
echo ""
echo "--- Test 5: Module count ---"
MODULE_COUNT=$(ls -1 "${DECKDOC_DIR}"/modules/*.sh | wc -l)
echo "  Total modules: ${MODULE_COUNT}"
if [ "$MODULE_COUNT" -eq 17 ]; then
    echo "  PASS: Expected 17 modules present (15 diagnostic + 2 remediation)."
else
    echo "  FAIL: Expected 17 modules, found ${MODULE_COUNT}."
    exit 1
fi

# === Test 6: deckdoc.sh launches all modules ===
echo ""
echo "--- Test 6: Parallel module launch check ---"
LAUNCH_COUNT=$(grep -c '"${MODULES_DIR}/.*\.sh".*&[[:space:]]*$' "${DECKDOC_DIR}/deckdoc.sh" 2>/dev/null || echo 0)
echo "  Module launches in deckdoc.sh: ${LAUNCH_COUNT}"
if [ "$LAUNCH_COUNT" -eq 15 ]; then
    echo "  PASS: All 15 diagnostic modules launched in parallel."
else
    echo "  FAIL: Expected 15 module launches, found ${LAUNCH_COUNT}."
    exit 1
fi

# === Test 7: panic_sync trap present ===
echo ""
echo "--- Test 7: panic_sync trap ---"
if grep -q 'panic_sync' "${DECKDOC_DIR}/deckdoc.sh"; then
    echo "  PASS: panic_sync trap registered."
else
    echo "  FAIL: panic_sync trap missing."
    exit 1
fi

# === Test 8: --fix flag and remediation module ===
echo ""
echo "--- Test 8: Remediation support ---"
if grep -q 'FIX_MODE' "${DECKDOC_DIR}/deckdoc.sh"; then
    echo "  PASS: --fix flag detection present."
else
    echo "  FAIL: --fix flag detection missing."
    exit 1
fi
if grep -q 'rem_audio_sof.sh' "${DECKDOC_DIR}/deckdoc.sh"; then
    echo "  PASS: rem_audio_sof.sh called from deckdoc.sh."
else
    echo "  FAIL: rem_audio_sof.sh not called from deckdoc.sh."
    exit 1
fi
if grep -q 'PRE_CHECK' "${DECKDOC_DIR}/modules/rem_audio_sof.sh" 2>/dev/null; then
    echo "  PASS: rem_audio_sof.sh implements PRE_CHECK lifecycle."
else
    echo "  FAIL: rem_audio_sof.sh lifecycle incomplete."
    exit 1
fi
if grep -q 'REMEDIATION_OUTCOME' "${DECKDOC_DIR}/modules/rem_audio_sof.sh" 2>/dev/null; then
    echo "  PASS: rem_audio_sof.sh reports REMEDIATION_OUTCOME."
else
    echo "  FAIL: rem_audio_sof.sh missing REMEDIATION_OUTCOME."
    exit 1
fi

# === Test 9: Physical-black display signature ===
echo ""
echo "--- Test 9: Display-path signature fixture ---"
mkdir -p "${TEST_ENV}/sys/class/drm/card0-eDP-1" \
    "${TEST_ENV}/sys/class/drm/card0-DP-1" \
    "${TEST_ENV}/sys/class/backlight/amdgpu_bl1" \
    "${TEST_ENV}/debug/dri/0"
printf 'connected\n' > "${TEST_ENV}/sys/class/drm/card0-eDP-1/status"
printf 'enabled\n' > "${TEST_ENV}/sys/class/drm/card0-eDP-1/enabled"
printf '800x1280\n' > "${TEST_ENV}/sys/class/drm/card0-eDP-1/modes"
head -c 128 /dev/zero > "${TEST_ENV}/sys/class/drm/card0-eDP-1/edid"
printf 'disconnected\n' > "${TEST_ENV}/sys/class/drm/card0-DP-1/status"
: > "${TEST_ENV}/sys/class/drm/card0-DP-1/edid"
printf '65535\n' > "${TEST_ENV}/sys/class/backlight/amdgpu_bl1/max_brightness"
printf '9996\n' > "${TEST_ENV}/sys/class/backlight/amdgpu_bl1/brightness"
printf '9996\n' > "${TEST_ENV}/sys/class/backlight/amdgpu_bl1/actual_brightness"
printf '0\n' > "${TEST_ENV}/sys/class/backlight/amdgpu_bl1/bl_power"
printf '%s\n' \
    'crtc[67]: crtc-0' \
    '  active=1' \
    '  mode: "800x1280": 60' \
    'plane[73]: plane-3' \
    '  crtc=crtc-0' \
    '  fb=123' \
    '  crtc-pos=1280x800+0+0' \
    'plane[95]: plane-6' \
    '  crtc=crtc-0' \
    '  fb=124' \
    '  crtc-pos=1280x800+0+0' > "${TEST_ENV}/debug/dri/0/state"

DISPLAY_REPORT="${TEST_ENV}/display-report.txt"
DECKDOC_SYS_ROOT="${TEST_ENV}/sys" \
DECKDOC_DEBUGFS_ROOT="${TEST_ENV}/debug" \
DECKDOC_DISPLAY_BLACK_REPORTED=true \
DECKDOC_SKIP_JOURNAL=1 \
DECKDOC_SKIP_GAMESCOPE=1 \
    "${DECKDOC_DIR}/modules/display_blackout.sh" > "$DISPLAY_REPORT"
if grep -q 'BLACKOUT_SIGNATURE: LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP' "$DISPLAY_REPORT" && \
   grep -q 'Multi-plane scanout is active (2 planes)' "$DISPLAY_REPORT"; then
    echo "  PASS: Healthy-link physical-black state is classified as a multi-plane scanout gap."
else
    echo "  FAIL: Display signature was not classified correctly."
    cat "$DISPLAY_REPORT"
    exit 1
fi
if grep -q 'WARNING: card0-DP-1.*EDID' "$DISPLAY_REPORT"; then
    echo "  FAIL: Disconnected dock connector produced a false EDID warning."
    exit 1
else
    echo "  PASS: Empty EDID on a disconnected dock connector is ignored."
fi

# === Test 10: Display remediation safety contract ===
echo ""
echo "--- Test 10: Display remediation safety contract ---"
if grep -q 'gamescopectl composite_force 1' "${DECKDOC_DIR}/modules/rem_display_blackout.sh" && \
   grep -q 'CONFIG_DIR="${SESSION_HOME}/.config/gamescope/scripts"' "${DECKDOC_DIR}/modules/rem_display_blackout.sh" && \
   grep -q 'gamescope.convars.composite_force.value = true' "${DECKDOC_DIR}/config/99-deckdoc-display-stability.lua" && \
   grep -q 'gamescope.hook("OnPostPaint"' "${DECKDOC_DIR}/config/99-deckdoc-display-stability.lua"; then
    echo "  PASS: Live and application-transition-stable forced-composition paths are present."
else
    echo "  FAIL: Forced-composition remediation is incomplete."
    exit 1
fi
if grep -Eq '(tee|echo).*(brightness|bl_power|power_control|power_dpm|pp_od_clk_voltage)' "${DECKDOC_DIR}/modules/rem_display_blackout.sh"; then
    echo "  FAIL: Display remediation contains a forbidden power/brightness/clock write."
    exit 1
else
    echo "  PASS: Display remediation contains no panel-power, brightness, or clock writes."
fi

# === Test 11: Current-boot crash classification ===
echo ""
echo "--- Test 11: Current-boot crash classification ---"
mkdir -p "${TEST_ENV}/bin"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ " $* " == *" --since "* ]]; then' \
    '  echo "Tue 2026-07-21 09:10:00 CDT 2000 1000 1000 SIGABRT none /home/deck/.dotnet/dotnet -"' \
    'else' \
    '  for pid in 1001 1002 1003 1004 1005 1006 1007; do' \
    '    echo "Mon 2026-07-20 21:00:00 CDT $pid 1000 1000 SIGABRT present /usr/bin/mangoapp 3M"' \
    '  done' \
    '  echo "Tue 2026-07-21 09:10:00 CDT 2000 1000 1000 SIGABRT none /home/deck/.dotnet/dotnet -"' \
    'fi' > "${TEST_ENV}/bin/coredumpctl"
chmod +x "${TEST_ENV}/bin/coredumpctl"
CORE_REPORT="${TEST_ENV}/core-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" DECKDOC_SKIP_JOURNAL=1 \
    "${DECKDOC_DIR}/modules/coredump_analysis.sh" > "$CORE_REPORT"
if grep -q 'Historical MangoApp dumps:   7' "$CORE_REPORT" && \
   grep -q 'Current-boot MangoApp dumps: 0' "$CORE_REPORT" && \
   grep -q 'Current-boot SIGABRT.*:.*1' "$CORE_REPORT" && \
   grep -Eq '/usr/bin/mangoapp[[:space:]]+7 crashes' "$CORE_REPORT" && \
   ! grep -q 'CRITICAL: Elevated current-boot crash rate' "$CORE_REPORT"; then
    echo "  PASS: Retained crashes are aggregated but do not trigger a current-boot critical."
else
    echo "  FAIL: Historical and current-boot crashes were conflated."
    cat "$CORE_REPORT"
    exit 1
fi

# === Test 12: Steam crash-file and session-home filtering ===
echo ""
echo "--- Test 12: Steam dump filtering and session context ---"
mkdir -p "${TEST_ENV}/dumps/completed" "${TEST_ENV}/dumps/new" \
    "${TEST_ENV}/session-home/.local/share/Steam/steamapps/compatdata/123"
printf 'healthy bookkeeping\n' > "${TEST_ENV}/dumps/settings.dat"
: > "${TEST_ENV}/dumps/completed/one.dmp"
: > "${TEST_ENV}/dumps/new/two.mdmp"
STEAM_REPORT="${TEST_ENV}/steam-report.txt"
DECKDOC_DUMP_DIR="${TEST_ENV}/dumps" \
DECKDOC_SESSION_HOME="${TEST_ENV}/session-home" \
DECKDOC_SKIP_JOURNAL=1 \
    "${DECKDOC_DIR}/modules/steam_client_logs.sh" > "$STEAM_REPORT"
if grep -q 'Actual crash dump files: 2' "$STEAM_REPORT" && \
   grep -q 'Proton prefixes: 1 total' "$STEAM_REPORT" && \
   ! grep -q '/root/.local/share/Steam' "$STEAM_REPORT"; then
    echo "  PASS: Steam bookkeeping is ignored and sudo reports use the session user's tree."
else
    echo "  FAIL: Steam dump/session filtering is inaccurate."
    cat "$STEAM_REPORT"
    exit 1
fi

# === Test 13: Sensor-native thermal thresholds ===
echo ""
echo "--- Test 13: Sensor-native thermal thresholds ---"
mkdir -p "${TEST_ENV}/hwmon/hwmon0" "${TEST_ENV}/hwmon/hwmon1"
printf 'acpitz\n' > "${TEST_ENV}/hwmon/hwmon0/name"
printf '91000\n' > "${TEST_ENV}/hwmon/hwmon0/temp1_input"
printf 'nvme\n' > "${TEST_ENV}/hwmon/hwmon1/name"
printf '85000\n' > "${TEST_ENV}/hwmon/hwmon1/temp1_input"
printf '82850\n' > "${TEST_ENV}/hwmon/hwmon1/temp1_max"
printf '84850\n' > "${TEST_ENV}/hwmon/hwmon1/temp1_crit"
THERMAL_REPORT="${TEST_ENV}/thermal-report.txt"
DECKDOC_HWMON_DIR="${TEST_ENV}/hwmon" "${DECKDOC_DIR}/modules/thermal_fan.sh" > "$THERMAL_REPORT"
if grep -q 'above 90 C; this sensor exposes no hardware critical threshold' "$THERMAL_REPORT" && \
   grep -q 'at or above its exported critical threshold' "$THERMAL_REPORT" && \
   ! grep -q 'Thermal Trip Point Exceeded (>90C)' "$THERMAL_REPORT"; then
    echo "  PASS: Thermal severity follows exported hardware thresholds without inventing a 90 C trip."
else
    echo "  FAIL: Thermal threshold classification is inaccurate."
    cat "$THERMAL_REPORT"
    exit 1
fi

# === Test 14: Sudo-to-session diagnostic routing ===
echo ""
echo "--- Test 14: Sudo-to-session diagnostic routing ---"
if grep -q 'run_session gamescopectl backend_info' "${DECKDOC_DIR}/modules/display_blackout.sh" && \
   grep -q 'run_session pw-cli list-objects' "${DECKDOC_DIR}/modules/audio_sof.sh" && \
   grep -q 'STEAM_DIR="${SESSION_HOME}/.local/share/Steam' "${DECKDOC_DIR}/modules/steam_client_logs.sh" && \
   grep -q 'journalctl -b 0 --priority=err -o cat' "${DECKDOC_DIR}/modules/steam_client_logs.sh"; then
    echo "  PASS: Per-user Gamescope, PipeWire, and Steam diagnostics retain the Game Mode session context."
else
    echo "  FAIL: A sudo diagnostic still falls through to root's session context."
    exit 1
fi

echo ""
echo "========================================="
echo "All scaffold tests completed successfully."
echo "========================================="
