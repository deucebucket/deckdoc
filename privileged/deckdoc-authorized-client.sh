#!/usr/bin/env bash
set -euo pipefail

readonly BROKER="/var/lib/deckdoc-authorized/bin/deckdoc-authorized"
readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LOG_DIR="${PROJECT_DIR}/logs"
ACTION="${1:-status}"

authorized() {
    if ! sudo -n "$BROKER" version >/dev/null 2>&1; then
        echo "DeckDoc diagnostics are not authorized for this user." >&2
        echo "Approve them once with: sudo ./privileged/install-authorized.sh install" >&2
        exit 1
    fi
}

save_report() {
    local broker_action="$1"
    local report_path temporary
    mkdir -p "$LOG_DIR"
    chmod 700 "$LOG_DIR" 2>/dev/null || true
    report_path="${LOG_DIR}/deckdoc_authorized_report_$(date +%s).log"
    temporary=$(mktemp "${LOG_DIR}/.authorized-report.XXXXXXXX")
    trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
    if ! sudo -n "$BROKER" "$broker_action" > "$temporary"; then
        echo "Authorized diagnostic collection failed." >&2
        exit 1
    fi
    chmod 600 "$temporary"
    mv -- "$temporary" "$report_path"
    trap - EXIT HUP INT TERM
    echo "$report_path"
}

case "$ACTION" in
    report)
        [ "$#" -eq 1 ] || exit 2
        authorized
        save_report report
        ;;
    report-display-black)
        [ "$#" -eq 1 ] || exit 2
        authorized
        save_report report-display-black
        ;;
    probe-capture)
        [ "$#" -eq 1 ] || exit 2
        authorized
        sudo -n "$BROKER" probe-capture
        ;;
    status)
        [ "$#" -eq 1 ] || exit 2
        authorized
        echo "Authorized snapshot: $(sudo -n "$BROKER" version)"
        if sudo -n "$BROKER" probe-status >/dev/null 2>&1; then
            echo "Continuous probe: active"
        else
            echo "Continuous probe: not active"
        fi
        ;;
    *)
        echo "Usage: ./privileged/deckdoc-authorized-client.sh {report|report-display-black|probe-capture|status}" >&2
        exit 2
        ;;
esac
