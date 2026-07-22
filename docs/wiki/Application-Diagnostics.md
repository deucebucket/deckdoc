# Application diagnostics

DeckDoc treats an application as one layer in the Deck, not as the whole diagnosis. A title that does
not appear can fail before the app starts, inside the app's loader or guest runtime, at the
Gamescope/Vulkan boundary, in SteamOS, or because the hardware path failed. The purpose of an app
adapter is to identify which boundary was reached and whether useful work continued.

## The diagnostic boundary

Use this sequence for any app:

1. **Install and launch:** is the expected production install/profile present, and did the intended
   executable start rather than an old or duplicate install?
2. **Host initialization:** did the app open its renderer, audio, input, files, and required runtime?
3. **Workload start:** did the game, guest, job, or document reach its app-defined running stage?
4. **Progress:** did frame, queue, heartbeat, transaction, or output counters continue advancing?
5. **Session/OS correlation:** did Gamescope restart, Vulkan lose the device, the kernel reset the GPU,
   memory run out, storage disappear, or another system module record the same event?
6. **Reversible contrast:** does the symptom follow one profile, cache, title, app build, display mode,
   or clean software state?
7. **Hardware contrast:** does it persist outside the app, across clean configuration, and where
   possible in firmware, recovery, or a second OS?

A running process is not proof of progress. A black screen is not proof of a dead renderer. One
warning is not proof of a root cause. DeckDoc requires a stage plus a progress signal and correlates
fatal system evidence before changing the failure boundary.

## RyuDeck adapter

`module_ryudeck.log` is the first application-specific adapter. It reports:

- production install and profile presence;
- whether the production runtime is active;
- installed firmware content count and the runtime-reported firmware version;
- whether `emulation_running` was reached;
- bounded zero- and nonzero-FPS samples plus the latest FPS sample;
- PTC, shader/cache, background-pipeline, controller/input, and realtime-scheduler signal counts;
- device-loss, out-of-memory, and fatal process/guest counts;
- one primary runtime signature and, where justified, a cache hypothesis.

The important signatures are:

| Signature | Meaning | Next contrast |
|---|---|---|
| `NOT_INSTALLED_OR_NO_PROFILE` | production install/profile evidence is absent | verify intended install and user profile |
| `ACTIVE_WITHOUT_RUNTIME_LOG` | process exists but structured title evidence is unavailable | confirm launch target/build and logging state |
| `GUEST_STARTUP_STALL` | guest reached running state but produced at least 30 zero-FPS samples and no nonzero frames | compare firmware, title state, and a preserved clean-cache A/B |
| `STALE_TITLE_CACHE_SUSPECTED` | the startup stall aligns with PTC/shader cache evidence | close RyuDeck, back up only that title cache, retry empty |
| `ACTIVE_RUNTIME_LOG_STALLED` | process remains but its structured telemetry stopped advancing | inspect process/core/GPU/session evidence at the same time |
| `RENDERER_OR_PROCESS_FATAL` | device loss, OOM, guest crash, unhandled exception, or process fatal was recorded | correlate GPU, memory, and coredump modules |
| `RENDERING` | current runtime is producing nonzero frames | move downstream toward presentation/display or user-visible app state |
| `RUNTIME_INDETERMINATE` | runtime started but the bounded evidence cannot prove healthy progress or a sustained stall | capture longer/current evidence |

Realtime scheduling `EPERM` is performance context, not automatically a launch failure. Background
pipeline misses during a fresh cache build can be temporary; if FPS continues and the log advances,
DeckDoc reports rendering rather than diagnosing a hang.

## Privacy contract for app adapters

App logs commonly contain usernames, library paths, ROM/game names, title and account IDs, controller
identifiers, launch arguments, network endpoints, and tokens. DeckDoc does not copy raw RyuDeck lines
into its report. The adapter emits only allowlisted state, versions, ages, counts, and signatures; the
shared report filter is still applied before disk as a second boundary.

Future adapters must follow the same rule: parse locally, minimize before output, never collect
credentials or content, and prove with adversarial fixtures that app-specific identifiers do not
escape. Review every report before posting because upstream formats and identifiers change.

## What this does not automate

DeckDoc does not delete app caches, saves, firmware, profiles, prefixes, mods, or configuration. A
cache contrast means move the exact cache to a timestamped backup while the app is closed, retry, and
restore it if the diagnosis does not improve. Firmware changes and copyrighted content remain the
owner's responsibility. Visible pixels, usable audio, and controller behavior still require human
confirmation.
