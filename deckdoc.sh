#!/usr/bin/env bash
set -uo pipefail

FIX_MODE=false
for arg in "$@"; do
    if [ "$arg" = "--fix" ]; then
        FIX_MODE=true
    fi
done

if [ "$(id -u)" -ne 0 ]; then
    echo "WARNING: Not running as root. Some diagnostics (dmesg, smartctl, btrfs stats) will be restricted."
    echo "WARNING: Remediation modules require root. Use --fix with sudo for full effect."
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
echo "DeckDoc v3.0.0 - Diagnostics + Remediation" >> "${REPORT_FILE}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${REPORT_FILE}"
echo "========================================" >> "${REPORT_FILE}"
sync

# Hardware telemetry modules (v1.x)
"${MODULES_DIR}/gpu_apu.sh" > "${LOG_DIR}/module_gpu.log" 2>&1 &
"${MODULES_DIR}/battery_pmic.sh" > "${LOG_DIR}/module_battery.log" 2>&1 &
"${MODULES_DIR}/thermal_fan.sh" > "${LOG_DIR}/module_thermal.log" 2>&1 &
"${MODULES_DIR}/storage_smart.sh" > "${LOG_DIR}/module_storage.log" 2>&1 &
"${MODULES_DIR}/fs_integrity.sh" > "${LOG_DIR}/module_fs.log" 2>&1 &

# Software/OS diagnostic modules (v2.0 / v3.0)
"${MODULES_DIR}/audio_sof.sh" > "${LOG_DIR}/module_audio.log" 2>&1 &
"${MODULES_DIR}/display_blackout.sh" > "${LOG_DIR}/module_display.log" 2>&1 &
"${MODULES_DIR}/coredump_analysis.sh" > "${LOG_DIR}/module_coredump.log" 2>&1 &
"${MODULES_DIR}/wifi_firmware.sh" > "${LOG_DIR}/module_wifi.log" 2>&1 &
"${MODULES_DIR}/gamescope_session.sh" > "${LOG_DIR}/module_gamescope.log" 2>&1 &
"${MODULES_DIR}/memory_swap.sh" > "${LOG_DIR}/module_memory.log" 2>&1 &
"${MODULES_DIR}/steam_client_logs.sh" > "${LOG_DIR}/module_steam.log" 2>&1 &
"${MODULES_DIR}/mmc_sd_card.sh" > "${LOG_DIR}/module_mmc.log" 2>&1 &
"${MODULES_DIR}/acpi_pm_state.sh" > "${LOG_DIR}/module_acpi.log" 2>&1 &
"${MODULES_DIR}/dxvk_page_fault.sh" > "${LOG_DIR}/module_dxvk.log" 2>&1 &

wait

for log in "${LOG_DIR}"/module_*.log; do
    cat "${log}" >> "${REPORT_FILE}"
    echo -e "\n----------------------------------------\n" >> "${REPORT_FILE}"
    sync
done

# Remediation modules (v3.0) — only with --fix flag
if [ "$FIX_MODE" = true ]; then
    echo "" >> "${REPORT_FILE}"
    echo "=== REMEDIATION PHASE ===" >> "${REPORT_FILE}"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${REPORT_FILE}"
    echo "=========================" >> "${REPORT_FILE}"
    sync

    echo "Remediation phase enabled."

    "${MODULES_DIR}/rem_audio_sof.sh" >> "${REPORT_FILE}" 2>&1
    echo "" >> "${REPORT_FILE}"
    sync

    echo "Remediation phase complete."
fi

sync
exit 0
