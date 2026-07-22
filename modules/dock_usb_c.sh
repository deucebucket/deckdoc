#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Dock / USB-C / Power Delivery]"
sync

SYS_ROOT="${DECKDOC_SYS_ROOT:-/sys}"
TYPEC_ROOT="${DECKDOC_TYPEC_ROOT:-${SYS_ROOT}/class/typec}"
POWER_ROOT="${DECKDOC_POWER_SUPPLY_ROOT:-${SYS_ROOT}/class/power_supply}"
DRM_ROOT="${DECKDOC_DRM_ROOT:-${SYS_ROOT}/class/drm}"

read_field() {
    local file="$1"
    if [ -r "$file" ]; then cat "$file" 2>/dev/null || echo inaccessible; else echo not-exported; fi
}

echo "--- USB topology ---"
if command -v lsusb >/dev/null 2>&1; then
    lsusb -t 2>/dev/null || echo "  USB topology inaccessible."
    echo "  USB device IDs (serial numbers intentionally omitted):"
    lsusb 2>/dev/null | sed -E 's/(ID [0-9a-fA-F]{4}:[0-9a-fA-F]{4}).*/\1 [description omitted]/' || true
else
    echo "  lsusb not available."
fi
sync

echo "--- USB Type-C roles and partner ---"
TYPEC_PORTS=0
for port in "$TYPEC_ROOT"/port[0-9]*; do
    [ -d "$port" ] || continue
    case "$(basename "$port")" in *-*) continue ;; esac
    TYPEC_PORTS=$((TYPEC_PORTS + 1))
    name=$(basename "$port")
    echo "  Port: ${name}"
    for field in data_role power_role port_type power_operation_mode orientation usb_power_delivery_revision usb_typec_revision; do
        echo "    ${field}=$(read_field "${port}/${field}")"
    done
    if [ -e "${TYPEC_ROOT}/${name}-partner" ] || [ -e "${port}/${name}-partner" ]; then
        echo "    partner=present"
    else
        echo "    partner=not-exported-or-absent"
    fi
done
if [ "$TYPEC_PORTS" -eq 0 ]; then
    echo "  INACCESSIBLE: No Type-C class port is exported by this kernel/driver."
fi

echo "--- DisplayPort Alternate Mode ---"
ALT_MODE_FOUND=false
for field in "$SYS_ROOT"/bus/typec/devices/*/displayport/configuration \
             "$SYS_ROOT"/bus/typec/devices/*/displayport/pin_assignment \
             "$SYS_ROOT"/bus/typec/devices/*/displayport/hpd; do
    [ -r "$field" ] || continue
    ALT_MODE_FOUND=true
    echo "  ${field#${SYS_ROOT}/}=$(cat "$field" 2>/dev/null || echo inaccessible)"
done
if [ "$ALT_MODE_FOUND" = false ]; then echo "  DisplayPort Alt Mode state not exported."; fi
sync

echo "--- Power Delivery and charger telemetry ---"
PD_TELEMETRY=false
for supply in "$POWER_ROOT"/*; do
    [ -d "$supply" ] || continue
    supply_type=$(read_field "${supply}/type")
    case "${supply_type,,}" in usb*|mains*) ;;
        *) continue ;;
    esac
    PD_TELEMETRY=true
    echo "  Supply: $(basename "$supply") type=${supply_type}"
    for field in online usb_type voltage_now current_now current_max power_now input_current_limit; do
        value=$(read_field "${supply}/${field}")
        echo "    ${field}=${value}"
    done
    voltage=$(read_field "${supply}/voltage_now")
    current=$(read_field "${supply}/current_now")
    case "$voltage:$current" in
        *[!0-9:-]*|not-exported:*|*:not-exported) ;;
        *)
            watts=$(awk -v v="$voltage" -v c="$current" 'BEGIN {printf "%.2f", (v*c)/1000000000000}')
            echo "    calculated_instantaneous_power=${watts} W (telemetry, not dock certification)"
            ;;
    esac
done
if [ "$PD_TELEMETRY" = false ]; then
    echo "  INACCESSIBLE: Charger voltage/current/PD telemetry is not exported. DeckDoc will not infer it."
fi
sync

echo "--- External display connectors ---"
EXTERNAL_CONNECTORS=0
for connector in "$DRM_ROOT"/card*-*; do
    [ -d "$connector" ] || continue
    name=$(basename "$connector")
    case "$name" in *-eDP-*|*-DSI-*) continue ;; esac
    EXTERNAL_CONNECTORS=$((EXTERNAL_CONNECTORS + 1))
    status=$(read_field "${connector}/status")
    edid_bytes=$(wc -c < "${connector}/edid" 2>/dev/null || echo inaccessible)
    echo "  ${name}: status=${status} edid_bytes=${edid_bytes} link_status=$(read_field "${connector}/link_status")"
    if [ "$status" = "connected" ] && [ -r "${connector}/modes" ]; then
        echo "    modes=$(head -5 "${connector}/modes" 2>/dev/null | tr '\n' ' ')"
    fi
done
if [ "$EXTERNAL_CONNECTORS" -eq 0 ]; then echo "  No external DRM connector is exported."; fi
sync

echo "--- Dock Ethernet candidates ---"
DOCK_NET=0
for iface_path in "$SYS_ROOT"/class/net/*; do
    [ -d "$iface_path" ] || continue
    iface=$(basename "$iface_path")
    [ "$iface" = "lo" ] && continue
    driver=$(basename "$(readlink -f "${iface_path}/device/driver" 2>/dev/null || echo unknown)")
    device_path=$(readlink -f "${iface_path}/device" 2>/dev/null || true)
    if [[ "$device_path" == *"/usb"* ]] || [[ "$driver" =~ ^(r8152|cdc_|asix|ax88179) ]]; then
        DOCK_NET=$((DOCK_NET + 1))
        echo "  ${iface}: driver=${driver} state=$(read_field "${iface_path}/operstate") carrier=$(read_field "${iface_path}/carrier") speed=$(read_field "${iface_path}/speed")"
    fi
done
if [ "$DOCK_NET" -eq 0 ]; then echo "  No USB/dock Ethernet interface identified."; fi
sync

echo "--- Dock/USB-C errors (current boot) ---"
KERNEL_LOG=""
if command -v journalctl >/dev/null 2>&1; then
    KERNEL_LOG=$(journalctl -k -b 0 -o short-monotonic --no-pager 2>/dev/null || true)
fi
if [ -z "$KERNEL_LOG" ] && command -v dmesg >/dev/null 2>&1; then KERNEL_LOG=$(dmesg 2>/dev/null || true); fi
if [ -n "$KERNEL_LOG" ]; then
    HARD_ERRORS=$(printf '%s\n' "$KERNEL_LOG" | grep -iE 'xhci.*(host.*(halt|reset)|error|timeout)|usb.*over-current|ucsi.*(error|fail|timeout)|type-?c.*(error|fail|timeout)|displayport.*(error|fail)|drm.*(link.*fail|edid.*fail)' | tail -20 || true)
    TOPOLOGY_EVENTS=$(printf '%s\n' "$KERNEL_LOG" | grep -iE 'usb [0-9-]+: (reset|disconnect)|xhci.*reset' | tail -20 || true)
    if [ -n "$HARD_ERRORS" ]; then
        echo "$HARD_ERRORS"
        echo "  HIGH: USB-C/host/PD/display-link errors occurred. Correlate exact time and direct-vs-dock behavior."
    else
        echo "  No selected USB-C host, PD, or display-link errors in the current boot."
    fi
    if [ -n "$TOPOLOGY_EVENTS" ]; then
        echo "  USB reset/disconnect observations (a deliberate unplug can be normal):"
        echo "$TOPOLOGY_EVENTS"
        if [ -n "$HARD_ERRORS" ]; then
            echo "  DOCK_SIGNATURE: TOPOLOGY_CHANGE_WITH_DOCK_PATH_ERROR"
        fi
    fi
else
    echo "  INACCESSIBLE: Current-boot kernel log unavailable."
fi
sync

echo "  INTERPRETATION: Software can observe negotiation and failures but cannot certify dock rail quality. Compare one docked report with a direct known-good charger/display/network path."
