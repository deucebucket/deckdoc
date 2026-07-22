#!/usr/bin/env bash
set -uo pipefail

umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "${SCRIPT_DIR}/deckdoc-redact.sh" ]; then
    REDACTOR="${SCRIPT_DIR}/deckdoc-redact.sh"
else
    REDACTOR="${SCRIPT_DIR}/../lib/deckdoc-redact.sh"
fi
if [ ! -x "$REDACTOR" ]; then
    echo "DeckDoc public-safe output filter is missing; refusing capture." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    DEFAULT_STATE_DIR="/var/lib/deckdoc-probe"
else
    DEFAULT_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/deckdoc-probe"
fi

STATE_DIR="${DECKDOC_PROBE_STATE_DIR:-$DEFAULT_STATE_DIR}"
EVENTS_DIR="${STATE_DIR}/events"
COOLDOWN_SECONDS="${DECKDOC_PROBE_COOLDOWN_SECONDS:-60}"
PRE_SECONDS="${DECKDOC_PROBE_PRE_SECONDS:-120}"
POST_SECONDS="${DECKDOC_PROBE_POST_SECONDS:-5}"
MAX_EVENTS="${DECKDOC_PROBE_MAX_EVENTS:-25}"
MAX_EVENT_KIB="${DECKDOC_PROBE_MAX_EVENT_KIB:-2048}"
SESSION_USER="${DECKDOC_SESSION_USER:-${SUDO_USER:-}}"
CATEGORY=""

valid_uint() {
    case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

for value in "$COOLDOWN_SECONDS" "$PRE_SECONDS" "$POST_SECONDS" "$MAX_EVENTS" "$MAX_EVENT_KIB"; do
    if ! valid_uint "$value"; then
        echo "Invalid non-negative probe limit: ${value}" >&2
        exit 2
    fi
done
if [ "$MAX_EVENTS" -lt 1 ] || [ "$MAX_EVENT_KIB" -lt 64 ]; then
    echo "DECKDOC_PROBE_MAX_EVENTS must be at least 1 and MAX_EVENT_KIB at least 64." >&2
    exit 2
fi

ensure_state() {
    mkdir -p "$EVENTS_DIR" "${STATE_DIR}/cooldowns"
    chmod 700 "$STATE_DIR" "$EVENTS_DIR" "${STATE_DIR}/cooldowns" 2>/dev/null || true
}

# Sets CATEGORY without spawning grep/awk for every journal line. The watcher is
# otherwise blocked in journalctl and consumes no polling CPU while the system is quiet.
classify_line() {
    local line="${1,,}"
    CATEGORY=""
    if [[ "$line" =~ amdgpu.*(job.*timed|ring.*timeout|page[[:space:]]fault|gpu[[:space:]]reset|vram[[:space:]]is[[:space:]]lost) ]]; then
        CATEGORY="gpu"
    elif [[ "$line" =~ (drm|amdgpu).*(flip_done.*timed|link.*fail|atomic.*fail|edid.*fail) ]]; then
        CATEGORY="display"
    elif [[ "$line" =~ (snd_sof|sof-audio|dsp).*(panic|ipc.*-22|ipc.*timed|restore.*fail|hw[[:space:]]lock.*fail) ]]; then
        CATEGORY="audio"
    elif [[ "$line" =~ (ath11k|ath12k|iwlwifi|rtw_?88|b43|brcmfmac).*(firmware.*crash|fail|error|timeout) ]]; then
        CATEGORY="wireless"
    elif [[ "$line" =~ (nvme|mmc|sdhci|ext4-fs|btrfs).*(i/o[[:space:]]error|critical[[:space:]]warning|reset.*fail|timeout|corrupt|read-only|error) ]]; then
        CATEGORY="storage"
    elif [[ "$line" =~ (oom-killer|out[[:space:]]of[[:space:]]memory|page[[:space:]]allocation[[:space:]]failure) ]]; then
        CATEGORY="memory"
    elif [[ "$line" =~ (critical[[:space:]]temperature|thermal.*trip|fan.*(fail|error|0[[:space:]]rpm)) ]]; then
        CATEGORY="thermal"
    elif [[ "$line" =~ (gamescope|steamwebhelper|mangoapp).*(segfault|sigsegv|sigabrt|core[[:space:]]dump|aborted|failed[[:space:]]with[[:space:]]result) ]]; then
        CATEGORY="session"
    elif [[ "$line" =~ (pm:.*resume.*fail|pci_pm_resume.*fail|failed[[:space:]]to[[:space:]]resume) ]]; then
        CATEGORY="resume"
    fi
}

run_session_user() {
    if [ -z "$SESSION_USER" ] || ! id "$SESSION_USER" >/dev/null 2>&1; then
        return 1
    fi
    local session_uid
    session_uid=$(id -u "$SESSION_USER" 2>/dev/null) || return 1
    if [ "$(id -un)" = "$SESSION_USER" ]; then
        XDG_RUNTIME_DIR="/run/user/${session_uid}" "$@"
    elif command -v runuser >/dev/null 2>&1; then
        runuser -u "$SESSION_USER" -- env XDG_RUNTIME_DIR="/run/user/${session_uid}" "$@"
    else
        return 1
    fi
}

capture_state() {
    local output="$1"
    {
        echo "[DeckDoc probe volatile state]"
        echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo inaccessible)"
        echo "kernel=$(uname -r 2>/dev/null || echo inaccessible)"
        echo "uptime_seconds=$(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo inaccessible)"
        if [ -r /etc/os-release ]; then
            grep -E '^(NAME|VERSION_ID|BUILD_ID|VARIANT_ID)=' /etc/os-release || true
        fi

        echo "--- memory and pressure ---"
        grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo 2>/dev/null || true
        for pressure in /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io; do
            if [ -r "$pressure" ]; then echo "${pressure}:"; cat "$pressure"; fi
        done

        echo "--- thermal, fan, and power ---"
        for input in /sys/class/hwmon/hwmon*/temp*_input /sys/class/hwmon/hwmon*/fan*_input; do
            [ -r "$input" ] || continue
            echo "${input}=$(cat "$input" 2>/dev/null || echo inaccessible)"
        done
        for supply in /sys/class/power_supply/*; do
            [ -d "$supply" ] || continue
            echo "supply=${supply}"
            for field in status online capacity voltage_now current_now power_now charge_control_limit charge_control_end_threshold; do
                [ -r "${supply}/${field}" ] && echo "  ${field}=$(cat "${supply}/${field}" 2>/dev/null || echo inaccessible)"
            done
        done

        echo "--- DRM display state ---"
        for connector in /sys/class/drm/card*-*; do
            [ -d "$connector" ] || continue
            echo "connector=$(basename "$connector") status=$(cat "${connector}/status" 2>/dev/null || echo inaccessible) edid_bytes=$(wc -c < "${connector}/edid" 2>/dev/null || echo inaccessible)"
        done
        for backlight in /sys/class/backlight/*; do
            [ -d "$backlight" ] || continue
            echo "backlight=$(basename "$backlight") actual=$(cat "${backlight}/actual_brightness" 2>/dev/null || echo inaccessible) max=$(cat "${backlight}/max_brightness" 2>/dev/null || echo inaccessible)"
        done
        for drm_state in /sys/kernel/debug/dri/*/state; do
            [ -r "$drm_state" ] || continue
            echo "drm_state=${drm_state}"
            sed -n '1,500p' "$drm_state" 2>/dev/null || true
        done

        echo "--- device presence ---"
        for iface in /sys/class/net/*; do
            [ -d "$iface" ] || continue
            echo "net=$(basename "$iface") state=$(cat "${iface}/operstate" 2>/dev/null || echo inaccessible)"
        done
        command -v lsusb >/dev/null 2>&1 && lsusb -t 2>/dev/null || true
        command -v lsblk >/dev/null 2>&1 && lsblk -o NAME,TYPE,TRAN,SIZE,RO,FSTYPE 2>/dev/null || true

        echo "--- active session services ---"
        run_session_user systemctl --user show gamescope-session.service gamescope-mangoapp.service \
            --property=Id,ActiveState,SubState,NRestarts 2>/dev/null || echo "session service state inaccessible"

        echo "--- recent core count ---"
        if command -v coredumpctl >/dev/null 2>&1; then
            core_count=$(coredumpctl list --no-legend --no-pager --since "${PRE_SECONDS} seconds ago" 2>/dev/null | wc -l)
            echo "recent_coredumps=${core_count}"
        fi
    } 2>&1 | "$REDACTOR" > "$output"
}

prune_events() {
    local -a records
    local excess victim record
    mapfile -t records < <(find "$EVENTS_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*_*' -printf '%T@ %p\n' 2>/dev/null | sort -n)
    excess=$((${#records[@]} - MAX_EVENTS))
    while [ "$excess" -gt 0 ]; do
        record="${records[0]}"
        records=("${records[@]:1}")
        victim="${record#* }"
        case "$victim" in
            "${EVENTS_DIR}"/20*_*) rm -rf -- "$victim" ;;
            *) echo "Refusing to prune unexpected path: ${victim}" >&2; return 1 ;;
        esac
        excess=$((excess - 1))
    done
}

capture_event() {
    local category="${1:-manual}" trigger="${2:-manual capture}" event_epoch="${3:-$(date +%s)}"
    local event_id temp_dir final_dir start_epoch end_epoch journal_limit
    case "$category" in *[!a-z0-9_-]*|'') category="manual" ;; esac
    ensure_state
    event_id="$(date -u -d "@${event_epoch}" +%Y%m%dT%H%M%SZ 2>/dev/null || date -u +%Y%m%dT%H%M%SZ)_${category}_$$_${RANDOM}"
    temp_dir="${EVENTS_DIR}/.${event_id}.tmp"
    final_dir="${EVENTS_DIR}/${event_id}"
    mkdir -m 700 "$temp_dir" || return 1

    {
        echo "event_id=${event_id}"
        echo "category=${category}"
        echo "event_epoch=${event_epoch}"
        echo "event_utc=$(date -u -d "@${event_epoch}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo inaccessible)"
        echo "window_seconds_before=${PRE_SECONDS}"
        echo "window_seconds_after=${POST_SECONDS}"
        echo "capture_scope=local-public-safe-filtered"
    } | "$REDACTOR" > "${temp_dir}/metadata.txt"
    printf '%s\n' "$trigger" | "$REDACTOR" > "${temp_dir}/trigger.log"
    capture_state "${temp_dir}/state.log"

    if [ "$POST_SECONDS" -gt 0 ]; then sleep "$POST_SECONDS"; fi
    start_epoch=$((event_epoch - PRE_SECONDS))
    end_epoch=$((event_epoch + POST_SECONDS))
    journal_limit=$((MAX_EVENT_KIB * 1024))
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --since "@${start_epoch}" --until "@${end_epoch}" -o short-iso-precise --no-pager 2>/dev/null \
            | tail -c "$journal_limit" | "$REDACTOR" > "${temp_dir}/journal.log" || true
    else
        echo "journalctl unavailable" > "${temp_dir}/journal.log"
    fi

    chmod 600 "${temp_dir}"/* 2>/dev/null || true
    mv "$temp_dir" "$final_dir"
    ln -sfn "events/${event_id}" "${STATE_DIR}/latest"
    printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$category" "$event_id" >> "${STATE_DIR}/events.index"
    chmod 600 "${STATE_DIR}/events.index" 2>/dev/null || true
    prune_events
    echo "$final_dir"
}

watch_journal() {
    ensure_state
    if ! command -v journalctl >/dev/null 2>&1; then
        echo "journalctl is required for watch mode." >&2
        exit 1
    fi
    exec 9>"${STATE_DIR}/probe.lock"
    if ! flock -n 9; then
        echo "Another DeckDoc probe is already watching ${STATE_DIR}." >&2
        exit 1
    fi
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) probe_started boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo inaccessible)" \
        | "$REDACTOR" >> "${STATE_DIR}/probe.log"
    chmod 600 "${STATE_DIR}/probe.log" 2>/dev/null || true

    journalctl --follow --since now -o short-iso-precise --no-pager 2>/dev/null | while IFS= read -r line; do
        classify_line "$line"
        [ -n "$CATEGORY" ] || continue
        now=$(date +%s)
        last=0
        cooldown_file="${STATE_DIR}/cooldowns/${CATEGORY}"
        if [ -r "$cooldown_file" ]; then read -r last < "$cooldown_file" || last=0; fi
        valid_uint "$last" || last=0
        if [ $((now - last)) -lt "$COOLDOWN_SECONDS" ]; then continue; fi
        printf '%s\n' "$now" > "$cooldown_file"
        capture_event "$CATEGORY" "$line" "$now" >> "${STATE_DIR}/probe.log" 2>&1 || true
    done
}

show_status() {
    if [ ! -d "$EVENTS_DIR" ]; then
        echo "Probe state not found at ${STATE_DIR}."
        return 1
    fi
    count=$(find "$EVENTS_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*_*' 2>/dev/null | wc -l)
    echo "State directory: ${STATE_DIR}"
    echo "Stored incidents: ${count}/${MAX_EVENTS}"
    if [ -L "${STATE_DIR}/latest" ]; then
        echo "Latest incident: $(readlink -f "${STATE_DIR}/latest" 2>/dev/null || readlink "${STATE_DIR}/latest")"
    else
        echo "Latest incident: none"
    fi
}

usage() {
    cat <<'EOF'
Usage: deckdoc-probe.sh COMMAND

Commands:
  watch                 Follow journald and capture only on matched high-value errors
  capture [reason]      Create a manual incident snapshot immediately
  classify LINE         Print the category DeckDoc would assign to one log line
  status                Show private state location and retained incident count
  latest                Print the latest incident directory

The probe is read-only toward system state. Captures are public-safe filtered before being written.
Review every report before sharing because arbitrary upstream log formats can change.
EOF
}

case "${1:-}" in
    watch) watch_journal ;;
    capture) capture_event manual "manual capture" "$(date +%s)" ;;
    classify)
        classify_line "${2:-}"
        if [ -n "$CATEGORY" ]; then echo "$CATEGORY"; else echo "unmatched"; fi
        ;;
    status) show_status ;;
    latest)
        if [ -L "${STATE_DIR}/latest" ]; then readlink -f "${STATE_DIR}/latest"; else exit 1; fi
        ;;
    -h|--help|help|'') usage ;;
    *) usage >&2; exit 2 ;;
esac
