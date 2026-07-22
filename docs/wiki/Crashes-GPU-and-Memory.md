# Crashes, GPU hangs, page faults, and memory pressure

A game closing, a frozen frame, a black screen, and a complete session restart may look similar but
leave different evidence. Use the incident time to correlate the game/Steam process, Gamescope, kernel
GPU, memory, and core-dump layers.

## Capture

```bash
sudo ./deckdoc.sh
```

Read these together:

- `module_coredump.log`
- `module_steam.log`
- `module_gamescope.log`
- `module_gpu.log`
- `module_dxvk.log`
- `module_memory.log`
- `module_thermal.log`

The core-dump module separates retained history, the current boot, and a rolling last-24-hour window.
It breaks that recent window into steamwebhelper, Gamescope, and Wine/Proton families. A helper
`SIGTRAP` needs UI/incident correlation; a Gamescope `SIGABRT` or `SIGSEGV` is a different, higher-value
session failure signal.

## Crash branches

### Process crash without GPU reset

A current-boot `SIGSEGV`/`SIGABRT` for the game, Wine/Proton, Steam helper, MangoApp, or Gamescope
identifies the process that terminated. It does not alone explain why. Check surrounding logs and
whether only one title reproduces.

### Gamescope/session crash

A current Gamescope dump, Vulkan descriptor failure, or repeated session restart can return the user
to Library/login or blank the whole session. A `gamescope-wl` dump recorded only at normal session exit
may be cosmetic; time and restart count matter.

The MangoApp `FDINFO_PERMISSION_ABORT` is a separate helper signature. Do not call it a GPU or panel
failure without additional evidence.

### AMD GPU timeout/reset

`amdgpu_job_timedout`, ring timeout, `VRAM is lost`, and reset messages can explain a frozen game or
session. Classify the outcome:

- reset succeeded: the driver recovered, but clients may still exit;
- reset failed/skipped: higher risk of a hard lock and orderly reboot may be required;
- no reset: inspect process crashes, VM faults, memory, and display-specific branches.

DeckDoc does not trigger the kernel's debugfs GPU-reset control because it discards in-flight work and
can destroy the failure state.

### GPU VM/page fault

The DXVK/VKD3D module recognizes selected `GCVM_L2_PROTECTION`, `UTCL2`, CB/DB/CPF/CPD, mapping, and
walker strings. These labels classify where the kernel reported a fault; they do not uniquely prove a
specific translation layer or hardware defect. Correlate process attribution, game/API, Mesa/Proton
version, and whether other titles reproduce.

### Memory pressure/OOM

Current-boot OOM-killer/page-allocation messages are strong evidence. Below 1 GB `MemAvailable` is a
warning and below 512 MB is critical. Swap over 50% and cumulative swapped pages are historical context;
live `vmstat` swap I/O is stronger evidence of current pressure. None reconstructs a past incident by
itself.

The Deck's memory is shared with graphics, so pressure can cascade into stutter, allocation failure,
or GPU/client instability. Close the workload and preserve the process/memory context; do not clear
arbitrary caches as a first response.

## One-title versus system-wide

| Scope | First hypotheses |
|---|---|
| One title/save/scene | game bug, mod, launch option, Proton/API path, corrupt title data |
| All D3D12 but not Vulkan/D3D11 | VKD3D/driver/API path |
| All titles after an update | SteamOS/Mesa/Gamescope/Proton regression |
| Desktop and games | compositor, kernel/GPU, memory, thermal, hardware |
| Only after wake | device/resume/firmware state |

Change one variable at a time: remove per-game modifications, select a known-good Proton version, verify
game files, or test a clean boot. Keep the exact result.

## Escalate when

- GPU reset fails or the Deck hard-locks repeatedly;
- multiple unrelated titles reproduce on a clean, updated system;
- page faults/timeouts recur at ordinary temperatures and memory use;
- filesystem/SMART errors accompany crashes;
- a core dump and logs identify a reproducible upstream component regression.

## References

- [systemd coredumpctl](https://www.freedesktop.org/software/systemd/man/latest/coredumpctl.html)
- [Linux kernel AMDGPU debugfs](https://docs.kernel.org/gpu/amdgpu/debugfs.html)
- [Gamescope repository](https://github.com/ValveSoftware/gamescope)
- [DXVK issue tracker](https://github.com/doitsujin/dxvk/issues)
- [vkd3d-proton issue tracker](https://github.com/HansKristian-Work/vkd3d-proton/issues)
