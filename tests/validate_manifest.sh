#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d /tmp/deckdoc-manifest-fixtures.XXXXXX)
cleanup() {
    chmod -R u+rwX "$TEST_ROOT" 2>/dev/null || true
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

make_fixture() {
    local name="$1" vendor="$2" product="$3" root
    root="${TEST_ROOT}/${name}"
    mkdir -p "${root}/sys/devices/virtual/dmi/id" \
        "${root}/sys/class/drm/card0" "${root}/sys/class/drm/card0-eDP-1" \
        "${root}/sys/class/backlight/amdgpu_bl0" "${root}/sys/class/power_supply/BAT1" \
        "${root}/sys/class/block/nvme0n1" "${root}/sys/class/net/wlan0/wireless" \
        "${root}/sys/class/input" "${root}/sys/class/hwmon" "${root}/sys/class/mmc_host" \
        "${root}/sys/bus/usb/devices" "${root}/sys/kernel/debug" \
        "${root}/proc/asound" "${root}/etc" "${root}/dev" "${root}/bin"
    printf '%s\n' "$vendor" > "${root}/sys/devices/virtual/dmi/id/sys_vendor"
    printf '%s\n' "$product" > "${root}/sys/devices/virtual/dmi/id/product_name"
    printf '1\n' > "${root}/sys/devices/virtual/dmi/id/product_version"
    printf '%s\n' "$product" > "${root}/sys/devices/virtual/dmi/id/board_name"
    printf 'FIXTURE-BIOS\n' > "${root}/sys/devices/virtual/dmi/id/bios_version"
    printf 'connected\n' > "${root}/sys/class/drm/card0-eDP-1/status"
    printf 'Battery\n' > "${root}/sys/class/power_supply/BAT1/type"
    printf ' 0 [fixture]: fixture\n' > "${root}/proc/asound/cards"
    : > "${root}/dev/nvme0n1"
    cat > "${root}/etc/os-release" <<'EOF'
NAME="SteamOS"
ID=steamos
VARIANT_ID=steamdeck
VERSION_ID=fixture
BUILD_ID=fixture-build
EOF
    cat > "${root}/bin/journalctl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    cat > "${root}/bin/gamescope" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod 755 "${root}/bin/journalctl" "${root}/bin/gamescope"
}

run_fixture() {
    local name="$1" root
    root="${TEST_ROOT}/${name}"
    PATH="${root}/bin:/usr/bin:/bin" \
        DECKDOC_SYS_ROOT="${root}/sys" \
        DECKDOC_PROC_ROOT="${root}/proc" \
        DECKDOC_ETC_ROOT="${root}/etc" \
        DECKDOC_DEV_ROOT="${root}/dev" \
        DECKDOC_ENVIRONMENT=installed_steamos \
        "${DECKDOC_DIR}/modules/system_manifest.sh" \
            --json "${root}/manifest.json" --env "${root}/manifest.env" > "${root}/manifest.log"
}

make_fixture galileo Valve Galileo
run_fixture galileo
grep -Fq '"model_family": "galileo_oled"' "${TEST_ROOT}/galileo/manifest.json"
grep -Fq '"model_class": "oled"' "${TEST_ROOT}/galileo/manifest.json"
grep -Fq '"brightness_export": {"state": "supported_and_readable"' "${TEST_ROOT}/galileo/manifest.json"
grep -Fq '"lcd_backlight_semantics": {"state": "not_applicable"}' "${TEST_ROOT}/galileo/manifest.json"

make_fixture jupiter Valve Jupiter
run_fixture jupiter
grep -Fq '"model_family": "jupiter_lcd"' "${TEST_ROOT}/jupiter/manifest.json"
grep -Fq '"model_class": "lcd"' "${TEST_ROOT}/jupiter/manifest.json"
grep -Fq '"lcd_backlight_semantics": {"state": "supported_and_readable"}' "${TEST_ROOT}/jupiter/manifest.json"

make_fixture unknown 'Example Vendor' 'private-user@example.com'
run_fixture unknown
grep -Fq '"vendor": "non_valve_or_unknown"' "${TEST_ROOT}/unknown/manifest.json"
grep -Fq '"product": "unknown"' "${TEST_ROOT}/unknown/manifest.json"
if grep -Fq 'private-user@example.com' "${TEST_ROOT}/unknown/manifest.json"; then
    echo "Manifest exposed non-allowlisted DMI data." >&2
    exit 1
fi

make_fixture spoofed_valve Valve 'Galileo-private-user@example.com'
run_fixture spoofed_valve
grep -Fq '"model_family": "unknown"' "${TEST_ROOT}/spoofed_valve/manifest.json"
if grep -Fq 'private-user' "${TEST_ROOT}/spoofed_valve/manifest.json"; then
    echo "Manifest trusted a prefix-spoofed model identity." >&2
    exit 1
fi

make_fixture inaccessible Valve Jupiter
chmod 000 "${TEST_ROOT}/inaccessible/sys/class/input"
run_fixture inaccessible
grep -Fq '"input": {"state": "supported_but_inaccessible"}' "${TEST_ROOT}/inaccessible/manifest.json"

if command -v node >/dev/null 2>&1; then
    node -e 'for (const file of process.argv.slice(1)) JSON.parse(require("fs").readFileSync(file, "utf8"));' \
        "${TEST_ROOT}/galileo/manifest.json" "${TEST_ROOT}/jupiter/manifest.json" \
        "${TEST_ROOT}/unknown/manifest.json" "${TEST_ROOT}/spoofed_valve/manifest.json" \
        "${TEST_ROOT}/inaccessible/manifest.json"
fi

echo "Capability manifest fixtures valid: Galileo, Jupiter, unknown hardware, and inaccessible evidence."
