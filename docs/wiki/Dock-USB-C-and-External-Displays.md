# Dock, USB-C, power delivery, and external displays

A dock is several paths in one enclosure: USB hub/controller, USB Ethernet/audio/storage, USB-C Power
Delivery, DisplayPort Alt Mode, and an HDMI/DisplayPort converter. One can fail while the others work.
DeckDoc can judge exported behavior and correlation; it cannot certify the dock's power rails or signal
integrity electrically.

## Capture two controlled states

Run one report with the symptom present while docked:

```bash
sudo ./deckdoc.sh
```

Then change only the path under test and run a second report—for example official/known-good charger
direct to Deck, direct USB-C display, another cable, or another Ethernet adapter. Record dock model,
power supply, cable, display/input/mode, peripherals, exact failure time, and what remained functional.

Read `module_dock.log`, `module_display.log`, `module_battery.log`, `module_acpi.log`, and the probe
incident if present.

## What `module_dock.log` sees

- USB topology and vendor/product IDs, with serial numbers intentionally omitted;
- Type-C data/power role, orientation, partner presence, PD and Type-C revision when exported;
- DisplayPort Alt Mode configuration/pin/HPD when the driver exports it;
- USB/PD supply voltage, current, power, online state, and a clearly labeled instantaneous calculation;
- external DRM connector, EDID byte count, link state, and modes;
- likely USB Ethernet interface, driver, carrier, speed, and state;
- current-boot xHCI, UCSI, Type-C, USB over-current, reset/disconnect, and display-link errors.

The kernel Type-C class defines role, partner, `power_operation_mode`, PD revision, and Alternate Mode
exports, but drivers are not required to expose every field. “Not exported” is not a zero-voltage or
bad-dock diagnosis. See the [Linux Type-C class](https://docs.kernel.org/driver-api/usb/typec.html) and
[Type-C sysfs ABI](https://www.kernel.org/doc/html/next/admin-guide/abi-testing-files.html).

## Decision boundaries

| Observation | Stronger next branch |
|---|---|
| Direct charger works; docked charging repeatedly renegotiates or drops | dock PSU, cable, PD passthrough, dock controller |
| Direct USB-C display works; same display/cable path through dock fails | dock/adapter conversion path |
| Dock works on another host | Deck port, SteamOS driver, mode, or Deck/dock combination |
| Multiple hosts fail on the same dock/cable/display | shared dock/cable/display path |
| Whole USB hub, Ethernet, and display reset together | controller, upstream cable, or power path before one peripheral |
| One peripheral resets while the rest remain stable | that device, its downstream port/cable, or its driver |
| External display fails but USB/Ethernet/charging remain stable | Alt Mode, converter, EDID/mode/link path |
| Failures reproduce only after suspend | resume/reinitialization path; correlate PM timestamps |

A `DOCK_SIGNATURE: TOPOLOGY_CHANGE_WITH_DOCK_PATH_ERROR` means a reset/disconnect and a selected
host/PD/display-link error both exist in the boot. It does not prove the dock caused either record;
timestamps and the direct-vs-dock comparison decide whether the signature is relevant.

## Voltage and power limits

When voltage/current are exported, DeckDoc reports raw micro-unit values and calculated instantaneous
watts. Battery current may differ from negotiated adapter power because the running Deck consumes power,
conversion has losses, and the battery may charge or discharge. Many docks expose no rail telemetry.
Software output is not an oscilloscope, USB-PD analyzer, or load tester.

Stop using a dock/cable for sparking, electrical smell, abnormal connector heat, visible damage,
over-current logs, or repeated power loss. Do not stress-test it further.

Valve's [docking guide](https://help.steampowered.com/en/faqs/view/4C18-08B5-DEC9-3AF4) is the primary
source for supported reset and cable/display cross-tests. Do not flash unofficial dock firmware, force
unsupported timings, unbind the USB host controller remotely, or backfeed through a powered hub.
