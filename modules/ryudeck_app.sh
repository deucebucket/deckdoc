#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: RyuDeck Application Health]"
sync

SESSION_USER="${DECKDOC_SESSION_USER:-${SUDO_USER:-$(id -un)}}"
if [ "$SESSION_USER" = "root" ]; then
    SESSION_USER=$(loginctl list-users --no-legend 2>/dev/null | awk '$2 != "root" { print $2; exit }')
fi
SESSION_HOME="${DECKDOC_SESSION_HOME:-$(getent passwd "$SESSION_USER" 2>/dev/null | cut -d: -f6)}"
if [ -z "$SESSION_HOME" ]; then
    SESSION_HOME="${HOME:-/nonexistent}"
fi

CONFIG_DIR="${DECKDOC_RYUDECK_CONFIG_DIR:-${SESSION_HOME}/.config/Ryudeck}"
INSTALL_DIR="${DECKDOC_RYUDECK_INSTALL_DIR:-${SESSION_HOME}/.local/share/ryudeck}"
TAIL_BYTES="${DECKDOC_RYUDECK_TAIL_BYTES:-8388608}"
case "$TAIL_BYTES" in ''|*[!0-9]*) TAIL_BYTES=8388608 ;; esac

if [ -x "${INSTALL_DIR}/Ryudeck.sh" ] || [ -x "${INSTALL_DIR}/bin2/Ryudeck" ] || \
   [ -f "${INSTALL_DIR}/bin2/Ryudeck.dll" ]; then
    echo "  Installation: detected"
else
    echo "  Installation: not detected"
fi

if [ ! -d "$CONFIG_DIR" ]; then
    echo "  Configuration: not detected"
    echo "  RYUDECK_SIGNATURE: NOT_INSTALLED_OR_NO_PROFILE"
    echo "  Public-safe scope: no application logs were found; no paths, titles, IDs, or arguments are emitted."
    sync
    exit 0
fi

echo "  Configuration: detected"

if [ -n "${DECKDOC_RYUDECK_ACTIVE:-}" ]; then
    case "$DECKDOC_RYUDECK_ACTIVE" in 1|true|yes) ACTIVE=1 ;; *) ACTIVE=0 ;; esac
else
    ACTIVE=0
    for proc_dir in /proc/[0-9]*; do
        [ -r "${proc_dir}/cmdline" ] || continue
        CMDLINE=$(tr '\0' ' ' < "${proc_dir}/cmdline" 2>/dev/null || true)
        case "$CMDLINE" in
            *"${INSTALL_DIR}/bin2/Ryudeck"*|*"${INSTALL_DIR}/bin2/Ryudeck.dll"*)
                ACTIVE=1
                break
                ;;
        esac
    done
fi
echo "  Runtime active: $([ "$ACTIVE" -eq 1 ] && echo yes || echo no)"

FIRMWARE_DIR="${CONFIG_DIR}/bis/system/Contents/registered"
if [ -d "$FIRMWARE_DIR" ]; then
    FIRMWARE_FILES=$(find "$FIRMWARE_DIR" -type f 2>/dev/null | wc -l)
    echo "  Firmware content files: ${FIRMWARE_FILES}"
else
    FIRMWARE_FILES=0
    echo "  Firmware content: not detected"
fi

TITLE_CACHE_COUNT=0
if [ -d "${CONFIG_DIR}/games" ]; then
    TITLE_CACHE_COUNT=$(find "${CONFIG_DIR}/games" -mindepth 2 -maxdepth 2 -type d -name cache 2>/dev/null | wc -l)
fi
echo "  Per-title caches: ${TITLE_CACHE_COUNT}"

LATEST_LOG=""
# Prefer a real title-runtime log. A newer library/UI log can contain firmware
# initialization without ever launching a guest and must not hide the active title.
for selection_pass in runtime firmware_fallback; do
    while IFS= read -r candidate; do
        [ -f "$candidate" ] || continue
        if [ "$selection_pass" = "runtime" ]; then
            PATTERN='RYUDECK FPS:|emulation_running'
        else
            PATTERN='Using Firmware Version:'
        fi
        if { head -c 2097152 "$candidate" 2>/dev/null; tail -c "$TAIL_BYTES" "$candidate" 2>/dev/null; } | \
           tr -d '\000' | grep -E "$PATTERN" >/dev/null; then
            LATEST_LOG="$candidate"
            break
        fi
    done < <(find "$CONFIG_DIR" -type f -name '*.log' ! -iname '*wrapper*' -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr | head -30 | cut -d' ' -f2-)
    [ -n "$LATEST_LOG" ] && break
done

if [ -z "$LATEST_LOG" ]; then
    echo "  Runtime evidence: no structured RyuDeck title log found"
    if [ "$ACTIVE" -eq 1 ]; then
        echo "  RYUDECK_SIGNATURE: ACTIVE_WITHOUT_RUNTIME_LOG"
    else
        echo "  RYUDECK_SIGNATURE: NO_RUNTIME_HISTORY"
    fi
    echo "  Public-safe scope: titles, title IDs, paths, filenames, launch arguments, account data, and raw lines are omitted."
    sync
    exit 0
fi

LOG_BYTES=$(stat -c %s "$LATEST_LOG" 2>/dev/null || echo 0)
LOG_MTIME=$(stat -c %Y "$LATEST_LOG" 2>/dev/null || echo 0)
NOW=$(date +%s)
case "$LOG_MTIME" in ''|*[!0-9]*) LOG_AGE=-1 ;; *) LOG_AGE=$((NOW - LOG_MTIME));; esac
echo "  Latest runtime log bytes: ${LOG_BYTES}"
echo "  Latest runtime evidence age seconds: ${LOG_AGE}"

HEADER=$(head -c 2097152 "$LATEST_LOG" 2>/dev/null | tr -d '\000' || true)
TAIL=$(tail -c "$TAIL_BYTES" "$LATEST_LOG" 2>/dev/null | tr -d '\000' || true)

FIRMWARE_VERSION=$(printf '%s\n' "$HEADER" | sed -nE 's/.*Using Firmware Version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | tail -1)
if [ -n "$FIRMWARE_VERSION" ]; then
    echo "  Runtime firmware version: ${FIRMWARE_VERSION}"
else
    echo "  Runtime firmware version: not observed"
fi

if printf '%s\n%s\n' "$HEADER" "$TAIL" | grep -q 'emulation_running'; then
    EMULATION_RUNNING=1
else
    EMULATION_RUNNING=0
fi
echo "  Emulation-running stage reached: $([ "$EMULATION_RUNNING" -eq 1 ] && echo yes || echo no)"

ZERO_FPS=$(printf '%s\n' "$TAIL" | grep -cE 'RYUDECK FPS: 0\.0 fps' || true)
NONZERO_FPS=$(printf '%s\n' "$TAIL" | grep -cE 'RYUDECK FPS: ([1-9][0-9]*|0\.[1-9][0-9]*)\.?[0-9]* fps' || true)
LATEST_FPS=$(printf '%s\n' "$TAIL" | sed -nE 's/.*RYUDECK FPS: ([0-9]+\.[0-9]+) fps.*/\1/p' | tail -1)
echo "  Recent zero-FPS samples: ${ZERO_FPS}"
echo "  Recent nonzero-FPS samples: ${NONZERO_FPS}"
echo "  Latest FPS sample: ${LATEST_FPS:-not observed}"

PIPELINE_MISSES=$(printf '%s\n' "$TAIL" | grep -c 'Background pipeline compile missed' || true)
SCHEDULER_WARNINGS=$(printf '%s\n' "$TAIL" | grep -cE 'realtime-sched FAILED|SetRealtimeScheduler.*EPERM' || true)
DEVICE_LOSS=$(printf '%s\n' "$TAIL" | grep -ciE 'device lost|VK_ERROR_DEVICE_LOST' || true)
OUT_OF_MEMORY=$(printf '%s\n' "$TAIL" | grep -ciE 'out of (device |host )?memory|VK_ERROR_OUT_OF.*MEMORY' || true)
FATAL_MARKERS=$(printf '%s\n' "$TAIL" | grep -ciE 'unhandled exception|guest.*crash|segmentation fault|core dumped' || true)
PTC_SIGNALS=$(printf '%s\n%s\n' "$HEADER" "$TAIL" | grep -ciE 'PTC.*(load|cache)|translated.*functions' || true)
SHADER_SIGNALS=$(printf '%s\n%s\n' "$HEADER" "$TAIL" | grep -ciE 'shader.*(load|cache|compile)' || true)
CONTROLLER_SIGNALS=$(printf '%s\n%s\n' "$HEADER" "$TAIL" | grep -ciE 'controller.*(open|connected)|input heartbeat' || true)

echo "  Background pipeline misses: ${PIPELINE_MISSES}"
echo "  Realtime scheduler warnings: ${SCHEDULER_WARNINGS} (performance context; not a launch-failure verdict)"
echo "  Device-loss markers: ${DEVICE_LOSS}"
echo "  Out-of-memory markers: ${OUT_OF_MEMORY}"
echo "  Fatal process/guest markers: ${FATAL_MARKERS}"
echo "  PTC/cache load signals: ${PTC_SIGNALS}"
echo "  Shader/cache signals: ${SHADER_SIGNALS}"
echo "  Controller/input-alive signals: ${CONTROLLER_SIGNALS}"

if [ "$DEVICE_LOSS" -gt 0 ] || [ "$OUT_OF_MEMORY" -gt 0 ] || [ "$FATAL_MARKERS" -gt 0 ]; then
    echo "  RYUDECK_SIGNATURE: RENDERER_OR_PROCESS_FATAL"
    echo "  Interpretation: the app recorded a fatal renderer, memory, guest, or process marker; correlate with GPU and coredump modules."
elif [ "$ACTIVE" -eq 1 ] && [ "$LOG_AGE" -gt 120 ]; then
    echo "  RYUDECK_SIGNATURE: ACTIVE_RUNTIME_LOG_STALLED"
    echo "  Interpretation: the process remains present but its structured runtime evidence stopped advancing."
elif [ "$ACTIVE" -eq 1 ] && [ "$EMULATION_RUNNING" -eq 1 ] && \
     [ "$NONZERO_FPS" -eq 0 ] && [ "$ZERO_FPS" -ge 30 ]; then
    echo "  RYUDECK_SIGNATURE: GUEST_STARTUP_STALL"
    echo "  Interpretation: host initialization completed, but the guest produced no frames for at least 30 samples."
    if [ "$TITLE_CACHE_COUNT" -gt 0 ] && { [ "$PTC_SIGNALS" -gt 0 ] || [ "$SHADER_SIGNALS" -gt 0 ]; }; then
        echo "  RYUDECK_SIGNATURE: STALE_TITLE_CACHE_SUSPECTED"
        echo "  Safe A/B: close RyuDeck, preserve the affected title cache as a backup, then retry with an empty cache. Do not delete saves or firmware."
    fi
elif [ "$ACTIVE" -eq 1 ] && [ -n "$LATEST_FPS" ] && \
     awk -v fps="$LATEST_FPS" 'BEGIN { exit !(fps > 0) }'; then
    echo "  RYUDECK_SIGNATURE: RENDERING"
    if [ "$PIPELINE_MISSES" -ge 20 ]; then
        echo "  NOTE: Rendering is active while a new or invalidated shader cache is rebuilding; short-lived stutter is expected."
    fi
elif [ "$ACTIVE" -eq 1 ] && [ "$EMULATION_RUNNING" -eq 1 ]; then
    echo "  RYUDECK_SIGNATURE: RUNTIME_INDETERMINATE"
    echo "  Interpretation: emulation started, but the bounded log window does not prove either a sustained stall or healthy rendering."
else
    echo "  RYUDECK_SIGNATURE: INACTIVE_HISTORY_ONLY"
    echo "  Interpretation: evidence is historical because no production RyuDeck runtime is currently active."
fi

echo "  Public-safe scope: titles, title IDs, paths, filenames, launch arguments, account data, controller IDs, and raw log lines are omitted."
sync
