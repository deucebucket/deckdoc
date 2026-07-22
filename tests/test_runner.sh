#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ENV="$(mktemp -d /tmp/deckdoc-test.XXXXXX)"
cleanup() { rm -rf -- "${TEST_ENV}"; }
trap cleanup EXIT

echo "========================================="
echo "DeckDoc v3.2.0 — Test Runner"
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
if [ "$MODULE_COUNT" -eq 19 ]; then
    echo "  PASS: Expected 19 modules present (17 diagnostic + 2 remediation)."
else
    echo "  FAIL: Expected 19 modules, found ${MODULE_COUNT}."
    exit 1
fi

# === Test 6: deckdoc.sh launches all modules ===
echo ""
echo "--- Test 6: Parallel module launch check ---"
LAUNCH_COUNT=$(grep -c '"${MODULES_DIR}/.*\.sh".*&[[:space:]]*$' "${DECKDOC_DIR}/deckdoc.sh" 2>/dev/null || echo 0)
echo "  Module launches in deckdoc.sh: ${LAUNCH_COUNT}"
if [ "$LAUNCH_COUNT" -eq 17 ]; then
    echo "  PASS: All 17 diagnostic modules launched in parallel."
else
    echo "  FAIL: Expected 17 module launches, found ${LAUNCH_COUNT}."
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
mkdir -p "${TEST_ENV}/hwmon/hwmon0" "${TEST_ENV}/hwmon/hwmon1" "${TEST_ENV}/hwmon/hwmon2"
printf 'acpitz\n' > "${TEST_ENV}/hwmon/hwmon0/name"
printf '91000\n' > "${TEST_ENV}/hwmon/hwmon0/temp1_input"
printf 'nvme\n' > "${TEST_ENV}/hwmon/hwmon1/name"
printf '85000\n' > "${TEST_ENV}/hwmon/hwmon1/temp1_input"
printf '82850\n' > "${TEST_ENV}/hwmon/hwmon1/temp1_max"
printf '84850\n' > "${TEST_ENV}/hwmon/hwmon1/temp1_crit"
printf 'nvme-sentinel\n' > "${TEST_ENV}/hwmon/hwmon2/name"
printf '42000\n' > "${TEST_ENV}/hwmon/hwmon2/temp1_input"
printf '65261850\n' > "${TEST_ENV}/hwmon/hwmon2/temp1_max"
THERMAL_REPORT="${TEST_ENV}/thermal-report.txt"
DECKDOC_HWMON_DIR="${TEST_ENV}/hwmon" "${DECKDOC_DIR}/modules/thermal_fan.sh" > "$THERMAL_REPORT"
if grep -q 'above 90 C; this sensor exposes no hardware critical threshold' "$THERMAL_REPORT" && \
   grep -q 'at or above its exported critical threshold' "$THERMAL_REPORT" && \
   grep -q 'Ignoring implausible exported high threshold 65261850' "$THERMAL_REPORT" && \
   ! grep -q '65261.8 C' "$THERMAL_REPORT" && \
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

# === Test 15: 24-hour crash-family classification ===
echo ""
echo "--- Test 15: 24-hour crash-family classification ---"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ " $* " == *" 24 hours ago "* ]]; then' \
    '  for pid in $(seq 1 11); do echo "Tue 2026-07-21 09:10:00 CDT $pid 1000 1000 SIGTRAP present /usr/bin/steamwebhelper 3M"; done' \
    '  echo "Tue 2026-07-21 09:11:00 CDT 20 1000 1000 SIGSEGV present /usr/bin/gamescope-wl 3M"' \
    'elif [[ " $* " == *" --since "* ]]; then' \
    '  for pid in $(seq 30 35); do echo "Tue 2026-07-21 09:12:00 CDT $pid 1000 1000 SIGTRAP present /usr/bin/steamwebhelper 3M"; done' \
    'else' \
    '  echo "Tue 2026-07-21 09:11:00 CDT 20 1000 1000 SIGSEGV present /usr/bin/gamescope-wl 3M"' \
    'fi' > "${TEST_ENV}/bin/coredumpctl"
chmod +x "${TEST_ENV}/bin/coredumpctl"
CRASH_RATE_REPORT="${TEST_ENV}/crash-rate-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" DECKDOC_SKIP_JOURNAL=1 \
    "${DECKDOC_DIR}/modules/coredump_analysis.sh" > "$CRASH_RATE_REPORT"
if grep -q 'More than 10 crashes were recorded in the last 24 hours' "$CRASH_RATE_REPORT" && \
   grep -q 'Gamescope SIGABRT/SIGSEGV records occurred' "$CRASH_RATE_REPORT" && \
   grep -q 'steamwebhelper crashes:  11 (11 SIGTRAP)' "$CRASH_RATE_REPORT"; then
    echo "  PASS: 24-hour volume and executable/signal families are classified."
else
    echo "  FAIL: 24-hour crash classification is incomplete."
    cat "$CRASH_RATE_REPORT"
    exit 1
fi

# === Test 16: Issue-aligned memory thresholds and live swap I/O ===
echo ""
echo "--- Test 16: Memory pressure thresholds ---"
mkdir -p "${TEST_ENV}/proc-memory"
printf '%s\n' \
    'MemTotal:       16384000 kB' \
    'MemFree:          100000 kB' \
    'MemAvailable:     500000 kB' \
    'SwapTotal:       1048576 kB' \
    'SwapFree:         400000 kB' > "${TEST_ENV}/proc-memory/meminfo"
printf '%s\n' 'pswpin 60000' 'pswpout 70000' > "${TEST_ENV}/proc-memory/vmstat"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'echo "procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----"' \
    'echo " r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st"' \
    'echo " 1  0 100000 500000 10000 200000   12   34     0     0  100  200 10  5 85  0  0"' > "${TEST_ENV}/bin/vmstat"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${TEST_ENV}/bin/journalctl"
chmod +x "${TEST_ENV}/bin/vmstat" "${TEST_ENV}/bin/journalctl"
MEMORY_REPORT="${TEST_ENV}/memory-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" DECKDOC_PROC_ROOT="${TEST_ENV}/proc-memory" DECKDOC_VMSTAT_SAMPLES=1 \
    "${DECKDOC_DIR}/modules/memory_swap.sh" > "$MEMORY_REPORT"
if grep -q 'CRITICAL: Available memory below 512 MB' "$MEMORY_REPORT" && \
   grep -q 'HIGH: Swap usage exceeds 50%' "$MEMORY_REPORT" && \
   grep -q 'Live swap I/O observed (si=12, so=34' "$MEMORY_REPORT"; then
    echo "  PASS: Memory, swap-consumption, and live-I/O thresholds match issue #5."
else
    echo "  FAIL: Memory pressure thresholds are inaccurate."
    cat "$MEMORY_REPORT"
    exit 1
fi

# === Test 17: Coupled Wi-Fi/SOF resume failure signature ===
echo ""
echo "--- Test 17: Coupled Wi-Fi/SOF failure signature ---"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'echo "[10.000] ath11k_pci firmware crashed"' \
    'echo "[10.250] traps: qrenderdoc error:0 in librenderdoc.so[1b437]"' \
    'echo "[10.500] snd_sof_amd_vangogh ipc tx failed -22"' > "${TEST_ENV}/bin/journalctl"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [ "${1:-}" = "-o" ]; then echo "2: wlan0: <BROADCAST> mtu 1500 state DOWN mode DEFAULT"; else echo "2: wlan0: <BROADCAST> mtu 1500 state DOWN mode DEFAULT"; fi' > "${TEST_ENV}/bin/ip"
printf '%s\n' '#!/usr/bin/env bash' 'echo "Not connected."' > "${TEST_ENV}/bin/iw"
printf '%s\n' '#!/usr/bin/env bash' 'echo "01:00.0 Network controller: Qualcomm device"' > "${TEST_ENV}/bin/lspci"
chmod +x "${TEST_ENV}/bin/journalctl" "${TEST_ENV}/bin/ip" "${TEST_ENV}/bin/iw" "${TEST_ENV}/bin/lspci"
WIFI_REPORT="${TEST_ENV}/wifi-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" "${DECKDOC_DIR}/modules/wifi_firmware.sh" > "$WIFI_REPORT"
if grep -q 'RESUME_SIGNATURE: WIFI_AND_SOF_FAILURES_IN_CURRENT_BOOT' "$WIFI_REPORT" && \
   grep -q 'CRITICAL: Wireless firmware crashed' "$WIFI_REPORT" && \
   ! grep -q 'qrenderdoc' "$WIFI_REPORT"; then
    echo "  PASS: Same-boot wireless and SOF failures produce an explicit correlation signature."
else
    echo "  FAIL: Coupled resume-device failures were not classified."
    cat "$WIFI_REPORT"
    exit 1
fi

# === Test 18: Gamescope restart severity threshold ===
echo ""
echo "--- Test 18: Gamescope restart severity threshold ---"
if grep -q 'RESTART_COUNT:-0.*-gt 3' "${DECKDOC_DIR}/modules/gamescope_session.sh" && \
   grep -q 'CRITICAL: Gamescope session started' "${DECKDOC_DIR}/modules/gamescope_session.sh" && \
   grep -q 'systemd NRestarts + active invocation' "${DECKDOC_DIR}/modules/gamescope_session.sh"; then
    echo "  PASS: More than three Gamescope starts in one boot is critical."
else
    echo "  FAIL: Gamescope restart threshold does not match issue #4."
    exit 1
fi

# === Test 19: Live fan-after-resume correlation ===
echo ""
echo "--- Test 19: Live fan-after-resume correlation ---"
mkdir -p "${TEST_ENV}/acpi-hwmon/hwmon0" "${TEST_ENV}/acpi-power/BAT1"
printf '0\n' > "${TEST_ENV}/acpi-hwmon/hwmon0/fan1_input"
printf '75000\n' > "${TEST_ENV}/acpi-hwmon/hwmon0/temp1_input"
printf '80\n' > "${TEST_ENV}/acpi-power/BAT1/charge_control_end_threshold"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'echo "PM: suspend entry (s2idle)"' \
    'echo "PM: suspend exit"' > "${TEST_ENV}/bin/journalctl"
chmod +x "${TEST_ENV}/bin/journalctl"
ACPI_REPORT="${TEST_ENV}/acpi-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" DECKDOC_HWMON_DIR="${TEST_ENV}/acpi-hwmon" \
DECKDOC_POWER_SUPPLY_ROOT="${TEST_ENV}/acpi-power" \
    "${DECKDOC_DIR}/modules/acpi_pm_state.sh" > "$ACPI_REPORT"
if grep -q 'RESUME_SIGNATURE: LIVE_ZERO_RPM_WITH_HOT_SENSOR_AFTER_SUSPEND' "$ACPI_REPORT" && \
   grep -q 'charge_control_end_threshold=80' "$ACPI_REPORT"; then
    echo "  PASS: Hot zero-RPM state is cross-correlated with suspend and charge-limit context."
else
    echo "  FAIL: Fan/resume cross-correlation is incomplete."
    cat "$ACPI_REPORT"
    exit 1
fi

# === Test 20: GPU page-fault correlation boundaries ===
echo ""
echo "--- Test 20: GPU page-fault correlation boundaries ---"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'echo "amdgpu: page fault process game pid 44 Faulty UTCL2 client ID: CPF (0x5) MAPPING_ERROR"' \
    'echo "amdgpu: ring gfx timeout"' \
    'echo "amdgpu: GPU reset succeeded"' > "${TEST_ENV}/bin/journalctl"
chmod +x "${TEST_ENV}/bin/journalctl"
DXVK_REPORT="${TEST_ENV}/dxvk-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" "${DECKDOC_DIR}/modules/dxvk_page_fault.sh" > "$DXVK_REPORT"
if grep -q 'command-path fault; driver, workload, and hardware remain candidates' "$DXVK_REPORT" && \
   grep -q 'GPU page-fault and ring-timeout evidence must be correlated' "$DXVK_REPORT" && \
   grep -q 'GPU reset succeeded; affected clients may still have terminated' "$DXVK_REPORT"; then
    echo "  PASS: Page faults are classified without over-claiming DXVK or hardware causality."
else
    echo "  FAIL: GPU page-fault causality boundaries are inaccurate."
    cat "$DXVK_REPORT"
    exit 1
fi

# === Test 21: Steam helper crash-frequency threshold ===
echo ""
echo "--- Test 21: Steam helper crash-frequency threshold ---"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'for pid in $(seq 1 12); do echo "Tue 2026-07-21 09:10:00 CDT $pid 1000 1000 SIGTRAP present /usr/bin/steamwebhelper 3M"; done' > "${TEST_ENV}/bin/coredumpctl"
chmod +x "${TEST_ENV}/bin/coredumpctl"
STEAM_RATE_REPORT="${TEST_ENV}/steam-rate-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" DECKDOC_DUMP_DIR="${TEST_ENV}/dumps" \
DECKDOC_SESSION_HOME="${TEST_ENV}/session-home" DECKDOC_SKIP_JOURNAL=1 \
    "${DECKDOC_DIR}/modules/steam_client_logs.sh" > "$STEAM_RATE_REPORT"
if grep -q 'Current-boot steamwebhelper dumps: 12' "$STEAM_RATE_REPORT" && \
   grep -q 'HIGH: Repeated steamwebhelper crashes exceed' "$STEAM_RATE_REPORT"; then
    echo "  PASS: Repeated Steam helper crashes are surfaced with a bounded threshold."
else
    echo "  FAIL: Steam helper crash frequency is not surfaced."
    cat "$STEAM_RATE_REPORT"
    exit 1
fi

# === Test 22: Lightweight incident-probe classification and capture ===
echo ""
echo "--- Test 22: Lightweight incident probe ---"
if [ "$("${DECKDOC_DIR}/probe/deckdoc-probe.sh" classify 'amdgpu: ring gfx timeout')" != "gpu" ] || \
   [ "$("${DECKDOC_DIR}/probe/deckdoc-probe.sh" classify 'snd_sof_amd_vangogh ipc tx failed -22')" != "audio" ] || \
   [ "$("${DECKDOC_DIR}/probe/deckdoc-probe.sh" classify 'normal informational line')" != "unmatched" ]; then
    echo "  FAIL: Probe signature classification is inaccurate."
    exit 1
fi
PROBE_STATE="${TEST_ENV}/probe-state"
DECKDOC_PROBE_STATE_DIR="$PROBE_STATE" DECKDOC_PROBE_POST_SECONDS=0 \
DECKDOC_PROBE_PRE_SECONDS=1 DECKDOC_PROBE_MAX_EVENTS=2 DECKDOC_PROBE_MAX_EVENT_KIB=64 \
    "${DECKDOC_DIR}/probe/deckdoc-probe.sh" capture test >/dev/null
PROBE_LATEST=$(readlink -f "${PROBE_STATE}/latest")
PROBE_REPORT="${TEST_ENV}/probe-report.txt"
DECKDOC_PROBE_STATE_DIR="$PROBE_STATE" "${DECKDOC_DIR}/modules/probe_incidents.sh" > "$PROBE_REPORT"
if [ -f "${PROBE_LATEST}/metadata.txt" ] && [ -f "${PROBE_LATEST}/state.log" ] && \
   [ -f "${PROBE_LATEST}/journal.log" ] && grep -q 'category=manual' "$PROBE_REPORT"; then
    echo "  PASS: Probe captures a bounded private incident and the main report can ingest it."
else
    echo "  FAIL: Probe capture/report integration is incomplete."
    exit 1
fi

# === Test 23: Probe opt-in and safety contract ===
echo ""
echo "--- Test 23: Probe service safety contract ---"
if grep -q 'systemctl enable --now deckdoc-probe.service' "${DECKDOC_DIR}/probe/install-probe.sh" && \
   grep -q 'ProtectSystem=strict' "${DECKDOC_DIR}/probe/deckdoc-probe.service" && \
   grep -q 'ReadWritePaths=/var/lib/deckdoc-probe' "${DECKDOC_DIR}/probe/deckdoc-probe.service" && \
   grep -q 'Captures are private but unredacted' "${DECKDOC_DIR}/probe/deckdoc-probe.sh" && \
   ! grep -q 'install_probe' "${DECKDOC_DIR}/setup.sh"; then
    echo "  PASS: Continuous monitoring remains opt-in, resource-limited, private, and read-only."
else
    echo "  FAIL: Probe opt-in or service safety boundary is incomplete."
    exit 1
fi

# === Test 24: Dock/USB-C/PD evidence boundaries ===
echo ""
echo "--- Test 24: Dock and USB-C diagnostics ---"
DOCK_SYS="${TEST_ENV}/dock-sys"
mkdir -p "${DOCK_SYS}/class/typec/port0" "${DOCK_SYS}/class/typec/port0-partner" \
    "${DOCK_SYS}/class/power_supply/ucsi-source" "${DOCK_SYS}/class/drm/card0-DP-1" \
    "${DOCK_SYS}/class/net/eth0" "${DOCK_SYS}/devices/usb1/1-1/net/eth0" \
    "${DOCK_SYS}/bus/usb/drivers/r8152"
printf 'host\n' > "${DOCK_SYS}/class/typec/port0/data_role"
printf 'sink\n' > "${DOCK_SYS}/class/typec/port0/power_role"
printf 'USB Power Delivery\n' > "${DOCK_SYS}/class/typec/port0/power_operation_mode"
printf 'USB\n' > "${DOCK_SYS}/class/power_supply/ucsi-source/type"
printf '1\n' > "${DOCK_SYS}/class/power_supply/ucsi-source/online"
printf '15000000\n' > "${DOCK_SYS}/class/power_supply/ucsi-source/voltage_now"
printf '3000000\n' > "${DOCK_SYS}/class/power_supply/ucsi-source/current_now"
printf 'connected\n' > "${DOCK_SYS}/class/drm/card0-DP-1/status"
printf '1920x1080\n' > "${DOCK_SYS}/class/drm/card0-DP-1/modes"
head -c 128 /dev/zero > "${DOCK_SYS}/class/drm/card0-DP-1/edid"
printf 'up\n' > "${DOCK_SYS}/class/net/eth0/operstate"
printf '1\n' > "${DOCK_SYS}/class/net/eth0/carrier"
printf '1000\n' > "${DOCK_SYS}/class/net/eth0/speed"
ln -s "${DOCK_SYS}/devices/usb1/1-1/net/eth0" "${DOCK_SYS}/class/net/eth0/device"
ln -s "${DOCK_SYS}/bus/usb/drivers/r8152" "${DOCK_SYS}/devices/usb1/1-1/net/eth0/driver"
printf '%s\n' '#!/usr/bin/env bash' 'echo "xhci host controller reset error"' 'echo "usb 1-1: disconnect"' > "${TEST_ENV}/bin/journalctl"
printf '%s\n' '#!/usr/bin/env bash' 'if [ "${1:-}" = "-t" ]; then echo "/: Bus 001.Port 001: Dev 1, Driver=xhci_hcd"; else echo "Bus 001 Device 002: ID 0bda:8153 Realtek"; fi' > "${TEST_ENV}/bin/lsusb"
chmod +x "${TEST_ENV}/bin/journalctl" "${TEST_ENV}/bin/lsusb"
DOCK_REPORT="${TEST_ENV}/dock-report.txt"
PATH="${TEST_ENV}/bin:${PATH}" DECKDOC_SYS_ROOT="$DOCK_SYS" \
    "${DECKDOC_DIR}/modules/dock_usb_c.sh" > "$DOCK_REPORT"
if grep -q 'power_operation_mode=USB Power Delivery' "$DOCK_REPORT" && \
   grep -q 'calculated_instantaneous_power=45.00 W' "$DOCK_REPORT" && \
   grep -q 'card0-DP-1: status=connected edid_bytes=128' "$DOCK_REPORT" && \
   grep -q 'eth0: driver=r8152' "$DOCK_REPORT" && \
   grep -q 'DOCK_SIGNATURE: TOPOLOGY_CHANGE_WITH_DOCK_PATH_ERROR' "$DOCK_REPORT" && \
   grep -q 'not dock certification' "$DOCK_REPORT"; then
    echo "  PASS: Dock topology, exported PD telemetry, and correlated path errors remain evidence—not certification."
else
    echo "  FAIL: Dock/USB-C evidence collection is incomplete."
    cat "$DOCK_REPORT"
    exit 1
fi

# === Test 25: Rescue collection remains outside-OS and read-only ===
echo ""
echo "--- Test 25: DeckDoc Rescue safety contract ---"
RESCUE_HELP=$("${DECKDOC_DIR}/bootprobe/deckdoc-rescue-collect.sh" --help)
if grep -q 'journalctl --image' <<< "$RESCUE_HELP" && \
   grep -q 'never mounts, repairs, unlocks, or writes' <<< "$RESCUE_HELP" && \
   grep -q 'journalctl --image=' "${DECKDOC_DIR}/bootprobe/deckdoc-rescue-collect.sh" && \
   ! grep -Eq '^[[:space:]]*(sudo[[:space:]]+)?(mount|fsck|btrfs[[:space:]]+check)([[:space:]]|$)' "${DECKDOC_DIR}/bootprobe/deckdoc-rescue-collect.sh" && \
   grep -q 'unsigned DeckDoc Rescue alpha' "${DECKDOC_DIR}/bootprobe/build-rescue-image.sh" && \
   grep -q 'not a Valve recovery image' "${DECKDOC_DIR}/bootprobe/build-rescue-image.sh"; then
    echo "  PASS: Rescue collection uses the image reader and the builder states its alpha trust boundary."
else
    echo "  FAIL: Rescue collection or image trust boundary is incomplete."
    exit 1
fi

# === Test 26: Exact-command privileged authorization boundary ===
echo ""
echo "--- Test 26: Privileged diagnostic authorization ---"
set +e
"${DECKDOC_DIR}/privileged/deckdoc-authorized" unexpected > "${TEST_ENV}/broker.out" 2> "${TEST_ENV}/broker.err"
BROKER_EXIT=$?
set -e
if [ "$BROKER_EXIT" -eq 2 ] && \
   grep -Fq 'NOPASSWD: NOSETENV: ${BROKER} report' "${DECKDOC_DIR}/privileged/install-authorized.sh" && \
   grep -q 'sha256sum -c --status' "${DECKDOC_DIR}/privileged/deckdoc-authorized" && \
   grep -q 'sudo -n "$BROKER"' "${DECKDOC_DIR}/privileged/deckdoc-authorized-client.sh" && \
   ! grep -Eq -- '--fix|bash[[:space:]]+-c|sh[[:space:]]+-c' "${DECKDOC_DIR}/privileged/deckdoc-authorized"; then
    echo "  PASS: Authorization exposes exact read-only operations and rejects unknown commands."
else
    echo "  FAIL: Privileged broker boundary is too broad or incomplete."
    cat "${TEST_ENV}/broker.err"
    exit 1
fi
if command -v visudo >/dev/null 2>&1; then
    if visudo -cf "${DECKDOC_DIR}/tests/fixtures/deckdoc-authorized.sudoers" >/dev/null 2>&1; then
        echo "  PASS: Exact-command sudoers fixture passes visudo syntax validation."
    else
        echo "  FAIL: Exact-command sudoers fixture is invalid."
        exit 1
    fi
fi

# === Test 27: DeckMD questionnaire and knowledge integrity ===
echo ""
echo "--- Test 27: DeckMD symptom checker schema ---"
if command -v node >/dev/null 2>&1; then
    node --check "${DECKDOC_DIR}/docs/assets/questionnaire.js"
    node --check "${DECKDOC_DIR}/docs/assets/knowledge.js"
    node --check "${DECKDOC_DIR}/docs/assets/app.js"
    node "${DECKDOC_DIR}/tests/validate_deckmd.js"
    echo "  PASS: DeckMD facts, progressive suggestions, rules, and wiki routes are internally consistent."
elif grep -Fq 'display: ["sound-works", "screen-backlight", "screen-no-light", "input-works", "ssh-works", "stream-works", "external-works", "during-game", "after-wake"' \
        "${DECKDOC_DIR}/docs/assets/questionnaire.js" && \
     grep -q 'const related = window.DECKDOC_RELATED_CHECKS' "${DECKDOC_DIR}/docs/assets/app.js" && \
     grep -q 'No safe pattern match yet' "${DECKDOC_DIR}/docs/assets/app.js"; then
    echo "  PASS: Required progressive-display and safe-unknown contracts are present."
    echo "  NOTE: Full JavaScript/schema validation skipped because Node.js is not installed."
else
    echo "  FAIL: DeckMD structural fallback contract is incomplete."
    exit 1
fi

echo ""
echo "========================================="
echo "All scaffold tests completed successfully."
echo "========================================="
