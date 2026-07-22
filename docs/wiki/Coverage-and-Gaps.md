# Coverage and diagnostic gaps

DeckDoc is broad, but it is not yet a complete hardware test suite. This page prevents an unsupported
symptom from being mistaken for a clean bill of health.

## Current automated coverage

DeckDoc directly inspects:

- model family and LCD/OLED applicability, allowlisted OS/firmware facts, discovered primary devices,
  and readable/inaccessible/absent evidence states through a versioned capability manifest;
- AMD GPU resets/timeouts and selected GPU VM page faults;
- internal eDP/backlight/CRTC/plane state and selected Gamescope failures;
- battery telemetry, hwmon thermals/fan, NVMe SMART, BTRFS/ext4 state;
- SOF audio errors and audio-device presence;
- current/historical crashes, Steam dump files, memory/swap/OOM;
- selected Wi-Fi drivers, interface presence/link state;
- microSD/mmc/ext4/TRIM/read-only signals;
- suspend/resume transitions and selected fan/PCI errors;
- dock USB topology, exported Type-C/PD state, external connectors, USB Ethernet, and selected path errors;
- RyuDeck installation/profile state, structured runtime stage and frame progress, bounded shader/PTC
  cache signals, and renderer/process fatal classes without exposing titles or raw logs;
- the latest opt-in continuous-probe incident and its volatile state.

## Partially covered

| Area | What DeckDoc sees | What remains uncertain |
|---|---|---|
| LCD/OLED display | Connector, EDID, backlight, CRTC, DRM state | Pixels, cable/TCON/panel electrical health; OLED has no conventional backlight |
| Wi-Fi | `wlan*`, link info, selected firmware patterns | Every LCD/OLED adapter/driver, router/AP faults, DNS, captive portal |
| Audio | SOF/ALSA/PipeWire presence | Speaker/headphone wiring, codec quality, Bluetooth audio |
| Battery/dock | exported voltage/current/energy/Type-C/PD values | Cell/rail electrical diagnosis, fields a driver does not export |
| Storage | discovered primary NVMe plus mounted filesystem evidence | Every replacement/non-NVMe path, destructive surface testing, offline repair |
| Thermals | exported hwmon values and thresholds | Physical airflow/thermal-interface inspection, sensor calibration |
| Games/Proton | dumps, selected Steam errors, prefixes | Per-game compatibility, anti-cheat, launch options, mod interactions |
| Applications | structured RyuDeck runtime adapter and generic process/crash evidence | Every application, app-specific semantics not yet modeled, and physical/UI confirmation |
| Suspend/resume | PM transitions and selected correlated errors | Every firmware/EC/device wake failure |

## Not automated yet

### Input and controls

DeckDoc does not test buttons, sticks, triggers, trackpads, gyro, haptics, touch input, or controller
firmware. Use [Controls, Bluetooth, touch, and input](Controls-Bluetooth-and-Input.md) and Steam's
`Settings -> Controller -> Test Controller Inputs`; record whether the problem
exists in firmware menus and across games, and note whether it began after wake/update.

### Bluetooth

There is no Bluetooth module yet. Use [Controls, Bluetooth, touch, and input](Controls-Bluetooth-and-Input.md),
record adapter presence, device type, pairing state, and whether the
fault affects discovery, pairing, reconnect, input, or audio. Avoid deleting every paired device before
capturing logs.

### Dock, USB-C, external monitors, and power delivery

The new dock module inventories USB topology and driver-exported Type-C/PD/Alt Mode state but cannot
electrically certify dock firmware, rails, adapters, cables, monitors, or signal integrity. Use
[Dock, USB-C, power delivery, and external displays](Dock-USB-C-and-External-Displays.md) and retain
docked/direct reports.

### Updates and image health

DeckDoc does not validate SteamOS image slots, update payloads, recovery media, or immutable-root
integrity. Use [Recovery and escalation](Recovery-and-Escalation.md) and Valve's official recovery
options.

### Camera, microphone, external peripherals

Microphone presence may appear indirectly in PipeWire, but DeckDoc has no capture-quality test. There
are no dedicated modules for webcams, printers, USB storage, keyboards, mice, or headsets.

## Model-aware limitations

- LCD and OLED Decks use different APUs, panels, wireless devices, audio paths, firmware, power-button
  timing, and sensor exports.
- `rem_audio_sof.sh` specifically reloads `snd_sof_amd_vangogh`; it is not a generic audio reset.
- The manifest discovers the primary NVMe, DRM card, battery, and Wi-Fi interface for initial
  consumers; several other modules still own legacy path discovery.
- A fixed 6.6 V battery threshold and certain frequency paths should be treated as implementation
  assumptions until model-aware discovery is added.
- A brightness export may exist on Galileo OLED, but LCD backlight semantics and LCD-only remediation
  remain explicitly `not_applicable` there.

## Proposed expansion backlog

High-value future modules include:

- complete manifest consumption across all modules, Rescue, and future environments;
- Bluetooth adapter and reconnect health;
- controller/input event and firmware inventory;
- direct-versus-dock differential summaries and broader PD/Alt Mode validation;
- DNS/gateway/connectivity separation from Wi-Fi firmware state;
- boot slot/update health and report packaging;
- additional application adapters using the RyuDeck structured/privacy-safe contract;
- title-scoped Proton/log collection without exposing secrets;
- longer structured trends for thermal, fan, power, memory, and clocks beyond incident snapshots.

Open a repository issue with a reproducible symptom and primary evidence before adding a broad fix.
