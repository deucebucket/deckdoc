# NVMe, filesystem, and microSD problems

Storage symptoms include corrupt downloads, games failing validation, I/O errors, read-only media,
missing mounts, slow installs, boot failure, and disappearing SD cards. Preserve data before repair.

## Capture

```bash
sudo ./deckdoc.sh
```

Read `module_storage.log`, `module_fs.log`, `module_mmc.log`, and the kernel/crash sections. Record the
exact device and mount containing the affected game or system path.

## Internal NVMe

DeckDoc runs SMART health against `/dev/nvme0n1`. A SMART failure or critical-warning/error field is
important, but the fixed path may miss replacement or differently enumerated storage. Confirm with:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

Do not run write/destructive tests on an unbacked-up device.

## BTRFS and ext4

BTRFS device statistics are persistent counters for read/write/flush/corruption/generation errors.
Nonzero values show that errors occurred; compare timestamps and whether counters increase. Official
BTRFS documentation explains that these counters persist and can be updated by normal I/O or scrub.

DeckDoc reads ext4 superblock state for mounted devices but does not run `fsck`. Never run an offline
repair command against a mounted filesystem, and never guess the partition name.

## microSD/mmc

Strong evidence includes:

- mmc/SDHCI I/O, timeout, signal-verification, or corruption messages;
- `EXT4-fs error` naming the same `mmcblk` device;
- the device switching read-only;
- mount disappearance in the same incident window;
- repeated game corruption only on that card.

A game file validation failure alone does not prove media corruption. SteamOS issue #2037 documents an
SD corruption report on another SteamOS handheld; it is research context, not proof that every Deck SD
failure has the same cause.

## Safe response

1. Stop writes/downloads to the suspected device.
2. Save the report and irreplaceable data if the device remains readable.
3. Resolve the exact block device and mount.
4. Unmount before any filesystem repair.
5. Use a separate trusted system/recovery environment for repair or imaging when needed.

DeckDoc does not format, trim, scrub, delete, or repair storage automatically. Its roadmap may add
operations only with exact device resolution, backup, explicit confirmation, and verification.

## Escalation

Escalate for increasing SMART/BTRFS counters, repeated mmc I/O errors across clean boots, read-only
media, inability to back up, or boot failure. For SteamOS image recovery, follow
[Recovery and escalation](Recovery-and-Escalation.md).

## References

- [BTRFS device statistics](https://btrfs.readthedocs.io/en/latest/btrfs-device.html#device-stats)
- [SteamOS #2037: SD card file corruption report](https://github.com/ValveSoftware/SteamOS/issues/2037)
- [Valve SteamOS recovery and troubleshooting](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)
