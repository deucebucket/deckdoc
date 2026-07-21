# Safe remediation policy

DeckDoc exists to make risky failures more observable, not to turn undocumented hardware controls
into experiments.

## Forbidden automatic display/GPU actions

- panel voltage or firmware changes;
- backlight brightness or `bl_power` writes;
- GPU/CPU TDP, clock, overclock, undervolt, or performance-level changes;
- charging-current, charge-limit, or PMIC changes;
- blind GPU, PCI, panel, or connector sysfs power cycles;
- forced refresh-rate or resolution changes presented as blackout fixes;
- Steam VDF edits while Steam is running.

When the GPU is genuinely wedged, preserve evidence and advise an orderly reboot. DeckDoc's roadmap
must not contain an automatic GPU sysfs power-cycle module.

## Required remediation lifecycle

1. **PRE_CHECK** — the exact trigger still exists and target identity is resolved.
2. **BACKUP** — the pre-change state and any replaced file are preserved.
3. **EXECUTE** — one narrow, documented action.
4. **VERIFY** — the target service/path remains alive and the trigger changes as expected.
5. **REPORT** — `SUCCESS`, `PARTIAL`, `FAILED`, or `SKIPPED`, with no false claim about physical pixels.
6. **ROLLBACK** — exact and recoverable.

The display mitigation follows this policy by changing only Gamescope's plane-selection convar.
Physical visibility always remains a human confirmation, so software-only verification reports
`PARTIAL` until that confirmation is recorded.
