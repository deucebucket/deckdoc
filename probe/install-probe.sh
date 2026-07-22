#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/var/lib/deckdoc-probe"
BIN_DIR="${STATE_DIR}/bin"
UNIT_PATH="/etc/systemd/system/deckdoc-probe.service"
CONFIG_PATH="/etc/deckdoc-probe.conf"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run this action with sudo." >&2
        exit 1
    fi
}

install_probe() {
    require_root
    local session_user="${SUDO_USER:-}"
    if [ "$session_user" = "root" ] || ! id "$session_user" >/dev/null 2>&1; then
        session_user=$(loginctl list-users --no-legend 2>/dev/null | awk '$2 != "root" {print $2; exit}')
    fi
    case "$session_user" in ''|*[!a-zA-Z0-9_.-]*) session_user="" ;; esac

    install -d -o root -g root -m 700 "$STATE_DIR" "$BIN_DIR"
    install -o root -g root -m 755 "${SOURCE_DIR}/deckdoc-probe.sh" "${BIN_DIR}/deckdoc-probe.sh"
    install -o root -g root -m 644 "${SOURCE_DIR}/deckdoc-probe.service" "$UNIT_PATH"
    {
        echo "DECKDOC_PROBE_STATE_DIR=${STATE_DIR}"
        echo "DECKDOC_PROBE_COOLDOWN_SECONDS=60"
        echo "DECKDOC_PROBE_PRE_SECONDS=120"
        echo "DECKDOC_PROBE_POST_SECONDS=5"
        echo "DECKDOC_PROBE_MAX_EVENTS=25"
        echo "DECKDOC_PROBE_MAX_EVENT_KIB=2048"
        if [ -n "$session_user" ]; then echo "DECKDOC_SESSION_USER=${session_user}"; fi
    } > "$CONFIG_PATH"
    chown root:root "$CONFIG_PATH"
    chmod 600 "$CONFIG_PATH"
    systemctl daemon-reload
    systemctl enable --now deckdoc-probe.service
    echo "DeckDoc probe installed and started. Captures remain private in ${STATE_DIR}/events."
}

uninstall_probe() {
    require_root
    systemctl disable --now deckdoc-probe.service 2>/dev/null || true
    if [ "$UNIT_PATH" = "/etc/systemd/system/deckdoc-probe.service" ]; then rm -f -- "$UNIT_PATH"; fi
    if [ -f "${BIN_DIR}/deckdoc-probe.sh" ]; then rm -f -- "${BIN_DIR}/deckdoc-probe.sh"; fi
    if [ -d "$BIN_DIR" ]; then rmdir "$BIN_DIR" 2>/dev/null || true; fi
    if [ "$CONFIG_PATH" = "/etc/deckdoc-probe.conf" ]; then rm -f -- "$CONFIG_PATH"; fi
    systemctl daemon-reload
    echo "DeckDoc probe stopped and uninstalled. Existing incident captures were preserved in ${STATE_DIR}."
}

purge_captures() {
    require_root
    if systemctl is-active --quiet deckdoc-probe.service; then
        echo "Uninstall or stop the probe before purging captures." >&2
        exit 1
    fi
    case "$STATE_DIR" in /var/lib/deckdoc-probe) rm -rf -- "$STATE_DIR" ;; *) exit 1 ;; esac
    echo "DeckDoc probe captures permanently removed from ${STATE_DIR}."
}

case "$ACTION" in
    install) install_probe ;;
    uninstall) uninstall_probe ;;
    purge) purge_captures ;;
    status) systemctl status deckdoc-probe.service --no-pager ;;
    *) echo "Usage: sudo ./probe/install-probe.sh {install|status|uninstall|purge}" >&2; exit 2 ;;
esac
