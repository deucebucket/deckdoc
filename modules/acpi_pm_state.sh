#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: ACPI Sleep/Wake (PM State)]"
sync

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

echo "--- Battery charge limit interaction ---"
BAT_DIR="/sys/class/power_supply/BAT1"
if [ ! -d "$BAT_DIR" ]; then
    BAT_DIR="/sys/class/power_supply/BAT0"
fi
if [ -f "${BAT_DIR}/charge_control_limit" ]; then
    echo "  Battery charge limit is set (may interact with PM resume bug #2475)."
else
    echo "  No battery charge limit configured."
fi
sync
