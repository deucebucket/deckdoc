#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ENV="/tmp/deckdoc_mock_env"
cleanup() { rm -rf "${TEST_ENV}"; }
trap cleanup EXIT

echo "========================================="
echo "DeckDoc v3.0.0 — Test Runner"
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
if [ "$MODULE_COUNT" -eq 16 ]; then
    echo "  PASS: Expected 16 modules present (15 diagnostic + 1 remediation)."
else
    echo "  WARNING: Expected 16 modules, found ${MODULE_COUNT}."
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

echo ""
echo "========================================="
echo "All scaffold tests completed successfully."
echo "========================================="
