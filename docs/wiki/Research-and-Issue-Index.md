# Research and issue index

This page maps DeckDoc's repository issues and upstream evidence to shipped behavior. Upstream issue
reports are field evidence, not automatically confirmed root causes.

## DeckDoc issue-backed modules

| DeckDoc issue | Topic | Implemented | Wiki route |
|---|---|---|---|
| [#1](https://github.com/deucebucket/deckdoc/issues/1) | SOF DSP panic / IPC `-22` | `audio_sof.sh`, `rem_audio_sof.sh` | [Audio](Audio-Problems.md) |
| [#2](https://github.com/deucebucket/deckdoc/issues/2) | systemd core-dump analysis | `coredump_analysis.sh` | [Crashes/report reading](Reading-DeckDoc-Reports.md#crashes-and-retained-history) |
| [#3](https://github.com/deucebucket/deckdoc/issues/3) | Wi-Fi firmware after resume | `wifi_firmware.sh` | [Network/resume](Network-and-Resume-Problems.md) |
| [#4](https://github.com/deucebucket/deckdoc/issues/4) | Gamescope session health | `gamescope_session.sh` | [Display/Gamescope](Display-and-Gamescope-Problems.md) |
| [#5](https://github.com/deucebucket/deckdoc/issues/5) | memory/swap/OOM | `memory_swap.sh` | [Crashes/GPU/memory](Crashes-GPU-and-Memory.md) |
| [#6](https://github.com/deucebucket/deckdoc/issues/6) | Steam client logs | `steam_client_logs.sh` | [Evidence](Collecting-and-Sharing-Evidence.md) |
| [#7](https://github.com/deucebucket/deckdoc/issues/7) | microSD/mmc errors | `mmc_sd_card.sh` | [Storage/microSD](Storage-and-MicroSD-Problems.md) |
| [#8](https://github.com/deucebucket/deckdoc/issues/8) | suspend/resume state | `acpi_pm_state.sh` | [Network/resume](Network-and-Resume-Problems.md) |
| [#9](https://github.com/deucebucket/deckdoc/issues/9) | DXVK/VKD3D GPU fault differentiation | `dxvk_page_fault.sh` | [Crashes/GPU/memory](Crashes-GPU-and-Memory.md) |

Issues #2–#9 may still be open in GitHub even though their initial diagnostic modules shipped in PR
[#10](https://github.com/deucebucket/deckdoc/pull/10). Treat them as implementation/follow-up trackers,
not as evidence that the modules are absent.

The diagnostic-center follow-up closes their remaining acceptance gaps with time-bounded crash-family
classification, broader wireless-driver discovery and coupled resume evidence, user-service restart
counts, live-versus-cumulative memory pressure, bounded Steam helper crash rates, severity-aware mmc/ext4
signals, live fan/temperature and charge-limit context, and neutral GPU-fault attribution. Each branch
has a healthy/triggered regression fixture; the issues should close when that change merges.

PR [#14](https://github.com/deucebucket/deckdoc/pull/14) added display-blackout correlation, guarded
forced composition, current-versus-historical crash cleanup, session-user routing, and the original
incident runbooks.

The [long-off startup blackout](Black-Screen-After-Long-Shutdown.md) is a community-reported research
case added on 2026-07-21. It remains unverified and intentionally separate from PR #14's live-render,
multi-plane LCD signature.

## Full-platform follow-up issues

| Issue | Scope | Current branch |
|---|---|---|
| [#15](https://github.com/deucebucket/deckdoc/issues/15) | Model and capability manifest | Schema-v1 baseline and first consumers shipped; expansion remains |
| [#16](https://github.com/deucebucket/deckdoc/issues/16) | Reproducible, signed DeckDoc Rescue | Alpha collector and builder added |
| [#17](https://github.com/deucebucket/deckdoc/issues/17) | Unified incident timeline and evidence-access ledger | Source data exists; normalization remains |
| [#18](https://github.com/deucebucket/deckdoc/issues/18) | Continuous-probe production hardening | Opt-in bounded prototype added |
| [#19](https://github.com/deucebucket/deckdoc/issues/19) | Privileged authorization security review | Exact-command broker prototype added |
| [#20](https://github.com/deucebucket/deckdoc/issues/20) | Dock/USB-C/PD validation | Read-only module and fixtures added |
| [#21](https://github.com/deucebucket/deckdoc/issues/21) | Network stages, Bluetooth/input, and update health | Wiki routes exist; module gaps remain |
| [#22](https://github.com/deucebucket/deckdoc/issues/22) | Redacted bundle and storage-risk gate | Pre-write public-safe filtering shipped; formal bundle and storage gate remain |
| [#23](https://github.com/deucebucket/deckdoc/issues/23) | DeckMD GitHub Pages symptom checker | Static checker and schema validation added |
| [#27](https://github.com/deucebucket/deckdoc/issues/27) | First-class application diagnostic adapters | RyuDeck structured/privacy-safe baseline added; generic schema and more apps remain |

The [deep research catalog](../research/steamdeck-issue-deep-dive.md) covers 33 failure families,
decision boundaries, detector candidates, and primary sources behind these priorities.

## Upstream symptom evidence

### SteamOS and Steam

- [Reviewing log information](https://github.com/ValveSoftware/SteamOS/wiki/Reviewing-log-information)
  documents `/tmp/dumps/`, `steam_stdout.txt`, and journal-based log review.
- [SteamOS #1376](https://github.com/ValveSoftware/SteamOS/issues/1376) reports loss of audio after
  sleep.
- [SteamOS #2313](https://github.com/ValveSoftware/SteamOS/issues/2313) reports SOF Vangogh IPC `-22`
  and a rarer wireless failure after resume.
- [SteamOS #2475](https://github.com/ValveSoftware/SteamOS/issues/2475) reports a fan-resume problem
  when sleeping while charging at a configured charge limit.
- [SteamOS #2037](https://github.com/ValveSoftware/SteamOS/issues/2037) reports SD/ext4 corruption on a
  SteamOS handheld; it informs detection patterns but is not Deck-specific proof.
- [SteamOS #1324](https://github.com/ValveSoftware/SteamOS/issues/1324),
  [#2632](https://github.com/ValveSoftware/SteamOS/issues/2632), and
  [#1015](https://github.com/ValveSoftware/SteamOS/issues/1015) provide comparison black-screen cases
  with different scopes and GPU evidence.

### Gamescope and graphics

- [Gamescope](https://github.com/ValveSoftware/gamescope) describes the compositor/direct-flip role in
  the SteamOS presentation path.
- [Gamescope #1368](https://github.com/ValveSoftware/gamescope/issues/1368) documents direct-scanout/
  plane-transition artifacts improved by forced composition on multiple AMD devices.
- [Linux AMD Display Core debugging](https://docs.kernel.org/gpu/amdgpu/display/dc-debug.html)
  emphasizes dmesg and pre/post display state.
- [Linux AMDGPU debugfs](https://docs.kernel.org/gpu/amdgpu/debugfs.html) documents low-level debug
  interfaces, including why DeckDoc does not blindly trigger a GPU reset.

### Linux data sources

- [journalctl](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html) defines boot,
  kernel, unit, and priority filtering.
- [coredumpctl](https://www.freedesktop.org/software/systemd/man/latest/coredumpctl.html) defines crash
  matching, metadata, storage, and access limitations.
- [BTRFS device stats](https://btrfs.readthedocs.io/en/latest/btrfs-device.html#device-stats) defines
  persistent read/write/flush/corruption/generation counters.

## Research rules for new signatures

Before adding a signature or fix:

1. Link a primary source or attach a sanitized real incident.
2. State affected model/version and whether the issue is open, fixed, or unknown.
3. Separate reporter hypothesis from maintainer-confirmed cause.
4. Define exact time-scoped detection and likely false positives.
5. Add a fixture for healthy, triggered, unavailable, and stale-history states.
6. For remediation, document precheck, backup, action, verify, report, and rollback.
7. Never turn one anecdote into a universal Deck rule.
