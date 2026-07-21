# DeckDoc v3.1.0

**Bare-Metal Diagnostic + Remediation Scaffold for SteamOS / Steam Deck**

Hardware telemetry, software crash analysis, and guarded remediation designed for Steam Deck failure modes. Fifteen diagnostic modules run in parallel and flush their output frequently so useful evidence survives many interrupted runs. Remediation is explicit, prechecked, backed up, and verified.

## Architecture

```
deckdoc/
├── setup.sh                  # Environment scaffold + permissions
├── deckdoc.sh                # Parallel runner + remediation dispatcher (--fix)
├── modules/
│   # Hardware telemetry (v1.x)
│   ├── gpu_apu.sh            # amdgpu ring timeout + CPU/GPU freq lock detection
│   ├── battery_pmic.sh       # Raw battery telemetry (voltage/current/energy)
│   ├── thermal_fan.sh        # hwmon temp sensors + fan RPM
│   ├── storage_smart.sh      # NVMe SMART health (smartctl + sudo fallback)
│   └── fs_integrity.sh       # BTRFS device stats + EXT4 state (btrfs + dumpe2fs)
│   # Software/OS diagnostics (v2.0 / v3.0)
│   ├── audio_sof.sh          # SOF DSP panic detection (IPC error -22)
│   ├── display_blackout.sh   # eDP link/backlight/CRTC/plane-path blackout correlation
│   ├── coredump_analysis.sh  # systemd-coredump crash counting & profiling
│   ├── wifi_firmware.sh      # ath11k/iwlwifi post-resume failure
│   ├── gamescope_session.sh  # Gamescope/MangoApp crashes and current-boot restarts
│   ├── memory_swap.sh        # Memory pressure, OOM events, swap analysis
│   ├── steam_client_logs.sh  # Steam /tmp/dumps/ crash inventory
│   ├── mmc_sd_card.sh        # SD card / mmc driver error detection
│   ├── acpi_pm_state.sh      # ACPI suspend/resume, fan-after-wake failures
│   └── dxvk_page_fault.sh    # DXVK/VKD3D GPU page fault classification
│   # Remediation modules
│   ├── rem_audio_sof.sh      # SOF DSP driver reload — PRE_CHECK/BACKUP/EXECUTE/VERIFY/REPORT
│   └── rem_display_blackout.sh # Gamescope forced composition; no power controls
├── config/
│   └── 99-deckdoc-display-stability.lua # Optional persistent Gamescope policy
├── tests/
│   └── test_runner.sh        # Mock sysfs unit tests
├── ROADMAP.md                # Remediation roadmap
└── .gitignore
```

## Quick Start

```bash
# Run diagnostics only
./deckdoc.sh

# Correlate a physically black LCD while sound/rendering continues
sudo ./deckdoc.sh --display-black

# Apply a reversible, session-only single-plane Gamescope mitigation
./deckdoc.sh --fix-display-blackout

# Apply it now and persist it for later Game Mode sessions
./deckdoc.sh --persist-display-stability

# Run diagnostics + remediation (requires root)
sudo ./deckdoc.sh --fix

# Or just setup the environment
./setup.sh
```

All output lands in `logs/` — one file per module plus a consolidated master report.

## Detected Failure Modes (15 modules)

| Failure Mode | Module | Detection Method |
|---|---|---|
| **400MHz CPU Lock** | gpu_apu.sh | `scaling_cur_freq` ≤ 405000 kHz |
| **200MHz GPU SCLK Lock** | gpu_apu.sh | `pp_dpm_sclk` active state at 200 MHz |
| **amdgpu Ring Timeout** | gpu_apu.sh | Kernel errors via `journalctl -b 0 --priority=err` |
| **GPU Reset Outcome** | gpu_apu.sh | `succeeded` vs `failed` classification |
| **Battery Deep Discharge** | battery_pmic.sh | Raw voltage < 6.6V (bypasses % spoofing) |
| **PMIC Trickle-Charge** | battery_pmic.sh | `current_now` ≈ 10000 µA with low voltage |
| **Cell Degradation** | battery_pmic.sh | `energy_full` / `energy_full_design` ratio |
| **Thermal Threshold** | thermal_fan.sh | Exported hwmon high/critical thresholds; >90°C is only a high observation when no threshold is exposed |
| **Fan Stopped** | thermal_fan.sh | Exported fan input at 0 RPM, reported alongside live temperatures |
| **NVMe Health** | storage_smart.sh | `smartctl -H` pass/fail (sudo fallback) |
| **BTRFS Corruption** | fs_integrity.sh | `btrfs device stats` non-zero counters |
| **EXT4 State** | fs_integrity.sh | `dumpe2fs -h` filesystem state flags |
| **SOF DSP Panic** | audio_sof.sh | IPC error -22, DSP panic, pipeline resume failure |
| **Display Blackout** | display_blackout.sh | eDP/EDID/backlight/CRTC correlation, active hardware planes, current and historical display warnings |
| **Core Dump Analysis** | coredump_analysis.sh | Historical counts by executable plus current-boot SIGTRAP/SIGABRT/SIGSEGV severity |
| **WiFi Firmware Crash** | wifi_firmware.sh | ath11k firmware errors, wlan0 DOWN state |
| **Gamescope / MangoApp Health** | gamescope_session.sh | Current-boot restarts, Vulkan errors, MangoApp fdinfo permission aborts |
| **OOM / Memory Pressure** | memory_swap.sh | OOM events, swap thrashing, MemAvailable |
| **Steam Crash Dumps** | steam_client_logs.sh | Actual minidump/core files only; ignores healthy `/tmp/dumps/` bookkeeping |
| **SD Card Errors** | mmc_sd_card.sh | mmc driver errors, ext4 corruption on SD |
| **ACPI Resume Failure** | acpi_pm_state.sh | Fan-after-wake bug, PCI PM resume errors |
| **GPU Page Faults** | dxvk_page_fault.sh | UTCL2 client ID classification (CB/DB/CPF) |

## Remediation

Run `sudo ./deckdoc.sh --fix` to attempt automatic recovery of detected failures. Each remediation module follows a strict lifecycle:

1. **PRE_CHECK** — Verify the trigger condition still exists (race-safe)
2. **BACKUP** — Snapshot state before modification
3. **EXECUTE** — Perform the remediation action (with timeout guard)
4. **VERIFY** — Confirm the fix worked
5. **REPORT** — Log outcome: SUCCESS, FAILED, or PARTIAL

The display remediation is intentionally separate from broad `--fix`. It requires `--fix-display-blackout` or `--persist-display-stability`, an explicitly reported symptom, a connected eDP panel, readable EDID, a nonzero backlight, and a live Gamescope session. It only sets Gamescope's `composite_force` policy, disabling direct/multi-plane scanout. The persistent Lua policy also uses Gamescope's documented `OnPostPaint` hook to restore the convar if a launcher-to-game transition clears it; live validation found that a one-time startup assignment was not sufficient.

To roll back persistence, remove `~/.config/gamescope/scripts/99-deckdoc-display-stability.lua` and start a new Game Mode session. For the current session, run `gamescopectl composite_force 0`.

### Display safety boundary

DeckDoc's display remediation does **not** write panel/backlight power, brightness, refresh rate, TDP, GPU/CPU clocks, charging controls, firmware, or GPU reset sysfs nodes. A black panel with a failed EDID, zero backlight, or inactive modeset is recorded but not forced through this mitigation.

## Bare-Metal Design Philosophy

The Steam Deck's aggressive PMIC and SMU protective mechanisms can trigger instantaneous power loss or kernel panic within seconds of boot. Traditional diagnostic tools fail because they rely on system stability to aggregate and format results.

DeckDoc's approach:
- **Parallel execution** — all 15 diagnostic modules launch simultaneously via `&` + `wait`; remediation runs sequentially after
- **Synchronous I/O** — `sync` invoked after every discrete hardware read
- **Trap handler** — `panic_sync` registered on EXIT/HUP/INT/QUIT/TERM
- **No daemonization** — runs once, terminates, leaves no persistent process

This improves the chance that evidence remains on disk if a run is interrupted; it cannot guarantee persistence across every storage, kernel, or power failure.

## Requirements

- Bash 4+
- SteamOS 3.x (Arch Linux-based)
- `smartctl` for NVMe health checks
- `btrfs` for BTRFS filesystem stats
- Root access for full diagnostic scope

## Next: Remediation

See [ROADMAP.md](ROADMAP.md) for the v3.0 roadmap — shifting from diagnosis to automated remediation and self-healing.

Engineering research and runbooks live under [docs/wiki](docs/wiki/Home.md); those files are also the
source of truth for the GitHub wiki.

## License

MIT
