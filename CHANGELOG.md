# Changelog

All notable DeckDoc changes are recorded here. The project follows
[Semantic Versioning](https://semver.org/); dates use `YYYY-MM-DD`.

## [Unreleased]

No unreleased changes.

## [3.4.0] - 2026-07-21

### Added

- A versioned model and capability manifest that distinguishes Jupiter LCD, Galileo OLED, unknown
  hardware, supported/readable evidence, inaccessible evidence, absence, and non-applicability.
- Shared public-safe filtering for full reports, continuous-probe incidents, remediations, and Rescue
  archives, applied before persistent log writes with no intentionally retained raw variant.
- Adversarial privacy fixtures and model fixtures for Jupiter, Galileo, unknown, and inaccessible
  evidence states.
- A first-class RyuDeck application adapter that classifies guest startup stalls, active rendering,
  stale title-cache suspicion, stalled telemetry, and renderer/process fatal markers without emitting
  titles, IDs, paths, arguments, filenames, or raw app-log lines.

### Changed

- Hardware consumers now use discovered DRM, battery, storage, and Wi-Fi paths from the manifest
  instead of assuming one fixed device path where discovery is available.
- Core, Steam, filesystem, mount, and block evidence is minimized to diagnostic fields rather than
  arbitrary filenames, paths, mount labels, or process inventories.

## [3.3.0] - 2026-07-21

### Added

- DeckMD's six-category guided entry point with 12 nested primary symptoms.
- Twenty-seven explicit contradiction rules that remove incompatible diagnostic paths.
- A grouped, searchable **Browse all checks** fallback covering all 128 diagnostic facts.
- Keyboard, pointer, mobile, URL-state, and no-match interaction validation for DeckMD.
- A local DeckMD favicon with no external runtime dependency.

### Changed

- DeckMD now presents one focused follow-up group at a time and initially ranks only the three
  strongest matching branches.
- README and Pages copy now describe DeckDoc as a full diagnostic platform rather than a black-screen
  utility.

## [3.2.0] - 2026-07-21

### Added

- Expanded full-system coverage to 17 read-only diagnostic modules and two guarded remediations.
- Opt-in, resource-limited continuous incident probe with bounded private captures.
- Dock, USB-C, Power Delivery, Alt Mode, Ethernet, and external-display evidence collection.
- Read-only DeckDoc Rescue collector and unsigned ArchISO alpha builder.
- Root-owned, exact-command privileged diagnostic authorization prototype.
- Research-backed diagnostic wiki, issue index, and hardware-failure decision guide.
- Initial private, static DeckMD symptom checker and GitHub Pages deployment.

### Changed

- Findings distinguish current-boot evidence from retained history and inaccessible sources.
- Steam, memory, thermal, Gamescope, display, and crash signatures gained tighter evidence boundaries.

## [3.1.0] - 2026-07-21

### Added

- LCD physical-blackout diagnosis and reversible Gamescope forced-composition testing.
- Optional persisted display-stability policy with backup, verification, and rollback.
- LCD blackout investigation notes and user-facing recovery documentation.

## [3.0.0] - 2026-06-25

### Added

- Diagnosis-first remediation lifecycle: `PRE_CHECK -> BACKUP -> EXECUTE -> VERIFY -> REPORT`.
- Guarded SOF audio reload for a current-boot Vangogh DSP failure signature.
- Display blackout diagnostic module and explicit `--fix` mode.

## [2.0.0] - 2026-06-25

### Added

- Nine software and operating-system diagnostic modules covering audio, crashes, Wi-Fi, Gamescope,
  memory, Steam, microSD, suspend/resume, and GPU page faults.
- Mock regression coverage for the expanded diagnostic set.

## [1.0.1] - 2026-06-25

### Added

- Initial Steam Deck hardware diagnostic scaffold for GPU, battery, thermals, NVMe, and filesystems.

[Unreleased]: https://github.com/deucebucket/deckdoc/compare/v3.4.0...HEAD
[3.4.0]: https://github.com/deucebucket/deckdoc/releases/tag/v3.4.0
[3.3.0]: https://github.com/deucebucket/deckdoc/releases/tag/v3.3.0
[3.2.0]: https://github.com/deucebucket/deckdoc/commit/6d31a545cdb947892d9e6179fb8188d5d26cff88
[3.1.0]: https://github.com/deucebucket/deckdoc/pull/14
[3.0.0]: https://github.com/deucebucket/deckdoc/pull/12
[2.0.0]: https://github.com/deucebucket/deckdoc/pull/10
[1.0.1]: https://github.com/deucebucket/deckdoc/commit/0e8eb36
