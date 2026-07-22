# Network and resume problems

“Wi-Fi is broken” can mean the PCI/firmware device disappeared, the interface is down, association
failed, DHCP/gateway/DNS failed, a captive portal intervened, or only Steam is offline. DeckDoc currently
covers the first three best.

## Capture the failed state

```bash
sudo ./deckdoc.sh
```

Record whether the issue started after wake, whether the Wi-Fi icon is misleading, whether other devices
can reach the same network, and whether local IP/gateway traffic works even when DNS/Steam does not.

Read `module_wifi.log` and `module_acpi.log`. If audio also disappeared after the same wake, inspect
`module_audio.log`; upstream reports show that both failures can share a resume window without proving
they share one root cause.

`module_wifi.log` searches the current boot for bounded ath11k, ath12k, iwlwifi, rtw88, b43, and
brcmfmac names, reports available firmware-version lines, and emits a coupled Wi-Fi/SOF signature when
both classes of failure exist. That signature is a prompt to compare timestamps with one resume—not a
claim that Wi-Fi caused the audio failure or vice versa.

## Interpret the signals

### No `wlanN` interface

This is stronger than “not connected.” Correlate PCI device presence and driver/firmware errors. A
missing interface after resume can indicate failed reinitialization, but model/driver coverage is not
complete.

### Interface `DOWN`

`DOWN` may be administrative (airplane mode, service action) or a failure. Look for a matching firmware
crash, resume failure, or device disappearance before escalating severity.

Driver names are matched at token boundaries. Text that merely contains the characters `b43`—for
example part of an unrelated identifier—must not be classified as a Broadcom driver error.

### Interface present and linked

DeckDoc does not currently separate DHCP, gateway, DNS, captive portal, router, or Steam service faults.
Useful read-only checks include:

```bash
ip address show
ip route
resolvectl status
```

Do not post full addresses, SSIDs, or BSSIDs without redaction.

## Recovery order

After preserving evidence:

1. Toggle Wi-Fi off/on in SteamOS and recheck interface/link state.
2. Test another known-good network if available.
3. Use a normal restart if the device/firmware is missing.
4. Only reload a specific wireless driver after identifying the actual adapter and module.

DeckDoc does not yet ship Wi-Fi remediation. Never copy a hard-coded `modprobe -r ath11k_pci` command
onto a model using a different driver. Driver removal may disrupt the current SSH connection and can
leave the device unavailable until reboot.

## Suspend/resume interpretation

`module_acpi.log` counts `PM: suspend entry` and `PM: suspend exit`/resume messages, then searches for
selected PM/PCI/fan warnings. A completed resume does not guarantee every device resumed. Conversely,
a wireless error somewhere in a boot with a suspend is not automatically caused by that suspend;
timestamps must align.

## Fan failure after resume

If the fan reads 0 RPM while APU temperature rises after wake, stop the workload and move to
[Power, thermal and battery](Power-Thermal-and-Battery-Problems.md). SteamOS issue #2475 documents a
charge-limit/sleep case; treat it as a pattern to test, not a universal cause.

## Escalation evidence

Include model, adapter/driver/firmware line, interface presence/state, exact wake time, PM transition,
audio co-failure, network scope (one AP/all APs), and recovery outcome.

## References

- [SteamOS #2313: audio and rare Wi-Fi failure after resume](https://github.com/ValveSoftware/SteamOS/issues/2313)
- [SteamOS #2475: fan resume failure at charge limit](https://github.com/ValveSoftware/SteamOS/issues/2475)
- [systemd journalctl boot filtering](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
