# Getting started

## Before installation

DeckDoc targets SteamOS 3.x. Use Desktop Mode or SSH and make sure the Deck has enough free space for
text logs. Diagnostics do not need the SteamOS read-only root filesystem to be disabled.

The normal DeckDoc report is not a daemon: it runs once, writes a report inside its checkout, and
exits. Continuous capture is a separate, explicit opt-in described in the
[continuous incident probe](Continuous-Incident-Probe.md).

## Install

```bash
git clone https://github.com/deucebucket/deckdoc.git
cd deckdoc
./setup.sh
```

To update an existing clean checkout:

```bash
git pull --ff-only
```

If `git status --short` shows local changes, preserve or commit them before pulling. Do not discard
local evidence or customization just to update the tool.

## Create a baseline

Run one report while the Deck is healthy. It gives you model-specific paths and normal values to
compare with a future incident.

```bash
sudo ./deckdoc.sh
```

The report is stored as:

```text
logs/deckdoc_master_report_<timestamp>.log
```

Individual subsystem output is stored in `logs/module_*.log`. A new run replaces those per-module
files but does not delete older timestamped master reports.

## Capture a failure

If the system still responds, run DeckDoc before restarting. A restart may clear the exact current
state even when journal history survives.

```bash
cd /path/to/deckdoc
sudo ./deckdoc.sh
```

For a physically black built-in panel where audio/input/rendering continue, declare the symptom so
the display module can classify it:

```bash
sudo ./deckdoc.sh --display-black
```

Do not suspend, change display power/brightness, force a GPU reset, or launch a broad “fix” script
before collecting the failure state.

## Why root is recommended

Without root, DeckDoc can still read many `/proc`, `/sys`, user-session, and Steam paths. It may not
be able to read:

- the full kernel/system journal;
- DRM debugfs state and active hardware planes;
- NVMe SMART data;
- BTRFS device statistics or ext4 superblock state;
- system-wide core dumps;
- some hardware telemetry.

An empty section in an unprivileged report can therefore mean “permission denied,” not “healthy.”

If repeatedly entering `sudo` is impractical, the owner can make a one-time approval for DeckDoc's
exact read-only collection operations. This does not disclose the password or authorize a root shell,
arbitrary command, or remediation. See [privileged diagnostic authorization](Privileged-Diagnostic-Authorization.md).

## Optional tools

DeckDoc degrades gracefully when commands are missing. Useful commands include `smartctl`, `btrfs`,
`dumpe2fs`, `coredumpctl`, `aplay`, `pw-cli`, `ip`, `iw`, `lspci`, `lsblk`, and `findmnt`.

SteamOS is an image-based operating system. Avoid disabling its read-only root or installing packages
solely for a first diagnostic run. Record missing commands and use the evidence that is available.

## Next step

Use the [triage flow](Triage-Flow.md), then read the relevant symptom page. Before sharing logs, review
[collecting and sharing evidence](Collecting-and-Sharing-Evidence.md).
