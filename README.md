# DeckDoc v1.0.1

**Bare-Metal Diagnostic Scaffold for SteamOS / Steam Deck**

Hardware telemetry extraction designed for the Steam Deck's unique failure modes — the 200/400MHz APU lock, PMIC voltage desync, BTRFS silent corruption, and unrecoverable amdgpu pipeline hangs. Executes all diagnostics in parallel with synchronous I/O (`sync` after every read) so that if the device suffers a kernel panic or power loss during extraction, the maximum diagnostic data has already been committed to persistent storage.

## Architecture

```
deckdoc/
├── setup.sh                  # Environment scaffold + permissions
├── deckdoc.sh                # Parallel bare-metal runner with panic_sync trap
├── modules/
│   ├── gpu_apu.sh            # amdgpu ring timeout + CPU/GPU freq lock detection
│   ├── battery_pmic.sh       # Raw battery telemetry (voltage/current/energy)
│   ├── thermal_fan.sh        # hwmon temp sensors + fan RPM
│   ├── storage_smart.sh      # NVMe SMART health (smartctl + sudo fallback)
│   └── fs_integrity.sh       # BTRFS device stats + EXT4 state (btrfs + dumpe2fs)
├── tests/
│   └── test_runner.sh        # Mock sysfs unit tests
├── ROADMAP.md                # v2.0 gap analysis and priority
└── .gitignore
```

## Quick Start

```bash
# Run as user (some modules will be restricted)
./deckdoc.sh

# Run as root for full diagnostics (SMART, BTRFS, dmesg, dumpe2fs)
sudo ./deckdoc.sh

# Or just setup the environment
./setup.sh
```

All output lands in `logs/` — one file per module plus a consolidated master report.

## Detected Failure Modes

| Failure Mode | Module | Detection Method |
|---|---|---|
| **400MHz CPU Lock** | gpu_apu.sh | `scaling_cur_freq` ≤ 405000 kHz |
| **200MHz GPU SCLK Lock** | gpu_apu.sh | `pp_dpm_sclk` active state at 200 MHz |
| **amdgpu Ring Timeout** | gpu_apu.sh | Kernel ring errors via journalctl (current boot) + dmesg (historical) |
| **GPU Reset Outcome** | gpu_apu.sh | `succeeded` vs `failed` classification |
| **Battery Deep Discharge** | battery_pmic.sh | Raw voltage < 6.6V (bypasses % spoofing) |
| **PMIC Trickle-Charge** | battery_pmic.sh | `current_now` ≈ 10000 µA with low voltage |
| **Cell Degradation** | battery_pmic.sh | `energy_full` / `energy_full_design` ratio |
| **Thermal Trip > 90°C** | thermal_fan.sh | hwmon temp sensor threshold |
| **Fan Failure** | thermal_fan.sh | 0 RPM while APU > 60°C |
| **NVMe Health** | storage_smart.sh | `smartctl -H` pass/fail |
| **BTRFS Corruption** | fs_integrity.sh | `btrfs device stats` non-zero counters |
| **EXT4 State** | fs_integrity.sh | `dumpe2fs -h` filesystem state flags |

## Bare-Metal Design Philosophy

The Steam Deck's aggressive PMIC and SMU protective mechanisms can trigger instantaneous power loss or kernel panic within seconds of boot. Traditional diagnostic tools fail because they rely on system stability to aggregate and format results.

DeckDoc's approach:
- **Parallel execution** — all 5 modules launch simultaneously via `&` + `wait`
- **Synchronous I/O** — `sync` invoked after every discrete hardware read
- **Trap handler** — `panic_sync` registered on EXIT/HUP/INT/QUIT/TERM
- **No daemonization** — runs once, terminates, leaves no persistent process

This guarantees that if the device dies mid-diagnostic, the data is already on disk.

## Requirements

- Bash 4+
- SteamOS 3.x (Arch Linux-based)
- `smartctl` for NVMe health checks
- `btrfs` for BTRFS filesystem stats
- `dumpe2fs` for EXT4 filesystem state
- Root access for full diagnostic scope

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned v2.0 modules:

- `audio_sof.sh` — SOF DSP panic detection (IPC error -22)
- `coredump_analysis.sh` — systemd-coredump crash counting
- `memory_swap.sh` — OOM and unified memory pressure
- `wifi_firmware.sh` — ath11k post-resume failure
- `gamescope_session.sh` — gamescope session restart tracking
- And more...

## License

MIT
