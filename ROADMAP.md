# DeckDoc v1.0.1 — Roadmap & Gap Analysis

## Diagnosis Quality Assessment — Current Coverage

### Clean (works well)

| Failure Mode | Module | Signal |
|---|---|---|
| CPU 400MHz lock | modules/gpu_apu.sh | Perfect — single int compare |
| GPU 200MHz SCLK lock | modules/gpu_apu.sh | Perfect — pp_dpm_sclk `*` marker |
| Battery deep discharge < 6.6V | modules/battery_pmic.sh | Clean — raw uV bypasses % spoofing |
| Fan 0 RPM during load | modules/thermal_fan.sh | Clean — direct RPM read |
| Thermal > 90°C | modules/thermal_fan.sh | Clean — hwmon read |
| NVMe SMART health | modules/storage_smart.sh | Binary pass/fail (needs root) |
| BTRFS corruption counters | modules/fs_integrity.sh | Clean (needs root) |

### Noisy (needs v1.0.1 fixes)

| Failure Mode | Module | Problem | Fix |
|---|---|---|---|
| amdgpu_job_timedout | modules/gpu_apu.sh | Scans all dmesg history | Filter to current boot with `-b 0 --priority=err` |
| amdgpu_job_timedout | modules/gpu_apu.sh | Can't differentiate recoverable vs hard lock | Check `succeeded` vs `failed` separately |
| SMART/dumpe2fs | modules/storage_smart.sh | Fails without root | Add `sudo -n` fallback |

## MISSING MODULES (Critical)

### 1. Audio DSP (SOF) — Most Common Software Failure
Pattern: `snd_sof_amd_vangogh: IPC error -22` after suspend/resume
Refs: SteamOS #1376, #2313; kernel patches by Cristian Ciocaltea (Collabora)
Diagnosis: `dmesg | grep -E 'snd_sof|DSP panic|ipc tx.*failed.*-22|Failed to setup widget'`

### 2. Core Dump / Crash Report Analysis
Pattern: `systemd-coredump[PID]: Process * dumped core` — SIGTRAP (steamwebhelper), SIGABRT (gamescope)
Diagnosis: `coredumpctl list` + `coredumpctl info` — count crashes, find SIGTRAP/SIGSEGV
Refs: steam-for-linux #11861, #12973

### 3. WiFi Firmware (ath11k) Failure After Resume
Pattern: `ath11k` interface disappears after resume
Diagnosis: Check `ip link` for `wlan0` presence + `dmesg | grep ath11k`
Refs: SteamOS #2313

### 4. Gamescope Session Health
Pattern: `gamescope-wl: core dump`, `vkAllocateDescriptorSets failed`
Diagnosis: `coredumpctl | grep gamescope` + `journalctl -u gamescope-session`
Refs: gamescope #1808, #1953

### 5. Memory Pressure / OOM
Pattern: GPU job timeouts at ~14GB total allocation, swap thrashing
Diagnosis: `/proc/meminfo` MemAvailable, `vmstat` swap i/o, `dmesg | grep -i oom`
Refs: Bugnet crash reporting guide

### 6. Steam Client Logs
Pattern: steamwebhelper crashes in `/tmp/dumps/`
Diagnosis: Check `/tmp/dumps/`, count crash dumps, check `steam_stdout.txt`
Refs: SteamOS wiki

### 7. MicroSD Card / mmc Errors
Pattern: `EXT4-fs error (device mmc*)`, `mmc0: cannot verify signal`
Diagnosis: `dmesg | grep -iE 'mmc|sdhci'`

### 8. ACPI Sleep/Wake State
Pattern: Fan 0 RPM after resume when battery at charge limit
Diagnosis: `journalctl -b 0 | grep -i 'fancontrol\|PM: suspend\|PM: resume'`
Refs: SteamOS #2475

### 9. DXVK/VKD3D Hang State
Pattern: Page faults `GCVM_L2_PROTECTION_FAULT_STATUS`, `CB/DB/CPF client ID`
Diagnosis: `dmesg | grep -i 'page fault\|VM_L2\|UTCL2'`
Refs: DXVK #5439

## V2.0 Module Priority

| Module | Priority | Rationale |
|---|---|---|
| audio_sof.sh | Critical | #1 software failure |
| coredump_analysis.sh | Critical | Primary crash diagnostic |
| memory_swap.sh | High | OOM triggers GPU cascade |
| wifi_firmware.sh | High | Coupled with audio crash |
| gamescope_session.sh | High | Session restart detection |
| steam_client_logs.sh | Medium | /tmp/dumps/ analysis |
| acpi_pm_state.sh | Medium | Fan/post-resume failures |
| mmc_sd_card.sh | Medium | SD ext4 corruption |
| dxvk_page_fault.sh | Low | Advanced GPU hang diff |

## v1.0.1 Fixes (existing modules)

- gpu_apu.sh: dmesg → `journalctl -k -b 0 --priority=err`
- gpu_apu.sh: Separate recoverable vs hard lock
- storage_smart.sh: Add `sudo -n` fallback
- fs_integrity.sh: Add `sudo -n` fallback
