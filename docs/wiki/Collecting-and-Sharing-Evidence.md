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
whole incident directory before rebooting or purging. A normal `sudo ./deckdoc.sh` includes the latest
incident, but an older incident may provide the comparison that matters.

## Public-safe collection contract

DeckDoc runs all full-report, remediation, continuous-probe, and Rescue text through the same
public-safe filter before writing it to persistent storage. It deliberately retains no raw report
variant. The capability JSON is built from an explicit allowlist rather than a dump.

The filter removes or pseudonymizes credential-bearing lines, private/secret keys, authorization and
cookie data, SSIDs/BSSIDs, serial and machine IDs, hostname, email, MAC/IP addresses, Steam account
IDs, UUIDs, URLs, and user/removable/temp paths. Collection modules also minimize source data: they
count core and Steam artifacts rather than retaining arbitrary filenames or process inventories, and
they omit mount labels and mount points.

“Public-safe” is a collection invariant, not permission to upload blindly. An upstream component can
introduce a new identifier format, and diagnostic timestamps or software names may still be sensitive
to a particular user. Review before posting:

```bash
rg -n -i 'password|token|cookie|ssid|bssid|serial|hostname|/home/|/var/home/|ipv4|ipv6|mac' \
  logs/deckdoc_master_report_*.log
```

Never publish passwords, API tokens, session cookies, Steam Guard codes, SSH private keys, browser
profiles, complete environment dumps, or raw core dumps without understanding their contents. A core
dump can contain process memory and secrets; DeckDoc never collects raw core contents.

If a future DeckDoc output exposes one of these values, treat it as a security/privacy bug and do not
share that artifact. The regression suite seeds fake secrets and identifiers to prevent known classes
from returning.

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
