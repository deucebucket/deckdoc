# Recovery and escalation

Recovery restores operation. Diagnosis explains the failure. Preserve evidence before recovery when
the device is safe and responsive enough to do so.

## Recovery ladder

Use the least destructive step that matches the evidence:

1. **Capture:** DeckDoc report, Steam System Report, current/previous boot journals, physical symptom.
2. **Narrow reversible action:** reconnect one device, toggle one service/setting, or use a documented
   DeckDoc remediation whose precheck matches.
3. **Normal restart:** appropriate for wedged firmware/session state after evidence capture.
4. **Clean control run:** updated stable system, third-party plugins/modifications disabled, one known
   title/device/network.
5. **Rollback previous SteamOS:** official recovery option that retains user data where supported.
6. **Repair SteamOS:** official recovery environment; understand the option before selecting it.
7. **Re-image/factory reset:** destructive, clears data; backup first.
8. **Hardware service/Steam Support:** physical safety, repeated cross-software faults, or failed storage,
   panel, board, battery, charging, fan, or input evidence.

Valve's recovery page is authoritative for the current options and their data impact. Do not follow an
old third-party button sequence when the official instructions differ.

## When not to keep troubleshooting

Stop and contact support for:

- smoke, swelling, liquid, electrical smell, sparking, or charging-port damage;
- abnormal heat while idle/off or a fan that remains stopped as temperature rises;
- recurring hard locks/GPU reset failures across unrelated software;
- storage errors that threaten data or prevent safe backup;
- a panel/input/charging fault that persists in firmware/recovery environments;
- any repair that would require opening the device when you are not equipped to do so.

## Choosing where to report

### Steam Support

Use for warranty/hardware, safety, account-specific issues, recovery failure, and guided service.

### Valve SteamOS issue tracker

Use for reproducible SteamOS/kernel/session regressions with version, model, steps, timestamps, and
redacted system evidence. Search first and add a high-quality reproduction to an existing matching
issue when appropriate.

### Gamescope or component tracker

Use when the evidence isolates a reproducible upstream component and includes its logs/version. A
generic “black screen” without branch evidence is unlikely to be actionable.

### DeckDoc issue tracker

Use when DeckDoc misclassifies a state, misses a documented signature, has an unsafe/incorrect command,
or needs a new module. Include a sanitized fixture whenever possible.

## Minimum escalation packet

- Steam Deck LCD/OLED model and relevant storage/peripheral;
- SteamOS, client, kernel, update channel;
- exact incident time and boot scope;
- Game/Desktop Mode, dock/power/wake state;
- reproducible steps and frequency;
- relevant report sections, not an unexplained dump;
- what has been ruled out and how;
- recovery/test outcome;
- privacy redaction statement.

## Official references

- [Valve: SteamOS Recovery and Troubleshooting](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)
- [Valve: Steam Deck Basic Use and Troubleshooting](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)
- [Valve SteamOS issues](https://github.com/ValveSoftware/SteamOS/issues)
- [DeckDoc issues](https://github.com/deucebucket/deckdoc/issues)
