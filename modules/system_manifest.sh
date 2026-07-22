#!/usr/bin/env bash
set -uo pipefail

umask 077

SYS_ROOT="${DECKDOC_SYS_ROOT:-/sys}"
PROC_ROOT="${DECKDOC_PROC_ROOT:-/proc}"
ETC_ROOT="${DECKDOC_ETC_ROOT:-/etc}"
DEV_ROOT="${DECKDOC_DEV_ROOT:-/dev}"
JSON_OUTPUT=""
ENV_OUTPUT=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --json)
            [ "$#" -ge 2 ] || { echo "--json requires a path" >&2; exit 2; }
            JSON_OUTPUT="$2"
            shift 2
            ;;
        --env)
            [ "$#" -ge 2 ] || { echo "--env requires a path" >&2; exit 2; }
            ENV_OUTPUT="$2"
            shift 2
            ;;
        *) echo "Unknown manifest argument: $1" >&2; exit 2 ;;
    esac
done

read_field() {
    local path="$1" fallback="${2:-unknown}" value
    if [ ! -r "$path" ]; then printf '%s\n' "$fallback"; return; fi
    value=$(tr -d '\r\n' < "$path" 2>/dev/null || true)
    if [ -n "$value" ]; then
        printf '%s' "$value" | tr -cd '[:alnum:] ._+:/()-'
        printf '\n'
    else
        printf '%s\n' "$fallback"
    fi
}

os_field() {
    local key="$1" value
    if [ ! -r "${ETC_ROOT}/os-release" ]; then printf 'unknown\n'; return; fi
    value=$(grep -m1 "^${key}=" "${ETC_ROOT}/os-release" 2>/dev/null | cut -d= -f2- || true)
    value=${value#\"}; value=${value%\"}
    if [ -n "$value" ]; then
        printf '%s' "$value" | tr -cd '[:alnum:] ._+:/()-'
        printf '\n'
    else
        printf 'unknown\n'
    fi
}

json_escape() {
    local value="${1:-}"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/ }
    printf '%s' "$value"
}

path_state() {
    local path="$1"
    if [ -e "$path" ]; then
        if [ -r "$path" ]; then printf 'supported_and_readable\n'; else printf 'supported_but_inaccessible\n'; fi
    else
        printf 'absent\n'
    fi
}

first_dir() {
    local candidate
    for candidate in "$@"; do
        [ -d "$candidate" ] || continue
        printf '%s\n' "$candidate"
        return
    done
}

DMI_ROOT="${SYS_ROOT}/devices/virtual/dmi/id"
RAW_SYSTEM_VENDOR=$(read_field "${DMI_ROOT}/sys_vendor")
RAW_PRODUCT_NAME=$(read_field "${DMI_ROOT}/product_name")
RAW_PRODUCT_VERSION=$(read_field "${DMI_ROOT}/product_version")
RAW_BOARD_NAME=$(read_field "${DMI_ROOT}/board_name")
RAW_BIOS_VERSION=$(read_field "${DMI_ROOT}/bios_version")

MODEL_FAMILY="unknown"
MODEL_CLASS="unknown"
case "${RAW_SYSTEM_VENDOR,,}:${RAW_PRODUCT_NAME,,}" in
    valve:jupiter) MODEL_FAMILY="jupiter_lcd"; MODEL_CLASS="lcd" ;;
    valve:galileo) MODEL_FAMILY="galileo_oled"; MODEL_CLASS="oled" ;;
esac

# DMI has many identity-bearing fields. Only expose the small Valve model and
# firmware allowlist needed for capability decisions; never fall back to a raw
# arbitrary-vendor DMI dump.
SYSTEM_VENDOR="non_valve_or_unknown"
PRODUCT_NAME="unknown"
PRODUCT_VERSION="unknown"
BOARD_NAME="unknown"
BIOS_VERSION="unknown"
if [ "$MODEL_FAMILY" != "unknown" ]; then
    SYSTEM_VENDOR="Valve"
    case "$MODEL_FAMILY" in
        jupiter_lcd) PRODUCT_NAME="Jupiter" ;;
        galileo_oled) PRODUCT_NAME="Galileo" ;;
    esac
    case "${RAW_BOARD_NAME,,}" in
        jupiter) BOARD_NAME="Jupiter" ;;
        galileo) BOARD_NAME="Galileo" ;;
    esac
    if [[ "$RAW_PRODUCT_VERSION" =~ ^[0-9]+([.][0-9]+)*$ ]]; then PRODUCT_VERSION="$RAW_PRODUCT_VERSION"; fi
    if [[ "$RAW_BIOS_VERSION" =~ ^[A-Z0-9][A-Z0-9._+-]{0,31}$ ]]; then BIOS_VERSION="$RAW_BIOS_VERSION"; fi
fi

OS_ID=$(os_field ID)
OS_VERSION=$(os_field VERSION_ID)
OS_BUILD=$(os_field BUILD_ID)
OS_VARIANT=$(os_field VARIANT_ID)
KERNEL=$(uname -r 2>/dev/null | tr -cd '[:alnum:] ._+-' || echo unknown)
ARCHITECTURE=$(uname -m 2>/dev/null | tr -cd '[:alnum:]_-' || echo unknown)
ENVIRONMENT="${DECKDOC_ENVIRONMENT:-}"
case "$ENVIRONMENT" in
    installed_steamos|rescue_linux|linux|windows) ;;
    '')
        if [ "$OS_ID" = "steamos" ]; then ENVIRONMENT="installed_steamos"; else ENVIRONMENT="linux"; fi
        ;;
    *) ENVIRONMENT="unknown" ;;
esac

INTERNAL_DISPLAY=""
for candidate in "${SYS_ROOT}"/class/drm/card*-eDP-* "${SYS_ROOT}"/class/drm/card*-edp-*; do
    [ -d "$candidate" ] || continue
    if [ "$(cat "${candidate}/status" 2>/dev/null || true)" = "connected" ]; then INTERNAL_DISPLAY="$candidate"; break; fi
    [ -n "$INTERNAL_DISPLAY" ] || INTERNAL_DISPLAY="$candidate"
done
INTERNAL_DISPLAY_STATE="absent"
if [ -n "$INTERNAL_DISPLAY" ]; then INTERNAL_DISPLAY_STATE=$(path_state "$INTERNAL_DISPLAY"); fi
INTERNAL_DISPLAY_LABEL="unknown"
if [ -n "$INTERNAL_DISPLAY" ] && [[ "$(basename "$INTERNAL_DISPLAY")" =~ ^card[0-9]+-(eDP|edp)-[0-9]+$ ]]; then
    INTERNAL_DISPLAY_LABEL=$(basename "$INTERNAL_DISPLAY")
fi

BACKLIGHT_PATH=$(first_dir "${SYS_ROOT}"/class/backlight/*)
BACKLIGHT_STATE="absent"
if [ -n "$BACKLIGHT_PATH" ]; then BACKLIGHT_STATE=$(path_state "$BACKLIGHT_PATH"); fi
BACKLIGHT_LABEL="unknown"
if [ -n "$BACKLIGHT_PATH" ] && [[ "$(basename "$BACKLIGHT_PATH")" =~ ^[a-zA-Z0-9_.+-]+$ ]]; then
    BACKLIGHT_LABEL=$(basename "$BACKLIGHT_PATH")
fi
LCD_BACKLIGHT_STATE="unknown"
case "$MODEL_CLASS" in
    lcd) LCD_BACKLIGHT_STATE="$BACKLIGHT_STATE" ;;
    oled) LCD_BACKLIGHT_STATE="not_applicable" ;;
esac

DRM_CARD=""
for candidate in "${SYS_ROOT}"/class/drm/card[0-9]*; do
    [ -e "$candidate" ] || continue
    [[ "$(basename "$candidate")" =~ ^card[0-9]+$ ]] || continue
    DRM_CARD="$candidate"
    break
done
GPU_STATE="absent"
if [ -n "$DRM_CARD" ]; then GPU_STATE=$(path_state "$DRM_CARD"); fi

BATTERY_PATH=""
for candidate in "${SYS_ROOT}"/class/power_supply/*; do
    [ -d "$candidate" ] || continue
    if [ "$(cat "${candidate}/type" 2>/dev/null || true)" = "Battery" ]; then BATTERY_PATH="$candidate"; break; fi
done
BATTERY_STATE="absent"
if [ -n "$BATTERY_PATH" ]; then BATTERY_STATE=$(path_state "$BATTERY_PATH"); fi
BATTERY_LABEL="unknown"
if [ -n "$BATTERY_PATH" ]; then
    if [[ "$(basename "$BATTERY_PATH")" =~ ^BAT[0-9]+$ ]]; then BATTERY_LABEL=$(basename "$BATTERY_PATH"); else BATTERY_LABEL="battery0"; fi
fi

PRIMARY_STORAGE=""
for candidate in "${SYS_ROOT}"/class/block/nvme*n1; do
    [ -e "$candidate" ] || continue
    PRIMARY_STORAGE="${DEV_ROOT}/$(basename "$candidate")"
    break
done
STORAGE_STATE="absent"
if [ -n "$PRIMARY_STORAGE" ]; then
    if [ -e "$PRIMARY_STORAGE" ] || [ "$DEV_ROOT" != "/dev" ]; then STORAGE_STATE="supported_and_readable"; else STORAGE_STATE="supported_but_inaccessible"; fi
fi

WIFI_INTERFACE=""
for candidate in "${SYS_ROOT}"/class/net/*; do
    [ -d "$candidate" ] || continue
    name=$(basename "$candidate")
    case "$name" in lo) continue ;; esac
    if [ -d "${candidate}/wireless" ] || [[ "$name" =~ ^(wlan[0-9]+|wl[^:]*)$ ]]; then WIFI_INTERFACE="$name"; break; fi
done
WIFI_STATE="absent"
if [ -n "$WIFI_INTERFACE" ]; then WIFI_STATE=$(path_state "${SYS_ROOT}/class/net/${WIFI_INTERFACE}"); fi
WIFI_LABEL="unknown"
if [ -n "$WIFI_INTERFACE" ]; then WIFI_LABEL="wireless0"; fi

SOUND_STATE="absent"
if [ -d "${PROC_ROOT}/asound" ]; then
    if [ -r "${PROC_ROOT}/asound/cards" ]; then SOUND_STATE="supported_and_readable"; else SOUND_STATE="supported_but_inaccessible"; fi
fi
INPUT_STATE=$(path_state "${SYS_ROOT}/class/input")
HWMON_STATE=$(path_state "${SYS_ROOT}/class/hwmon")
TYPEC_STATE=$(path_state "${SYS_ROOT}/class/typec")
USB_STATE=$(path_state "${SYS_ROOT}/bus/usb/devices")
MMC_STATE=$(path_state "${SYS_ROOT}/class/mmc_host")

JOURNAL_STATE="absent"
KERNEL_JOURNAL_STATE="absent"
if command -v journalctl >/dev/null 2>&1; then
    if journalctl -b 0 -n 1 --no-pager >/dev/null 2>&1; then JOURNAL_STATE="supported_and_readable"; else JOURNAL_STATE="supported_but_inaccessible"; fi
    if journalctl -k -b 0 -n 1 --no-pager >/dev/null 2>&1; then KERNEL_JOURNAL_STATE="supported_and_readable"; else KERNEL_JOURNAL_STATE="supported_but_inaccessible"; fi
fi
if [ "$ENVIRONMENT" != "installed_steamos" ]; then
    STEAMOS_SESSION_STATE="not_applicable"
elif command -v gamescope >/dev/null 2>&1; then
    STEAMOS_SESSION_STATE="supported_and_readable"
else
    STEAMOS_SESSION_STATE="absent"
fi

DEBUGFS_STATE="absent"
if [ -d "${SYS_ROOT}/kernel/debug" ]; then
    if find "${SYS_ROOT}/kernel/debug" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
        DEBUGFS_STATE="supported_and_readable"
    else
        DEBUGFS_STATE="supported_but_inaccessible"
    fi
fi

CAPTURE_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[MODULE: System & Capability Manifest]"
echo "  Schema version: 1"
echo "  Capture UTC: ${CAPTURE_UTC}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Model family: ${MODEL_FAMILY} (${MODEL_CLASS})"
echo "  DMI: vendor=${SYSTEM_VENDOR}, product=${PRODUCT_NAME}, product_version=${PRODUCT_VERSION}, board=${BOARD_NAME}"
echo "  Firmware: BIOS ${BIOS_VERSION}"
echo "  OS: id=${OS_ID}, version=${OS_VERSION}, build=${OS_BUILD}, variant=${OS_VARIANT}, kernel=${KERNEL}, arch=${ARCHITECTURE}"
echo "  PRIVACY: allowlisted hardware/OS facts only; no serial, hostname, account, network identity, secret material, or environment dump."
echo "--- Capability states ---"
printf '  %-28s %-28s %s\n' "gpu_drm" "$GPU_STATE" "$(basename "${DRM_CARD:-unknown}")"
printf '  %-28s %-28s %s\n' "internal_display" "$INTERNAL_DISPLAY_STATE" "$INTERNAL_DISPLAY_LABEL"
printf '  %-28s %-28s %s\n' "brightness_export" "$BACKLIGHT_STATE" "$BACKLIGHT_LABEL"
printf '  %-28s %-28s %s\n' "lcd_backlight_semantics" "$LCD_BACKLIGHT_STATE" "model=${MODEL_CLASS}"
printf '  %-28s %-28s %s\n' "battery" "$BATTERY_STATE" "$BATTERY_LABEL"
printf '  %-28s %-28s %s\n' "primary_nvme" "$STORAGE_STATE" "$(basename "${PRIMARY_STORAGE:-unknown}")"
printf '  %-28s %-28s %s\n' "wifi" "$WIFI_STATE" "$WIFI_LABEL"
printf '  %-28s %-28s\n' "audio" "$SOUND_STATE"
printf '  %-28s %-28s\n' "input" "$INPUT_STATE"
printf '  %-28s %-28s\n' "thermal_fan_hwmon" "$HWMON_STATE"
printf '  %-28s %-28s\n' "typec_exports" "$TYPEC_STATE"
printf '  %-28s %-28s\n' "usb" "$USB_STATE"
printf '  %-28s %-28s\n' "microsd_host" "$MMC_STATE"
printf '  %-28s %-28s\n' "system_journal" "$JOURNAL_STATE"
printf '  %-28s %-28s\n' "kernel_journal" "$KERNEL_JOURNAL_STATE"
printf '  %-28s %-28s\n' "debugfs" "$DEBUGFS_STATE"
printf '  %-28s %-28s\n' "steamos_session" "$STEAMOS_SESSION_STATE"

if [ -n "$ENV_OUTPUT" ]; then
    : > "$ENV_OUTPUT"
    chmod 600 "$ENV_OUTPUT" 2>/dev/null || true
    printf '%s=%s\n' DECKDOC_MODEL_FAMILY "$MODEL_FAMILY" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_MODEL_CLASS "$MODEL_CLASS" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_DRM_CARD_PATH "$DRM_CARD" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_INTERNAL_DISPLAY_PATH "$INTERNAL_DISPLAY" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_BACKLIGHT_PATH "$BACKLIGHT_PATH" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_BATTERY_PATH "$BATTERY_PATH" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_PRIMARY_STORAGE "$PRIMARY_STORAGE" >> "$ENV_OUTPUT"
    printf '%s=%s\n' DECKDOC_WIFI_INTERFACE "$WIFI_INTERFACE" >> "$ENV_OUTPUT"
fi

if [ -n "$JSON_OUTPUT" ]; then
    cat > "$JSON_OUTPUT" <<JSON
{
  "schema_version": 1,
  "capture": {"utc": "$(json_escape "$CAPTURE_UTC")", "environment": "$(json_escape "$ENVIRONMENT")"},
  "system": {
    "vendor": "$(json_escape "$SYSTEM_VENDOR")",
    "product": "$(json_escape "$PRODUCT_NAME")",
    "product_version": "$(json_escape "$PRODUCT_VERSION")",
    "board": "$(json_escape "$BOARD_NAME")",
    "model_family": "$(json_escape "$MODEL_FAMILY")",
    "model_class": "$(json_escape "$MODEL_CLASS")",
    "bios_version": "$(json_escape "$BIOS_VERSION")",
    "os_id": "$(json_escape "$OS_ID")",
    "os_version": "$(json_escape "$OS_VERSION")",
    "os_build": "$(json_escape "$OS_BUILD")",
    "os_variant": "$(json_escape "$OS_VARIANT")",
    "kernel": "$(json_escape "$KERNEL")",
    "architecture": "$(json_escape "$ARCHITECTURE")"
  },
  "capabilities": {
    "gpu_drm": {"state": "$GPU_STATE", "device": "$(json_escape "$(basename "${DRM_CARD:-unknown}")")"},
    "internal_display": {"state": "$INTERNAL_DISPLAY_STATE", "device": "$(json_escape "$INTERNAL_DISPLAY_LABEL")"},
    "brightness_export": {"state": "$BACKLIGHT_STATE", "device": "$(json_escape "$BACKLIGHT_LABEL")"},
    "lcd_backlight_semantics": {"state": "$LCD_BACKLIGHT_STATE"},
    "battery": {"state": "$BATTERY_STATE", "device": "$(json_escape "$BATTERY_LABEL")"},
    "primary_nvme": {"state": "$STORAGE_STATE", "device": "$(json_escape "$(basename "${PRIMARY_STORAGE:-unknown}")")"},
    "wifi": {"state": "$WIFI_STATE", "device": "$(json_escape "$WIFI_LABEL")"},
    "audio": {"state": "$SOUND_STATE"},
    "input": {"state": "$INPUT_STATE"},
    "thermal_fan_hwmon": {"state": "$HWMON_STATE"},
    "typec_exports": {"state": "$TYPEC_STATE"},
    "usb": {"state": "$USB_STATE"},
    "microsd_host": {"state": "$MMC_STATE"},
    "system_journal": {"state": "$JOURNAL_STATE"},
    "kernel_journal": {"state": "$KERNEL_JOURNAL_STATE"},
    "debugfs": {"state": "$DEBUGFS_STATE"},
    "steamos_session": {"state": "$STEAMOS_SESSION_STATE"}
  },
  "privacy": {"classification": "public_safe_filtered", "review_before_sharing": true}
}
JSON
    chmod 600 "$JSON_OUTPUT" 2>/dev/null || true
fi
