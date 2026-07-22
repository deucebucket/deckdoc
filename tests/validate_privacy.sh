#!/usr/bin/env bash
set -euo pipefail

DECKDOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT=$(mktemp /tmp/deckdoc-redaction.XXXXXX)
cleanup() { rm -f -- "$OUTPUT"; }
trap cleanup EXIT

printf '%s\n' \
    'password=correct-horse-battery-staple' \
    'Authorization: Bearer sample-access-token' \
    'user@example.com 192.168.10.25 aa:bb:cc:dd:ee:ff' \
    'remote=2001:db8:abcd:12::99 steam=76561198012345678' \
    'UserId: 00000000000000010000000000000000' \
    'console_account=0123456789abcdef0123456789abcdef' \
    'path=/home/alice/private/save url=https://example.com/case?key=value' \
    'temp=/tmp/alice-secret.txt mounted=/mnt/family-drive/private' \
    'boot_id=12345678-1234-1234-1234-123456789abc' \
    'SSID=PrivateNetwork' \
    'normal GPU reset diagnostic line' \
    | "${DECKDOC_DIR}/lib/deckdoc-redact.sh" > "$OUTPUT"

for forbidden in correct-horse sample-access-token user@example.com 192.168.10.25 2001:db8 aa:bb:cc:dd:ee:ff alice family-drive PrivateNetwork 12345678 76561198012345678 0000000000000001 0123456789abcdef; do
    if grep -Fq "$forbidden" "$OUTPUT"; then
        echo "Public-safe filter retained forbidden fixture: ${forbidden}" >&2
        exit 1
    fi
done
grep -Fq 'normal GPU reset diagnostic line' "$OUTPUT"
grep -Fq '<email-1>' "$OUTPUT"
grep -Fq '<ip-1>' "$OUTPUT"
grep -Fq '<mac-1>' "$OUTPUT"
grep -Fq '<id-1>' "$OUTPUT"
grep -Fq '<account-1>' "$OUTPUT"

grep -Fq 'run_module "${MODULES_DIR}/gpu_apu.sh"' "${DECKDOC_DIR}/deckdoc.sh"
grep -Fq '| "$REDACTOR" > "${temp_dir}/journal.log"' "${DECKDOC_DIR}/probe/deckdoc-probe.sh"
grep -Fq '| "$REDACTOR" > "${CASE_DIR}/installed-journals.log"' "${DECKDOC_DIR}/bootprobe/deckdoc-rescue-collect.sh"
if grep -RqiE 'private but unredacted|privacy=private-unredacted|capture_scope=local-private-unredacted' \
    "${DECKDOC_DIR}/README.md" "${DECKDOC_DIR}/docs" "${DECKDOC_DIR}/probe" "${DECKDOC_DIR}/bootprobe"; then
    echo "Documentation or capture metadata still promises unredacted output." >&2
    exit 1
fi
if grep -Rqs 'DECKDOC_DECK_SUDO_PASSWORD' \
    "${DECKDOC_DIR}/deckdoc.sh" "${DECKDOC_DIR}/modules" "${DECKDOC_DIR}/probe" \
    "${DECKDOC_DIR}/bootprobe" "${DECKDOC_DIR}/lib"; then
    echo "A collector references the local development sudo credential." >&2
    exit 1
fi

echo "Public-safe logging contract valid: credentials and common identities are removed before disk write."
