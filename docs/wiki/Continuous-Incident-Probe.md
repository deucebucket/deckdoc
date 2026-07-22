# Continuous incident probe

The optional DeckDoc probe preserves evidence that is easy to lose between a failure and a later full
report. It does not repeatedly run every diagnostic module. One low-priority process follows the local
system journal and remains blocked while no new record arrives. When a bounded GPU, display, SOF audio,
wireless, storage, OOM, thermal, Gamescope, or resume signature appears, it captures one public-safe
filtered incident.

## What an incident contains

- the trigger, UTC time, boot ID, category, and requested pre/post window;
- up to two minutes before and five seconds after the event from the journal;
- RAM/swap and pressure-stall state;
- fan, thermal, power-supply, DRM connector/backlight/plane, network-device, USB, storage, Gamescope,
  MangoApp, and recent core metadata that was readable at capture time.

This is correlation evidence, not a verdict. A later core may be downstream of an earlier GPU reset;
a deliberate USB unplug can look like a disconnect; a matching line can still be unrelated to the
user-visible incident.

## Opt in

```bash
sudo ./probe/install-probe.sh install
sudo ./probe/install-probe.sh status
```

The normal `setup.sh` never installs or starts it. The system service is low-priority, capped at 128 MB,
can write only its private state directory, uses a 60-second per-category cooldown, retains at most 25
incidents, and caps each journal window at 2 MiB by default.

Create a manual marker immediately after an odd symptom. The probe intentionally stores a fixed marker
rather than user-entered free text:

```bash
sudo /var/lib/deckdoc-probe/bin/deckdoc-probe.sh capture
```

The next `sudo ./deckdoc.sh` automatically includes the latest incident through
`module_probe.log`. Older incidents remain under `/var/lib/deckdoc-probe/events/`.

## Stop, uninstall, and retention

```bash
sudo systemctl stop deckdoc-probe.service
sudo ./probe/install-probe.sh uninstall
```

Uninstall preserves existing incidents. `sudo ./probe/install-probe.sh purge` is a separate,
permanent deletion and refuses to run while the service is active.

## Privacy

State is mode `0700`; individual files are `0600`. Every captured stream is passed through DeckDoc's
public-safe filter before disk and no raw incident variant is retained. The probe also stores only a
recent core count and ignores user-entered marker text. Review before sharing because arbitrary
upstream journal formats can change; a storage cap limits size, not sensitivity.

## Performance boundary

The probe uses Bash pattern matching in-process instead of spawning `grep` for each record. Expensive
commands run only after a trigger or manual capture. Validate real idle CPU, wakeups, memory, and storage
growth on both LCD and OLED releases before calling the overhead universally negligible.

The watcher depends on the journal. A kernel hard lock, abrupt power loss, volatile journal, or storage
failure may prevent the final records from persisting; software cannot guarantee a last-gasp capture.

## Why this design

[`journalctl --follow`](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html) already
provides the append stream and boot/time filtering. Re-running SMART, filesystem, coredump, Steam, and
all hardware modules every few seconds would add unnecessary work and still might miss the transient
DRM/fan/device state that an event-triggered snapshot preserves.
