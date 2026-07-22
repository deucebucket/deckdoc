# DeckDoc

**Current source release: v3.3.0** · [Changelog](CHANGELOG.md) ·
[Roadmap](ROADMAP.md) · [DeckMD](https://deucebucket.github.io/deckdoc/) ·
[Diagnostic wiki](https://github.com/deucebucket/deckdoc/wiki)

DeckDoc is a full-system Steam Deck diagnostic and incident-response platform. It helps answer the
larger question behind almost every Deck failure: **what actually failed, what evidence supports that
conclusion, and what is the safest next action?**

It collects and correlates evidence across the APU/GPU, memory, storage and filesystems, battery and
power, thermals and fan, Wi-Fi, audio, controls, Steam and Proton, Gamescope, suspend/resume, display,
USB-C docks, and connected peripherals. It can capture a one-time system snapshot, preserve evidence
from intermittent failures, inspect a docked hardware path, or collect from outside the installed OS.
The result is one timestamped case that can separate likely application/configuration faults,
SteamOS or driver faults, peripheral faults, and evidence that warrants hardware escalation.

The project currently ships 17 read-only diagnostic modules, an opt-in incident probe, dock/USB-C
analysis, an alpha rescue collector/image builder, a guided symptom checker, a diagnostic wiki, and
two tightly guarded remediations. DeckDoc is diagnosis-first: its coverage is intentionally much
broader than the small number of conditions it can safely change automatically.

> Start with the [DeckDoc diagnostic center](docs/wiki/Home.md) if you have a symptom and do not yet
> know which subsystem is responsible.

Or use [DeckMD](https://deucebucket.github.io/deckdoc/), the private in-browser symptom checker. It
starts with six broad categories, reveals only the connected follow-up questions, removes conflicting
paths as you answer, and keeps the complete grouped checklist behind **Browse all checks**.

## Problems DeckDoc investigates

| Area | Questions DeckDoc helps answer |
|---|---|
| Boot and stability | Did the Deck fail before SteamOS, panic, freeze, restart, or lose only one service? |
| Games and graphics | Did one title fail, did Gamescope restart, or did the AMD GPU fault and recover? |
| Memory and crashes | Was there an OOM kill, active pressure, swap churn, or a relevant new core dump? |
| Storage | Is the NVMe or microSD reporting health, controller, filesystem, TRIM, or read-only errors? |
| Power and thermals | Are battery, charging, PMIC, fan, temperature, or low-frequency signals abnormal? |
| Network and audio | Is the device absent, disconnected, driver-failed, or broken specifically after resume? |
| Suspend and resume | Which power transition failed, and which devices or services failed with it? |
| Controls and peripherals | Is the failure tied to Bluetooth, input configuration, USB, or a physical device path? |
| Docks and USB-C | Did PD, Alt Mode, USB topology, Ethernet, or the external display path renegotiate or reset? |
| Display | Is rendering alive while physical scanout failed, or is the symptom part of a wider GPU/session fault? |
| Intermittent incidents | What happened immediately before and after a rare failure that a later report would miss? |
| Hardware decisions | Does the evidence follow the OS/configuration, a peripheral, or the physical Deck across clean tests? |

DeckDoc does not replace Valve Support, prove that hardware is healthy, repair arbitrary filesystems,
or make risky firmware, voltage, clock, charge, panel-power, or blind GPU-reset changes.

## Quick start

Run these commands from Desktop Mode or over SSH:

```bash
git clone https://github.com/deucebucket/deckdoc.git
cd deckdoc
./setup.sh

# Full read-only report. Root reveals kernel/debugfs and device details.
sudo ./deckdoc.sh
```

Reports are written under `logs/`. The file named `deckdoc_master_report_<timestamp>.log` is the
combined report; `module_*.log` files contain each subsystem's raw section.

Before posting a report publicly, read [Collecting and sharing evidence](docs/wiki/Collecting-and-Sharing-Evidence.md).
Network names/addresses, usernames, paths, process names, and game titles may be present.

## One project, five diagnostic modes

| Mode | Best for | Output |
|---|---|---|
| Full report | Current system-wide snapshot | 17 correlated module logs plus one master report |
| Continuous probe | Rare/transient failures | Trigger, pre/post journal window, and volatile incident state |
| Dock A/B | Third-party dock, PD, USB, Ethernet, display failures | Topology, exported negotiation, connector, and reset evidence |
| DeckDoc Rescue | Installed OS cannot boot or needs an outside-OS contrast | Private read-only rescue archive and installed journal image evidence |
| DeckMD + wiki | User does not know which subsystem to test | Ranked symptom branches, known patterns, safe checks, and escalation route |

## Core commands

| Command | Effect | Changes the system? |
|---|---|---|
| `sudo ./deckdoc.sh` | Run all 17 diagnostic modules | No; creates local logs |
| `./deckdoc.sh` | Run with reduced access | No; some checks may be incomplete |
| `sudo ./probe/install-probe.sh install` | Opt in to the low-overhead incident watcher | Yes; installs/starts one constrained service |
| `sudo ./probe/install-probe.sh uninstall` | Stop/remove watcher, preserving incidents | Yes; service files only |
| `sudo ./bootprobe/deckdoc-rescue-collect.sh ...` | Collect outside-OS evidence from a compatible rescue environment | No writes to installed disk; creates private archive |
| `sudo ./privileged/install-authorized.sh install` | Approve DeckDoc's exact read-only privileged operations once | Yes; root-owned snapshot and narrow sudoers rules |
| `./privileged/deckdoc-authorized-client.sh report` | Run a complete authorized report later without sharing a password | No; creates a private local report |
| `bash tests/test_runner.sh` | Run mocked regression tests | No production-device changes |

The optional authorization does not give DeckDoc—or an agent—a password or general sudo access. It
installs a root-owned, checksummed snapshot and allowlists only exact diagnostic operations. Arbitrary
arguments, paths, commands, shells, environment injection, and remediations are excluded. Updating the
snapshot or changing that allowlist requires another visible user approval. See
[Privileged diagnostic authorization](docs/wiki/Privileged-Diagnostic-Authorization.md).

## Diagnostic coverage

| Area | Module | Evidence and signatures |
|---|---|---|
| GPU/APU | `gpu_apu.sh` | amdgpu ring timeouts, reset outcome, low CPU/GPU frequency state |
| Display | `display_blackout.sh` | eDP status, EDID, backlight, CRTC, DRM planes, Gamescope, display warnings |
| Dock/USB-C | `dock_usb_c.sh` | USB topology, Type-C/PD/Alt Mode exports, external displays, Ethernet, path errors |
| Battery/PMIC | `battery_pmic.sh` | raw capacity, voltage, current, charge/energy counters |
| Thermals/fan | `thermal_fan.sh` | hwmon readings, plausible exported thresholds, fan RPM |
| NVMe | `storage_smart.sh` | SMART/NVMe health and error fields for `/dev/nvme0n1` |
| Filesystems | `fs_integrity.sh` | BTRFS device counters and ext4 filesystem state |
| Audio | `audio_sof.sh` | SOF panic, IPC timeout/-22, firmware state, ALSA and PipeWire presence |
| Crashes | `coredump_analysis.sh` | retained/current-boot/last-24h dumps, process families, signals, disk use |
| Wi-Fi | `wifi_firmware.sh` | `wlan`/`wl` presence, link info, bounded driver errors/version, Wi-Fi+SOF signature |
| Game Mode | `gamescope_session.sh` | Gamescope dumps and user-service restarts, Vulkan/Wayland errors, MangoApp signature |
| Memory | `memory_swap.sh` | MemAvailable, swap use, cumulative vs live I/O, current-boot OOM events |
| Incident history | `probe_incidents.sh` | latest opt-in trigger, volatile snapshot, bounded journal window |
| Steam/Proton | `steam_client_logs.sh` | real crash files, helper crash rate, Steam errors, prefix/lock inventory |
| microSD | `mmc_sd_card.sh` | mmc presence/mounts, driver/ext4/TRIM errors, read-only state |
| Suspend/resume | `acpi_pm_state.sh` | PM transitions/failures, fan-controller warnings, wake sources |
| Vulkan translation | `dxvk_page_fault.sh` | AMD VM/UTCL2 page-fault class, process hints, timeouts, reset result |

See [Module reference](docs/wiki/Module-Reference.md) for prerequisites, limitations, and how to
interpret every section.

## Symptom routes

| Symptom | Start here |
|---|---|
| Will not power on, boot, or reach SteamOS | [Recovery and escalation](docs/wiki/Recovery-and-Escalation.md) |
| Game freezes, crashes, reboots, or returns to Library | [Crashes, GPU and memory](docs/wiki/Crashes-GPU-and-Memory.md) |
| No sound, especially after wake | [Audio problems](docs/wiki/Audio-Problems.md) |
| Wi-Fi missing or broken after wake | [Network and resume problems](docs/wiki/Network-and-Resume-Problems.md) |
| Overheating, fan stopped, charging, battery, sudden shutdown | [Power, thermal and battery](docs/wiki/Power-Thermal-and-Battery-Problems.md) |
| microSD errors, corrupt games, storage warnings | [Storage and microSD](docs/wiki/Storage-and-MicroSD-Problems.md) |
| Dock, USB-C, charging, Ethernet, or external display | [Dock and USB-C](docs/wiki/Dock-USB-C-and-External-Displays.md) |
| Controls, Bluetooth, touch, or gyro | [Controls and Bluetooth](docs/wiki/Controls-Bluetooth-and-Input.md) |
| Screen black while the rest of the system may still work | [Display problems](docs/wiki/Display-and-Gamescope-Problems.md) |
| First start after days off is black; second boot works | [Long-off startup blackout](docs/wiki/Black-Screen-After-Long-Shutdown.md) |
| Installed OS cannot boot or hardware needs outside-OS comparison | [DeckDoc Rescue](docs/wiki/DeckDoc-Rescue.md) |
| Hardware failure versus fixable software is unclear | [Hardware decision guide](docs/wiki/Hardware-Failure-Decision-Guide.md) |

## Reading a report

Treat a DeckDoc finding as a lead, not a verdict:

1. Match the timestamp to the incident. Old core dumps and old journal warnings are context, not proof
   of a current failure.
2. Correlate independent signals. An OOM victim plus live memory pressure, a filesystem error plus new
   block I/O failures, or a dock-wide reset plus UCSI/display-link errors is stronger than any one line.
3. Distinguish absence from inaccessibility. A non-root run may be unable to read debugfs, SMART,
   BTRFS, system journals, or another user's Game Mode services.
4. Prefer the smallest reversible experiment that tests the leading hypothesis.
5. Re-run diagnostics and physically verify the result before calling a remediation successful.

The full interpretation guide is [Reading DeckDoc reports](docs/wiki/Reading-DeckDoc-Reports.md).

## Diagnosis first, narrow remediation second

DeckDoc's main product is evidence and decision support. Seventeen modules, the probe, Rescue, DeckMD,
and the wiki diagnose far more conditions than DeckDoc modifies. Only two signature-specific
remediations exist today:

- a Vangogh SOF audio reload after a current-boot DSP panic or IPC `-22`;
- a session-only Gamescope forced-composition test after the validated live LCD scanout-gap precheck.

Everything else ends in evidence, a safe manual contrast, an upstream-ready report, or escalation—not
an invented “fix.”

| Specialized command | Guarded action |
|---|---|
| `sudo ./deckdoc.sh --fix` | Reload SOF audio only when the current diagnostic trigger is present |
| `sudo ./deckdoc.sh --display-black` | Collect additional evidence for a declared physical-panel blackout; read-only |
| `./deckdoc.sh --fix-display-blackout` | Run a reversible, session-only Gamescope composition test |
| `./deckdoc.sh --persist-display-stability` | Install the backed-up display policy only after the live test succeeds |

Every remediation follows:

```text
PRE_CHECK -> BACKUP -> EXECUTE -> VERIFY -> REPORT -> documented ROLLBACK
```

The audio and display commands, exact prechecks, verification, and rollbacks are documented in the
[safe remediation policy](docs/wiki/Safe-Remediation-Policy.md). Unsupported hardware or a mismatched
signature is skipped rather than guessed.

DeckDoc never automatically writes panel power, backlight brightness, refresh rate, resolution, TDP,
CPU/GPU clocks, charging behavior, firmware, or GPU-reset sysfs nodes. See the
[safe remediation policy](docs/wiki/Safe-Remediation-Policy.md).

## Architecture

```text
deckdoc.sh
  |-- launches 17 diagnostic modules in parallel
  |-- flushes module output into logs/module_*.log
  |-- consolidates a timestamped master report
  `-- dispatches explicit remediation modes sequentially

modules/                  diagnostic and remediation shell modules
probe/                    opt-in event-triggered watcher and constrained service installer
bootprobe/                outside-OS collector and unsigned alpha ArchISO builder
privileged/               one-time approved, exact-command diagnostic broker
config/                   optional Gamescope policy template
docs/wiki/                GitHub-wiki-ready diagnostic center
tests/test_runner.sh      mocked behavior and safety regression checks
VERSION                   canonical source release version
CHANGELOG.md              release history and current unreleased state
remediation_backups/      created only when a remediation records state
logs/                     generated reports; ignored by Git
```

The runner registers a `sync` trap and modules flush after discrete evidence groups. This improves the
chance that partial evidence survives a crash or power interruption; it cannot guarantee persistence
after every kernel, device, or filesystem failure.

## Requirements and tested scope

- SteamOS 3.x on Steam Deck is the target environment.
- Bash 4+, `systemd`/`journalctl`, and standard Linux userland are assumed.
- Root is recommended for a complete report, but fixes always require an explicit flag.
- `smartctl` is needed for NVMe SMART; `btrfs` and `dumpe2fs` enable filesystem checks.
- `aplay`, PipeWire tools, `iw`, `ip`, `lspci`, and `coredumpctl` enrich their related sections.
- Read-only coverage and regression fixtures include Jupiter LCD and Galileo OLED differences;
  model-specific findings and remediations remain evidence-first.
- Device paths such as `/dev/nvme0n1`, DRM card indices, driver names, thresholds, and exported sysfs
  nodes vary. Missing or different hardware should be reported as a coverage gap.

## Development

Run the checks before submitting a change:

```bash
bash -n deckdoc.sh setup.sh modules/*.sh probe/*.sh bootprobe/*.sh privileged/* tests/*.sh
bash tests/test_runner.sh
node tests/validate_links.js
git diff --check
```

New diagnostic knowledge should include a symptom, exact evidence, time scope, confidence boundary,
safe next step, rollback if applicable, and primary references. The
[research and issue index](docs/wiki/Research-and-Issue-Index.md) maps repository issues and upstream
reports to implemented modules and remaining work.

## Roadmap and project status

The current roadmap is in [ROADMAP.md](ROADMAP.md). The research-backed priorities are a model/capability
manifest, evidence access ledger, unified incident timeline, safe redacted packager, storage risk gate,
and production hardening/signing of the probe and Rescue image.

## License

[MIT](LICENSE)
