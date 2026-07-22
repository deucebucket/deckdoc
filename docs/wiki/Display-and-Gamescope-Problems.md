# Display and Gamescope problems

“Black screen” is a symptom shared by several different failures. First determine whether the Deck,
the game, Gamescope, the GPU, and the physical panel are still alive.

## Symptom classes

| Symptom | Leading branches |
|---|---|
| Backlight on, sound/input/rendering continue | physical scanout, plane transition, eDP/TCON/cable |
| Backlight off or brightness actually zero | panel/backlight/power/modeset state |
| Game frozen and sound loops/stops | game, Proton, GPU timeout/reset, OOM |
| Returned to Library/login repeatedly | game or Gamescope crash/session restart |
| External monitor works, internal panel fails | eDP/panel-specific path |
| Internal panel works, docked display fails | dock/cable/monitor/DP Alt Mode/modeset |
| Desktop Mode wake only | KDE/Wayland/resume/display state |
| First power-on after days off; immediate second boot works | cold-start/firmware/panel initialization branch |

The last row has its own [long-off startup blackout protocol](Black-Screen-After-Long-Shutdown.md). It is
not evidence for the Gamescope forced-composition fix, especially when reported on Windows or OLED.

## Capture while black

From SSH or a usable terminal:

```bash
sudo ./deckdoc.sh --display-black
```

Record whether:

- the backlight is visibly on;
- audio and controls continue;
- a recording/stream shows advancing frames;
- an external display changes the symptom;
- the event followed wake, app transition, overlay toggle, dock/undock, or update.

Do not change brightness, write `bl_power`, force a GPU reset, or suspend again before capture.

## Interpret the display section

### `LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP`

DeckDoc found connected eDP, a readable EDID, nonzero LCD backlight, and an active CRTC while the user
declared the panel physically black. When a recording also shows valid frames and there is no matching
GPU/app crash, the failure boundary moves downstream toward plane commit, DCN/eDP scanout, panel timing,
TCON, cable, or panel.

Multiple planes are not an error by themselves. They justify a reversible forced-composition test only
for this complete signature. Follow [Screen black while sound works](Steam-Deck-Black-Screen-Sound-Working.md).

### `PANEL_OR_MODESET_STATE_INCOMPLETE`

At least one panel prerequisite failed. Forced composition is not automatically indicated. Inspect the
missing eDP, EDID, backlight, or CRTC state and correlate kernel modeset/reset errors.

### GPU or Gamescope evidence

- `amdgpu_job_timedout`, reset, or VM fault: use [Crashes, GPU and memory](Crashes-GPU-and-Memory.md).
- current-boot Gamescope core dump or repeated restart: inspect the crash/session branch.
- MangoApp `FDINFO_PERMISSION_ABORT`: an overlay helper failed; do not automatically label it a
  compositor crash or panel failure.

## Docked/external display branch

DeckDoc lists connectors but does not diagnose the whole dock chain. Preserve both docked and undocked
reports, then test one known-good variable at a time: monitor input, cable, adapter/dock, USB-C port,
resolution/refresh setting, and power supply. A successful undocked test narrows the path but does not
identify which dock component failed.

Use Valve's [Docking the Steam Deck](https://help.steampowered.com/en/faqs/view/4C18-08B5-DEC9-3AF4)
guidance for official first steps.

## Escalate when

- the panel is black with missing EDID/eDP or zero backlight;
- forced composition does not help or one plane was already active;
- the issue recurs across clean boots and channels with third-party tools disabled;
- an external/internal split strongly suggests a hardware path;
- there are GPU reset failures, persistent display-engine errors, or physical damage.

Attach the relevant display, GPU, Gamescope, coredump, ACPI, and exact incident-time excerpts. Linux's
amdgpu documentation recommends dmesg and pre/post-reproduction display debug state for DC problems.

## References

- [Linux kernel: AMD Display Core debug tools](https://docs.kernel.org/gpu/amdgpu/display/dc-debug.html)
- [Gamescope repository](https://github.com/ValveSoftware/gamescope)
- [Gamescope direct-scanout/force-composite investigation #1368](https://github.com/ValveSoftware/gamescope/issues/1368)
- [SteamOS backlight-on black screen #1324](https://github.com/ValveSoftware/SteamOS/issues/1324)
- [SteamOS intermittent LCD-black report #2632](https://github.com/ValveSoftware/SteamOS/issues/2632)
- [SteamOS GPU-reset comparison case #1015](https://github.com/ValveSoftware/SteamOS/issues/1015)
