# Controls, Bluetooth, touch, and input

DeckDoc does not yet automate raw input testing because an always-on recorder could capture typing,
gestures, or private content. Diagnosis should use device inventory, bounded activity counts, Steam's
test UI, and controlled comparisons—not raw event dumps shared publicly.

## Built-in controls

Use `Steam -> Settings -> Controller -> Test Controller Inputs`. Record the exact control, whether the
test UI sees it, whether firmware/boot menus see it, whether all titles or one layout fail, and whether
the event followed wake/update. Valve documents the controller test in its
[basic troubleshooting guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28).

- Test UI passes, one title/layout fails: Steam Input or game configuration first.
- Test UI and several titles fail, external controller works: built-in device/firmware/hardware branch.
- Whole controller device disappears only after wake: USB/HID/resume path.
- One physical control fails in firmware/recovery too: stronger hardware suspicion.

Do not flash controller firmware outside the official flow, write calibration values from another
unit, or publish raw keyboard/event streams.

## Touchscreen

Record missing versus phantom touches, charger/dock state, external display mapping, screen condition,
and behavior in firmware/recovery. Desktop-only rotation/mapping points to configuration; absence or
phantom input across recovery on a clean/dry panel raises digitizer/hardware suspicion. Do not press on
the panel or delete calibration/mapping files before capturing them.

## Bluetooth

Separate discovery, pairing, connecting, reconnect-after-wake, input, audio profile, and latency.
Capture adapter/rfkill/firmware and `bluetoothd` timestamps before forgetting devices.

- one peripheral only: its battery/firmware/profile first;
- adapter missing or firmware error: Deck driver/device branch;
- docked-only or 2.4 GHz-dependent: RF placement/coexistence;
- input works but audio profile fails: PipeWire/Bluetooth profile branch.

After evidence capture, forget only the affected device, update its official firmware, and compare
docked/undocked or line-of-sight placement. Do not erase every bond or blindly reset the USB controller.

Bluetooth and privacy-preserving input inventory are P1 detector gaps. See
[Coverage and gaps](Coverage-and-Gaps.md) and [Dock/USB-C](Dock-USB-C-and-External-Displays.md).
