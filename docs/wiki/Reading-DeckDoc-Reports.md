# Reading DeckDoc reports

DeckDoc reports observations from several time scopes and privilege contexts. Interpretation is about
correlation, not counting the words `WARNING` and `CRITICAL`.

## Report structure

The timestamped master report contains all module sections. Per-module logs make it easier to share or
compare one subsystem.

| Log | Module |
|---|---|
| `module_gpu.log` | GPU/APU |
| `module_battery.log` | Battery/PMIC |
| `module_thermal.log` | Thermal/fan |
| `module_storage.log` | NVMe SMART |
| `module_fs.log` | Filesystem integrity |
| `module_audio.log` | SOF/ALSA/PipeWire audio |
| `module_display.log` | eDP/backlight/CRTC/DRM/Gamescope display path |
| `module_coredump.log` | systemd core dumps |
| `module_wifi.log` | Wi-Fi interface and firmware |
| `module_gamescope.log` | Gamescope and MangoApp session health |
| `module_memory.log` | RAM, swap, and OOM |
| `module_steam.log` | Steam dumps/logs and Proton prefixes |
| `module_mmc.log` | microSD/mmc |
| `module_acpi.log` | suspend/resume |
| `module_dxvk.log` | GPU VM/page-fault classification |

## Confidence ladder

- **Observation:** the report read a value or log entry.
- **Time-correlated:** its timestamp aligns with the incident.
- **Cross-correlated:** an independent subsystem agrees.
- **Likely cause:** evidence supports one branch more strongly than alternatives.
- **Confirmed recovery:** a narrow action changed the signature and the user-observed symptom.
- **Root cause:** requires enough evidence to explain why the failure occurred, not just how it was
  recovered.

For example, a game becoming visible after forced composition confirms that the presentation-path
change recovered that occurrence. It does not by itself prove whether the underlying defect was in
Gamescope, DRM/DCN, panel timing, the cable, or the panel.

## Current boot versus retained history

`journalctl -b 0` is the current boot. `coredumpctl` can retain crashes from older boots, and the
display module intentionally looks back seven days for selected warnings. A retained crash is useful
history but should not be reported as active instability unless it matches the incident time.

### Crashes and retained history

The core-dump module separates:

- historical counts by executable;
- current-boot dump count;
- current-boot `SIGTRAP`, `SIGABRT`, and `SIGSEGV` counts;
- historical and current-boot MangoApp counts;
- disk space used by retained dumps.

`SIGTRAP` from `steamwebhelper` is not automatically harmless, but it is not equivalent to a
Gamescope `SIGSEGV`. Read the executable, signal, boot, and surrounding journal together.

## Severity is contextual

- `CRITICAL` means the matched condition can represent serious failure, not that every surrounding
  symptom has the same cause.
- A stopped fan is more urgent when temperature is rising after resume than when the system is off or
  a sensor is not the Deck fan.
- A high temperature without an exported hardware critical threshold is an observation, not proof of
  thermal shutdown.
- A Wi-Fi interface marked `DOWN` can be administratively disabled; a firmware crash in the same
  window is stronger evidence.
- More than one active DRM plane is normal by itself. It becomes relevant to the validated blackout
  only when rendering, eDP, EDID, backlight, and CRTC remain live while the physical panel is black.

## Empty, missing, and inaccessible

The following are different:

- `No ... detected` after a successful read;
- `command not found` because an optional dependency is absent;
- `permission denied` because the report lacked access;
- a path not existing because the model/kernel exports a different interface;
- a per-user service being queried as the wrong user.

DeckDoc routes several Gamescope, PipeWire, Steam, and user-journal reads through the active session
user during a root run. If session-user resolution fails, treat those sections as incomplete.

## Strong correlation examples

### Audio after resume

SOF IPC error `-22` or `DSP panic` + missing ALSA card + missing PipeWire sink + a nearby resume event
supports an audio-DSP failure. A muted sink with healthy cards does not.

### GPU or game crash

`amdgpu_job_timedout` + a reset result + a matching game/Gamescope core dump + the same incident time
supports a GPU-driven crash chain. A historical GPU reset days earlier does not explain today's exit.

### Storage

mmc I/O errors + ext4 errors for the same `mmcblk` device + game file corruption strongly supports an
SD path problem. A game validation failure without device/filesystem errors can have other causes.

## Compare reports

Keep one healthy baseline and one failure report. Compare exact sections instead of entire files:

```bash
diff -u healthy-module_audio.log failed-module_audio.log
```

Do not publish a raw report until it has been reviewed for private data.
