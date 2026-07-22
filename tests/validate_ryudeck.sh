#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/deckdoc-ryudeck-test.XXXXXX)"
cleanup() { rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT

run_fixture() {
    local name="$1" active="$2"
    local output="${TEST_ROOT}/${name}.out"
    DECKDOC_SESSION_HOME="${TEST_ROOT}/${name}/home" \
    DECKDOC_RYUDECK_CONFIG_DIR="${TEST_ROOT}/${name}/config" \
    DECKDOC_RYUDECK_INSTALL_DIR="${TEST_ROOT}/${name}/install" \
    DECKDOC_RYUDECK_ACTIVE="$active" \
        "${DECKDOC_DIR}/modules/ryudeck_app.sh" > "$output"
    printf '%s' "$output"
}

mkdir -p "${TEST_ROOT}/absent/home"
ABSENT=$(run_fixture absent 0)
grep -q 'RYUDECK_SIGNATURE: NOT_INSTALLED_OR_NO_PROFILE' "$ABSENT"

STALL_ROOT="${TEST_ROOT}/stall"
mkdir -p "$STALL_ROOT/install/bin2" "$STALL_ROOT/config/logs" \
    "$STALL_ROOT/config/bis/system/Contents/registered" \
    "$STALL_ROOT/config/games/0123456789abcdef/cache"
touch "$STALL_ROOT/install/bin2/Ryudeck"
chmod +x "$STALL_ROOT/install/bin2/Ryudeck"
touch "$STALL_ROOT/config/bis/system/Contents/registered/content.nca"
{
    printf '%s\n' \
        'Application LoadGuestApplication: Using Firmware Version: 18.1.0' \
        'E2E stage=emulation_running' \
        'Loaded 59943 translated PTC functions' \
        'shader cache loaded from /home/alice/private/0123456789abcdef' \
        'UserId: 00000000000000010000000000000000'
    for _ in $(seq 1 35); do
        echo 'GPU.MainThread Application UpdateStatus: RYUDECK FPS: 0.0 fps Infinityms FIFO 0%'
    done
} > "$STALL_ROOT/config/logs/runtime.log"
STALL=$(run_fixture stall 1)
grep -q 'RYUDECK_SIGNATURE: GUEST_STARTUP_STALL' "$STALL"
grep -q 'RYUDECK_SIGNATURE: STALE_TITLE_CACHE_SUSPECTED' "$STALL"
grep -q 'Runtime firmware version: 18.1.0' "$STALL"
if grep -Eq 'alice|0123456789abcdef|0000000000000001|runtime\.log|/home/' "$STALL"; then
    echo 'RyuDeck module leaked a title, identity, path, or filename fixture.' >&2
    exit 1
fi

RENDER_ROOT="${TEST_ROOT}/render"
mkdir -p "$RENDER_ROOT/install/bin2" "$RENDER_ROOT/config/logs"
touch "$RENDER_ROOT/install/bin2/Ryudeck"
chmod +x "$RENDER_ROOT/install/bin2/Ryudeck"
{
    echo 'E2E stage=emulation_running'
    echo 'GPU.MainThread Application UpdateStatus: RYUDECK FPS: 0.0 fps Infinityms FIFO 0%'
    echo 'GPU.MainThread Application UpdateStatus: RYUDECK FPS: 58.7 fps 17.0ms FIFO 80%'
} > "$RENDER_ROOT/config/logs/runtime.log"
RENDER=$(run_fixture render 1)
grep -q 'RYUDECK_SIGNATURE: RENDERING' "$RENDER"

FATAL_ROOT="${TEST_ROOT}/fatal"
mkdir -p "$FATAL_ROOT/install/bin2" "$FATAL_ROOT/config/logs"
touch "$FATAL_ROOT/install/bin2/Ryudeck"
chmod +x "$FATAL_ROOT/install/bin2/Ryudeck"
printf '%s\n' 'E2E stage=emulation_running' 'Vulkan: VK_ERROR_DEVICE_LOST' > "$FATAL_ROOT/config/logs/runtime.log"
FATAL=$(run_fixture fatal 1)
grep -q 'RYUDECK_SIGNATURE: RENDERER_OR_PROCESS_FATAL' "$FATAL"

echo 'RyuDeck app adapter valid: absent, startup-stall, stale-cache, rendering, fatal, and privacy fixtures pass.'
