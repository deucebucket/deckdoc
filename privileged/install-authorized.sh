#!/usr/bin/env bash
set -euo pipefail

readonly ACTION="${1:-status}"
readonly SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INSTALL_ROOT="/var/lib/deckdoc-authorized"
readonly APP_DIR="${INSTALL_ROOT}/app"
readonly BIN_DIR="${INSTALL_ROOT}/bin"
readonly BROKER="${BIN_DIR}/deckdoc-authorized"
readonly VERSION="$(<"${SOURCE_DIR}/VERSION")"

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This action needs one interactive sudo approval." >&2
        echo "Run: sudo ./privileged/install-authorized.sh ${ACTION}" >&2
        exit 1
    fi
}

resolve_user() {
    local candidate="${SUDO_USER:-}"
    if [ "$candidate" = "root" ] || [ -z "$candidate" ]; then
        candidate="${2:-}"
    fi
    case "$candidate" in
        ''|*[!a-zA-Z0-9_.-]*)
            echo "Could not safely identify the user to authorize." >&2
            exit 1
            ;;
    esac
    if ! id "$candidate" >/dev/null 2>&1; then
        echo "Unknown authorization user: $candidate" >&2
        exit 1
    fi
    printf '%s\n' "$candidate"
}

sudoers_path_for() {
    printf '/etc/sudoers.d/deckdoc-authorized-%s\n' "$1"
}

install_authorization() {
    require_root
    local auth_user sudoers_path sudoers_tmp
    auth_user=$(resolve_user "$@")
    sudoers_path=$(sudoers_path_for "$auth_user")
    sudoers_tmp=$(mktemp /tmp/deckdoc-sudoers.XXXXXXXX)
    trap 'rm -f -- "$sudoers_tmp"' EXIT HUP INT TERM

    install -d -o root -g root -m 755 "$INSTALL_ROOT" "$APP_DIR" "$BIN_DIR"
    install -o root -g root -m 755 "${SOURCE_DIR}/deckdoc.sh" "${APP_DIR}/deckdoc.sh"
    install -d -o root -g root -m 755 "${APP_DIR}/modules"
    find "${APP_DIR}/modules" -maxdepth 1 -type f -name '*.sh' -delete
    local module
    for module in "${SOURCE_DIR}"/modules/*.sh; do
        install -o root -g root -m 755 "$module" "${APP_DIR}/modules/$(basename "$module")"
    done
    install -o root -g root -m 755 "${SOURCE_DIR}/privileged/deckdoc-authorized" "$BROKER"
    printf '%s\n' "$VERSION" > "${INSTALL_ROOT}/VERSION"
    chown root:root "${INSTALL_ROOT}/VERSION"
    chmod 644 "${INSTALL_ROOT}/VERSION"

    (
        cd "$INSTALL_ROOT"
        find app bin -type f -print0 | sort -z | xargs -0 sha256sum
        sha256sum VERSION
    ) > "${INSTALL_ROOT}/MANIFEST.sha256"
    chown root:root "${INSTALL_ROOT}/MANIFEST.sha256"
    chmod 644 "${INSTALL_ROOT}/MANIFEST.sha256"

    {
        echo "# DeckDoc read-only diagnostic authorization for ${auth_user}"
        echo "${auth_user} ALL=(root) NOPASSWD: NOSETENV: ${BROKER} report"
        echo "${auth_user} ALL=(root) NOPASSWD: NOSETENV: ${BROKER} report-display-black"
        echo "${auth_user} ALL=(root) NOPASSWD: NOSETENV: ${BROKER} probe-capture"
        echo "${auth_user} ALL=(root) NOPASSWD: NOSETENV: ${BROKER} probe-status"
        echo "${auth_user} ALL=(root) NOPASSWD: NOSETENV: ${BROKER} version"
    } > "$sudoers_tmp"
    chmod 440 "$sudoers_tmp"
    visudo -cf "$sudoers_tmp" >/dev/null
    install -o root -g root -m 440 "$sudoers_tmp" "$sudoers_path"

    echo "DeckDoc read-only diagnostics authorized for ${auth_user}."
    echo "Installed root-owned snapshot: ${VERSION}"
    echo "No password, root shell, arbitrary command, remediation, or arbitrary output path was authorized."
}

show_status() {
    local auth_user sudoers_path
    auth_user="${SUDO_USER:-${USER:-}}"
    case "$auth_user" in ''|*[!a-zA-Z0-9_.-]*) auth_user="" ;; esac
    if [ -r "${INSTALL_ROOT}/VERSION" ]; then
        echo "Installed snapshot: $(cat "${INSTALL_ROOT}/VERSION")"
    else
        echo "Installed snapshot: none"
    fi
    if [ -n "$auth_user" ]; then
        sudoers_path=$(sudoers_path_for "$auth_user")
        if [ -r "$sudoers_path" ]; then
            echo "Authorization for ${auth_user}: installed"
        else
            echo "Authorization for ${auth_user}: not installed"
        fi
    fi
}

uninstall_authorization() {
    require_root
    local auth_user sudoers_path
    auth_user=$(resolve_user "$@")
    sudoers_path=$(sudoers_path_for "$auth_user")
    case "$sudoers_path" in
        /etc/sudoers.d/deckdoc-authorized-*) rm -f -- "$sudoers_path" ;;
        *) exit 1 ;;
    esac
    echo "DeckDoc passwordless diagnostic authorization removed for ${auth_user}."
    echo "The root-owned snapshot remains until explicitly purged."
}

purge_snapshot() {
    require_root
    if find /etc/sudoers.d -maxdepth 1 -type f -name 'deckdoc-authorized-*' -print -quit 2>/dev/null | grep -q .; then
        echo "Remove every DeckDoc authorization before purging the snapshot." >&2
        exit 1
    fi
    case "$INSTALL_ROOT" in
        /var/lib/deckdoc-authorized) rm -rf -- "$INSTALL_ROOT" ;;
        *) exit 1 ;;
    esac
    echo "DeckDoc authorized snapshot removed."
}

case "$ACTION" in
    install) install_authorization "$@" ;;
    status) show_status ;;
    uninstall) uninstall_authorization "$@" ;;
    purge) purge_snapshot ;;
    *)
        echo "Usage: sudo ./privileged/install-authorized.sh {install|status|uninstall|purge}" >&2
        exit 2
        ;;
esac
