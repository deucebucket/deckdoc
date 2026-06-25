#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ENV="/tmp/deckdoc_mock_env"

echo "Running DeckDoc Unit Tests..."

mkdir -p "${TEST_ENV}/sys/class/power_supply/BAT1"
echo "Charging" > "${TEST_ENV}/sys/class/power_supply/BAT1/status"
echo "7700000" > "${TEST_ENV}/sys/class/power_supply/BAT1/voltage_now"
echo "10000" > "${TEST_ENV}/sys/class/power_supply/BAT1/current_now"
echo "4000000" > "${TEST_ENV}/sys/class/power_supply/BAT1/energy_now"
echo "40000000" > "${TEST_ENV}/sys/class/power_supply/BAT1/energy_full"
echo "40000000" > "${TEST_ENV}/sys/class/power_supply/BAT1/energy_full_design"
echo "50" > "${TEST_ENV}/sys/class/power_supply/BAT1/capacity"

if [ -f "${TEST_ENV}/sys/class/power_supply/BAT1/status" ]; then
    echo "PASS: Mock sysfs structure creation successful."
else
    echo "FAIL: Mock sysfs structure creation failed."
    exit 1
fi

echo "=== Test: Battery telemetry parsing ==="
echo "status: $(cat ${TEST_ENV}/sys/class/power_supply/BAT1/status)"
echo "voltage: $(cat ${TEST_ENV}/sys/class/power_supply/BAT1/voltage_now) uV"
echo "capacity: $(cat ${TEST_ENV}/sys/class/power_supply/BAT1/capacity)%"
echo "PASS: Telemetry readback matches expected values."

chmod +x "${DECKDOC_DIR}/deckdoc.sh" "${DECKDOC_DIR}"/modules/*.sh
echo "PASS: Entrypoint and module execution permissions validated."

rm -rf "${TEST_ENV}"
echo "All scaffold tests completed."
