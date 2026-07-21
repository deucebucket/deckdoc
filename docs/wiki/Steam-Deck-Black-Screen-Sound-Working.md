# Steam Deck screen black but sound still works: diagnosis and safe fix

This guide covers an intermittent Steam Deck failure where the built-in screen goes black while the
backlight is still on and game audio, controls, and rendering continue. It is also described as a
Steam Deck black screen with sound, a backlight-on black screen, or a screen that dies during game
loading even though the game keeps running.

DeckDoc captured and repaired this exact signature on a Jupiter LCD Steam Deck running SteamOS
3.8.14. The physical image returned after Gamescope was told to force composition instead of using
direct or multi-plane scanout. This is a validated workaround for that signature, not proof that
every Steam Deck black screen has the same root cause.

## What the captured failure looked like

During the blackout:

- the LCD backlight was visibly on;
- sound and controls still worked;
- Steam Game Recording showed a visible, advancing game;
- Gamescope and the game remained alive;
- the internal `eDP-1` connector, EDID, backlight, and CRTC all reported healthy state;
- the display was using the native 1280x800 game surface and 800x1280 panel timing;
- DRM showed multiple full-screen hardware planes;
- there was no correlated GPU reset, ring timeout, out-of-memory kill, thermal shutdown, or app
  crash.

That evidence localizes the failure after the game produced its frames and near the physical display
scanout path. It does not distinguish with certainty between a Gamescope/DRM plane transition,
kernel DCN/eDP behavior, panel timing/TCON, cable, or panel hardware. Software cannot directly see
the pixels emitted by the LCD, so physical confirmation still matters.

## Try the reversible Gamescope fix

If the screen is physically black but its backlight and sound remain on, first capture evidence from
an SSH session or terminal without rebooting, suspending, changing brightness, or resetting the GPU:

```bash
sudo ./deckdoc.sh --display-black
```

Then apply DeckDoc's guarded, session-only test as the normal `deck` user:

```bash
./deckdoc.sh --fix-display-blackout
```

Without DeckDoc, the equivalent temporary Gamescope command is:

```bash
gamescopectl composite_force 1
```

If the panel image immediately returns and the game continues normally, the result supports a
multi-plane/direct-scanout failure. On the captured Deck, the command reduced the active display
from multiple full-screen planes to one without restarting the game.

Do not use this procedure if the backlight is off, the Deck itself has crashed, audio/rendering have
stopped, eDP or EDID is unavailable, a GPU reset occurred, or the blackout persists with a single
active plane. Those symptoms need a different diagnosis.

## Make the workaround persistent

DeckDoc can install the persistent policy:

```bash
./deckdoc.sh --persist-display-stability
```

The manual equivalent is to create `~/.config/gamescope/scripts/99-deckdoc-display-stability.lua`
with:

```lua
gamescope.convars.composite_force.value = true

gamescope.hook("OnPostPaint", function()
    if not gamescope.convars.composite_force.value then
        gamescope.convars.composite_force.value = true
    end
end)
```

On SteamOS 3.8.14, the `scripts` directory is required; placing the file directly under
`~/.config/gamescope/` did not load it. Start a new Game Mode session after installing it. The frame
hook matters because a launcher-to-game transition was observed clearing a one-time setting.

The corrected policy survived a reboot and a launcher-to-game transition. The user physically
confirmed that the LCD image returned, and the same session then ran for nearly five hours at about
60 FPS with one game process, one MangoApp process, and no current-boot coredump.

## Roll back

If only the one-time command was used, restore Gamescope's default for the current session with:

```bash
gamescopectl composite_force 0
```

If the persistent script was installed, remove that exact file and start a new Game Mode session:

```bash
rm ~/.config/gamescope/scripts/99-deckdoc-display-stability.lua
```

Do not recursively delete the Gamescope configuration directory.

## Safety and tradeoffs

Forced composition changes Gamescope's presentation path and may have a small power, latency, or
performance cost compared with direct scanout. DeckDoc therefore does not enable it globally for
every user or include it in broad automatic repair.

This mitigation does not write panel power, backlight brightness, refresh rate, resolution, TDP,
CPU/GPU clocks, charging controls, firmware, or GPU reset nodes. Avoid guides that make blind sysfs
power or brightness writes before the failure state has been captured.

Decky Loader and an old docked 1080p setting were investigated for the captured incident. Neither
caused it: no Decky process owned the display path or injected the running native game, and the live
session was already at the Deck's native 1280x800 resolution. Those findings apply to the captured
system; a future incident should still record its current plugin and display configuration.

## When this workaround does not help

Capture a new report while the screen is still black. If forced composition is already active and
DRM shows one plane, the multi-plane explanation is ruled out for that occurrence. Escalate the
report toward kernel DCN/eDP, panel timing/TCON, display cable, or LCD hardware investigation instead
of changing power controls.

For the full evidence, ruled-out theories, and remaining regression exercises, see the
[LCD blackout investigation](LCD-Blackout-Investigation.md) and
[display diagnostic runbook](Display-Diagnostic-Runbook.md).
