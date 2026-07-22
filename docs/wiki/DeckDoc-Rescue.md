# DeckDoc Rescue: bootable outside-OS diagnostics

DeckDoc Rescue is an alpha design for diagnosing a Deck independently of its installed OS. It boots
from removable media through the firmware boot manager, captures live hardware state, and attempts to
read installed SteamOS journals without mounting or repairing the internal disk.

It is not a Valve recovery image. It does not repair, re-image, factory-reset, unlock encrypted data,
run `fsck`, mount internal filesystems, change EFI entries, flash firmware, or write the installed disk.

## Why boot outside the installed OS

- separate “installed SteamOS is broken” from “hardware also fails in another environment”;
- recover previous-boot logs after a boot loop or black startup;
- inspect NVMe SMART, enumeration, USB-C/dock, display, thermal, power, and input presence even when
  Game Mode cannot start;
- compare BIOS/recovery/live behavior with the installed system before destructive recovery.

Booting another OS changes the kernel and drivers. A device working in Rescue strongly argues against
total hardware absence, but does not prove the installed driver/config root cause. A device missing in
one generic rescue kernel can also mean that kernel lacks Steam Deck support.

## Current portable collector

From a compatible Linux rescue environment:

```bash
sudo ./bootprobe/deckdoc-rescue-collect.sh \
  --installed-disk /dev/nvme0n1 \
  --output-dir /path/to/removable-media
```

The collector creates a private archive with live PCI/USB/block/Type-C/PD/DRM/network/thermal/power
state, rescue-boot journal, NVMe health, EFI boot entries, and installed boot indexes/current/previous
journals where systemd can dissect the image. `journalctl --image=` is the documented image reader;
the collector never mounts the disk. See [systemd journalctl](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html).

If the installed image cannot be dissected, the report says inaccessible. It must not silently remount
or repair it. Encrypted or unusual layouts require a separate, explicit evidence-preserving workflow.

## Alpha image builder

`bootprobe/build-rescue-image.sh` builds an ArchISO development image on an Arch Linux build host with
the official `archiso` package. Arch's [`mkarchiso`](https://man.archlinux.org/man/mkarchiso.1.en)
creates UEFI-capable live images and can sign artifacts, but this project does not yet ship a signed
release.

Release gates:

1. pin and record every package/build input;
2. make the image reproducible and publish checksums/signatures;
3. boot-test Jupiter LCD and Galileo OLED, internal NVMe untouched;
4. validate Wi-Fi, docked Ethernet, USB storage, display, SMART, journal image reading, and shutdown;
5. threat-model remote access and redaction;
6. document safe image-writing with exact target verification.

Use Valve's current [SteamOS recovery instructions](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)
for firmware boot and official recovery workflows. Do not confuse or replace those recovery actions
with DeckDoc evidence collection.

## Remote control and export

Docked Ethernet is the default remote transport. A release image should accept only an explicitly
supplied SSH public key or one-time authenticated setup; it must not ship a default password or an
unauthenticated web server. Reports remain local unless the user explicitly transfers them.

Direct USB-C networking is optional future work. Linux USB gadget mode requires a real USB Device
Controller plus configfs/libcomposite support; connector shape alone is insufficient. The image must
verify `/sys/class/udc` and kernel capabilities before offering it. See the
[kernel USB gadget documentation](https://docs.kernel.org/usb/gadget_configfs.html).

## Hardware boundary

Persistence in BIOS, Valve recovery, and DeckDoc Rescue with known-good external power/cables raises
hardware suspicion. Only Valve/service diagnosis, qualified electrical testing, or replacement of the
isolated component resolving a controlled reproduction confirms hardware failure.
