# Wwise musical-timeline spike (#45)

## Recommendation

Adopt Wwise for the next arrangement prototype in #21, behind the
repository-owned adapter demonstrated here. Continuous Wwise segment position is
stable enough to back the existing `BeatClock` contract, and Wwise's authored
State transitions provide useful bar-quantized layer and section changes without
moving combat rules into the audio engine.

This is a recommendation, not a production migration. Keep native Godot audio as
the rollback path until #21 proves the arrangement interface in the real combat
flow. An FMOD comparison is not warranted by this spike because no Wwise-specific
technical blocker was found. Revisit the smallest equivalent FMOD check only if a
later target platform, licensing constraint, or integration upgrade blocks Wwise.

## What the spike contains

- `wwise_music_adapter.gd`: a repository-owned, `BeatClock`-compatible timing and
  arrangement seam. Combat callers do not see Wwise event, callback, State, or
  SDK types.
- `wwise_runtime_bridge.gd`: the replaceable Wwise-specific implementation behind
  that seam.
- `wwise_position_continuity_tracker.gd`: a spike-only monitor that compares each
  continuous position sample with monotonic elapsed time and records regressions
  separately from material delta anomalies.
- `wwise_spike_harness.tscn`: an isolated recorder that exercises looping,
  quarter/half/whole boundaries, continuous position, layer changes, and section
  transitions.
- `author_spike.lua`: an idempotent Wwise automation script for the project under
  `authoring/WwiseSpike`.
- `WwiseBanks`: the generated Windows bank and metadata used by Godot.
- `evidence`: raw CSV observations and JSON summaries from the editor soak and
  exported Windows build.

The authored music is 130 BPM in 4/4. `Combat_Spike` is a Music Switch Container
with four combinations of Loop/Alternate section and Disabled/Enabled layer
State. Its 32-beat segments have explicit entry and exit cues. The universal
[transition rule](https://www.audiokinetic.com/en/library/edge/?id=setting_source_and_destination_properties&source=Help)
changes at the next bar while preserving the destination timeline position. The
harness requests a layer change at beat 16, Alternate at beat 32, the layer off at
beat 48, and Loop at beat 64, then repeats that sequence.

## Versions and dependency pin

| Component | Tested version |
|---|---|
| Godot | 4.6.3 stable Mono, official commit `7d41c59c` |
| Wwise Authoring and SDK | 2025.1.9 build 9197 |
| Community Godot integration | [`wwise_v2025.1.9`](https://github.com/alessandrofama/wwise-godot-integration/releases/tag/wwise_v2025.1.9), commit `da5f19a08c77aac91f1ce9f3db0ff56024ca7277` |
| Integration release archive | 242,032,793 bytes; SHA-256 `5948039D37C420E984AB2A6A5484C66720BA384B9C6AD2C474E12AA2DFBC6536` |

The integration is community-maintained rather than an Audiokinetic-supported
Godot product. Its code is MIT-licensed; the bundled Wwise SDK/runtime remains
subject to Audiokinetic's separate terms. Only the Windows editor/profile,
Windows debug/profile, and Windows release/release native slices are committed.
Each slice contains only its core DLL: 3 tracked native files totaling 18,101,248
bytes (17.26 MiB). Before the final trim those directories held 48 files totaling
37,461,577 bytes (35.73 MiB). Removing 39 unused DSP DLLs and 6 link-time
`.lib`/`.exp` artifacts removed 19,360,329 bytes (18.46 MiB, 51.7%). The full
expanded integration release was about 713 MiB and mostly contained unused
platform binaries.

`WwiseBanks/Windows/PluginInfo.json` names only the standard `System` and
`No Output` audio devices; the authored bank uses no optional DSP plug-in. Commit
an additional DSP library only when regenerated bank metadata proves the runtime
dependency and its licensing has been reviewed. The neighboring `.lib` and `.exp`
files are linker artifacts and are not needed by Godot editor or exported runtime
loading.

Treat the exact Wwise patch version and integration tag as one dependency. An
upgrade requires regenerating banks, validating `PluginInfo.json`, importing the
editor with the teardown caveat below, rerunning the adapter tests, completing the
timing soak, and verifying an export contains only its required runtime libraries.
Do not silently mix SDK and integration patch versions.

## Timing design

The adapter uses extrapolated `get_playing_segment_info(..., true)` position as
the authoritative musical clock. Each frame it emits every crossed subdivision,
so a late frame recovers boundaries exactly once. Segment-position wraps are
unrolled into one continuous timeline. Arrangement requests do not reset that
timeline.

The evidence harness observes every valid continuous-position query through a
repository-owned signal. It records all samples the adapter rejects to preserve a
monotonic gameplay clock, and separately flags position-delta errors above 20 ms
as material discontinuities. This threshold distinguishes the integration's
sub-frame query noise from a stall or jump large enough to matter to presentation;
all raw anomalies remain in the CSV.

Wwise music callbacks are observations, not the gameplay clock. The harness
compares their authored positions with the extrapolated position to measure
main-thread callback jitter. A short exploratory run observed one missing beat
callback at a natural authored segment wrap while the continuous adapter still
published every boundary; this is why scoring must not depend on callback
delivery. Callbacks remain useful for presentation and diagnostics.

Future latency calibration in #25 should apply a signed scoring/input offset to
the continuous snapshot. It must not rewrite the Wwise musical position or teach
combat code about Wwise callback timing.

The integration-required `WwiseRuntimeManager` autoload is the sole owner of Wwise
`RenderAudio()`. The adapter never renders independently. The adapter waits for
the first valid music callback before polling segment position, avoiding expected
startup errors while the event enters its music segment.

The editor/export plugin injects `WwiseRuntimeManager` if it is absent. Attempting
to replace it with a scene-local manager caused exported builds to initialize the
sound engine twice and emit `AK_AlreadyInitialized`, so the spike keeps the
upstream lifecycle. This means the normal game and test processes initialize the
vendored engine even though Combat V1 never calls it—an integration cost that #21
must either accept or solve in a maintained integration fork.

## Recorded evidence

The strict result for a run is: exit code 0, exact `=== done ===`, and no `FAIL`,
`SCRIPT ERROR`, or line-leading `ERROR:` diagnostic.

| Run | Duration | Continuous whole beats | Missed / duplicate | Beat callbacks | Callback missed / duplicate | Callback error (mean / jitter / p95 / max) | Position samples / discontinuities / max delta | Clock phase drift |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Godot headless soak | 900.018 s | 1,949 | 0 / 0 | 1,890 | 60 / 0 | 3.004 / 2.400 / 6 / 40 ms | 129,829 / 2 / 30.478 ms | -13.556 ms (-15.062 ppm) |
| Windows release export | 10.033 s | 21 | 0 / 0 | 22 | 0 / 0 | 2.434 / 1.928 / 5 / 6 ms | 1,593 / 0 / 10.278 ms | -3.301 ms (-329 ppm; short-run sampling noise) |

The raw CSV stores every emitted boundary, arrangement request, and callback
comparison. JSON is a reproducible summary rather than a substitute for the raw
data. The clock drift value compares the first and last sampled audio-position
phase against Godot's monotonic clock; it is not wall-clock playback latency.
The full soak recorded consecutive quarter-steps 1–7,799: 1,949 whole beats,
1,950 half-beats, and 3,900 quarter-beats, all exactly once. Its 60 missing Wwise
beat callbacks clustered at authored segment/arrangement changes; no callback was
allowed to suppress or duplicate an adapter boundary. The isolated 51 ms maximum
callback error from the original soak did not affect its 6 ms p95; the
instrumented rerun reduced the maximum to 40 ms with the same p95.

Of 129,829 continuous samples, 5,442 small backward source samples were rejected
and clamped by the adapter. Their largest delta error was 11.203 ms. Two adjacent,
accepted samples at 233.240 s formed one bounded stall/catch-up pair (-29.420 ms,
then +30.478 ms); they produced no skipped, duplicate, or non-monotonic published
boundary and did not accumulate. The final phase drift remained -13.556 ms across
15 minutes. This observed behavior supports using the clamped continuous position
for gameplay, while #21 should retain the monitor and calibration seam rather than
assuming the raw integration query is perfectly monotonic.

Validate the complete quarter-step sequence, summary metrics, and raw anomaly
counts with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File ./spikes/wwise/analyze_timing_evidence.ps1 `
  ./spikes/wwise/evidence/editor/wwise-timing-2026-08-20T14-07-54.csv
```

The post-trim Windows release export completed under the same strict contract.
Its 10.023-second packaged runtime emitted 21 consecutive whole boundaries, no
missed/duplicate/non-monotonic boundary, 1,439 position samples, 62 clamped minor
regressions, no material discontinuity, and a 9.924 ms maximum delta error. Its
files were:

| File/content | Bytes |
|---|---:|
| `RhythmGameWwiseSpike.exe` | 104,755,712 |
| exported `.pck` | 7,860,860 |
| Wwise release DLL | 4,248,064 |
| export total (excluding evidence logs) | 116,864,636 (111.45 MiB) |
| Wwise bank plus runtime DLL | 12,067,358 (11.51 MiB) |

The test bank is 7,819,294 bytes and is dominated by uncompressed prototype PCM.
Production sizing should use an intentional conversion/compression preset.

One integration caveat remains visible outside runtime verification: a headless
Godot **editor import-and-quit** emitted renderer RID/resource-leak diagnostics at
editor teardown. Focused scripts, the playback harness, and the exported build did
not emit those errors. Treat that as an integration-upgrade guardrail; investigate
before calling editor-import CI green, even though it did not affect playback.
The headless playback/test processes also printed Godot's line-leading `WARNING:
ObjectDB instances leaked at exit`. A minimal Godot/Mono project exited cleanly,
while the same project with only `wwise.gdextension` loaded--no runtime manager,
listener, event, bank, or harness--reproduced exactly one anonymous leaked
`ObjectDB` instance. This isolates the warning to the native community integration
rather than the spike scene or adapter.

Manual Godot 4.6.3 editor validation on 2026-08-20 confirmed audible backing/layer
playback, no `SCRIPT ERROR` or line-leading `ERROR:` console diagnostics, and
stable repeated run/stop cycles in one editor session; the Wwise authoring project
was also inspected without finding a configuration issue.
The single process-exit warning is therefore non-blocking evidence of an
integration teardown defect, not an observed accumulating runtime leak. Warnings
are permitted by the repository's strict contract, but #21 should retain a
teardown smoke check and re-open this risk if the leaked-instance count grows,
voices or game objects fail to return to baseline, memory rises across scene
restarts, or the warning appears before process exit.

## Post-trim packaging verification

The final 2026-08-24 trim and verification changed packaging only; the adapter,
bridge, bank, and accepted 15-minute timing evidence above are unchanged. The
short-run packaging logs were intentionally written to ignored temporary paths;
the committed raw acceptance record remains the full timing evidence above.

- Native inventory: 48 files / 37,461,577 bytes before; 3 core DLLs /
  18,101,248 bytes after. No DSP directory, `.lib`, `.exp`, or `*~RF*.TMP`
  artifact remained. The three tracked DLLs are the editor/profile,
  template-debug/profile, and template-release/release libraries referenced by
  `wwise.gdextension`.
- Bank metadata: `PluginInfo.json` contains only the standard `System` and
  `No Output` audio devices.
- Focused Wwise contract: 3/3 scripts valid, 60 visible `PASS` lines, every exact
  `=== done ===`, and no strict diagnostic.
- Short playback harness: 35.019 seconds, 75 whole boundaries, 5,048 position
  samples, and all four layer/section requests (layer on/off and Alternate/Loop).
  It recorded no missed/duplicate/non-monotonic boundary and no material position
  discontinuity; 197 minor source regressions were clamped, with a 10.968 ms
  maximum delta error.
- Windows release export: export exit `0` with no strict diagnostic. The package
  contains the release core DLL and no DSP/linker artifact. Its waited packaged
  runtime exited `0`, printed one exact completion marker, and emitted no `FAIL`,
  `SCRIPT ERROR`, or line-leading `ERROR:`.
- Complete suite: 55/55 scripts valid and 933 visible `PASS` lines under the same
  strict contract.

Godot's native-extension `ObjectDB` exit warning remains the isolated,
non-accumulating caveat documented above. These runtime results do not supersede
the separate headless editor-import teardown caveat and must not be reported as a
green editor-import CI check.

## Reproduce the authoring project and bank

Install Wwise 2025.1.9.9197 through the
[Audiokinetic Launcher](https://www.audiokinetic.com/en/library/Launcher_2023.2.4.3909/?id=install_wwise_through_launcher&source=InstallGuide).
From the repository root in PowerShell:

```powershell
$wwiseConsole = "C:\Audiokinetic\Wwise_2025.1.9.9197\Authoring\x64\Release\bin\WwiseConsole.exe"
$wwiseProject = "$PWD\spikes\wwise\authoring\WwiseSpike\WwiseSpike.wproj"

& $wwiseConsole execute-lua-script "$PWD\spikes\wwise\author_spike.lua" `
  --project $wwiseProject --watchdog-timeout 120 --no-color

& $wwiseConsole generate-soundbank $wwiseProject `
  --platform Windows --bank Combat_Spike `
  --root-output-path "$PWD\WwiseBanks" `
  --soundbank-path Windows "$PWD\WwiseBanks\Windows" `
  --no-source-control --save --verbose
```

The script is idempotent. To change the experiment, update its object properties,
rerun it, generate the bank, and restart the harness so Wwise reloads the bank.
On the final machine, an idempotent author pass took 0.917 seconds wall time and a
zero-warning/zero-error bank rebuild took 0.664 seconds. Once the automation
existed, changing and reloading the bank was therefore a short command-line loop;
the integration installation, project schema discovery, and first export were the
material setup cost. Wwise Authoring remains the practical tool for auditioning
and visually inspecting transitions.

## Run the harness

All Godot commands on the primary Windows machine must run outside the filesystem
sandbox, as required by `docs/DEVELOPMENT.md`.

```powershell
$godot = "C:\Users\Tim\External Applications\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"

& $godot --headless --path . `
  --log-file "$PWD\spikes\wwise\evidence\editor\editor-run.log" `
  res://spikes/wwise/wwise_spike_harness.tscn -- `
  --spike-seconds=900 `
  --evidence-dir="$PWD\spikes\wwise\evidence\editor"
```

Focused adapter tests:

```powershell
& $godot --headless --path . -s res://test/test_wwise_music_adapter.gd
& $godot --headless --path . -s res://test/test_wwise_runtime_bridge.gd
& $godot --headless --path . -s res://test/test_wwise_spike_harness.gd
```

## Windows export workflow

`export_presets.cfg` intentionally exports only the isolated harness and its
dependencies. Because Godot still resolves the project's configured main scene
and autoloads during export, temporarily set both main-scene keys to
`res://spikes/wwise/wwise_spike_harness.tscn` and temporarily remove the normal
`BeatClock` and `RhythmInput` autoloads. Keep `WwiseRuntimeManager`; it must remain
the only Wwise lifecycle/render owner. Export, then restore `project.godot` before
committing.

```powershell
& $godot --headless --path . --export-release "Wwise Spike Windows"
$runtime = "$PWD\builds\wwise-spike\RhythmGameWwiseSpike.exe"
$evidence = "$PWD\spikes\wwise\evidence\windows-export"
$log = "$evidence\export-run.log"
$process = Start-Process -FilePath $runtime -WindowStyle Hidden -PassThru -Wait `
  -ArgumentList @("--headless", "--log-file", $log, "--", "--spike-seconds=10", "--evidence-dir=$evidence")
if ($process.ExitCode -ne 0) { throw "Wwise export exited $($process.ExitCode)" }
```

The build directory is ignored. The evidence files are retained.

## Version-control policy

Commit:

- the `.wproj`, work units, Originals, and their Wwise import metadata;
- the deterministic authoring script;
- generated banks and their JSON/TXT metadata, so a clone can run without Wwise
  Authoring installed;
- `Wwise/resources/Windows.tres` and exactly the three pinned Windows core DLLs
  referenced by `wwise.gdextension`;
- the integration's upstream `LICENSE`; and
- raw timing acceptance evidence.

Ignore Wwise caches, user settings, validation caches, Wwise project-database
resources, generated Godot UIDs, and exported builds. The narrow `*~RF*.TMP`
pattern covers Godot hot-reload replacements without ignoring normal `.TMP` files.
Do not commit the integration's optional DSP directories or link-time `.lib`/`.exp`
artifacts by default; add an individual DSP only after bank metadata and license
review establish that it is required. Review Wwise work-unit diffs like source
code. Audiokinetic's [source-control guidance](https://www.audiokinetic.com/en/public-library/2024.1.4_8780/?id=pg_source_control_unity.html&source=Unity)
also recommends keeping only the plug-in binaries a project actually uses.

## Platforms, licensing, and maintenance risk

This spike validates Windows x64 only. The [community integration](https://github.com/alessandrofama/wwise-godot-integration)
advertises Windows, macOS, Linux, Android, iOS, and experimental Web support, but
those targets were neither committed nor exercised. Each new target needs the
matching integration binary slice, a platform bank and `PlatformInfo`, a Godot
export, and its own timing run. Console platforms need a separate
feasibility/licensing check.

Audiokinetic's current [game pricing](https://www.audiokinetic.com/pricing/for-games/)
lists the core Indie license as free for projects with a production budget up to
USD 250,000, with licensing handled per title and platform. Register the title and
actual target platforms; do not infer shipping rights from the integration's MIT
license or from successful local authoring. Recheck pricing and terms when funding,
platforms, DLC plans, or commercial status changes.

The dependency-update burden is meaningful: 17.26 MiB of Windows core native DLLs
is vendored, Godot support is community-maintained, CI cannot regenerate banks
without installing/licensing Wwise tooling, and patch updates can affect native
ABI, callbacks, editor import, and bank compatibility. The deterministic authoring
script, exact pin, committed banks, focused fake-runtime tests, timing soak, and
export smoke test are the guardrails.

## Follow-up for #21

Define a production-facing arrangement interface in repository terms—for example
layer enabled/disabled and section/approach intent—and implement a Wwise adapter
that maps those intents to authored States. Preserve the current timing surface
and the continuous-position authority. Do not expose Wwise event names, States,
RTPCs, or callback dictionaries to combat. Keep native audio selectable until the
real combat slice has passed the same loop, transition, continuity, teardown, and
export checks. Retain discontinuity/regression monitoring when that adapter is
integrated so a dependency update cannot silently weaken the timing evidence.
