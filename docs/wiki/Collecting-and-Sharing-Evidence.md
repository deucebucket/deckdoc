# Collecting and sharing evidence

The best report preserves the failure state, the event timeline, and enough system context to reproduce
the problem without exposing personal data.

## Capture order

When the Deck is stable enough to use a terminal or SSH:

1. Record the local time and what is physically visible/audible.
2. Note Game Mode/Desktop Mode, dock state, power state, and the last transition (wake, launch, update,
   overlay, dock/undock).
3. Run `sudo ./deckdoc.sh` before restarting.
4. Save Steam's built-in System Report when available:
   `Settings -> System -> Advanced -> System Report -> Create Report`.
5. Photograph or record a physical-only symptom when software capture differs from the panel.
6. Copy the timestamped master report somewhere safe before experiments.

For a physically black LCD where the system remains alive:

```bash
sudo ./deckdoc.sh --display-black
```

## Useful manual context

```bash
# Versions and kernel
cat /etc/os-release
uname -a

# Available boot journals
journalctl --list-boots

# Current and previous boot kernel logs
sudo journalctl -k -b 0 --no-pager
sudo journalctl -k -b -1 --no-pager

# Crash index; do not upload core files blindly
coredumpctl list --no-pager
```

Valve's SteamOS wiki identifies `/tmp/dumps/` and `steam_stdout.txt` as useful Steam-client evidence.
DeckDoc counts only actual minidump/core filename classes; normal bookkeeping files in that directory
are not crashes.

If the optional [continuous probe](Continuous-Incident-Probe.md) captured the incident, preserve its
whole private directory before rebooting or purging. A normal `sudo ./deckdoc.sh` includes the latest
incident, but an older incident may provide the comparison that matters.

## Privacy review

Assume a report can contain:

- Wi-Fi SSID/BSSID and network interface addresses;
- hostname and local usernames;
- home-directory paths;
- game names, Steam AppIDs, launch arguments, and process command lines;
- mounted device labels and paths;
- plugin names and third-party software;
- timestamps and usage patterns;
- hardware identifiers or serial-like values in manually added logs.

Search before posting:

```bash
rg -n -i 'ssid|bssid|serial|hostname|/home/|command line|ipv4|ipv6|mac' \
  logs/deckdoc_master_report_*.log
```

Make a redacted copy. Keep the original private. Replace sensitive values consistently so correlations
remain readable, for example `HOME_USER`, `WIFI_NAME`, or `BSSID_1`.

Never publish passwords, API tokens, session cookies, Steam Guard codes, SSH private keys, browser
profiles, complete environment dumps, or raw core dumps without understanding their contents. A core
dump can contain process memory and secrets.

## A useful bug report

Include:

- one-sentence symptom and expected behavior;
- device model (LCD/OLED and storage involved);
- SteamOS/client version and update channel;
- exact reproduction steps and frequency;
- Game/Desktop Mode, dock/power/sleep context;
- incident timestamp and whether logs are current- or previous-boot;
- minimal relevant DeckDoc sections;
- what changed recently;
- one-at-a-time tests and their outcomes;
- whether third-party plugins/modifications were disabled for a control run.

Do not upload a huge report without pointing maintainers to the relevant timestamps and signatures.

## Preserve evidence through reboot

A forced restart can erase volatile state, but persistent journals and Steam's System Report may still
contain current/previous boot data. After reboot, record that the report is post-reboot and do not claim
that current sysfs state represents the failed state.

## References

- [Valve SteamOS: Reviewing log information](https://github.com/ValveSoftware/SteamOS/wiki/Reviewing-log-information)
- [systemd journalctl manual](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
- [systemd coredumpctl manual](https://www.freedesktop.org/software/systemd/man/latest/coredumpctl.html)
