#!/usr/bin/env bash
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "WARNING: Not running as root. Some diagnostics (dmesg, smartctl, btrfs stats) will be restricted."
fi

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${DECKDOC_DIR}/modules"
LOG_DIR="${DECKDOC_DIR}/logs"
REPORT_FILE="${LOG_DIR}/deckdoc_master_report_$(date +%s).log"

mkdir -p "${LOG_DIR}"
rm -f "${LOG_DIR}"/module_*.log

panic_sync() {
    sync
}
trap panic_sync EXIT HUP INT QUIT TERM

echo "========================================" > "${REPORT_FILE}"
echo "DeckDoc v1.0.0 - Bare-Metal Diagnostics" >> "${REPORT_FILE}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${REPORT_FILE}"
echo "========================================" >> "${REPORT_FILE}"
sync

"${MODULES_DIR}/gpu_apu.sh" > "${LOG_DIR}/module_gpu.log" 2>&1 &
"${MODULES_DIR}/battery_pmic.sh" > "${LOG_DIR}/module_battery.log" 2>&1 &
"${MODULES_DIR}/thermal_fan.sh" > "${LOG_DIR}/module_thermal.log" 2>&1 &
"${MODULES_DIR}/storage_smart.sh" > "${LOG_DIR}/module_storage.log" 2>&1 &
"${MODULES_DIR}/fs_integrity.sh" > "${LOG_DIR}/module_fs.log" 2>&1 &

wait

for log in "${LOG_DIR}"/module_*.log; do
    cat "${log}" >> "${REPORT_FILE}"
    echo -e "\n----------------------------------------\n" >> "${REPORT_FILE}"
    sync
done

sync
exit 0
