# Steam Deck triage flow

Use the symptom that is happening now, not the diagnosis you expect.

## 1. Is the device physically unsafe?

Stop and disconnect power if safe when there is smoke, swelling, liquid ingress, an electrical smell,
a damaged USB-C port/cable, sparking, or abnormal heat while idle/off. Do not charge, open, stress-test,
or run DeckDoc. Contact Steam Support.

## 2. Does the Deck boot?

- **No power or charging response:** use Valve's basic power/charging checks, then Steam Support.
- **Firmware/recovery menu appears but SteamOS will not boot:** go to
  [Recovery and escalation](Recovery-and-Escalation.md).
- **SteamOS begins booting but loops, freezes, or enters a black screen:** if SSH works, capture DeckDoc
  and the previous/current boot journals before repair or re-image.
- **Only the first start after several days off is black, with sound, and a second boot works:** use the
  [long-off startup blackout protocol](Black-Screen-After-Long-Shutdown.md).
- **SteamOS boots:** continue below.

## 3. Is the whole system dead or only one output?

Test without changing state:

- Does audio continue?
- Do controls produce sounds or haptics?
- Does SSH still connect?
- Does Steam Game Recording or streaming show advancing frames?
- Does the fan respond to load?
- Does only the internal panel fail while an external monitor works, or vice versa?

If sound/rendering/input continue with a black internal LCD, use
[Screen black while sound works](Steam-Deck-Black-Screen-Sound-Working.md). If the game and controls
freeze or the session returns to Library, use [Crashes, GPU and memory](Crashes-GPU-and-Memory.md).

## 4. Pick the subsystem branch

| What you observe | First report sections | Guide |
|---|---|---|
| Built-in LCD black, Deck otherwise alive | display, GPU, Gamescope, coredump | [Display and Gamescope](Display-and-Gamescope-Problems.md) |
| First start after days off is black; second boot works | previous-boot journal, power/boot/display state | [Long-off startup blackout](Black-Screen-After-Long-Shutdown.md) |
| Game closes, freezes, or returns to Library | coredump, Steam, Gamescope, GPU, memory | [Crashes, GPU and memory](Crashes-GPU-and-Memory.md) |
| No sound/device after sleep | audio, ACPI, coredump | [Audio problems](Audio-Problems.md) |
| Wi-Fi missing/down after sleep | Wi-Fi, ACPI, audio | [Network and resume](Network-and-Resume-Problems.md) |
| Sudden shutdown, fan/heat, low clocks | thermal, battery, GPU, ACPI | [Power, thermal and battery](Power-Thermal-and-Battery-Problems.md) |
| Corrupt game files, SD disappears/read-only | mmc, filesystem, SMART | [Storage and microSD](Storage-and-MicroSD-Problems.md) |
| Dock, charging, external display, USB Ethernet | dock, display, battery, ACPI | [Dock/USB-C](Dock-USB-C-and-External-Displays.md) |
| Controller, Bluetooth, touch | baseline report plus manual evidence | [Controls/Bluetooth/input](Controls-Bluetooth-and-Input.md) |
| Installed OS will not boot | Rescue/live hardware plus installed journal image | [DeckDoc Rescue](DeckDoc-Rescue.md) |
| Hardware versus software is unclear | controlled A/B evidence | [Hardware decision guide](Hardware-Failure-Decision-Guide.md) |

## 5. Establish time and scope

Record:

- exact local time and current boot;
- LCD or OLED model and storage device involved;
- SteamOS/Steam client channel and version;
- Game Mode or Desktop Mode, docked or handheld;
- whether the event followed boot, wake, dock/undock, overlay toggle, game launch, update, or plugin
  change;
- whether it affects one title, all titles, or the whole OS;
- whether it reproduces after a normal restart with third-party tools disabled.

## 6. Preserve, test, verify

1. Save the report and relevant logs.
2. Redact private data before upload.
3. Choose one reversible experiment that tests the leading explanation.
4. Reproduce or monitor without stacking unrelated tweaks.
5. Re-run DeckDoc and physically confirm the result.

Avoid changing several variables at once. A successful reboot proves recovery, not root cause.
