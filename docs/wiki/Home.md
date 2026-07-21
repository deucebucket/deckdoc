# DeckDoc engineering wiki

This wiki records Steam Deck failure signatures, evidence standards, and safe recovery procedures.
It is intentionally stricter than a collection of tweaks: a remediation must have an observable
trigger, read-only prechecks, a backup, a narrow action, verification, and a rollback.

## Current investigations

- [Steam Deck black screen with sound working: diagnosis and fix](Steam-Deck-Black-Screen-Sound-Working.md)
- [Physical LCD blackout with live rendering](LCD-Blackout-Investigation.md)
- [Display diagnostic runbook](Display-Diagnostic-Runbook.md)
- [Safe remediation policy](Safe-Remediation-Policy.md)

## Important distinction

A captured or streamed frame and the physical LCD are different observation points. If a recording
continues to show valid frames while the built-in panel is black, the application and most of the
compositor path are still working. DeckDoc then inspects the eDP link, EDID, backlight, CRTC, and
hardware-plane commit state instead of blaming the foreground application.
