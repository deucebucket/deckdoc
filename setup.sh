#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${DECKDOC_DIR}/logs"

mkdir -p "${LOG_DIR}"
chmod 755 "${DECKDOC_DIR}/deckdoc.sh"
chmod 755 "${DECKDOC_DIR}"/modules/*.sh
chmod 755 "${DECKDOC_DIR}"/tests/*.sh

echo "[*] DeckDoc v1.0.0 environment scaffolded successfully at ${DECKDOC_DIR}"
sync
