# Physical LCD blackout with live rendering

Status: mitigation deployed; long-duration and suspend/resume recurrence testing remains open.

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
write. It must be loaded by a new Game Mode session before lifecycle persistence is considered
verified.

The first persistence attempt also exposed a path-specific failure: SteamOS 3.8.14 logged that its
user script root is `~/.config/gamescope/scripts/`; a file directly under `~/.config/gamescope/` was
silently skipped. DeckDoc now installs into the logged script root and tests that exact destination.

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

## Remaining validation

- Confirm physical LCD visibility immediately after mitigation and after the next Game Mode restart.
- Verify that launcher-to-game activation remains at one plane after the hook loads.
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
