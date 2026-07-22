# Steam Deck issue deep dive: evidence, decision boundaries, and detector backlog

**Research cutoff:** 2026-07-21. **Target:** Steam Deck LCD (Jupiter) and OLED (Galileo), SteamOS
3.x. **Current DeckDoc baseline:** 15 read-only modules and two guarded remediations.

This audit is a diagnostic map, not a list of folk fixes. A linked issue proves only what its attached
logs and maintainer response establish. Reporter diagnoses, correlations, temperature guesses, and
“same here” comments remain hypotheses. Upstream bug reports are useful reproducible observations;
they are not proof that every similar Deck has the same root cause. A hardware verdict requires either
device-local electrical/physical evidence, persistence outside the installed OS, or Valve service
diagnosis—not merely a scary log string.

## Evidence rules

- **Incident time first.** Capture local time, timezone, boot ID, monotonic kernel timestamp, SteamOS
  build/channel, client build, BIOS/firmware, LCD/OLED identity, dock/charger/display, title, Proton
  version, and exact action. [`journalctl --list-boots` and `-b`](https://github.com/systemd/systemd/blob/main/man/journalctl.xml)
  separate current (`-b 0`) from prior boots (`-b -1`); retained cores and persistent BTRFS counters
  are historical until correlated.
- **Three layers before a verdict.** Symptom + subsystem evidence + controlled contrast. For example,
  a frozen game plus `amdgpu ... timeout` plus recurrence across titles is stronger than a crash dump;
  a live Gamescope process, active CRTC, connected eDP, and nonzero LCD backlight during a physically
  black panel localize a render-to-scanout gap but still cannot inspect the panel electrically.
- **Absence is scoped.** “No error” means no error in the readable source and time window. Non-root
  reports can miss kernel/debugfs/SMART/BTRFS data; volatile journals cannot explain an older reboot.
- **Prefer upstream semantics.** Kernel PM states are defined by the
  [Linux sleep-state documentation](https://docs.kernel.org/admin-guide/pm/sleep-states.html), DRM
  connector/CRTC properties by [DRM/KMS](https://docs.kernel.org/gpu/drm-kms.html), core-dump retention
  by [`systemd-coredump`](https://github.com/systemd/systemd/blob/main/man/systemd-coredump.xml),
  Proton logging/compatdata behavior by [Valve Proton](https://github.com/ValveSoftware/Proton), and
  Gamescope’s compositor/direct-scanout role by [Valve Gamescope](https://github.com/ValveSoftware/gamescope).
- **Known-good contrast beats reset folklore.** Stable vs beta, stock vs third-party changes disabled,
  docked vs direct, internal vs external display, cold boot vs resume, one title vs many, one AP vs
  hotspot, and recovery environment vs installed OS are reversible discriminators. Valve’s
  [basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28) explicitly starts with
  updates, restart, and disabling third-party Desktop Mode software.
- **Recovery has a data-loss ladder.** Previous SteamOS is lower risk than repair/re-image; factory
  reset, erase-user-data and re-image destroy data. Use Valve’s
  [SteamOS recovery guide](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)
  and record the pre-recovery state.

### Confidence labels used below

| Label | Meaning |
|---|---|
| **Confirmed mechanism** | Upstream docs define the signature, or a Valve maintainer ties the supplied trace to the mechanism. |
| **Strong local inference** | Two or more independent device signals fit one boundary; physical root cause still unproved. |
| **Reporter hypothesis** | Correlation, suspected component, workaround, or anecdote without causal confirmation. |

## Cross-symptom decision matrix

| Observable at incident | Most likely layer to investigate first | Evidence that moves the boundary | Evidence against / next branch |
|---|---|---|---|
| No LED/chime/fan/display | power input, battery/EC, board | official PSU direct, charge LED behavior, BIOS reachability; Valve documents LCD/OLED power-hold differences in the [basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28) | BIOS or recovery boots: installed OS/boot path, not “dead board” |
| Chime/haptics/audio, internal panel black | internal display path or compositor | eDP/EDID/backlight (LCD)/CRTC/planes live; external display; Gamescope state | missing connector/EDID/backlight/CRTC points lower; GPU timeout/reset points GPU path |
| Internal works, external does not | dock/cable/PD/Alt Mode/mode | USB topology, DRM connector, EDID, negotiated mode; cross-test device/cable/display per [Valve dock guide](https://help.steampowered.com/en/faqs/view/4C18-08B5-DEC9-3AF4) | other device also fails on dock: dock/cable/display; direct USB-C succeeds: dock branch |
| Whole image freezes, returns, then session restarts | GPU hang/reset/Gamescope recovery | earliest `amdgpu` timeout/reset lines and Gamescope core/restart; Valve maintainer says post-reset errors may be secondary in [SteamOS #1312](https://github.com/ValveSoftware/SteamOS/issues/1312) | title process alone dumps with no kernel/Gamescope event: game/Proton branch |
| Game exits to Library only | title, Proton, anti-cheat, mod, game | title dump, `PROTON_LOG`, exit code, same title/version across compatibility tools | multiple unrelated titles + GPU/OOM/I/O events: system layer |
| Sudden power-off | thermal protection, exhausted/failed power, kernel panic, board | last sensor/power samples, pstore/journal tail, charger state, recurrence under controlled load | normal shutdown target and clean journal: user/software shutdown; no retained logs is inconclusive |
| Slow/stutter without crash | thermal/power cap, memory pressure, storage I/O, shader compilation | load-normalized clocks/temp/power, PSI, swap I/O, disk latency, Steam download/shader activity | idle low clocks or allocated swap alone are normal, not evidence |
| Device missing after resume | PM/device reinitialization | paired suspend entry/exit and device driver error in same monotonic window; cold-boot restore | missing before suspend or still missing after recovery boot: config/hardware branch |
| Storage disappears/read-only/I/O errors | media/controller/filesystem | block/MMC/NVMe errors, RO transition, SMART, filesystem counters, another reader/system | mount/path/library issue with healthy block layer: config/client branch |
| Wi-Fi “connected,” internet broken | routing/DNS/AP/captive portal before firmware | link + address + route + gateway + DNS stages | interface vanished or firmware/PCI error: driver/device branch |
| Controls fail in one title/layout | Steam Input/game config | Steam controller test passes; clean layout/new title works | firmware menus/controller test also fail: firmware/input hardware branch |
| Symptom starts exactly after update | regression candidate, never proof alone | before/after build, previous-image A/B result, same hardware/config | persists on previous image/recovery: hardware/user-data/config branch |

## Failure-family audit

Each row gives the **strongest positive signature**, a falsifier or alternative, time scope, a decision
boundary, safe reversible test, forbidden action, escalation addition, current coverage, and one missing
detector. `CB` means current boot; `PB` previous boot; `H` persistent/historical.

### Boot, power, battery, thermal, fan, and performance

| Family / user symptom | Evidence and scope | Hardware / driver / config boundary | Safe reversible test; forbid | Escalation addition; DeckDoc coverage -> gap |
|---|---|---|---|---|
| No power / power button ignored | Charge LED + official PSU direct + BIOS accessibility are strongest. A flashing LED on press means depleted battery per [Valve basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28). **CB/live**, often no OS log. | BIOS/recovery reachable argues against dead mainboard; installed OS failure remains. No response after known-good PD source and official timing is hardware/EC suspicion, not proof. | Charge ≥15 min; use Valve LCD/OLED-specific hold timing; try Volume+ BIOS. **Forbid:** random charger injection, opening unit, battery disconnect, repeated forced cycles before data capture. | LED color/pattern, charger wattage, last successful boot. `battery_pmic` partial -> add preboot questionnaire + USB-PD/Type-C status detector. |
| Boot loop / logo / emergency shell | PB journal, boot target failure, mount errors, slot/build identity. Valve exposes previous-image and recovery options in [recovery guide](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3). **PB/H**. | Previous image boots: regression/current deployment. Recovery boots but both images fail: installed storage/filesystem/user config. Recovery also fails: media/firmware/hardware branch. | Photograph exact error; boot previous image; recovery “repair” only after backup. **Forbid:** re-image/factory reset before evidence, blind `fsck` on mounted root, editing boot entries from guesses. | Both slot versions, boot menu result, PB journal/export. `fs_integrity` partial -> add deployment/slot/boot-health inventory. |
| Battery drains fast / percentage jumps | `POWER_SUPPLY_*` energy/charge/full/design, current, voltage and cycle data over time; workload and refresh rate. Valve notes charge may intentionally fall below 100% while continuously plugged in ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)). **live/trend**. | One percentage snapshot cannot prove bad cells. Repeatable capacity collapse at comparable load plus abnormal full/design ratio raises battery suspicion; one title/high refresh is workload/config. | Reboot, stock performance settings, known workload, record 10–15 min trend. **Forbid:** forced discharge, calibration loops, changing charge limits/EC/BIOS, generic voltage cutoffs. | Charger, load, FPS/refresh cap, elapsed Wh. `battery_pmic` snapshot -> model-aware energy trend + plausibility detector. |
| Will not charge / slow charge | Online/status/current plus Type-C/PD role/partner data; official adapter direct. Steam Deck uses USB-PD, not QC/Fast Charge ([Valve](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)). **live**. | Charges direct but not docked: dock/cable/PD topology. Multiple known-good PD supplies + port debris ruled out + no contract: port/controller/hardware suspicion. | Direct official PSU, inspect port without metal, shut down and retest. **Forbid:** untrusted high-voltage supplies, probing/shorting port, firmware downgrade. | Supply/cable/dock IDs and Type-C sysfs. `battery_pmic` partial -> USB-PD contract/role and charger-power detector. |
| Hot, fan loud/zero, throttling, shutdown | Sensor-specific temp/max/crit, fan RPM/PWM, load-normalized CPU/GPU clocks, thermal-zone events and journal tail. Kernel hwmon ABI defines exported fields ([kernel](https://docs.kernel.org/hwmon/sysfs-interface.html)). **live/trend/PB**. | Zero RPM at idle or missing hwmon export is not failed fan. Rising temperature under sustained load with no RPM on a known fan channel is strong hardware/control evidence; update-correlated fan controller errors suggest driver/EC. | Clear vents, stock TDP/fan profile, short monitored load, stop before exported critical threshold. **Forbid:** blocking fan, overriding PWM, repasting/opening, disabling thermal protection. | Ambient/load/time curve, shutdown time, sensor labels. `thermal_fan` snapshot -> 60 s labeled trend, fan response slope, shutdown-correlation detector. |
| Low clocks / stutter / “200/400 MHz” | Sustained per-engine clocks under measured load + temp/power/current + PSI/swap/I/O, not an idle sample. AMDGPU exposes utilization/frequency/debug semantics in [kernel GPU docs](https://docs.kernel.org/gpu/amdgpu/index.html). **live/trend**. | Low idle clock is normal. Low clocks only while hot/power-limited is policy/protection; fixed low clocks across cold stock workloads and boots raises firmware/hardware suspicion. | Compare stock profile, plugged/unplugged, two workloads; record 1 s series. **Forbid:** manual clock/voltage/SMU writes or disabling limits. | Performance profile, charger, FPS cap. `gpu_apu`,`memory_swap`,`thermal_fan` partial -> correlated performance sampler and cause ranking. |

### Internal/external display, GPU/APU, dock, and USB-C

| Family / user symptom | Evidence and scope | Hardware / driver / config boundary | Safe reversible test; forbid | Escalation addition; coverage -> gap |
|---|---|---|---|---|
| Internal LCD black but audio/input live | During physical black: eDP connected, readable EDID, nonzero backlight, active CRTC/plane, live Gamescope, no preceding GPU reset. DRM meanings come from [DRM/KMS](https://docs.kernel.org/gpu/drm-kms.html). **live/CB**. | All scanout state live = compositor/scanout/panel-link boundary, not proof of software. No backlight on LCD, missing EDID/CRTC, or failure in BIOS/recovery moves toward panel/cable/hardware. OLED has no conventional backlight. | Mark `--display-black`, test external display, session-only forced composition only when prechecks pass. **Forbid:** sysfs backlight/panel-power writes, guessed modesets, persistent tweak before session test. | Photo/video, external result, physical observation. `display_blackout` strong LCD partial + `rem_display_blackout` -> OLED-aware emitted-pixel/manual branch and model capability manifest. |
| Black screen on Desktop/Game Mode transition | Gamescope/KWin start/exit, core, DRM hotplug/modeset, active session and user journal. A SteamOS report documents backlight/live-system behavior but its cause remains reporter-level ([#1324](https://github.com/ValveSoftware/SteamOS/issues/1324)). **CB**. | Session process/core/modeset error with other mode working: software/config. Same black in BIOS/recovery: hardware. | Switch mode once, SSH capture, disable third-party session plugins, compare previous image. **Forbid:** delete all KDE/Steam configs before copying them, re-image first. | Exact transition, displays, config diff. `gamescope_session`,`display_blackout`,`coredump` partial -> session-transition timeline detector. |
| Artifacts/flicker/scanout corruption | Photo plus DRM mode/planes, Gamescope composition state, kernel version, `amdgpu` errors. Gamescope #1368 reproduces direct-scanout artifacts on multiple AMD/display setups and calls its kernel attribution a **best guess**, while force composition changes outcome ([issue](https://github.com/ValveSoftware/gamescope/issues/1368)). **CB/repro**. | Artifact absent in BIOS/recovery and changes with composition/mode = software path. Persistent before OS/on captures from external frame source = display/GPU hardware suspicion. | Stock refresh/resolution; session-only composition; internal/external A/B. **Forbid:** over/underclock, EDID deletion without backup, permanent kernel flags from anecdotes. | Photo, mode, plane count, kernel/Mesa/Gamescope. `display_blackout`,`gpu_apu` partial -> artifact incident mode/composition diff detector. |
| External display blank / wrong mode / HDR | DRM connector/EDID/link-status, USB topology, mode list, dock firmware, cable and direct-USB-C A/B. Valve lists cable/input/mode limitations and reset/cross-device tests ([dock guide](https://help.steampowered.com/en/faqs/view/4C18-08B5-DEC9-3AF4)). **live/CB**. | Another host also fails through dock = dock/cable/display. Direct Deck USB-C succeeds = dock. Connector absent with other functions working = Alt Mode/link. | Power-cycle dock per Valve, known-good cable/input, conservative 1080p60, one display. **Forbid:** flash unofficial dock firmware, force unsupported timings/HDR/DSC, hot-plug damaged cable repeatedly. | Full topology/EDID hash and good/bad combinations. `display_blackout` connector-only -> dock/USB/PD/Alt-Mode module. |
| USB peripherals disconnect / dock instability | `usb`/`xhci` resets, descriptor errors, device tree before/after, Type-C partner/role, power budget; correlate exact monotonic time. **CB**. | One device/cable only = peripheral. Whole hub resets with multiple peripherals = dock/controller/power. Repeat direct on Deck = Deck port/controller/OS. | Remove nonessential devices, direct-test one known-good low-power device, update official dock firmware. **Forbid:** `usbreset` loops, unbind host controller remotely, powered-hub backfeed. | `lsusb -t`, IDs, cable/dock PSU. no dedicated coverage -> topology/event-correlation detector. |
| GPU hang, freeze, black/recover, Gamescope restart | Earliest `amdgpu` ring timeout/page fault/reset begin/outcome, then Gamescope/core timeline. In SteamOS #1312 a Valve maintainer says post-reset Gamescope/fan errors may be secondary and requests earlier AMDGPU lines ([issue](https://github.com/ValveSoftware/SteamOS/issues/1312)). **CB/PB**. | One title/API/Proton only and reset succeeds: driver/game first. Cross-title, stock, repeated failed reset or machine check raises kernel/hardware; a reset line alone does not identify faulty silicon. | Capture PB journal after reboot, A/B Proton/API/title and stable/previous image. **Forbid:** manual PCI/GPU reset/sysfs power writes, voltage/clocks, repeated stress after failed resets. | Full journal from ≥2 min before event, dumps, title/API. `gpu_apu`,`dxvk_page_fault`,`gamescope_session`,`coredump` good partial -> unified causal timeline/first-error detector. |
| Visual glitch/game crash blamed on VRAM/GPU | VM fault address/status/client IDs, guilty process if logged, ring and reset result. Kernel AMDGPU docs expose mechanisms, not a board-failure verdict ([AMDGPU](https://docs.kernel.org/gpu/amdgpu/index.html)). **CB**. | Fault confined to one renderer/title/build points software/submission. ECC/PCI/AER/machine-check evidence or broad stock recurrence is stronger hardware evidence; Deck shared memory makes “VRAM failure” from symptoms speculative. | Clean launch options/mods, alternate Proton/render API, multiple known titles. **Forbid:** memory “repair,” UMA/BIOS tweaks as diagnosis, RMA claim from one VM fault. | Fault block untruncated + process/title/version. `dxvk_page_fault` partial -> decoder keyed to current kernel plus cross-title recurrence grouping. |

### Audio, Wi-Fi, Bluetooth, suspend, and input

| Family / user symptom | Evidence and scope | Hardware / driver / config boundary | Safe reversible test; forbid | Escalation addition; coverage -> gap |
|---|---|---|---|---|
| Speakers/headphones silent | ALSA cards/devices, PipeWire/WirePlumber nodes/default route, mute/volume, external audio sinks, SOF firmware/IPC/panic. Valve says disconnect alternate BT/USB-C/3.5 mm sinks and switch output ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)). **live/CB**. | ALSA device exists and alternate sink works: routing/profile/config. SOF IPC/panic and missing card after resume: driver/DSP. Speaker absent in recovery/known-good image while headphones work: speaker/wiring suspicion. | Switch output away/back, restart, compare headphones/speakers; guarded Vangogh reload only on exact trigger/model. **Forbid:** force-remove busy audio modules, delete all PipeWire config, apply LCD driver name to OLED. | Sink/source/profile, jack state, resume time. `audio_sof` strong partial + guarded remediation -> codec/jack/route and OLED model detector. |
| Mic missing/wrong after 3.5 mm | PipeWire source profile/port and ALSA capture devices. Valve documents LCD internal mic unavailable with 3.5 mm, while OLED can use both ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)); SteamOS #1346 shows profile/port evidence but workaround comments are not a root-cause confirmation ([issue](https://github.com/ValveSoftware/SteamOS/issues/1346)). **live**. | Expected LCD behavior vs OLED route bug vs physical mic decided by model and available ports, not “missing mic” alone. | Record model, unplug jack, inspect/select exposed profile, short local recording. **Forbid:** editing UCM/WirePlumber files before backup, assuming LCD behavior on OLED. | `pactl`/WP JSON, jack/headset. `audio_sof` partial -> model-aware capture route/profile detector. |
| Wi-Fi missing/disconnects | PCI/USB adapter ID, driver/firmware, interface transitions, NetworkManager state, signal, deauth reason, paired resume window. **CB**. | Interface present + associated but no internet = route/DNS/AP first. Firmware/PCI error or vanished interface = driver/device. One AP only = AP/security/channel compatibility. | Cold boot, toggle Wi-Fi, known-good hotspot, disable third-party networking, compare pre/post-resume. **Forbid:** unload guessed module, delete all connections before capture, regulatory/channel hacks. | AP band/security (redact SSID/BSSID), adapter/driver/fw. `wifi_firmware`,`acpi_pm_state` partial -> staged link/IP/route/gateway/DNS detector and model-aware drivers. |
| Connected but no internet / slow Wi-Fi | Association + IP + default route + gateway reachability + DNS resolution + throughput/signal/retry; each stage timestamped. **live/trend**. | Gateway fails = link/AP/routing. Gateway passes but DNS fails = resolver. Only Steam fails = client/service. Low signal/retries and 2.4/5/6 GHz context distinguish RF. | Compare hotspot, gateway vs literal IP vs DNS, dock Ethernet. **Forbid:** public ping flood, global DNS replacement as first step, exposing network identifiers. | Stage results, AP band/channel, VPN/captive portal. no current coverage beyond link -> connectivity-stage module. |
| Bluetooth cannot pair/reconnect / latency | Adapter/driver/firmware, `bluetoothd` journal, rfkill, discovery/pair/connect transitions, codec/profile. Valve recommends show-all, device firmware, reconnect/re-pair, then A2DP codec change for latency ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)); dock placement/2.4 GHz coexistence matters ([dock guide](https://help.steampowered.com/en/faqs/view/4C18-08B5-DEC9-3AF4)). **CB/live**. | One device only = peripheral firmware/profile. Adapter absent/firmware error = Deck driver/device. Docked-only/interference-dependent = RF topology. | Reconnect; after capture forget only affected device; update peripheral firmware; line-of-sight/docked A/B. **Forbid:** erase all bonds, reset adapter USB blindly, force codecs unsupported by device. | Device class/vendor (redact address), profile/codec. no module -> Bluetooth state-machine/coexistence detector. |
| Suspend fails / immediate wake / dead after wake | Paired `PM: suspend entry`/exit, chosen sleep state, wake source, driver suspend/resume error, device state before/after. Linux defines `freeze`, `standby`, `mem` and disk states ([kernel PM](https://docs.kernel.org/admin-guide/pm/sleep-states.html)). **CB/PB**. | A nearby error is not causal by proximity alone. Repeat with one device removed identifies config/peripheral. Device absent only after resume is reinit path; failure across previous image/recovery raises firmware/hardware. | Reboot, remove dock/SD/BT one at a time, short controlled sleep, capture immediately. **Forbid:** repeated suspend loops on overheating/failing storage, changing ACPI/kernel params from generic PC guides. | Sleep state, wake source, dock/power/title. `acpi_pm_state` partial -> monotonic suspend transaction and per-device delta detector. |
| Buttons/sticks/trackpads/touch/gyro fail | Steam’s Controller Test, kernel input device inventory, event activity (without recording user content), calibration/firmware, whether BIOS/recovery and multiple titles reproduce. Valve provides Controller Test and notes controller firmware needs ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)). **live**. | Test passes but one layout/title fails = Steam Input/config. Test and firmware UI fail for one physical control = hardware/calibration suspicion. Whole device missing after resume = driver/USB/HID. | Default template, Controller Test, restart, compare before/after wake; external controller A/B. **Forbid:** calibration writes, controller firmware flashing outside official flow, logging raw keyboard events. | Control name, test screen result, firmware, wake/update. no module -> privacy-preserving input inventory/event-count/firmware detector. |
| Touchscreen phantom/missing | DRM/input mapping, touch device presence, bounded contact counts, dmesg HID/I2C errors, BIOS/recovery behavior. **live/CB**. | Wrong rotation/display mapping in Desktop only = config. Missing/phantom touches across recovery with clean/dry panel = digitizer/hardware suspicion. | Clean/dry screen, restart, internal-only display, Controller/UI test. **Forbid:** raw input capture containing gestures/typing, pressure on panel, calibration-file deletion. | Screen condition, charger/dock state, video. no module -> touch device/mapping/error detector. |

### Storage, NVMe, microSD, and filesystems

| Family / user symptom | Evidence and scope | Hardware / driver / config boundary | Safe reversible test; forbid | Escalation addition; coverage -> gap |
|---|---|---|---|---|
| NVMe warnings / I/O errors / disappearance | NVMe controller resets/timeouts, block I/O errors, SMART critical warning/media/data-integrity/error-log fields, device identity/temperature. The [smartmontools NVMe printer](https://www.smartmontools.org/browser/trunk/smartmontools/nvmeprint.cpp) is the upstream implementation that labels these fields. **CB + lifetime H counters**. | Error-log count alone can be historical/nonfatal. New media errors/critical warnings plus I/O failures across boots strongly implicate drive/path; mount/library failure without block evidence is software. | Stop writes, back up, read-only SMART, cold boot/recovery visibility. **Forbid:** destructive self-test/format, firmware flash, repeated benchmarks, `badblocks` on live data. | Raw SMART, exact device, PB journal, backup status. `storage_smart` fixed path -> dynamic NVMe discovery, counter baselines/deltas, controller-reset timeline. |
| microSD not seen / read-only / corrupt games | mmc enumeration, card CID/model/size, RO state, mmc/SDHCI timeouts/CRC, ext4 errors, mount and Steam library state. Valve specifies UHS-I class 3+ and formats through Settings ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)). **CB/H FS**. | Card fails in another trusted reader/system = card. Multiple cards fail only in Deck = slot/driver. Block device healthy but Steam library absent = mount/client config. | Power down before reseat, read-only copy/backup, known-good card/reader A/B. **Forbid:** format when data matters, repeated trim/write tests, counterfeit-capacity test before imaging, bending/cleaning with liquid. | Card identity/size, another-reader result, new errors. `mmc_sd_card` good partial -> card-health delta, dynamic FS mapping, explicit library/mount split. |
| Filesystem errors / forced read-only | First kernel error, mount flags, ext4 superblock state/error counters or BTRFS device stats, underlying block errors. BTRFS says device stats are persistent I/O error-class records ([`btrfs-device(8)`](https://btrfs.readthedocs.io/en/latest/btrfs-device.html)); ext4 error behavior is documented in [kernel ext4](https://docs.kernel.org/filesystems/ext4/index.html). **CB + H counters**. | FS counter with no timestamp does not date incident. Underlying I/O/media errors shift to device; clean device plus reproducible metadata error shifts FS/software. | Stop writes, backup, read-only inspection; offline check only from correct recovery guidance. **Forbid:** `fsck` on mounted FS, `btrfs check --repair`, clearing counters before capture, remount-RW to “see if fixed.” | First error through RO transition, device SMART. `fs_integrity` partial -> mount graph, counter baseline/delta, RO transition classifier. |
| Full disk / update/game install fails | `df` + inode use, Steam library/content logs, journal size/coredump retention, immutable root vs `/home` allocation. `systemd-coredump` explains external core storage/limits ([upstream source](https://github.com/systemd/systemd/blob/main/man/systemd-coredump.xml)). **live/H**. | Space exhaustion is config/retention, not failing flash. Free space with I/O/FS errors moves storage path. | Use Steam Storage UI; inventory largest categories and cores; remove only known cache/content through supported UI after capture. **Forbid:** recursive deletion under system paths, hand-editing immutable root, deleting unknown compatdata/saves. | Per-filesystem blocks/inodes and top categories, redacted. `coredump_analysis`,`steam_client_logs` partial -> capacity/inode/retention detector. |

### Steam client, Gamescope, Proton, games, updates, and immutable OS

| Family / user symptom | Evidence and scope | Hardware / driver / config boundary | Safe reversible test; forbid | Escalation addition; coverage -> gap |
|---|---|---|---|---|
| Steam client/Game Mode crashes or restarts | Client dump/core, user-unit exit/status, Gamescope start/stop/core and session boundary. Core means signal termination, not cause ([systemd-coredump](https://github.com/systemd/systemd/blob/main/man/systemd-coredump.xml)). **CB/H retained**. | Steam-only core with kernel clean = client/plugin/config first. Gamescope core after AMD reset is likely downstream; earliest event rules. | Stable client, disable plugins/themes, reproduce once, preserve dump/backtrace. **Forbid:** delete all userdata/config, upload unsanitized dumps, infer current incident from an old core. | Client/build/channel, plugin list, exact core metadata. `coredump_analysis`,`gamescope_session`,`steam_client_logs` partial -> incident joiner by boot/time/process ancestry. |
| Gamescope crash / black session | Gamescope backtrace/core, exact build/args/backend, Wayland/DRM/Vulkan preceding errors. Gamescope #1434 includes a reproducible cursor-enter crash, requested backtrace and fixing PR; later scaling comments may describe a separate issue ([issue](https://github.com/ValveSoftware/gamescope/issues/1434)). **CB/repro**. | Repro tied to action/build/backend and fixed by known version = software. No process failure and panel also black in BIOS = not Gamescope. | Stable/previous image, stock session args, remove overlays, capture backtrace. **Forbid:** transplant unrelated launch flags, persistent compositor policy from one anecdote. | Repro action + full backtrace + DRM state. `gamescope_session`,`coredump` partial -> symbol/build/backtrace fingerprint detector. |
| One game fails to launch / crashes | Title-specific Steam log, dump, exit code, `PROTON_LOG=1` output, Proton version, prefix age, launch options/mods/anti-cheat. Valve’s [Proton issue template](https://github.com/ValveSoftware/Proton/issues) requests system information and logs; DXVK and VKD3D-Proton are distinct translation layers ([DXVK](https://github.com/doitsujin/dxvk), [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton)). **live/H per title**. | One title/Proton/API only = compatibility/game/config. Multiple unrelated titles with shared GPU/OOM/I/O signature = system. Anti-cheat/service refusal is not hardware. | Verify files via Steam, clear launch options/mods, try Valve-supported Proton versions one at a time, preserve prefix first. **Forbid:** delete compatdata containing saves before backup/cloud check, install random DLLs/scripts, call one crash hardware. | App ID, Proton and game build, sanitized log/dump, save status. `steam_client_logs`,`dxvk_page_fault`,`coredump` partial -> title-scoped bundle and prefix mutation inventory. |
| Shader stutter / poor performance | Frame-time trace, shader pre-caching/download state, CPU/GPU utilization, translation-layer log, cache warm/cold A/B. **live/trend**. | First-run/cache-warm improvement = compilation. Persistent load-normalized cap with thermal/PSI/I/O evidence moves system. Average FPS alone hides stutter cause. | Repeat same scene after warm-up; stock cap/resolution; compare one Proton version. **Forbid:** delete all shader caches first, disable safety limits, benchmark while downloads run. | Frame-time sample, scene, cache/download state. performance modules partial -> frame-time/context collector (opt-in) and background-activity detector. |
| OOM / app killed / swap thrash | `oom-kill` victim/cgroup, PSI, MemAvailable, swap-in/out, kernel allocation failure at incident. Kernel PSI defines CPU/memory/I/O stall signals ([kernel PSI](https://docs.kernel.org/accounting/psi.html)). **CB/live**. | Allocated or 50% used swap alone is not failure. OOM victim plus sustained memory PSI is decisive for memory pressure; GPU reset or I/O error may be separate. | Close overlays/browser/mods, stock title, short PSI/vmstat trend. **Forbid:** disable OOM protections, arbitrary huge swap, memory stress after instability. | Victim, cgroup, workload, PSI window. `memory_swap` partial -> PSI/cgroup victim/time-series detector. |
| Update failed / rollback / regression | Old/new OS, kernel, BIOS, client and Mesa/Gamescope versions; updater/deployment logs; selected slot; same repro on previous image. Valve documents previous-image/recovery hierarchy ([recovery](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3)). **CB/PB/H**. | Previous image fixes with unchanged user data/hardware = strong regression. Both slots fail but clean user/recovery succeeds = user config. All environments fail = hardware/peripheral branch. | Retry on reliable power/network; previous image A/B; stable channel; back up. **Forbid:** interrupt update, manual package replacement on immutable root, re-image before export. | Exact builds/slot/updater status and A/B table. no dedicated module -> deployment/slot/update health detector. |
| Read-only/immutable root or modifications lost | Mount source/options, overlay/state, `steamos-readonly` status if present, pacman/local modification inventory. SteamOS system immutability is policy; inability to edit root is not corruption. **live**. | Expected read-only root = configuration model. Unexpected mount/verity/deployment error plus boot failure = image/storage. Third-party root changes widen unsupported state. | Record changes; use Flatpak/user config; revert only known customization; official repair path. **Forbid:** disable read-only as a generic fix, system-wide `pacman -Syu`, overwrite OS files, hide modifications from reports. | Modification manifest and readonly state. no module -> immutable-root/deviation detector with secret-safe hashes. |
| Plugins/mods/overlays cause UI or title issues | Plugin loader/service versions, injected processes/layers/env, difference with all third-party components disabled. Valve’s first steps explicitly request disabling third-party Desktop Mode applications ([basic guide](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28)). **CB/repro**. | Clean stock repro = not eliminated but less likely. Symptom disappears with one component disabled and returns on re-enable = strong config causality. | Disable, do not delete; binary search components; record versions. **Forbid:** purge userdata, blame plugin from mere presence, upload tokens/config secrets. | Plugin/layer/version list and A/B result. `steam_client_logs` minimal -> third-party/injected-layer inventory detector. |

## Hardware-failure decision standard

Classify conservatively:

1. **Fixable configuration / application:** stock hardware and OS paths function; failure follows a
   title, layout, route, plugin, AP, mode, prefix, cable, or setting; reversible A/B changes outcome.
2. **Driver / firmware / OS:** a timestamped kernel/session/device transition fails, a previous build
   changes outcome, or a reproducible upstream signature matches. This is still not proof of a
   particular source file unless a maintainer/bisect confirms it.
3. **Strong hardware suspicion:** reproducible in BIOS or official recovery, across both OS slots and
   stock config, with known-good external components; or device-local evidence such as new media
   errors, failed enumeration across environments, consistent physical-control failure, or electrical
   abnormality. Stop risky testing and escalate.
4. **Confirmed hardware failure:** Valve/service-center diagnosis, component-level electrical test by
   a qualified technician, or replacement of the isolated component resolves the controlled repro.

Never label `amdgpu` timeout, coredump, nonzero BTRFS counter, swap use, hot chassis, low idle clock,
zero idle fan RPM, or “black screen” alone as hardware failure.

## Universal escalation packet

Generate one sanitized archive containing:

- UTC/local incident time, timezone, boot ID and `journalctl --list-boots`; current and previous boot
  journal windows around the event (kernel + relevant user session), plus pstore if present;
- LCD/OLED/model/board/APU, BIOS, SteamOS build/channel/slot, kernel, Mesa, Gamescope, Steam client,
  Proton/title build, dock firmware, adapter/driver/firmware, charger/cable/display IDs as applicable;
- the smallest exact repro, frequency, last known good, update/resume/dock correlation, and a compact
  known-good A/B table;
- DeckDoc master report plus relevant module logs, untruncated first-error block, core metadata and
  backtrace where available; keep raw dump local unless support requests it;
- physical observations software cannot see: LEDs/chime/fan, pixels/backlight, heat/odor/liquid/drop,
  port/cable condition, and BIOS/recovery result;
- backup status and every test/change already attempted, with rollback result.

Redact usernames, home paths, SSIDs/BSSIDs/MAC/IPs, hostnames, serials unless Valve Support requires
them, account/session tokens, launch credentials, chat text, and game save content. Preserve hashes
and relative timing so two reports can still be compared.

## DeckDoc detector backlog (issue-ready)

Priorities use **P0** = prevents unsafe/wrong verdicts, **P1** = high-frequency localization, **P2** =
depth/convenience. Each detector must emit `OBSERVED`, `NOT_OBSERVED`, or `INACCESSIBLE`; include boot
and time scope; never turn absence into “healthy.”

| Priority | Proposed issue / detector | Minimum safe output and acceptance boundary | Extends |
|---|---|---|---|
| P0 | Model/capability manifest | LCD/OLED, board/APU, panel/backlight capability, Wi-Fi/BT/audio/storage drivers, dynamic DRM/block paths; fixtures for Jupiter/Galileo and unknown hardware | all modules; removes fixed-path/model assumptions |
| P0 | Incident timeline correlator | normalize realtime/monotonic + boot ID; order first AMDGPU/OOM/I/O/PM/device event before downstream cores/restarts; never claim causation from proximity | GPU, DXVK, Gamescope, cores, PM, storage |
| P0 | Evidence scope/access ledger | per source: CB/PB/H/live, requested window, permission/retention/read failure; distinguish empty from unreadable | runner/report schema |
| P0 | Safe escalation packager/redactor | manifest + selected logs + deterministic redaction preview; exclude raw cores/secrets by default; no system mutation | new report packaging |
| P0 | Storage risk gate | detect fresh block/media/FS/RO transition; recommend stop-write/backup; explicitly forbid mounted `fsck`, BTRFS repair, destructive tests | `storage_smart`,`fs_integrity`,`mmc` |
| P1 | Dynamic storage + counter delta | all NVMe/mmc/mount graph; SMART/BTRFS/ext4 counters with prior-report delta; no “new” claim without baseline | storage modules |
| P1 | Suspend transaction analyzer | pair entry/exit by monotonic time, selected sleep state/wake source, per-device before/after and errors; avoid loose “after suspend” attribution | `acpi_pm_state` |
| P1 | USB-C/dock/PD topology | Type-C role/partner/PD power where exported, USB tree resets, DRM connectors/EDID, dock firmware and direct-vs-dock questionnaire | new module |
| P1 | Network stage classifier | interface -> association -> address -> route -> gateway -> DNS; opt-in endpoint; redact identifiers; separate RF/firmware from internet | `wifi_firmware` |
| P1 | Bluetooth state-machine | rfkill/adapter/firmware, discover/pair/connect/profile/codec, resume and coexistence window; redact addresses | new module |
| P1 | Input/controller inventory | Steam input devices, driver/firmware, bounded event counts per control, test instructions; never record key values/text | new module |
| P1 | Display model-aware classifier | OLED path without fake backlight requirement; connector/EDID/CRTC/planes/Gamescope/GPU timeline; external A/B; physical-observation field | `display_blackout` |
| P1 | Boot/deployment/update health | slot/current/previous build, update status/logs, immutable mount state, recovery result questionnaire; no automatic rollback | new module |
| P1 | Load-correlated performance sampler | opt-in 60 s 1 Hz temp/fan/clocks/power/memory PSI/I/O, workload marker and stop thresholds; no stress generator | GPU/battery/thermal/memory |
| P1 | Title-scoped compatibility bundle | App ID/build, Proton version, sanitized per-title log, dump metadata, launch options hash, prefix age/lock/mutation inventory; warn about saves | Steam/DXVK/cores |
| P2 | Audio route/profile/jack model | ALSA -> PipeWire/WirePlumber graph, default route/profile/ports, jack and model-specific mic behavior; Vangogh remediation remains gated | `audio_sof` |
| P2 | Gamescope/core fingerprinting | build/backend/args, restart boundary, symbolized signature when locally available, distinguish normal end dump from crash | Gamescope/cores |
| P2 | Capacity/retention analyzer | blocks + inodes per FS, journal/core/cache categories, supported cleanup guidance only | cores/Steam/FS |
| P2 | Third-party deviation inventory | plugins, Vulkan layers, overlays, injected env/services, readonly-root changes as presence—not blame; secret-safe hashes | Steam/session |
| P2 | Trend/report comparison | compatible manifests, counter deltas and incident-aligned diff; never compare different models/paths as equivalent | runner/schema |

### Suggested issue order

1. Capability manifest, scope/access ledger, incident timeline, and escalation packager establish a safe
   evidence substrate.
2. Storage risk gate, dock/PD, suspend transaction, network stages, Bluetooth, input, and deployment
   health close the largest dangerous/uncovered families.
3. Model-aware display, dynamic storage, performance trend, and title-scoped bundle turn frequent
   reports into reproducible upstream packets.
4. Audio routing, fingerprinting, capacity, deviations, and trend comparison deepen diagnosis after the
   schema is stable.

## Primary-source index

The audit intentionally excludes Reddit, blogs, repair-shop claims, search snippets, and generic PC
fix lists. Representative upstream reports below are evidence examples, not universal diagnoses.

| Authority | Diagnostic use |
|---|---|
| [Valve: Steam Deck basic use/troubleshooting](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28) | model-specific power timing; charging, display, audio/mic, BT, input, Wi-Fi, microSD |
| [Valve: Docking Steam Deck](https://help.steampowered.com/en/faqs/view/4C18-08B5-DEC9-3AF4) | dock reset, cable/device/display cross-tests, external modes, BT placement |
| [Valve: SteamOS recovery](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3) | previous image, factory reset, repair and re-image/data-loss boundaries |
| [Valve SteamOS issues](https://github.com/ValveSoftware/SteamOS/issues), [Steam for Linux issues](https://github.com/ValveSoftware/steam-for-linux/issues) | reporter logs and Valve maintainer triage; treat unconfirmed diagnoses as hypotheses |
| [Valve Gamescope](https://github.com/ValveSoftware/gamescope), [Proton](https://github.com/ValveSoftware/Proton) | compositor/direct-scanout architecture, issue traces, compatibility logging |
| [Linux DRM/KMS](https://docs.kernel.org/gpu/drm-kms.html), [AMDGPU](https://docs.kernel.org/gpu/amdgpu/index.html), [PM sleep](https://docs.kernel.org/admin-guide/pm/sleep-states.html), [hwmon](https://docs.kernel.org/hwmon/sysfs-interface.html), [PSI](https://docs.kernel.org/accounting/psi.html) | kernel signal semantics |
| [systemd journalctl](https://github.com/systemd/systemd/blob/main/man/journalctl.xml), [systemd-coredump](https://github.com/systemd/systemd/blob/main/man/systemd-coredump.xml) | boot/time selection, retention and meaning of core metadata |
| [BTRFS docs](https://btrfs.readthedocs.io/en/latest/), [ext4 docs](https://docs.kernel.org/filesystems/ext4/index.html), [smartmontools](https://www.smartmontools.org/) | persistent counters, filesystem and SMART boundaries |
| [Mesa](https://docs.mesa3d.org/), [DXVK](https://github.com/doitsujin/dxvk), [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton), [SOF](https://thesofproject.github.io/latest/) | graphics translation/driver and DSP evidence; version-specific upstream context |
