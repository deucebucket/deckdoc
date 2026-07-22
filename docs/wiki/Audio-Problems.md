# Audio problems and SOF DSP failures

Audio can fail at the game, Steam, PipeWire, ALSA, codec, Bluetooth, USB, or kernel DSP layer. DeckDoc's
strongest audio diagnosis is the SOF DSP failure that can follow suspend/resume.

## First classify the symptom

- One game only or all system audio?
- Speakers, 3.5 mm, USB, HDMI/DP, Bluetooth, or every output?
- Output missing, muted, distorted, crackling, or silent?
- Did it begin immediately after wake?
- Does `Settings -> Audio` still list the expected output?

Run:

```bash
sudo ./deckdoc.sh
```

Read `module_audio.log`, then correlate `module_acpi.log`, `module_coredump.log`, and the incident time.

## SOF DSP signature

Strong kernel signals include:

```text
DSP panic
ipc tx ... failed ... -22
ipc ... timed out
Failed to restore pipeline after resume
Failed to acquire HW lock
```

Confidence rises when ALSA cards/playback devices and PipeWire nodes disappear in the same boot after a
resume event. A healthy card with only the wrong sink selected is a different problem.

Upstream SteamOS reports document post-sleep audio loss and the Vangogh IPC `-22` pattern, sometimes
alongside a wireless failure.

## Safe response

Preserve a diagnostic report first. A normal restart is the safest general recovery and does not prove
root cause.

DeckDoc can attempt its Vangogh-specific driver reload only when the trigger is present:

```bash
sudo ./deckdoc.sh --fix
```

The remediation backs up module/card state, reloads `snd_sof_amd_vangogh`, checks for new errors, and
verifies audio-card presence. It can fail when the module is busy or firmware is wedged. If the driver
or device model differs, skip this fix rather than substituting a guessed module name.

After a reported success, confirm actual sound through the intended output. Device enumeration alone is
not proof that speakers/headphones work.

## Other audio branches

- **Only one game:** check in-game output, Proton/game logs, and title-specific compatibility.
- **Bluetooth only:** DeckDoc does not yet diagnose Bluetooth; record adapter/profile/codec and reconnect
  behavior.
- **Dock/HDMI only:** correlate external connector state and test the dock/cable/display chain.
- **3.5 mm or speaker only:** compare outputs and consider a codec/jack/hardware path.
- **PipeWire node missing but ALSA healthy:** inspect the active user session and PipeWire services.

Avoid deleting all PipeWire configuration, changing kernel modules blindly, or reinstalling SteamOS
before determining whether the failure is global, output-specific, or resume-correlated.

## Escalation evidence

Include model, SteamOS version/channel, output device, wake context, exact time, SOF journal excerpt,
ALSA/PipeWire presence, and whether a restart or guarded reload recovered it.

## References

- [SteamOS #1376: No sound after sleep](https://github.com/ValveSoftware/SteamOS/issues/1376)
- [SteamOS #2313: SOF Vangogh IPC -22 and Wi-Fi after resume](https://github.com/ValveSoftware/SteamOS/issues/2313)
- [SOF project issue #9095](https://github.com/thesofproject/sof/issues/9095)
