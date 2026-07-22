#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: ACPI Sleep/Wake (PM State)]"
sync

HWMON_DIR="${DECKDOC_HWMON_DIR:-/sys/class/hwmon}"
POWER_SUPPLY_ROOT="${DECKDOC_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"

echo "--- Suspend/resume transitions (current boot) ---"
SUSPEND_COUNT=0
RESUME_COUNT=0
if command -v journalctl >/dev/null 2>&1; then
    SUSPEND_COUNT=$(journalctl -b 0 2>/dev/null | grep -c 'PM: suspend entry' || true)
    # Current SteamOS kernels report a completed resume as "PM: suspend exit".
    RESUME_COUNT=$(journalctl -b 0 2>/dev/null | grep -Ec 'PM: suspend exit|PM: resume' || true)
    echo "  Suspend entries: ${SUSPEND_COUNT}"
    echo "  Resume entries:  ${RESUME_COUNT}"

    if journalctl -b 0 2>/dev/null | grep -q 'PM: suspend entry'; then
        echo "  Last suspend/resume cycle:"
        journalctl -b 0 2>/dev/null | grep -E 'PM: suspend entry|PM: suspend exit|PM: resume' | tail -6
    fi
fi
sync

echo "--- Resume failure detection ---"
if command -v journalctl >/dev/null 2>&1; then
    RESUME_FAILURES=$(journalctl -b 0 2>/dev/null | grep -iE 'PM:.*resume.*fail|pci_pm_resume.*fail|-22.*PM|PM.*error.*-22' | head -10 || true)
    if [ -n "$RESUME_FAILURES" ]; then
        echo "  CRITICAL: Resume failures detected:"
        echo "$RESUME_FAILURES"
    else
        echo "  No resume failures in current boot."
    fi
fi
sync

echo "--- Fan controller journal observations (current boot) ---"
if command -v journalctl >/dev/null 2>&1; then
    FAN_WARNINGS=$(journalctl -b 0 2>/dev/null | grep -iE 'fancontrol.*Warning|jupiter.*Warning|Setting fan to max' | tail -10 || true)
    if [ -n "$FAN_WARNINGS" ]; then
        echo "  Fan controller warnings detected:"
        echo "$FAN_WARNINGS"
        if [ "$SUSPEND_COUNT" -eq 0 ]; then
            echo "  NOTE: No suspend occurred this boot; these entries are not resume-failure evidence."
        else
            echo "  NOTE: Correlate timestamps with the suspend window before attributing these entries to resume."
        fi
    else
        echo "  No fan controller warnings in current boot."
    fi

    FAN_CRASH=$(journalctl -b 0 2>/dev/null | grep -iE 'fancontrol.*fail|jupiter-fan.*fail|fan.*RPM.*0|fan.*error' | tail -5 || true)
    if [ -n "$FAN_CRASH" ]; then
        echo "  CRITICAL: Fan controller failure detected:"
        echo "$FAN_CRASH"
    fi
fi
sync

echo "--- ACPI wake sources ---"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -b 0 2>/dev/null | grep -iE 'wake source|PM:.*wakeup|ACPI.*wake' | tail -5 || echo "  No wake source information available."
fi
sync

echo "--- Live fan/temperature cross-check ---"
LIVE_FAN_ZERO=false
MAX_TEMP_RAW=0
FAN_INPUTS=0
for fan in "${HWMON_DIR}"/hwmon*/fan*_input; do
    [ -r "$fan" ] || continue
    FAN_INPUTS=$((FAN_INPUTS + 1))
    rpm=$(cat "$fan" 2>/dev/null || echo unknown)
    echo "  ${fan}: ${rpm} RPM"
    if [ "$rpm" = "0" ]; then LIVE_FAN_ZERO=true; fi
done
for temp in "${HWMON_DIR}"/hwmon*/temp*_input; do
    [ -r "$temp" ] || continue
    raw=$(cat "$temp" 2>/dev/null || echo 0)
    case "$raw" in ''|*[!0-9]*) raw=0 ;; esac
    if [ "$raw" -gt "$MAX_TEMP_RAW" ]; then MAX_TEMP_RAW="$raw"; fi
done
if [ "$FAN_INPUTS" -eq 0 ]; then
    echo "  No live fan RPM input exported."
elif [ "$LIVE_FAN_ZERO" = "true" ] && [ "$SUSPEND_COUNT" -gt 0 ] && [ "$MAX_TEMP_RAW" -ge 70000 ]; then
    echo "  RESUME_SIGNATURE: LIVE_ZERO_RPM_WITH_HOT_SENSOR_AFTER_SUSPEND"
    echo "  HIGH: A fan input is 0 RPM while a sensor is at least 70 C after a suspend in this boot. Stop load and verify fan-controller state."
elif [ "$LIVE_FAN_ZERO" = "true" ] && [ "$SUSPEND_COUNT" -gt 0 ]; then
    echo "  NOTE: A fan input is 0 RPM after a suspend in this boot, but no sensor is currently at least 70 C. Timing and fan-stop policy require correlation."
else
    echo "  No live hot-sensor/zero-RPM resume signature."
fi
sync

echo "--- Battery charge limit interaction ---"
BAT_DIR="${DECKDOC_BATTERY_PATH:-${POWER_SUPPLY_ROOT}/BAT1}"
if [ ! -d "$BAT_DIR" ]; then
    BAT_DIR="${POWER_SUPPLY_ROOT}/BAT0"
fi
CHARGE_LIMIT_FILE=""
for candidate in "${BAT_DIR}/charge_control_limit" "${BAT_DIR}/charge_control_end_threshold"; do
    if [ -r "$candidate" ]; then CHARGE_LIMIT_FILE="$candidate"; break; fi
done
if [ -n "$CHARGE_LIMIT_FILE" ]; then
    echo "  Battery charge-limit control: ${CHARGE_LIMIT_FILE}=$(cat "$CHARGE_LIMIT_FILE" 2>/dev/null || echo unreadable)"
    echo "  NOTE: Compare the configured limit and charging state with the suspend window before applying issue #2475."
else
    echo "  No battery charge limit configured."
fi
sync
