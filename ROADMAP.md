# DeckDoc v3.0 — Roadmap: Diagnosis → Remediation

v2.0 added 9 new diagnostic modules covering software/OS failure modes. v3.0 shifts focus from **detecting** failures to **automatically remediating** them — and building the feedback loop that tells you whether the fix worked.

## Implemented (v2.0)

| Module | Detects | Status |
|---|---|---|
| gpu_apu.sh | CPU 400MHz lock, GPU 200MHz SCLK lock, GPU reset outcome | Delivered |
| battery_pmic.sh | Deep discharge, trickle-charge, cell degradation | Delivered |
| thermal_fan.sh | Thermal trip > 90°C, fan failure (0 RPM) | Delivered |
| storage_smart.sh | NVMe SMART health (sudo fallback) | Delivered |
| fs_integrity.sh | BTRFS corruption, EXT4 state (sudo fallback) | Delivered |
| audio_sof.sh | SOF DSP panic, IPC error -22, pipeline resume failure | Delivered |
| coredump_analysis.sh | systemd-coredump crash counts, signal profiling | Delivered |
| wifi_firmware.sh | ath11k/iwlwifi firmware crash, wlan0 state | Delivered |
| gamescope_session.sh | Session restarts, Vulkan descriptor failures | Delivered |
| memory_swap.sh | OOM events, memory pressure, swap analysis | Delivered |
| steam_client_logs.sh | /tmp/dumps/ crash inventory, stdout errors | Delivered |
| mmc_sd_card.sh | mmc driver errors, ext4 corruption on SD | Delivered |
| acpi_pm_state.sh | Suspend/resume failures, fan-after-wake bug | Delivered |
| dxvk_page_fault.sh | GPU page fault classification (CB/DB/CPF) | Delivered |

## Delivered (v3.0)

| Module | Action | Status |
|---|---|---|
| **rem_audio_sof.sh** | Reload snd_sof_amd_vangogh, verify aplay recovery, PRE_CHECK/BACKUP/EXECUTE/VERIFY/REPORT lifecycle | Delivered |
| deckdoc.sh --fix flag | Runs remediation modules after diagnostics, requires explicit flag | Delivered |

## v3.0 — Remediation Modules (Remaining)

### P0 — Must Have

| Module | Trigger | Remediation Action |
|---|---|---|
| **rem_wifi_firmware.sh** | wifi_firmware.sh: wlan0 DOWN or firmware crash | `sudo modprobe -r ath11k_pci && sudo modprobe ath11k_pci`, then verify `ip link show wlan0` shows UP. |
| **rem_coredump_cleanup.sh** | coredump_analysis.sh: >100 dumps | `sudo rm /var/lib/systemd/coredump/*.zst` older than 30 days, report freed space. |
| **rem_gpu_reset.sh** | gpu_apu.sh: GPU reset failed (hard lock) | Attempt `sudo sysfs` power cycle of GPU via `device_power_state`, fall back to advising full reboot. |

### P1 — Should Have

| Module | Trigger | Remediation Action |
|---|---|---|
| **rem_oom_protection.sh** | memory_swap.sh: MemAvailable < 1GB | Recommend closing games, list top memory consumers by %mem. Non-destructive advisory only. |
| **rem_fan_recovery.sh** | acpi_pm_state.sh + thermal_fan.sh: fan 0 RPM after resume | `sudo systemctl restart jupiter-fan-control`, verify RPM returns in 10s. |
| **rem_steam_cache.sh** | steam_client_logs.sh: shader cache errors | `rm -rf ~/.local/share/Steam/steamapps/shadercache/*` with user confirmation prompt. |
| **rem_btrfs_scrub.sh** | fs_integrity.sh: BTRFS corruption > 0 | `sudo btrfs scrub start /` and report progress. |

### P2 — Nice to Have

| Module | Trigger | Remediation Action |
|---|---|---|
| **rem_battery_calibrate.sh** | battery_pmic.sh: `energy_full` / `energy_full_design` ratio < 60% or voltage desync | Guide user through full discharge/charge calibration cycle. |
| **rem_sd_repair.sh** | mmc_sd_card.sh: EXT4 errors on mmc | `sudo umount /run/media/* && sudo fsck.ext4 -y /dev/mmcblk*p*` with confirmation. |
| **rem_gamescope_restart.sh** | gamescope_session.sh: >3 session restarts | Kill stale gamescope processes, restart session cleanly. |
| **rem_dxvk_cache.sh** | dxvk_page_fault.sh: CB/DB page faults in specific game | Clear DXVK state cache for that title ID. |

### Non-Functional Improvements

- `--fix` flag: `./deckdoc.sh --fix` runs all remediation modules after diagnosis
- `--watch` mode: Run in a loop with configurable interval for thermal/memory trend monitoring
- JSON output: Machine-parseable output alongside human-readable logs
- USB bootable mode: Run from recovery media to diagnose unbootable SteamOS installations
- Report upload: Optional `gh issue` creation with diagnostic output attached

## Architecture for Remediation

Each remediation module follows a strict lifecycle:

```
1. PRE_CHECK  — Verify the trigger condition still exists (race-safe)
2. BACKUP     — Snapshot state before modification (if destructive)
3. EXECUTE    — Perform the remediation action (with timeout guard)
4. VERIFY     — Confirm the fix worked (re-check trigger condition)
5. REPORT     — Log outcome: SUCCESS, FAILED, or PARTIAL
```

Remediation modules never run automatically — they require `--fix` flag or explicit invocation.

## Completed (v1.0.1)

- gpu_apu.sh: dmesg → `journalctl -k -b 0 --priority=err`
- gpu_apu.sh: Separate recoverable vs hard lock classification
- storage_smart.sh: Add `sudo -n` fallback
- fs_integrity.sh: Add `sudo -n` fallback
