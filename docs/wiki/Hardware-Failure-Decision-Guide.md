# Hardware failure decision guide

DeckDoc uses four deliberately conservative outcomes.

| Outcome | Evidence standard |
|---|---|
| Fixable application/configuration | A title, layout, route, plugin, AP, mode, prefix, cable, or setting follows the symptom and a reversible A/B changes it |
| Driver/firmware/OS | A timestamped subsystem transition fails, a previous build changes the result, or a reproducible upstream signature matches |
| Strong hardware suspicion | The failure persists in firmware or official recovery, across OS slots/stock config and known-good external components, or has new device-local physical/media/electrical evidence |
| Confirmed hardware failure | Valve/service diagnosis, qualified component-level test, or isolated replacement resolves the controlled reproduction |

Never label an `amdgpu` timeout, one core dump, nonzero historical BTRFS counter, swap use, a hot
chassis, low idle clock, zero idle fan RPM, or “black screen” alone as hardware failure.

## Three-layer rule

Require:

1. the physical/user-visible symptom at an exact time;
2. subsystem evidence from that boot/window;
3. a controlled contrast or independent signal.

For example, a game freeze plus an AMDGPU timeout plus recurrence across unrelated stock titles is
stronger than any one signal. A physically black LCD plus live audio, live Gamescope, connected eDP,
readable EDID, active CRTC, nonzero backlight, and no reset localizes the display path—but still cannot
inspect panel electronics.

## High-value contrasts

- firmware/recovery/Rescue versus installed OS;
- current versus previous SteamOS image;
- stable versus beta/client update;
- clean stock versus plugins/mods/overlays;
- docked versus direct known-good cable/power/display/network;
- internal versus external display;
- cold boot versus resume;
- one title/API/Proton versus several unrelated titles;
- one AP versus a known-good hotspot;
- one SD card/peripheral versus another known-good device.

Change one variable and record the result. A reboot proves recovery, not root cause.

## Stop conditions

Stop software testing for smoke, swelling, liquid, electrical smell, sparking, port/cable damage,
abnormal heat while idle/off, fan stopped while temperature rises, new storage I/O/media errors,
repeated failed GPU resets, or loss of safe backup access. Disconnect power if safe and escalate.

The full source audit and detector priorities live in the repository's
`docs/research/steamdeck-issue-deep-dive.md`; the [research index](Research-and-Issue-Index.md) maps its
primary sources into this wiki.
