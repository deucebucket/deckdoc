#!/usr/bin/env bash
set -uo pipefail

echo "[REMEDIATION: Audio DSP (SOF)]"
sync

RC=0

# PRE_CHECK — does the trigger condition exist?
echo "--- PRE_CHECK: Scanning for SOF DSP errors ---"
PRE_TRIGGER=$(journalctl -k -b 0 --priority=err 2>/dev/null | grep -iE 'ipc tx.*failed.*-22|DSP panic' | tail -5 || true)
if [ -z "$PRE_TRIGGER" ]; then
    echo "No SOF DSP panic or IPC error -22 detected. Nothing to remediate."
    echo "REMEDIATION_OUTCOME: SKIPPED (no trigger)"
    RC=0
else
    echo "Trigger found:"
    echo "$PRE_TRIGGER"
    sync

    # BACKUP — snapshot pre-remediation state
    echo "--- BACKUP: Saving audio state before remediation ---"
    BACKUP_DIR="${DECKDOC_DIR:-/tmp/deckdoc}/remediation_backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="${BACKUP_DIR}/audio_sof_pre_$(date +%s).txt"
    {
        echo "=== Pre-Remediation Audio State ==="
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo ""
        echo "--- Loaded sound modules ---"
        lsmod | grep -iE 'snd_sof|snd_hda|snd_acp|soundcore' 2>/dev/null || echo "lsmod unavailable"
        echo ""
        echo "--- Audio cards before ---"
        cat /proc/asound/cards 2>/dev/null || echo "proc/asound unavailable"
        echo ""
        echo "--- aplay devices before ---"
        aplay -l 2>/dev/null || echo "aplay unavailable"
        echo ""
        echo "--- Triggering errors ---"
        echo "$PRE_TRIGGER"
    } > "$BACKUP_FILE"
    sync
    echo "Backup saved to $BACKUP_FILE"

    # EXECUTE — reload the SOF driver
    echo "--- EXECUTE: Reloading SOF DSP driver ---"
    if ! sudo -n true 2>/dev/null; then
        echo "FAILED: sudo not available or password required."
        echo "REMEDIATION_OUTCOME: FAILED (no sudo)"
        RC=1
    else
        echo "Removing snd_sof_amd_vangogh..."
        if sudo modprobe -r snd_sof_amd_vangogh 2>/dev/null; then
            echo "Module removed successfully."
        else
            echo "WARNING: modprobe -r failed (module may be in use). Trying forced removal..."
            sudo modprobe -rf snd_sof_amd_vangogh 2>/dev/null || true
        fi
        sync
        sleep 1

        # Record journal cursor before reinsert for precise VERIFY
        JOURNAL_CURSOR=$(journalctl -b 0 -n 0 --show-cursor 2>/dev/null | grep -o '\-\- cursor:.*' | cut -d' ' -f3 || echo "")
        echo "Journal cursor recorded for VERIFY."

        echo "Reinserting snd_sof_amd_vangogh..."
        if sudo modprobe snd_sof_amd_vangogh 2>/dev/null; then
            echo "Module inserted successfully."
        else
            echo "FAILED: Could not reinsert snd_sof_amd_vangogh."
            echo "REMEDIATION_OUTCOME: FAILED (modprobe insert failed)"
            RC=1
        fi
        sync

        # Allow DSP firmware to initialize
        sleep 2

        # VERIFY — did the fix work?
        echo "--- VERIFY: Checking audio recovery ---"

        VERIFY_PASS=0
        VERIFY_FAIL=0

        CARD_COUNT=$(aplay -l 2>/dev/null | grep -c '^card' || true)
        if [ "$CARD_COUNT" -gt 0 ]; then
            echo "PASS: $CARD_COUNT audio card(s) detected via aplay."
            VERIFY_PASS=$((VERIFY_PASS + 1))
        else
            echo "FAIL: No audio cards detected via aplay."
            VERIFY_FAIL=$((VERIFY_FAIL + 1))
        fi

        if [ -n "$JOURNAL_CURSOR" ]; then
            NEW_ERRORS=$(journalctl -b 0 --cursor="$JOURNAL_CURSOR" --priority=err 2>/dev/null | grep -iE 'snd_sof|DSP panic|ipc tx.*failed' | tail -5 || true)
        else
            NEW_ERRORS=""
        fi
        if [ -z "$NEW_ERRORS" ]; then
            echo "PASS: No new SOF DSP errors since driver reload."
            VERIFY_PASS=$((VERIFY_PASS + 1))
        else
            echo "WARNING: New SOF DSP errors detected after reload:"
            echo "$NEW_ERRORS"
            VERIFY_FAIL=$((VERIFY_FAIL + 1))
        fi

        ASOUND_CARDS=$(cat /proc/asound/cards 2>/dev/null | grep -c '\[.*\]' || true)
        if [ "$ASOUND_CARDS" -gt 0 ]; then
            echo "PASS: $ASOUND_CARDS audio card(s) in /proc/asound/cards."
            VERIFY_PASS=$((VERIFY_PASS + 1))
        else
            echo "FAIL: No audio cards in /proc/asound/cards."
            VERIFY_FAIL=$((VERIFY_FAIL + 1))
        fi

        # REPORT
        echo "--- REPORT ---"
        if [ "$VERIFY_FAIL" -eq 0 ]; then
            OUTCOME="SUCCESS"
            RC=0
        elif [ "$VERIFY_PASS" -gt 0 ] && [ "$VERIFY_FAIL" -gt 0 ]; then
            OUTCOME="PARTIAL"
            RC=1
        else
            OUTCOME="FAILED"
            RC=1
        fi
        echo "Remediation outcome: $OUTCOME"
        echo "  Passed checks: $VERIFY_PASS"
        echo "  Failed checks: $VERIFY_FAIL"
        echo "REMEDIATION_OUTCOME: $OUTCOME"
    fi
fi
sync
exit $RC
