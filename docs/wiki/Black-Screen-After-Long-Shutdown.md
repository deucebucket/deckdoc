# Black screen after several days powered off

Status: community-reported signature; not yet reproduced or root-caused by DeckDoc.

## Reported behavior

A user described a Deck that starts to a black screen with the display illuminated and audible system
sound only after it has been unused for several days. Holding the power button to force it off, then
powering it on again, restores the display. An immediate shutdown/power-on cycle does not reproduce it.
The reporter sees it mostly on an LCD Deck running Windows and occasionally on an OLED Deck running
SteamOS.

This timing makes it a different branch from DeckDoc's validated in-game blackout:

| Long-off startup report | Validated live-render blackout |
|---|---|
| Begins during first power-on after days off | Began during an already-running Game Mode workload |
| First boot after a long powered-off interval matters | App/plane transition and live session mattered |
| Reported across Windows/LCD and SteamOS/OLED systems | Validated on one Jupiter LCD SteamOS system |
| Force-off/second boot recovers | Gamescope forced composition recovered the live session |
| No live DRM/plane evidence captured yet | eDP, EDID, backlight, CRTC, planes, recording captured |

Do not apply the Gamescope `composite_force` workaround by default. Windows does not use Gamescope,
OLED does not have the same LCD backlight path, and no multi-plane/live-render signature has been
captured for this startup case.

## What the report suggests—and does not prove

The delayed first-start condition makes cold initialization, firmware/embedded-controller state,
panel/link initialization, residual power state, battery/charger state, boot mode, or OS startup path
reasonable branches to test. A successful second boot proves recovery, not which branch caused it.

Reports from two different Deck models and operating systems weaken a narrow SteamOS-Gamescope-only
explanation, but they do not establish one shared root cause. The LCD/Windows and OLED/SteamOS events
could still be different failures with the same visible symptom.

## Capture protocol

The next occurrence needs evidence before the forced shutdown when practical:

1. Record days/hours since last use, whether the prior action was shutdown/sleep/hibernate, and whether
   the Deck was charging while stored.
2. Record power LED, visible LCD illumination or OLED glow, startup chime/audio, fan, haptics, controls,
   and whether the screen ever displayed the logo or firmware menu.
3. Test a known-good external display once, without repeated dock/undock cycling.
4. Check whether the device responds to ping/SSH or remote access. This distinguishes a booted OS with
   failed local display from a pre-session boot failure.
5. Photograph/video the panel and LEDs, including the time from power press to sound.
6. After recovery, immediately save current and previous boot evidence.

On SteamOS after the second boot:

```bash
cd /path/to/deckdoc
sudo ./deckdoc.sh
sudo journalctl -k -b -1 --no-pager > previous-boot-kernel.log
sudo journalctl -b -1 --no-pager > previous-boot-journal.log
```

The failed first start may not have written a persistent boot journal. Record that absence; do not treat
the second boot's healthy DRM state as the failed state.

On Windows, preserve Event Viewer system/display/kernel-power entries and generate a system report only
after reviewing it for private data. Also record whether Windows Fast Startup/hibernation was enabled,
because the user-visible “Shut down” path may not represent the same boot type as a full shutdown.

## Controlled reproduction matrix

Change one row at a time and avoid repeatedly forcing power unless necessary:

| Variable | Values to compare |
|---|---|
| Off interval | immediate, overnight, 2–3 days, longer |
| Prior state | verified full shutdown, sleep, hibernate/hybrid shutdown |
| Storage power | unplugged, official charger connected |
| Battery state | approximate percentage at shutdown and first start |
| Display | handheld only, known-good external display attached before boot |
| Boot layer | firmware menu visible, boot logo visible, OS audio only |
| Software | SteamOS stable clean control; Windows full-shutdown control |

Do not drain the battery deliberately, change firmware, write panel power nodes, or repeatedly hard-cycle
the device to chase the bug.

## When to escalate

Escalate with Valve Support if the issue repeats across clean full shutdowns, the firmware/boot logo is
also invisible, external display behavior points to a panel path, or there are charging/battery/physical
symptoms. File a SteamOS bug when a SteamOS Deck has a repeatable matrix and previous-boot/System Report
evidence. Windows-specific reports should also include the APU/display driver and firmware versions.

## Related—not equivalent—reports

- [SteamOS #1324: backlight-on black screen around Desktop Mode](https://github.com/ValveSoftware/SteamOS/issues/1324)
- [SteamOS #2632: intermittent black screen after Desktop Mode wake](https://github.com/ValveSoftware/SteamOS/issues/2632)
- [Valve: Steam Deck basic use and troubleshooting](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)

These references show nearby symptom classes, not a confirmed match for the long-off first-start report.
