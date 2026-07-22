# Power, thermal, fan, charging, and battery problems

Physical safety outranks diagnostics. Stop using and disconnect the Deck from power if safe when there
is swelling, smoke, liquid, sparking, an electrical smell, damaged charging hardware, or abnormal heat
while idle/off. Contact Steam Support; do not stress-test or open the device.

## Symptom branches

- sudden power loss under load;
- will not power on or charge;
- battery percentage jumps or runtime is unexpectedly short;
- charging is slow/intermittent;
- fan stays at 0 RPM while temperature rises;
- high temperatures, throttling, or low CPU/GPU clocks;
- problem begins after sleep/wake or at a charge limit.

For a safe, booted device run:

```bash
sudo ./deckdoc.sh
```

Read battery, thermal, GPU, ACPI, memory, and storage sections together.

## Battery telemetry

DeckDoc records raw exported `capacity`, `voltage_now`, `current_now`, charge, and energy values. Units
come from the kernel power-supply interface and current sign conventions can vary.

Important limitations:

- the implemented 6.6 V warning is not model-aware;
- one voltage/current sample does not establish battery health;
- `energy_full` versus design can inform capacity loss but is not a cell-level diagnosis;
- DeckDoc does not inspect the USB-PD contract or charger/cable electrical quality.

Use Valve's model-specific charging LED and power-button guidance before inferring board failure.

## Thermal and fan interpretation

DeckDoc prefers each hwmon sensor's exported `max` and `crit` thresholds. When no critical threshold is
exported, above 90 C is retained as a warning observation, not called a hardware trip.

A 0 RPM reading is urgent when all of the following align:

- it is the actual Deck fan input;
- APU temperature is rising;
- the system is under load;
- the state persists rather than being a low-load fan-stop moment;
- ACPI/fan logs align with a resume event.

Stop the workload and allow the device to cool. DeckDoc does not yet restart the fan controller.

SteamOS issue #2475 describes a fan-resume failure when sleep occurs while charging at a configured
charge limit. Use it as a testable pattern and compare timestamps; do not assume every stopped fan has
that cause.

## Low-frequency state

An instantaneous low CPU/GPU clock can be normal at idle. A suspected 400 MHz CPU or 200 MHz GPU lock
needs sustained sampling under a known workload plus temperature, power, and kernel context. A GPU
reset, thermal limit, or power problem can produce similar poor performance.

## Recovery and escalation

- For depleted power/no start, follow Valve's basic use and charging checks.
- For a safe booted system, collect before restarting.
- Do not write TDP, clock, undervolt, charge-current, panel-power, or PMIC controls as a diagnostic
  experiment.
- Repeated sudden shutdowns, charging faults with known-good official power, swelling, or persistent fan
  failure require Steam Support/hardware service.

## References

- [Valve: Steam Deck basic use and troubleshooting](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)
- [SteamOS #2475: fan fails after sleep at charge limit](https://github.com/ValveSoftware/SteamOS/issues/2475)
