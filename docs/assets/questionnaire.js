window.DECKDOC_QUESTIONNAIRE = [
  {
    id: "safety",
    eyebrow: "Stop gate",
    title: "Is the Deck physically unsafe?",
    hint: "Select every observation. Any match stops software troubleshooting.",
    tone: "danger",
    options: [
      ["smoke", "Smoke or electrical smell"], ["swelling", "Swelling or case separation"],
      ["liquid", "Liquid ingress"], ["sparking", "Sparking or arcing"],
      ["port-damage", "Damaged USB-C port or cable"], ["hot-off", "Abnormally hot while idle or off"],
      ["none-unsafe", "None of these"]
    ]
  },
  {
    id: "symptom",
    eyebrow: "01 · Symptom",
    title: "What is actually failing?",
    hint: "Choose observed symptoms, not your suspected diagnosis.",
    options: [
      ["display", "Internal screen black, dim, flickering, or corrupted"],
      ["boot", "No power, boot loop, logo freeze, or cannot reach SteamOS"],
      ["crash", "Game closes, freezes, hard-locks, or returns to Library"],
      ["audio", "No speakers, headphones, microphone, or audio device"],
      ["network", "Wi-Fi missing, disconnecting, slow, or no internet"],
      ["thermal", "Hot, fan loud/stopped, throttling, or sudden shutdown"],
      ["charge-problem", "Will not charge, slow charging, battery drain, or jumps"],
      ["storage", "NVMe/microSD missing, read-only, corrupt, or I/O errors"],
      ["dock", "Dock, USB-C, Ethernet, USB, charging, or external display"],
      ["input", "Buttons, sticks, pads, touch, gyro, Bluetooth, or controller"],
      ["performance", "Low FPS, stutter, low clocks, or long stalls"],
      ["update", "Update failed, changes vanished, rollback, or image health"]
    ]
  },
  {
    id: "timing",
    eyebrow: "02 · Timing",
    title: "When does it happen?",
    hint: "The transition immediately before failure is often more useful than the final screen.",
    options: [
      ["first-after-days", "First power-on after several days off"],
      ["cold-boot", "Every cold boot"], ["boot-loop", "During boot or in a boot loop"],
      ["logo-freeze", "At the logo"], ["after-wake", "Immediately after wake/resume"],
      ["during-suspend", "While trying to sleep or immediate wake"],
      ["during-game", "In the middle of gaming"], ["game-launch", "When launching a game"],
      ["returns-library", "At return to Library or game exit"],
      ["mode-switch", "Switching Game Mode ↔ Desktop Mode"],
      ["dock-transition", "Docking or undocking"], ["display-hotplug", "Connecting an external display"],
      ["after-update", "Started directly after an OS/client/BIOS update"],
      ["after-plugin", "Started after a plugin, mod, overlay, or root change"],
      ["under-load", "Only under sustained load"], ["idle", "While idle"],
      ["while-charging", "Only while charging"], ["battery-only", "Only on battery"],
      ["random", "No repeatable transition yet"]
    ]
  },
  {
    id: "alive",
    eyebrow: "03 · What survives",
    title: "What still works during the failure?",
    hint: "These answers separate a dead system, a frozen session, and one failed output path.",
    options: [
      ["sound-works", "Game/UI audio continues"], ["input-works", "Controls still make sounds or haptics"],
      ["ssh-works", "SSH still connects"], ["stream-works", "Streaming/recording shows moving frames"],
      ["external-works", "External display works while internal is black"],
      ["internal-works", "Internal display works while external is black"],
      ["fan-reacts", "Fan still reacts to load"], ["power-led", "Power/charge LED behaves normally"],
      ["screen-backlight", "LCD backlight is visibly on"], ["screen-no-light", "LCD has no visible backlight"],
      ["connected-icon", "Wi-Fi says connected"], ["local-network", "Gateway/local network still works"],
      ["whole-system", "Nothing responds / whole system appears dead"],
      ["hard-lock", "Frozen image/audio loop; no SSH or input"], ["no-response", "No LED, chime, fan, haptic, or display"]
    ]
  },
  {
    id: "scope",
    eyebrow: "04 · Scope",
    title: "How broad and repeatable is it?",
    hint: "Controlled contrasts move the hardware/software boundary.",
    options: [
      ["one-title", "One title, save, scene, layout, or app only"],
      ["all-titles", "Several unrelated games"], ["desktop-too", "Desktop Mode too"],
      ["game-mode", "Game Mode only"], ["second-boot-works", "Forced off, then second boot works"],
      ["restart-fixes", "Normal restart temporarily fixes it"],
      ["previous-image-fixes", "Previous SteamOS image fixes it"],
      ["stable-fixes", "Stable channel fixes it"], ["plugins-off-fixes", "Disabling plugins/mods fixes it"],
      ["firmware-also-fails", "Also fails in BIOS/firmware or official recovery"],
      ["rescue-works", "Works in Valve recovery or DeckDoc Rescue"],
      ["other-deck", "Same accessory fails on another host"],
      ["known-good-accessory", "Known-good replacement cable/dock/card/display also fails"],
      ["repro-always", "Reproduces every time"], ["repro-rare", "Rare/intermittent"],
      ["new-problem", "New after previously working"], ["physical-event", "Started after drop, liquid, opening, or port damage"]
    ]
  },
  {
    id: "environment",
    eyebrow: "05 · Environment",
    title: "Which hardware and software path?",
    hint: "Model and OS decide which signatures and fixes can safely apply.",
    options: [
      ["lcd", "Steam Deck LCD / Jupiter"], ["oled", "Steam Deck OLED / Galileo"],
      ["model-unknown", "Model unknown"], ["steamos", "SteamOS"], ["windows", "Windows"],
      ["other-os", "Another Linux/OS"], ["docked", "Docked"], ["handheld", "Handheld/direct"],
      ["official-dock", "Official Valve Dock"], ["third-party-dock", "Third-party dock/hub"],
      ["uses-external-display", "External monitor/TV connected"],
      ["ethernet-drops", "Dock Ethernet drops"], ["vpn", "VPN/custom DNS/captive portal"],
      ["beta-channel", "Beta/Preview client or OS"], ["third-party", "Decky/plugins/mods/overlays/root changes"],
      ["charge-limit", "Custom battery charge limit active"], ["micro-sd", "microSD involved"],
      ["replacement-ssd", "Replacement/additional SSD"], ["bluetooth-device", "Bluetooth accessory involved"]
    ]
  },
  {
    id: "details",
    eyebrow: "06 · Exact behavior",
    title: "Which narrower observations match?",
    hint: "Choose only what you directly saw or measured.",
    options: [
      ["device-missing", "Device/interface disappears entirely"], ["interface-down", "Interface exists but is DOWN"],
      ["fan-zero", "Fan reports or appears 0 RPM"], ["hot-now", "Temperature is at least 70°C while fan is stopped"],
      ["read-only", "Storage changed to read-only"], ["io-errors", "Block/MMC/NVMe/filesystem errors appeared"],
      ["battery-jump", "Battery percentage jumps or capacity collapses"],
      ["slow-charge", "Charging power is low or repeatedly renegotiates"],
      ["external-display-fails", "External display blank/wrong mode/flicker"],
      ["multi-dock-failure", "Multiple dock functions reset together"],
      ["audio-route", "Audio devices exist but wrong output/profile selected"],
      ["bluetooth-pair", "Bluetooth discovery/pair/connect fails"],
      ["bluetooth-latency", "Bluetooth works but has latency/dropouts"],
      ["touch-phantom", "Phantom or mapped-wrong touch"], ["one-control", "One physical control fails"],
      ["low-clocks", "Clocks stay low under measured load"], ["stutter-warm", "Stutter improves after repeating the same scene"],
      ["full-disk", "Filesystem or inode space is full"], ["immutable-root", "Read-only root or OS changes disappeared"]
    ]
  },
  {
    id: "evidence",
    eyebrow: "07 · Evidence",
    title: "What did DeckDoc or the logs actually show?",
    hint: "A scary string is a lead. Select only current-incident evidence with matching timestamps.",
    options: [
      ["sig-display-gap", "LIVE_RENDER_TO_PHYSICAL_SCANOUT_GAP"],
      ["sig-panel-incomplete", "PANEL_OR_MODESET_STATE_INCOMPLETE"],
      ["sig-gpu-timeout", "AMDGPU ring/job timeout"], ["sig-gpu-reset-ok", "GPU reset succeeded"],
      ["sig-gpu-reset-fail", "GPU reset failed or skipped"], ["sig-page-fault", "GPU VM/UTCL2 page fault"],
      ["sig-gamescope-core", "Current Gamescope SIGABRT/SIGSEGV"],
      ["sig-session-restarts", "More than one Gamescope session start"],
      ["sig-oom", "OOM killer / Out of memory"], ["sig-live-swap", "Live vmstat swap I/O"],
      ["sig-sof", "SOF panic / IPC timeout / -22"], ["sig-wifi-fw", "Wireless firmware crash/failure"],
      ["sig-hot-fan", "LIVE_ZERO_RPM_WITH_HOT_SENSOR_AFTER_SUSPEND"],
      ["sig-dock", "TOPOLOGY_CHANGE_WITH_DOCK_PATH_ERROR"],
      ["sig-ext4", "EXT4-fs error on mmc/storage"], ["sig-smart", "New SMART media/critical warning"],
      ["sig-btrfs", "Nonzero BTRFS device counter without a baseline"],
      ["sig-core-old", "Only retained/old core dumps"], ["sig-no-errors", "No matching errors in readable window"],
      ["sig-inaccessible", "Relevant source was inaccessible or not retained"]
    ]
  }
];

// The guided path starts broad, then reveals only the symptom families nested
// beneath the selected category. Every primary symptom appears exactly once.
window.DECKDOC_CATEGORIES = [
  {
    id: "screen_display",
    code: "SCREEN",
    title: "Screen & display",
    description: "Black, dim, flickering, corrupted, or missing picture",
    symptoms: ["display"]
  },
  {
    id: "power_boot",
    code: "POWER",
    title: "Power, boot & charging",
    description: "Won't start, boot loops, heat, fan, battery, or charging",
    symptoms: ["boot", "charge-problem", "thermal"]
  },
  {
    id: "games_performance",
    code: "GAMES",
    title: "Games & performance",
    description: "Crashes, freezes, low FPS, stutter, or low clocks",
    symptoms: ["crash", "performance"]
  },
  {
    id: "sound_network",
    code: "LINK",
    title: "Sound & connectivity",
    description: "Audio, microphone, Wi-Fi, internet, or resume trouble",
    symptoms: ["audio", "network"]
  },
  {
    id: "controls_dock",
    code: "I/O",
    title: "Controls & accessories",
    description: "Buttons, touch, Bluetooth, docks, USB, or external gear",
    symptoms: ["input", "dock"]
  },
  {
    id: "storage_system",
    code: "SYSTEM",
    title: "Storage & system updates",
    description: "NVMe, microSD, corrupt data, updates, rollback, or image health",
    symptoms: ["storage", "update"]
  }
];

// Selecting one side makes the other unavailable until the first answer is
// cleared. These rules are symmetric and shared by guided and all-check views.
window.DECKDOC_CONFLICTS = [
  ["screen-backlight", "screen-no-light", "The LCD backlight cannot be both visibly on and visibly off."],
  ["oled", "screen-backlight", "OLED models do not use the LCD backlight check."],
  ["oled", "screen-no-light", "OLED models do not use the LCD backlight check."],
  ["fan-zero", "fan-reacts", "A stopped fan conflicts with a fan that still reacts to load."],
  ["device-missing", "interface-down", "A missing device cannot also be present in a DOWN state."],
  ["device-missing", "connected-icon", "A missing device cannot still report connected."],
  ["device-missing", "local-network", "A missing network device cannot still reach the local network."],
  ["interface-down", "connected-icon", "A DOWN interface conflicts with an active connected state."],
  ["interface-down", "local-network", "A DOWN interface conflicts with working local connectivity."],
  ["no-response", "power-led", "No response includes no normal LED response."],
  ["no-response", "sound-works", "No response conflicts with continuing audio."],
  ["no-response", "input-works", "No response conflicts with controls or haptics still working."],
  ["no-response", "ssh-works", "No response conflicts with a working SSH session."],
  ["no-response", "stream-works", "No response conflicts with a live stream or recording."],
  ["no-response", "fan-reacts", "No response conflicts with a fan reacting to load."],
  ["whole-system", "sound-works", "A wholly unresponsive system conflicts with continuing audio."],
  ["whole-system", "input-works", "A wholly unresponsive system conflicts with working controls."],
  ["whole-system", "ssh-works", "A wholly unresponsive system conflicts with a working SSH session."],
  ["whole-system", "stream-works", "A wholly unresponsive system conflicts with advancing frames."],
  ["hard-lock", "input-works", "A hard lock conflicts with controls still being accepted."],
  ["hard-lock", "ssh-works", "A hard lock conflicts with a working SSH session."],
  ["hard-lock", "stream-works", "A hard lock conflicts with advancing frames."],
  ["sig-no-errors", "sig-gpu-timeout", "No matching errors conflicts with a current-incident GPU timeout."],
  ["sig-no-errors", "sig-sof", "No matching errors conflicts with a current-incident SOF failure."],
  ["sig-no-errors", "sig-wifi-fw", "No matching errors conflicts with a current-incident firmware failure."],
  ["sig-no-errors", "sig-ext4", "No matching errors conflicts with a current-incident filesystem error."],
  ["sig-no-errors", "sig-smart", "No matching errors conflicts with a current SMART warning."]
];

// Ordered follow-ups define the progressive checklist. The first entries are
// the highest-value branch separators for each primary symptom.
window.DECKDOC_RELATED_CHECKS = {
  display: ["sound-works", "screen-backlight", "screen-no-light", "input-works", "ssh-works", "stream-works", "external-works", "whole-system", "during-game", "after-wake", "first-after-days", "second-boot-works", "mode-switch", "dock-transition", "lcd", "oled", "sig-display-gap", "sig-panel-incomplete", "sig-gpu-timeout", "sig-no-errors"],
  boot: ["no-response", "power-led", "sound-works", "logo-freeze", "boot-loop", "cold-boot", "first-after-days", "second-boot-works", "after-update", "firmware-also-fails", "rescue-works", "lcd", "oled", "sig-no-errors", "sig-inaccessible"],
  crash: ["one-title", "all-titles", "desktop-too", "during-game", "game-launch", "returns-library", "hard-lock", "ssh-works", "after-update", "after-plugin", "plugins-off-fixes", "sig-gpu-timeout", "sig-gpu-reset-ok", "sig-gpu-reset-fail", "sig-page-fault", "sig-gamescope-core", "sig-oom"],
  audio: ["after-wake", "device-missing", "audio-route", "sig-sof", "lcd", "oled", "bluetooth-device", "restart-fixes", "sig-no-errors"],
  network: ["after-wake", "device-missing", "interface-down", "connected-icon", "local-network", "sig-wifi-fw", "docked", "vpn", "restart-fixes", "sig-no-errors"],
  thermal: ["fan-zero", "fan-reacts", "hot-now", "under-load", "idle", "after-wake", "while-charging", "charge-limit", "sig-hot-fan", "repro-always", "repro-rare"],
  "charge-problem": ["docked", "handheld", "third-party-dock", "official-dock", "slow-charge", "battery-jump", "while-charging", "battery-only", "port-damage", "known-good-accessory", "repro-always", "repro-rare"],
  storage: ["micro-sd", "replacement-ssd", "device-missing", "read-only", "io-errors", "sig-ext4", "sig-smart", "sig-btrfs", "full-disk", "repro-always", "repro-rare"],
  dock: ["third-party-dock", "official-dock", "multi-dock-failure", "external-display-fails", "ethernet-drops", "charge-problem", "dock-transition", "display-hotplug", "known-good-accessory", "other-deck", "sig-dock"],
  input: ["one-title", "one-control", "firmware-also-fails", "after-wake", "bluetooth-device", "bluetooth-pair", "bluetooth-latency", "touch-phantom", "restart-fixes", "repro-always", "repro-rare"],
  performance: ["one-title", "all-titles", "under-load", "low-clocks", "stutter-warm", "after-update", "after-plugin", "plugins-off-fixes", "sig-live-swap", "sig-oom", "sig-gpu-timeout"],
  update: ["after-update", "boot-loop", "logo-freeze", "previous-image-fixes", "stable-fixes", "immutable-root", "rescue-works", "full-disk", "sig-inaccessible"]
};
