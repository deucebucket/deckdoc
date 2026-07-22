#!/usr/bin/env bash
set -uo pipefail

echo "[MODULE: Continuous Incident Probe]"
sync

SESSION_USER="${DECKDOC_SESSION_USER:-${SUDO_USER:-$(id -un)}}"
SESSION_HOME=$(getent passwd "$SESSION_USER" 2>/dev/null | cut -d: -f6)
USER_STATE="${XDG_STATE_HOME:-${SESSION_HOME}/.local/state}/deckdoc-probe"
JOURNAL_LINES="${DECKDOC_PROBE_JOURNAL_LINES:-250}"
case "$JOURNAL_LINES" in ''|*[!0-9]*) JOURNAL_LINES=250 ;; esac

if [ -n "${DECKDOC_PROBE_STATE_DIR:-}" ]; then
    STATE_DIR="$DECKDOC_PROBE_STATE_DIR"
elif [ -d /var/lib/deckdoc-probe ]; then
    STATE_DIR=/var/lib/deckdoc-probe
else
    STATE_DIR="$USER_STATE"
fi
EVENTS_DIR="${STATE_DIR}/events"

echo "--- Probe availability ---"
echo "  State directory: ${STATE_DIR}"
if [ ! -d "$EVENTS_DIR" ]; then
    echo "  Probe not installed or no probe state is available."
    sync
    exit 0
fi
if [ ! -r "$EVENTS_DIR" ]; then
    echo "  INACCESSIBLE: Probe events exist but this report cannot read them. Run the report with sudo."
    sync
    exit 0
fi

EVENT_COUNT=$(find "$EVENTS_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*_*' 2>/dev/null | wc -l)
echo "  Stored incidents: ${EVENT_COUNT}"
if command -v systemctl >/dev/null 2>&1; then
    ACTIVE=$(systemctl is-active deckdoc-probe.service 2>/dev/null || true)
    echo "  System probe service: ${ACTIVE:-unknown}"
fi

LATEST=""
if [ -L "${STATE_DIR}/latest" ]; then
    LATEST=$(readlink -f "${STATE_DIR}/latest" 2>/dev/null || true)
fi
if [ -z "$LATEST" ]; then
    LATEST=$(find "$EVENTS_DIR" -mindepth 1 -maxdepth 1 -type d -name '20*_*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
fi
case "$LATEST" in
    "${EVENTS_DIR}"/20*_*) ;;
    '') echo "  No captured incidents."; sync; exit 0 ;;
    *) echo "  INACCESSIBLE: Latest incident path failed validation."; sync; exit 0 ;;
esac
if [ ! -d "$LATEST" ]; then
    echo "  Latest incident directory is missing."
    sync
    exit 0
fi

echo "--- Latest incident metadata ---"
if [ -r "${LATEST}/metadata.txt" ]; then cat "${LATEST}/metadata.txt"; else echo "  Metadata inaccessible."; fi
echo "--- Triggering record ---"
if [ -r "${LATEST}/trigger.log" ]; then cat "${LATEST}/trigger.log"; else echo "  Trigger inaccessible."; fi
echo "--- Volatile state captured at incident ---"
if [ -r "${LATEST}/state.log" ]; then cat "${LATEST}/state.log"; else echo "  State snapshot inaccessible."; fi
echo "--- Incident journal tail (up to ${JOURNAL_LINES} lines) ---"
if [ -r "${LATEST}/journal.log" ]; then
    tail -n "$JOURNAL_LINES" "${LATEST}/journal.log"
else
    echo "  Journal window inaccessible."
fi
echo "  PRIVACY: Probe captures are unredacted. Review network, username, path, serial, and command-line data before sharing."
sync
