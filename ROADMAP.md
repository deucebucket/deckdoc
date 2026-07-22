# DeckDoc v3.2 roadmap — full-system diagnostics and incident response

DeckDoc's product is evidence, correlation, and safe decision support. It should help a user separate
application/configuration faults, SteamOS/driver faults, accessory or dock faults, and strong hardware
suspicion without turning one log line into a verdict. Automatic remediation stays intentionally
narrow and is not the measure of project coverage.

## Current platform

| Capability | Current state |
|---|---|
| Full report | 17 read-only modules across GPU, power, thermal, storage, filesystems, audio, display, docks, crashes, Wi-Fi, Gamescope, memory, probe history, Steam, microSD, resume, and GPU page faults |
| Incident probe | Opt-in bounded event capture prototype; private, resource-limited, no remediation |
| Dock analysis | USB/Type-C/PD/Alt Mode/display/Ethernet evidence and current-boot path-error correlation |
| DeckDoc Rescue | Read-only collector plus unsigned ArchISO alpha builder for outside-OS comparison |
| DeckMD | Static local-only symptom checker with progressive questions and ranked diagnostic branches |
| Diagnostic wiki | Symptom routes, evidence interpretation, safe contrasts, recovery, and hardware decisions |
| Privileged collection | One-time approved, exact-command, root-owned diagnostic broker prototype |
| Remediation | Two guarded signature-specific paths: SOF reload and Gamescope forced-composition test |

## P0 — trustworthy evidence foundation

### [#15 Model and capability manifest](https://github.com/deucebucket/deckdoc/issues/15)

Identify model, OS/build/slot, drivers, devices, and supported evidence sources before interpreting
their presence or absence. Modules must not assume LCD/OLED behavior, device indices, or driver names.

### [#17 Unified timeline and access ledger](https://github.com/deucebucket/deckdoc/issues/17)

Normalize boot IDs, time scopes, sources, events, and permission/retention state. “No matching event,”
“not retained,” “permission denied,” and “not applicable” must remain different outcomes.

### [#22 Safe redacted bundle and storage-risk gate](https://github.com/deucebucket/deckdoc/issues/22)

Stop normal writes when storage evidence threatens data, then produce separate private/raw and reviewed,
redacted bundles without automatic upload.

## P1 — productionize the new diagnostic modes

- [#18 Continuous probe](https://github.com/deucebucket/deckdoc/issues/18): measure overhead, harden
  suspend/restart/rotation behavior, expand fixtures, and integrate the incident timeline.
- [#16 DeckDoc Rescue](https://github.com/deucebucket/deckdoc/issues/16): pin and reproduce builds,
  sign releases, boot-test LCD/OLED, and document authenticated docked-Ethernet support.
- [#20 Dock/USB-C/PD](https://github.com/deucebucket/deckdoc/issues/20): validate official and
  third-party paths and generate direct-vs-dock differential summaries.
- [#19 Privileged authorization](https://github.com/deucebucket/deckdoc/issues/19): adversarially
  review the allowlist, snapshot integrity, output path, environment, and revocation flow.
- [#23 DeckMD](https://github.com/deucebucket/deckdoc/issues/23): deploy Pages, share a versioned
  vocabulary, expand rules, and complete keyboard/touch/responsive/accessibility validation.

## P2 — close broad subsystem gaps

[#21](https://github.com/deucebucket/deckdoc/issues/21) covers three evidence families:

- staged networking from device and association through route, gateway, DNS, VPN/captive portal, and
  service reachability;
- Bluetooth, HID, Steam Input, touch, gyro, and controller lifecycle without logging raw input;
- SteamOS update, slot, image, immutable-root, free-space, and previous-image health.

Future coverage should also add structured JSON output, battery trend baselines, performance timelines,
firmware/recovery contrasts, and an upstream-ready issue packet built from the redacted bundle.

## Remediation policy

A fix is eligible only when DeckDoc has a current, model-compatible signature; a bounded reversible
action; a backup where state changes; direct verification; and a documented rollback. Unsupported or
ambiguous cases end in evidence and escalation.

```text
PRE_CHECK -> BACKUP -> EXECUTE -> VERIFY -> REPORT -> documented ROLLBACK
```

DeckDoc will not add generic driver unloads, blind GPU resets, automatic cache deletion, mounted
filesystem repair, clock/voltage/power changes, firmware flashing, or automatic report upload as
routine remedies. Advisory actions such as closing a memory-heavy process are described as advice,
not disguised as remediation modules.

## Definition of a credible hardware decision

DeckDoc may report a strong hardware suspicion when a repeatable failure persists across clean
software/configuration tests, outside the installed OS or in firmware where applicable, and across
known-good external parts. Confirmed hardware failure requires direct hardware/service evidence or a
validated repair outcome. A timeout, core dump, persistent BTRFS counter, swap allocation, hot chassis,
zero idle fan, or black screen alone is never confirmation.
