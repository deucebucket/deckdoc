# Physical LCD blackout with live rendering

Status: persistent mitigation deployed and verified across a reboot plus launcher-to-title transition;
physical-panel confirmation and long-duration suspend/resume recurrence testing remain open.

## Symptom

On a Jupiter LCD Steam Deck, the internal panel intermittently became visually black during a
foreground Vulkan workload. Audio continued and the backlight remained visibly on. The same behavior
had occurred outside that workload, so an application-only explanation was insufficient.

The incident was an LCD-output failure, not an application crash:

- the foreground process continued at roughly 38–40 FPS and continued receiving input;
- Steam Game Recording contained a fully visible, advancing scene during the physical blackout;
- Gamescope remained active and no Vulkan device-loss or guest-exit event appeared;
- the kernel logged no correlated amdgpu reset, ring timeout, OOM kill, or thermal critical event.

## Panel and DRM evidence during the failure

| Check | Observed state |
|---|---|
| Internal connector | `eDP-1` connected and enabled |
| EDID | readable, 128 bytes |
| Backlight | requested and actual brightness nonzero; `bl_power=0` |
| CRTC | active at native `800x1280` panel timing, 60 Hz |
| Foreground surface | 1280×800 |
| External DP | disconnected |
| Hardware scanout | full-screen base plane plus full-screen alpha overlay plane |
| DRM ownership | Gamescope owned the physical card; expected render clients only |

This combination is recorded by DeckDoc as:

```text
BLACKOUT_SIGNATURE: LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP
```

The recording proves the composed content existed upstream of physical scanout. The live eDP,
backlight, and CRTC state proves the kernel still believed the panel pipeline was active. The failure
boundary is therefore after frame production/capture and at or below the display-plane commit,
kernel DCN/eDP scanout, panel timing/TCON, or physical panel-link layer.

That boundary is strong evidence, not proof that the panel hardware is healthy. A cable, panel/TCON,
or kernel display-engine fault can all leave software state apparently valid.

## Safe mitigation and result

The live session ran:

```bash
gamescopectl composite_force 1
```

Gamescope describes this convar as forcing composition and never using direct scanout. After the
change, the overlay plane detached and DRM showed one active full-screen framebuffer plane. Gamescope,
the foreground process, audio, and its control socket remained alive.

The same policy is persisted for future Game Mode sessions in:

```text
~/.config/gamescope/scripts/99-deckdoc-display-stability.lua
```

with an initial assignment plus a documented Gamescope frame hook:

```lua
gamescope.convars.composite_force.value = true
gamescope.hook("OnPostPaint", function()
    if not gamescope.convars.composite_force.value then
        gamescope.convars.composite_force.value = true
    end
end)
```

This changes plane selection only. It does not change brightness, panel power, refresh rate, display
resolution, TDP, clocks, charging, firmware, or GPU power state.

### Launcher-to-game lifecycle finding

Live validation found one lifecycle gap in the first version of the policy. The Ryudeck library was
single-plane after `gamescopectl composite_force 1`, but activating the title's Vulkan surface
restored three full-screen scanout planes. Running the same convar command again immediately reduced
DRM state to one plane while the title kept rendering at about 60 FPS. This rules out an ineffective
convar and shows that a per-application transition can overwrite a one-time startup assignment.

The persistent policy therefore checks the convar from Gamescope's documented `OnPostPaint` hook and
reasserts it only after another component clears it. The hook makes no panel, power, timing, or clock
write.

The first persistence attempt also exposed a path-specific failure: SteamOS 3.8.14 logged that its
user script root is `~/.config/gamescope/scripts/`; a file directly under `~/.config/gamescope/` was
silently skipped. DeckDoc now installs into the logged script root and tests that exact destination.

### Reboot and title-transition verification (2026-07-21)

The corrected policy survived an orderly reboot and passed the lifecycle test that failed the first
version:

- Gamescope logged that it loaded
  `/home/deck/.config/gamescope/scripts/99-deckdoc-display-stability.lua` as script id 12, with no Lua
  error.
- Gamescope later logged `DeckDoc restored composite_force after an application transition.`, proving
  that the hook observed and repaired the transition-time convar reset.
- The Steam library, Ryudeck library, and foreground Vulkan title each retained one active DRM plane:
  `plane-3`, `crtc-0`, and `plane_mask=8` at the native 800x1280 panel timing.
- Root KMS capture produced a native 1280x800 advancing title frame at approximately 53--60 FPS after
  the transition. The foreground process and MangoApp remained alive, and the boot had no coredump.

This verifies script discovery, hook execution, native resolution, and scanout-plane containment. It
does not verify emitted LCD pixels; a person looking at the physical panel must still confirm that
the same frame is visible there.

### Post-mitigation diagnostic integrity

The first healthy-state DeckDoc report revealed several reporting errors that could obscure this
result. They were corrected and covered by fixtures before the final snapshot:

- 18 retained pre-fix MangoApp coredumps are now explicitly historical; the current boot reports zero
  MangoApp dumps, zero SIGABRT, zero SIGSEGV, and an active MangoApp service.
- Steam's normal `/tmp/dumps/settings.dat` and bookkeeping directories are no longer counted as crash
  dumps. The current boot has zero actual minidump/core files.
- Root reports route Gamescope, PipeWire, and Steam-path reads through the active Game Mode user rather
  than `/root`; the final report sees a responsive internal Gamescope backend, real audio sinks, and
  the actual Steam compatibility tree.
- Thermal severity follows each sensor's exported hwmon threshold. A sensor without a published
  critical point can be recorded as above 90 C, but DeckDoc no longer calls 90 C a hardware trip.
- Journal matching strips the `steamdeck` hostname before looking for Steam process failures, avoiding
  false matches against unrelated messages containing a later word such as `tx_abort`.

The corrected running-title sample held at about 83 C CPU, 75--76 C GPU, and 6,200 RPM for 30 seconds
after brief 90--94 C load spikes. There was no thermal trip, GPU reset, process exit, or plane-policy
loss. This temperature history is worth tracking, but it did not correlate with the original blackout,
which occurred at lower measured temperatures.

## Suspend/resume and thermal context

The affected boot contained three deep suspend cycles and all three completed (`PM: suspend exit`).
The blackout occurred about 45 minutes after the last resume, not at the resume boundary. Repeated
`Failed to add display topology, DTM TA is not initialized` messages appeared at boot/resume and are
retained as external-display-topology evidence, but they do not prove the internal-LCD cause.

At the incident, measured temperatures were below critical shutdown territory (APU sensor about
82°C, GPU about 72°C, battery about 33°C, NVMe about 45°C). Earlier high-temperature warnings on the
same boot describe workload stress history, not a correlated thermal trip.

## Docked-resolution finding

The incident itself occurred at the correct 1280×800 Game Mode and XWayland resolution. Historical
Steam configuration backups did contain a global 1920×1080 game resolution, while the current global
setting is `Default`. That old global override can explain occasional small UI/icons or a retained
1080p virtual desktop after dock transitions, but it does not explain this blackout: the live CRTC,
framebuffer, Gamescope command line, and application windows were all 800p.

DeckDoc should report this distinction and must not silently edit Steam's VDF files while Steam is
running.

## Ruled-out leading causes

- **Foreground application crash:** rendering, recording, audio, and input continued.
- **Decky Loader/plugin injection:** installed plugins did not own DRM, inject the foreground process,
  or log a correlated failure.
- **Rogue second renderer:** DRM client ownership was expected.
- **GPU reset/hang:** no correlated reset, ring timeout, device loss, or fence failure occurred.
- **Current global 1080p override:** current Steam and display state were 1280×800.
- **Backlight-off event:** actual brightness was nonzero and `bl_power=0`.

### Decky-specific audit

Decky was not assumed absent: the system `plugin_loader.service` was active and its backend processes
were inspected. The installed set was CSS Loader, SteamGridDB, Decky-Framegen, and Free Loader.
Decky-Framegen was the only member with a plausible graphics association, but its backend contains no
background Gamescope/display action: it only prepares or removes per-game Windows compatibility files
after an explicit frontend request. Its current-boot log contained only `Framegen plugin loaded`.

The running native foreground process had no `/home/deck/homebrew` mapping and no Decky/framegen Vulkan
layer or preload environment. Its only `LD_PRELOAD` entries were Steam's normal 32-bit and 64-bit game
overlay renderers. CSS Loader's activity was confined to Steam browser CSS injection. None of the Decky
processes owned the DRM card or emitted a current-boot crash correlated with the blackout.

This rules Decky out for the captured incident without globally disabling it. A future blackout should
still record the current plugin inventory and logs because a later plugin update or a per-game mod could
change that result.

## Remaining validation

- Confirm physical LCD visibility in the rebooted, title-running one-plane session.
- Exercise multiple sleep/resume cycles and dock/undock transitions with forced composition active.
- Track recurrence duration. If blackouts continue in a verified single-plane session, preserve the
  DRM state and escalate the kernel/panel-link/TCON branch rather than changing power controls.
- Compare behavior after future SteamOS/gamescope updates; remove the policy only after a controlled
  recurrence test.

## Primary references

- Gamescope source and configuration: https://github.com/ValveSoftware/gamescope
- Gamescope direct-scanout pipeline discussion: https://github.com/ValveSoftware/gamescope/issues/1368
- SteamOS backlight-on black-screen report: https://github.com/ValveSoftware/SteamOS/issues/1324
- SteamOS no-reset intermittent LCD-black report: https://github.com/ValveSoftware/SteamOS/issues/2632
- SteamOS GPU-reset black-screen comparison case: https://github.com/ValveSoftware/SteamOS/issues/1015
