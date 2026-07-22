# Module reference

All diagnostic modules run in parallel. Output order in the master report is filename/glob order, not
incident order; use the timestamps inside journal excerpts.

## Hardware and kernel

### `gpu_apu.sh` -> `module_gpu.log`

Reads current-boot amdgpu errors, reset outcomes, historical dmesg matches, CPU frequency, and the
active GPU SCLK state. A low instantaneous frequency can be normal at idle; correlate it with sustained
poor performance and load. A failed/skipped GPU reset is more serious than a successful recovery.

Limitations: fixed CPU/GPU sysfs paths, no load-normalized trend sample, and current journal access may
require root.

### `battery_pmic.sh` -> `module_battery.log`

Reads the first available `BAT1`/`BAT0` status, capacity, voltage, current, charge, and energy nodes.
The raw 6.6 V warning is an implementation threshold, not a model-independent battery diagnosis.

Limitations: no USB-PD contract, charger, cell-balance, or model-aware threshold logic.

### `thermal_fan.sh` -> `module_thermal.log`

Inventories all hwmon temperature/fan inputs. It compares temperature with each sensor's exported
`max`/`crit` threshold. Above 90 C without an exported threshold is reported as a high observation,
not a hardware trip. Exported thresholds above 200 C are treated as invalid sentinel values and ignored.

Limitations: a 0 RPM export needs context; the fan may legitimately be stopped at low load or the
sensor may not be the system fan.

### `storage_smart.sh` -> `module_storage.log`

Runs NVMe SMART health and selected warning/error fields through `smartctl` for `/dev/nvme0n1`.

Limitations: fixed device path; USB, SD, or additional NVMe devices are not SMART-scanned.

### `fs_integrity.sh` -> `module_fs.log`

Reads BTRFS device statistics for mounted BTRFS filesystems and ext4 superblock state for mounted ext4
devices. Nonzero BTRFS counters are persistent and need device/time context.

Limitations: read-only mounted-state inspection, not an offline `fsck`, scrub, or repair.

## Session, display, audio, and network

### `display_blackout.sh` -> `module_display.log`

Inventories DRM connectors, identifies a connected eDP panel, reads EDID size, backlight, deduplicated
DRM CRTC/plane state, Gamescope backend data, selected current/recent kernel warnings, and sleep mode.
With `--display-black`, it can emit:

- `LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP` when eDP/EDID, backlight, and CRTC remain live;
- `PANEL_OR_MODESET_STATE_INCOMPLETE` when a required state is missing.

Limitations: root/debugfs required for planes; software cannot observe physical pixels; LCD backlight
logic is not directly portable to OLED.

### `dock_usb_c.sh` -> `module_dock.log`

Inventories USB topology, driver-exported Type-C roles/partner/PD/DisplayPort Alt Mode, USB/PD supply
telemetry, external DRM connectors, likely USB Ethernet, and current-boot xHCI/UCSI/Type-C/display-link
errors. It emits a correlation signature when a topology reset/disconnect and selected dock-path error
coexist.

Limitations: exported voltage/current are instantaneous system telemetry, not electrical certification;
many docks expose no rail or PD fields; deliberate unplug events are normal without aligned errors.

### `audio_sof.sh` -> `module_audio.log`

Searches current-boot kernel errors for SOF DSP panic, IPC failures/timeouts, firmware state, and resume
pipeline errors. It also lists ALSA cards/playback devices and the active user's PipeWire nodes.

Limitations: log matching is broader than one codec; absence may be a user-session/permission issue.

### `wifi_firmware.sh` -> `module_wifi.log`

Finds common `wlanN` or `wl*` interfaces, reports link state/info, searches current-boot kernel records
for bounded ath11k/ath12k/iwlwifi/rtw88/b43/brcmfmac driver errors and firmware versions, and lists a
PCI network device. It also flags Wi-Fi and SOF failures retained in the same boot for timestamp review.

Limitations: a down interface is not proof of a firmware crash; driver pattern coverage is incomplete;
no gateway, DNS, captive-portal, throughput, or Bluetooth test.

### `gamescope_session.sh` -> `module_gamescope.log`

Separates Gamescope crashes from normal session-end dumps, counts current-boot starts/restarts using the
active user service's `NRestarts` where available, searches for Vulkan and Wayland errors, and classifies
the MangoApp `/proc/<pid>/fdinfo` permission abort.

Limitations: unit names and per-user journal access vary across SteamOS releases.

### `acpi_pm_state.sh` -> `module_acpi.log`

Counts current-boot suspend entries and resume exits, lists recent cycles, searches for PM/PCI failures,
fan-controller warnings, wake sources, and the presence of a battery charge-limit interface.

Limitations: log proximity matters; a fan warning anywhere after any suspend is not automatically a
resume-caused fan failure.

## Crashes, memory, Steam, and storage media

### `coredump_analysis.sh` -> `module_coredump.log`

Aggregates retained dumps by executable; separates current-boot records/signals; classifies all,
steamwebhelper, Gamescope, and Wine/Proton crashes from the last 24 hours; distinguishes
historical/current MangoApp crashes; and reports storage use. A helper `SIGTRAP` is reported separately
from a Gamescope `SIGABRT`/`SIGSEGV` so the two are not treated as equivalent failures.

Limitations: coredump retention policy and permissions affect visibility; core presence proves a process
terminated by a signal, not the root cause.

### `memory_swap.sh` -> `module_memory.log`

Reports RAM/swap totals and usage, current-boot OOM/page-allocation events, swap configuration, and a
short `vmstat` sample. Current implementation warns below 1 GB available, becomes critical below 512 MB,
and flags swap use above 50%. Cumulative pages swapped since boot are history; only the live sample
indicates current swap traffic.

Limitations: one short sample cannot reconstruct memory pressure at a past incident.

### `steam_client_logs.sh` -> `module_steam.log`

Counts actual `.dmp`, `.mdmp`, `.core`, and `.crash` files under `/tmp/dumps`, bounds current-boot and
last-24-hour steamwebhelper crash rates, scans Steam stdout, searches current-boot Steam errors, and
inventories Proton compatibility prefixes/lock files for the active user.

Limitations: error-word counts contain false positives; a lock file is not automatically corruption.

### `probe_incidents.sh` -> `module_probe.log`

Reports whether the optional continuous probe is installed/active and ingests the latest incident's
metadata, trigger, volatile snapshot, and bounded journal tail. No probe means a normal “not installed”
result, not a diagnostic failure.

Limitations: incidents are unredacted; journal persistence and a functioning kernel/storage path are
required; signature proximity is not causation. See [Continuous incident probe](Continuous-Incident-Probe.md).

### `mmc_sd_card.sh` -> `module_mmc.log`

Lists mmc devices and mounts, searches mmc/SDHCI and ext4-on-mmc errors, finds selected TRIM failures,
and reports size/read-only state.

Limitations: no offline filesystem repair, counterfeit-card capacity test, or flash wear assessment.

### `dxvk_page_fault.sh` -> `module_dxvk.log`

Classifies selected AMD VM/UTCL2 page-fault client IDs (CB, DB, CPF, CPD), mapping/walker errors,
possible process attribution, ring timeouts, and GPU-reset outcome. The module title says DXVK/VKD3D
correlation because those are hypotheses to correlate, not conclusions derived from a kernel client ID.

Limitations: kernel log labels do not uniquely identify DXVK/VKD3D or prove hardware failure.

## Remediation modules

### `rem_audio_sof.sh`

Triggered by a current-boot DSP panic or IPC `-22`; backs up audio state, reloads
`snd_sof_amd_vangogh`, and verifies ALSA cards plus post-cursor errors. It is dispatched by `--fix`.

### `rem_display_blackout.sh`

Requires an explicitly declared physical-black symptom, live Gamescope, connected eDP, readable EDID,
and nonzero backlight. It backs up DRM state, applies `gamescopectl composite_force 1`, optionally
installs one user Lua policy, and reports `PARTIAL` until a human confirms the image.

Read [Safe remediation policy](Safe-Remediation-Policy.md) before extending either module.
