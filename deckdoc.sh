#!/usr/bin/env bash
set -uo pipefail
umask 077

FIX_MODE=false
DISPLAY_BLACK_REPORTED=false
DISPLAY_FIX_MODE=false
PERSIST_DISPLAY_STABILITY=false
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
        --display-black|--symptom=display-black) DISPLAY_BLACK_REPORTED=true ;;
        --fix-display-blackout)
            DISPLAY_BLACK_REPORTED=true
            DISPLAY_FIX_MODE=true
            ;;
        --persist-display-stability)
            DISPLAY_BLACK_REPORTED=true
            DISPLAY_FIX_MODE=true
            PERSIST_DISPLAY_STABILITY=true
            ;;
    esac
done

export DECKDOC_DISPLAY_BLACK_REPORTED="$DISPLAY_BLACK_REPORTED"
export DECKDOC_PERSIST_DISPLAY_STABILITY="$PERSIST_DISPLAY_STABILITY"

if [ "$(id -u)" -ne 0 ]; then
    echo "WARNING: Not running as root. Some diagnostics (dmesg, smartctl, btrfs stats) will be restricted."
    echo "WARNING: Remediation modules require root. Use --fix with sudo for full effect."
fi

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DECKDOC_DIR
if [ -r "${DECKDOC_DIR}/VERSION" ]; then
    DECKDOC_VERSION=$(<"${DECKDOC_DIR}/VERSION")
else
    DECKDOC_VERSION="unknown"
fi
readonly DECKDOC_VERSION
MODULES_DIR="${DECKDOC_DIR}/modules"
REDACTOR="${DECKDOC_DIR}/lib/deckdoc-redact.sh"
LOG_DIR="${DECKDOC_LOG_DIR:-${DECKDOC_DIR}/logs}"
RUN_ID=$(date +%s)
REPORT_FILE="${LOG_DIR}/deckdoc_master_report_${RUN_ID}.log"
CAPABILITY_JSON="${LOG_DIR}/deckdoc_capabilities_${RUN_ID}.json"
CAPABILITY_ENV="${LOG_DIR}/.deckdoc_capabilities_${RUN_ID}.env"

if [ ! -x "$REDACTOR" ]; then
    echo "DeckDoc public-safe output filter is missing or not executable; refusing collection." >&2
    exit 1
fi

mkdir -p "${LOG_DIR}"
rm -f "${LOG_DIR}"/module_*.log

panic_sync() {
    sync
}
trap panic_sync EXIT HUP INT QUIT TERM

echo "========================================" > "${REPORT_FILE}"
echo "DeckDoc v${DECKDOC_VERSION} - Diagnostics + Safe Remediation" >> "${REPORT_FILE}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${REPORT_FILE}"
echo "Reported symptom: display-black=${DISPLAY_BLACK_REPORTED}" >> "${REPORT_FILE}"
echo "========================================" >> "${REPORT_FILE}"
sync

run_module() {
    local module="$1" output="$2"
    "$module" 2>&1 | "$REDACTOR" > "$output"
}

if ! "${MODULES_DIR}/system_manifest.sh" --json "$CAPABILITY_JSON" --env "$CAPABILITY_ENV" 2>&1 \
    | "$REDACTOR" > "${LOG_DIR}/module_00_system_manifest.log"; then
    rm -f -- "$CAPABILITY_ENV" "$CAPABILITY_JSON"
    echo "DeckDoc capability discovery failed; refusing an assumption-based report." >&2
    exit 1
fi
while IFS='=' read -r capability_key capability_value; do
    case "$capability_key" in
        DECKDOC_MODEL_FAMILY|DECKDOC_MODEL_CLASS|DECKDOC_DRM_CARD_PATH|DECKDOC_INTERNAL_DISPLAY_PATH|\
        DECKDOC_BACKLIGHT_PATH|DECKDOC_BATTERY_PATH|DECKDOC_PRIMARY_STORAGE|DECKDOC_WIFI_INTERFACE)
            export "${capability_key}=${capability_value}"
            ;;
    esac
done < "$CAPABILITY_ENV"
rm -f -- "$CAPABILITY_ENV"
export DECKDOC_CAPABILITY_JSON="$CAPABILITY_JSON"

# Hardware telemetry modules (v1.x)
run_module "${MODULES_DIR}/gpu_apu.sh" "${LOG_DIR}/module_gpu.log" &
run_module "${MODULES_DIR}/battery_pmic.sh" "${LOG_DIR}/module_battery.log" &
run_module "${MODULES_DIR}/thermal_fan.sh" "${LOG_DIR}/module_thermal.log" &
run_module "${MODULES_DIR}/storage_smart.sh" "${LOG_DIR}/module_storage.log" &
run_module "${MODULES_DIR}/fs_integrity.sh" "${LOG_DIR}/module_fs.log" &

# Software/OS diagnostic modules (v2.0 / v3.0)
run_module "${MODULES_DIR}/audio_sof.sh" "${LOG_DIR}/module_audio.log" &
run_module "${MODULES_DIR}/display_blackout.sh" "${LOG_DIR}/module_display.log" &
run_module "${MODULES_DIR}/dock_usb_c.sh" "${LOG_DIR}/module_dock.log" &
run_module "${MODULES_DIR}/coredump_analysis.sh" "${LOG_DIR}/module_coredump.log" &
run_module "${MODULES_DIR}/wifi_firmware.sh" "${LOG_DIR}/module_wifi.log" &
run_module "${MODULES_DIR}/gamescope_session.sh" "${LOG_DIR}/module_gamescope.log" &
run_module "${MODULES_DIR}/memory_swap.sh" "${LOG_DIR}/module_memory.log" &
run_module "${MODULES_DIR}/probe_incidents.sh" "${LOG_DIR}/module_probe.log" &
run_module "${MODULES_DIR}/steam_client_logs.sh" "${LOG_DIR}/module_steam.log" &
run_module "${MODULES_DIR}/ryudeck_app.sh" "${LOG_DIR}/module_ryudeck.log" &
run_module "${MODULES_DIR}/mmc_sd_card.sh" "${LOG_DIR}/module_mmc.log" &
run_module "${MODULES_DIR}/acpi_pm_state.sh" "${LOG_DIR}/module_acpi.log" &
run_module "${MODULES_DIR}/dxvk_page_fault.sh" "${LOG_DIR}/module_dxvk.log" &

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

    "${MODULES_DIR}/rem_audio_sof.sh" 2>&1 | "$REDACTOR" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
    sync

    echo "Remediation phase complete."
fi

# Display remediation is deliberately separate from broad --fix. A physical-black
# report and the module's live-panel prechecks are both required before it acts.
if [ "$DISPLAY_FIX_MODE" = true ]; then
    echo "" >> "${REPORT_FILE}"
    echo "=== DISPLAY REMEDIATION PHASE ===" >> "${REPORT_FILE}"
    "${MODULES_DIR}/rem_display_blackout.sh" 2>&1 | "$REDACTOR" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
    sync
fi

sync
exit 0
