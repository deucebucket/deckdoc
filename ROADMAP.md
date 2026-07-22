# DeckDoc v3.4.0 roadmap — full-system diagnostics and incident response

DeckDoc's product is evidence, correlation, and safe decision support. It should help a user separate
application/configuration faults, SteamOS/driver faults, accessory or dock faults, and strong hardware
suspicion without turning one log line into a verdict. Automatic remediation stays intentionally
narrow and is not the measure of project coverage.

## Current platform

| Capability | Current state |
|---|---|
| Full report | Model/capability manifest plus 18 read-only subsystem modules across GPU, power, thermal, storage, filesystems, audio, display, docks, crashes, Wi-Fi, Gamescope, memory, probe history, Steam, RyuDeck app health, microSD, resume, and GPU page faults |
| Application diagnostics | First privacy-safe RyuDeck adapter separates host initialization, guest progress, cache/pipeline behavior, rendering, and fatal runtime classes; the adapter contract is intended to extend to other apps |
| Incident probe | Opt-in bounded event capture prototype; public-safe filtered, resource-limited, no remediation |
| Dock analysis | USB/Type-C/PD/Alt Mode/display/Ethernet evidence and current-boot path-error correlation |
| DeckDoc Rescue | Read-only collector plus unsigned ArchISO alpha builder for outside-OS comparison |
| DeckMD | Public, static, local-only checker with six guided categories, contradiction pruning, 128 facts, and 15 ranked branches |
| Diagnostic wiki | Symptom routes, evidence interpretation, safe contrasts, recovery, and hardware decisions |
| Privileged collection | One-time approved, exact-command, root-owned diagnostic broker prototype |
| Remediation | Two guarded signature-specific paths: SOF reload and Gamescope forced-composition test |

## P0 — trustworthy evidence foundation

### [#15 Model and capability manifest](https://github.com/deucebucket/deckdoc/issues/15)

Identify model, OS/build/slot, drivers, devices, and supported evidence sources before interpreting
their presence or absence. The schema-v1 Jupiter/Galileo/unknown baseline and first dynamic-path
consumers shipped in v3.4.0; remaining modules, Rescue semantics, OS-slot data, and schema compatibility
remain tracked here.

### [#17 Unified timeline and access ledger](https://github.com/deucebucket/deckdoc/issues/17)

Normalize boot IDs, time scopes, sources, events, and permission/retention state. “No matching event,”
“not retained,” “permission denied,” and “not applicable” must remain different outcomes.

### [#22 Safe redacted bundle and storage-risk gate](https://github.com/deucebucket/deckdoc/issues/22)

Stop normal writes when storage evidence threatens data. v3.4.0 filters every normal capture before
disk and intentionally retains no raw variant; a formal share-bundle gate, storage-risk gate, and
continued adversarial review remain.

## P1 — productionize the new diagnostic modes

- [#18 Continuous probe](https://github.com/deucebucket/deckdoc/issues/18): measure overhead, harden
  suspend/restart/rotation behavior, expand fixtures, and integrate the incident timeline.
- [#16 DeckDoc Rescue](https://github.com/deucebucket/deckdoc/issues/16): pin and reproduce builds,
  sign releases, boot-test LCD/OLED, and document authenticated docked-Ethernet support.
- [#20 Dock/USB-C/PD](https://github.com/deucebucket/deckdoc/issues/20): validate official and
  third-party paths and generate direct-vs-dock differential summaries.
- [#19 Privileged authorization](https://github.com/deucebucket/deckdoc/issues/19): adversarially
  review the allowlist, snapshot integrity, output path, environment, and revocation flow.
- [#23 DeckMD](https://github.com/deucebucket/deckdoc/issues/23): keep the launched Pages app aligned
  with CLI/wiki vocabulary, validate on physical Deck hardware, and complete a formal accessibility audit.

## P2 — close broad subsystem gaps

[#21](https://github.com/deucebucket/deckdoc/issues/21) covers three evidence families:

- staged networking from device and association through route, gateway, DNS, VPN/captive portal, and
  service reachability;
- Bluetooth, HID, Steam Input, touch, gyro, and controller lifecycle without logging raw input;
- SteamOS update, slot, image, immutable-root, free-space, and previous-image health.

Future coverage should also extend structured JSON beyond the capability manifest, add battery trend
baselines, performance timelines, firmware/recovery contrasts,
[additional first-party application adapters](https://github.com/deucebucket/deckdoc/issues/27), and
an upstream-ready issue packet built from the redacted bundle.

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
