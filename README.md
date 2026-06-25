# DeckDoc v2.0.0

**Bare-Metal Diagnostic Scaffold for SteamOS / Steam Deck**

Hardware telemetry and software crash analysis designed for the Steam Deck's unique failure modes — the 200/400MHz APU lock, PMIC voltage desync, BTRFS silent corruption, SOF DSP panic, and unrecoverable amdgpu pipeline hangs. Executes 14 diagnostic modules in parallel with synchronous I/O (`sync` after every read) so that if the device suffers a kernel panic or power loss during extraction, the maximum diagnostic data has already been committed to persistent storage.

## Architecture

```
deckdoc/
├── setup.sh                  # Environment scaffold + permissions
├── deckdoc.sh                # Parallel bare-metal runner with panic_sync trap
├── modules/
│   # Hardware telemetry (v1.x)
│   ├── gpu_apu.sh            # amdgpu ring timeout + CPU/GPU freq lock detection
│   ├── battery_pmic.sh       # Raw battery telemetry (voltage/current/energy)
│   ├── thermal_fan.sh        # hwmon temp sensors + fan RPM
│   ├── storage_smart.sh      # NVMe SMART health (smartctl + sudo fallback)
│   └── fs_integrity.sh       # BTRFS device stats + EXT4 state (btrfs + dumpe2fs)
│   # Software/OS diagnostics (v2.0)
│   ├── audio_sof.sh          # SOF DSP panic detection (IPC error -22)
│   ├── coredump_analysis.sh  # systemd-coredump crash counting & profiling
│   ├── wifi_firmware.sh      # ath11k/iwlwifi post-resume failure
│   ├── gamescope_session.sh  # Gamescope core dump & session restarts
│   ├── memory_swap.sh        # Memory pressure, OOM events, swap analysis
│   ├── steam_client_logs.sh  # Steam /tmp/dumps/ crash inventory
│   ├── mmc_sd_card.sh        # SD card / mmc driver error detection
│   ├── acpi_pm_state.sh      # ACPI suspend/resume, fan-after-wake failures
│   └── dxvk_page_fault.sh    # DXVK/VKD3D GPU page fault classification
├── tests/
│   └── test_runner.sh        # Mock sysfs unit tests
├── ROADMAP.md                # Next: remediation & self-healing
└── .gitignore
```

## Quick Start

```bash
# Run as user (some modules restricted)
./deckdoc.sh

# Run as root for full diagnostic scope
sudo ./deckdoc.sh

# Or just setup the environment
./setup.sh
```

All output lands in `logs/` — one file per module plus a consolidated master report.

## Detected Failure Modes (14 modules)

| Failure Mode | Module | Detection Method |
|---|---|---|
| **400MHz CPU Lock** | gpu_apu.sh | `scaling_cur_freq` ≤ 405000 kHz |
| **200MHz GPU SCLK Lock** | gpu_apu.sh | `pp_dpm_sclk` active state at 200 MHz |
| **amdgpu Ring Timeout** | gpu_apu.sh | Kernel errors via `journalctl -b 0 --priority=err` |
| **GPU Reset Outcome** | gpu_apu.sh | `succeeded` vs `failed` classification |
| **Battery Deep Discharge** | battery_pmic.sh | Raw voltage < 6.6V (bypasses % spoofing) |
| **PMIC Trickle-Charge** | battery_pmic.sh | `current_now` ≈ 10000 µA with low voltage |
| **Cell Degradation** | battery_pmic.sh | `energy_full` / `energy_full_design` ratio |
| **Thermal Trip > 90°C** | thermal_fan.sh | hwmon temp sensor threshold |
| **Fan Failure** | thermal_fan.sh | 0 RPM while APU > 60°C |
| **NVMe Health** | storage_smart.sh | `smartctl -H` pass/fail (sudo fallback) |
| **BTRFS Corruption** | fs_integrity.sh | `btrfs device stats` non-zero counters |
| **EXT4 State** | fs_integrity.sh | `dumpe2fs -h` filesystem state flags |
| **SOF DSP Panic** | audio_sof.sh | IPC error -22, DSP panic, pipeline resume failure |
| **Core Dump Analysis** | coredump_analysis.sh | SIGTRAP/SIGABRT/SIGSEGV counts by binary |
| **WiFi Firmware Crash** | wifi_firmware.sh | ath11k firmware errors, wlan0 DOWN state |
| **Gamescope Restarts** | gamescope_session.sh | Session restart count, Vulkan descriptor failures |
| **OOM / Memory Pressure** | memory_swap.sh | OOM events, swap thrashing, MemAvailable |
| **Steam Crash Dumps** | steam_client_logs.sh | `/tmp/dumps/` inventory, stdout errors |
| **SD Card Errors** | mmc_sd_card.sh | mmc driver errors, ext4 corruption on SD |
| **ACPI Resume Failure** | acpi_pm_state.sh | Fan-after-wake bug, PCI PM resume errors |
| **GPU Page Faults** | dxvk_page_fault.sh | UTCL2 client ID classification (CB/DB/CPF) |

## Bare-Metal Design Philosophy

The Steam Deck's aggressive PMIC and SMU protective mechanisms can trigger instantaneous power loss or kernel panic within seconds of boot. Traditional diagnostic tools fail because they rely on system stability to aggregate and format results.

DeckDoc's approach:
- **Parallel execution** — all 14 modules launch simultaneously via `&` + `wait`
- **Synchronous I/O** — `sync` invoked after every discrete hardware read
- **Trap handler** — `panic_sync` registered on EXIT/HUP/INT/QUIT/TERM
- **No daemonization** — runs once, terminates, leaves no persistent process

This guarantees that if the device dies mid-diagnostic, the data is already on disk.

## Requirements

- Bash 4+
- SteamOS 3.x (Arch Linux-based)
- `smartctl` for NVMe health checks
- `btrfs` for BTRFS filesystem stats
- Root access for full diagnostic scope

## Next: Remediation

See [ROADMAP.md](ROADMAP.md) for the v3.0 roadmap — shifting from diagnosis to automated remediation and self-healing.

## License

MIT
