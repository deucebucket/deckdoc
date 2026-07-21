# Display diagnostic runbook

## Capture while the panel is physically black

Do not suspend, reboot, change brightness, or power-cycle the GPU before collecting the first report;
those actions destroy the state needed to classify the failure.

Run:

```bash
sudo ./deckdoc.sh --display-black
```

Then preserve the consolidated report under `logs/` and answer one external question: does a Steam
recording, remote-play view, or capture still show advancing frames? Software cannot infer emitted LCD
pixels from DRM state alone.

## Classification

### `LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP`

Required correlation:

- symptom explicitly declared;
- connected eDP and nonempty EDID;
- nonzero actual backlight;
- active CRTC;
- physical panel black despite the above.

If captured frames remain valid and more than one full-screen plane is active, apply the reversible
session test:

```bash
./deckdoc.sh --fix-display-blackout
```

If the panel recovers and DRM collapses to one plane, persist it only after recording the evidence:

```bash
./deckdoc.sh --persist-display-stability
```

Start a new Game Mode session, launch a title, and check the DRM plane count again. Steam can clear a
one-time convar assignment during the launcher-to-game transition; DeckDoc's persistent Lua policy
uses Gamescope's documented `OnPostPaint` hook to restore forced composition when that occurs.

### `PANEL_OR_MODESET_STATE_INCOMPLETE`

An eDP, EDID, backlight, or CRTC check failed. Forced composition is not automatically indicated.
Keep the report and investigate that failed layer. Do not force panel/backlight sysfs values.

### Single-plane blackout

If the symptom recurs while forced composition is already active, the multi-plane theory is ruled
out for that occurrence. Capture a fresh root report before reboot and escalate toward kernel DCN/eDP,
panel timing/TCON, cable, or panel hardware.

## Overlay-helper side finding

DeckDoc separately recognizes repeated MangoApp aborts caused by an unreadable client
`/proc/<pid>/fdinfo`. This kills the performance-overlay helper, not Gamescope itself, and should not
be misclassified as the LCD blackout. Fix or update the nondumpable client; do not weaken `/proc`
permissions system-wide.

## Rollback

Current session:

```bash
gamescopectl composite_force 0
```

Future sessions:

```bash
rm ~/.config/gamescope/scripts/99-deckdoc-display-stability.lua
```

The removal is intentionally manual and exact. Never recursively delete the Gamescope config
directory.
