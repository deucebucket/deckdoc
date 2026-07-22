# DeckDoc Rescue image (alpha)

DeckDoc Rescue is a separate, bootable evidence environment for a Deck that cannot boot its installed
OS or whose behavior needs an outside-OS comparison. It is not a Valve recovery image and performs no
repair, re-image, filesystem check, unlock, mount, firmware change, or write to the installed disk.

The collector works from a compatible Linux rescue environment today:

```bash
sudo ./deckdoc-rescue-collect.sh --installed-disk /dev/nvme0n1 --output-dir /path/to/removable-media
```

The alpha ArchISO builder requires an Arch Linux build host with the official `archiso` package:

```bash
sudo ./build-rescue-image.sh ./out
```

The resulting rolling, unsigned image is for controlled development testing. Do not publish it as a
trusted release until package versions are pinned, artifacts are reproducible and signed, checksums are
published, and it has boot/hardware validation on both Jupiter LCD and Galileo OLED Decks.

For remote operation, use authenticated SSH over docked Ethernet. The image intentionally does not
enable an unauthenticated web server or a default password. Direct USB gadget networking is future,
capability-gated work: Linux requires a USB Device Controller plus configfs gadget support, and the
transport must never be assumed from the connector alone.
