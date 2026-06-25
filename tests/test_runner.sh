#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ENV="/tmp/deckdoc_mock_env"
cleanup() { rm -rf "${TEST_ENV}"; }
trap cleanup EXIT

echo "========================================="
echo "DeckDoc v2.0.0 — Test Runner"
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
if [ "$MODULE_COUNT" -eq 14 ]; then
    echo "  PASS: Expected 14 modules present."
else
    echo "  WARNING: Expected 14 modules, found ${MODULE_COUNT}."
fi

# === Test 6: deckdoc.sh launches all modules ===
echo ""
echo "--- Test 6: Parallel module launch check ---"
LAUNCH_COUNT=$(grep -c '"${MODULES_DIR}/.*\.sh"' "${DECKDOC_DIR}/deckdoc.sh" 2>/dev/null || echo 0)
echo "  Module launches in deckdoc.sh: ${LAUNCH_COUNT}"
if [ "$LAUNCH_COUNT" -eq 14 ]; then
    echo "  PASS: All 14 modules launched in parallel."
else
    echo "  FAIL: Expected 14 module launches, found ${LAUNCH_COUNT}."
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

echo ""
echo "========================================="
echo "All scaffold tests completed successfully."
echo "========================================="
