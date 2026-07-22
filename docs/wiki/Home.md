# DeckDoc diagnostic center

DeckDoc is a full-system Steam Deck diagnostic and incident-response platform. Its job is to turn “my
Deck is broken” into a narrower, evidence-based question across boot, applications, Steam/Proton,
Gamescope, kernel/GPU, memory, storage, power, thermal, audio, network, suspend/resume, controls,
display, docks/peripherals, or physical hardware. The wiki is the symptom-first entry point to the
collector, continuous probe, outside-OS Rescue environment, and guided DeckMD checker.

If the Deck is smoking, swollen, wet, unusually hot to touch, smells electrical, or has a damaged
charging port, stop using it, disconnect power if safe, and contact Steam Support. Do not run software
diagnostics on a physically unsafe device.

## Start here

1. [Getting started](Getting-Started.md) — install DeckDoc and create the first report.
2. [Triage flow](Triage-Flow.md) — choose the branch that matches what is happening now.
3. [Reading DeckDoc reports](Reading-DeckDoc-Reports.md) — separate strong evidence from noise.
4. [Collecting and sharing evidence](Collecting-and-Sharing-Evidence.md) — preserve the incident and
   protect private data.
5. [Recovery and escalation](Recovery-and-Escalation.md) — decide when to restart, roll back, repair,
   re-image, file a bug, or contact Valve.
6. [Continuous incident probe](Continuous-Incident-Probe.md) — opt in to low-overhead event capture.
7. [DeckDoc Rescue](DeckDoc-Rescue.md) — outside-OS evidence for a Deck that will not boot normally.
8. [Privileged diagnostic authorization](Privileged-Diagnostic-Authorization.md) — approve an exact
   read-only command set once without sharing a password.
9. [Application diagnostics](Application-Diagnostics.md) — separate app, guest/runtime, OS/session,
   and hardware failure boundaries.

## Find your symptom

### Boot, crashes, and performance

- [Recovery, boot failure, and escalation](Recovery-and-Escalation.md)
- [Crashes, GPU hangs, page faults, and memory pressure](Crashes-GPU-and-Memory.md)
- [Application diagnostics and RyuDeck runtime tracing](Application-Diagnostics.md)
- [Reading retained core dumps and current-boot crashes](Reading-DeckDoc-Reports.md#crashes-and-retained-history)

### Audio, network, and sleep

- [Audio problems and SOF DSP failures](Audio-Problems.md)
- [Network and resume problems](Network-and-Resume-Problems.md)

### Power and storage

- [Power, thermal, fan, charging, and battery problems](Power-Thermal-and-Battery-Problems.md)
- [NVMe, filesystem, and microSD problems](Storage-and-MicroSD-Problems.md)

### Docks, controls, boot, and hardware decisions

- [Dock, USB-C, power delivery, and external displays](Dock-USB-C-and-External-Displays.md)
- [Controls, Bluetooth, touch, and input](Controls-Bluetooth-and-Input.md)
- [Hardware failure decision guide](Hardware-Failure-Decision-Guide.md)
- [DeckDoc Rescue](DeckDoc-Rescue.md)
- [Coverage and diagnostic gaps](Coverage-and-Gaps.md)
- [Recovery and escalation](Recovery-and-Escalation.md)

### Display and Game Mode

- [Display and Gamescope problems](Display-and-Gamescope-Problems.md)
- [Black screen on first start after several days powered off](Black-Screen-After-Long-Shutdown.md)
- [Screen black while sound or input still works](Steam-Deck-Black-Screen-Sound-Working.md)
- [Display diagnostic runbook](Display-Diagnostic-Runbook.md)
- [Physical LCD blackout investigation](LCD-Blackout-Investigation.md)

## Reference desk

- [Module reference](Module-Reference.md) — every module, log file, dependency, and limitation.
- [Research and issue index](Research-and-Issue-Index.md) — repository issues, upstream evidence, and
  implementation status.
- [Safe remediation policy](Safe-Remediation-Policy.md) — mandatory safety boundary for every fix.
- [Continuous incident probe](Continuous-Incident-Probe.md) — capture architecture, limits, privacy,
  installation, status, and removal.
- [Privileged diagnostic authorization](Privileged-Diagnostic-Authorization.md) — exact allowlist,
  security boundary, use, update, and removal.

## Evidence standard

A single log line rarely proves a root cause. A strong DeckDoc diagnosis has:

- the symptom captured while it is present or immediately afterward;
- timestamps that align with the failure;
- two or more independent signals that agree;
- current-boot evidence separated from retained history;
- explicit alternative explanations and coverage limits;
- a narrow, reversible test and post-test verification;
- human confirmation for physical outcomes such as visible pixels, sound, fan motion, or charging.

The wiki distinguishes `observed`, `correlated`, `likely`, `ruled out for this incident`, and
`confirmed by remediation`. Those phrases are intentionally different.

## Project boundary

DeckDoc collects evidence and implements only a small number of guarded fixes. It is not a replacement
for Steam's built-in System Report, Steam Support, warranty service, electrical safety judgment, or
offline filesystem repair. When a symptom is not automated, this wiki says so and provides a safe
collection/escalation path instead of inventing a fix.
