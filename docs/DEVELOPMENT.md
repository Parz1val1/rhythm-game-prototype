# Development Guide

`AGENTS.md` is the canonical repository contract. This file keeps the operational
Godot details that are useful but too specialized for the entry point.

Rules naming `ATTACK`, `DEFEND`, HP, damage, neutral hits, or the current note
injection path protect the legacy implementation while it exists. They are not
target combat behavior; use [Combat System v1](combat/COMBAT_SPEC_V1.md) and its
[reconciliation ledger](combat/reconciliation-v1.md) when migrating those systems.

## Local Setup

The project has no package-manager dependencies. It requires Godot
`4.6.3-stable` Mono and includes a pinned Windows native dependency for the
isolated Wwise spike. The verified Godot executable on the primary Windows
machine is:

```powershell
$env:GODOT_PATH = "C:\Users\Tim\External Applications\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
& $env:GODOT_PATH --version
```

Expected version prefix: `4.6.3.stable.mono`.

### Agent sandbox execution

On the primary Windows host, launch every Godot process outside the filesystem
sandbox, including version checks, imports, focused tests, and the full suite.
Sandboxed Godot 4.6.3 cannot open its `user://logs` path and may crash with signal
11 plus a Windows application-error dialog. Request scoped unsandboxed execution
before the first Godot command. If approval is unavailable, report Godot
verification as blocked; do not run a sandboxed probe.

Open the editor or run the configured main scene:

```powershell
& $env:GODOT_PATH --editor --path .
& $env:GODOT_PATH --path .
```

Run a headless import/parse smoke check without opening the GUI:

```powershell
& $env:GODOT_PATH --headless --editor --path . --quit
```

### Wwise spike dependency

See the [Wwise spike record](../spikes/wwise/README.md) for the exact dependency
pin and the install, authoring, bank-generation, harness, Windows export, and
upgrade procedures. A clone can run the committed Windows bank and core runtime
DLLs without Wwise Authoring installed. Regenerating or changing the bank requires
the pinned Wwise 2025.1.9.9197 Authoring/SDK installation.

Only the three Windows core DLLs used by editor, debug, and release profiles are
vendored. Unused DSP libraries and link-time `.lib`/`.exp` artifacts are excluded;
add a DSP only when generated-bank metadata proves the dependency and its license
has been reviewed. Godot hot-reload `*~RF*.TMP` replacements are narrowly ignored.
The spike record owns the known native `ObjectDB` exit warning and headless
editor-import teardown caveat; do not describe editor-import CI as green from
runtime/test results alone.

The repository has one isolated Windows export preset for the Wwise technical
spike. It is not a production game export; follow the temporary main-scene and
autoload procedure in [the spike record](../spikes/wwise/README.md#windows-export-workflow).
There are no configured formatter, linter, separate type checker, dependency
scanner, or CI workflow.

## Testing

Each `test/test_*.gd` file is a standalone `SceneTree` entry point. Run an
individual file with:

```powershell
& $env:GODOT_PATH --headless --path . -s res://test/test_scoring.gd
```

Run every test with strict diagnostic checks:

```powershell
$failed = $false
$tests = Get-ChildItem -File ./test/test_*.gd | Sort-Object Name
foreach ($test in $tests) {
    $output = @(& $env:GODOT_PATH --headless --path . -s "res://test/$($test.Name)" 2>&1 | ForEach-Object { $_.ToString() })
    $output
    $bad = $output | Select-String '^\s*FAIL(?:\s|:|$)|SCRIPT ERROR|^ERROR:'
    $done = $output | Select-String '^=== done ===$'
    if ($LASTEXITCODE -ne 0 -or $bad -or -not $done) { $failed = $true }
}
if ($failed) { throw "Godot test suite failed; inspect raw diagnostics above." }
```

A valid test process must:

- exit `0`;
- contain no `FAIL`, `SCRIPT ERROR`, or line-leading `ERROR:` diagnostic; and
- print the exact completion marker `=== done ===`.

The older filtered command that selects only `PASS`, `FAIL`, and `===` lines is
not sufficient because it hides engine diagnostics.

### Verified green baseline (2026-08-25)

- 58 discovered scripts and 964 visible `PASS` lines.
- 0 visible `FAIL` lines, `SCRIPT ERROR` diagnostics, or line-leading `ERROR:`
  diagnostics.
- Every script exited `0` and printed the exact `=== done ===` completion marker.

## Debug Logging

All new gameplay code should log meaningful event boundaries through `DebugLog`.
Do not log every frame.

| Method | Flag | Use |
|---|---|---|
| `DebugLog.timing(msg)` | `beat_timing` | Beat/sub-beat events, note injection, offsets, expiry |
| `DebugLog.combat(msg)` | `combat_events` | Phase transitions, actions, damage, HP, outcomes, limit break |
| `DebugLog.visual(msg)` | `note_visuals` | Visual spawn, removal, and hit-zone feedback |
| `DebugLog.audio(msg)` | `audio_events` | Audio cue routing and playback |

Enable categories before the relevant systems initialize, normally in
`test_scene.gd::_ready()` through its exported flags or directly:

```gdscript
DebugLog.enable_all()
# Or enable DebugLog.enabled plus selected category flags.
```

Log messages follow the compact event format:

```text
[TAG    ] key=value  key=value
```

In regular scene scripts, use the `DebugLog` global class. In autoload scripts,
preload it because autoload parse order cannot rely on `class_name` scope:

```gdscript
const DebugLog = preload("res://autoloads/debug_log.gd")
```

## Godot-Specific Conventions

### Autoload parse order

Preload cross-file types in autoload scripts instead of relying on global
`class_name` resolution:

```gdscript
const NoteData = preload("res://rhythm_engine/note_data.gd")
var _active: Array = []
```

Regular scene scripts may use `class_name` types normally.

### Gameplay Resource ownership

Loaded `.tres` objects are shared templates. Deep-copy them before live mutation:

```gdscript
var hero := load("res://characters/luthier_frett.tres").duplicate(true) as CharacterData
```

`EncounterManager.start_combat_from_definition()` already does this for enemies.

### Strings and typed collections

`String` and `StringName` hash differently in Dictionaries. Convert explicitly
when a signal value indexes a `String`-keyed map. Build typed nested arrays with
`append()`; an untyped literal cannot always be assigned to `Array[SomeType]` or
`Array[Array]`.

Use an explicit annotation when a value comes from an untyped `Object`/`Variant`.
Godot cannot reliably infer either a property read or a ternary branch in that
case:

```gdscript
var old_hp: int = target.hp
var actor_name: String = target.character_name if target != null else "Unknown"
```

### Timing and patterns

- `beat_offset` is a float and supports sub-beat positions.
- `BeatClock.quarter_beat` carries the exact `.25` or `.75` subdivision as its
  second signal argument; do not infer it from `BeatClock.beat_position` inside a
  callback because recovered thresholds emit before that property updates.
- Continuous presentation and scoring timelines read BeatClock's atomic
  `get_musical_position_beats()` snapshot. Do not compose `beat_number` and
  `beat_position` inside boundary callbacks.
- `RhythmInput.add_note()` returns `false` when duplicate prevention rejects an
  already-active note. Use that result for observability; never gate damage on it.
- DEFEND injection has one path in `CombatScene._inject_notes_due()`.
- Visual announcement and injection must resolve the same hit with the same
  `sequence_index`.
- Test evenly spaced offsets `0, 1, 2, ...` whenever alternation/cycling changes.
- Never restore beat-handler injection for whole-beat DEFEND notes; they are
  pre-injected at the half beat and re-adding them causes phantom expiry damage.

### Signals and scene reloads

Disconnect autoload and combat signals in `teardown()` / `_exit_tree()`, guarded by
`is_connected()`. Static variables survive `reload_current_scene()` but reset on a
new process; the replay selector intentionally uses that behavior.

### Controller mappings

Controller inputs use Godot's standardized joypad positions rather than
platform-specific glyph names. Luthier maps D-pad and face-button top/bottom/left/
right to the matching rhythm directions. Beatrice maps the positive left/right
trigger axes to her left/right drum actions with the InputMap's `0.5` deadzone.
`RhythmInput` edge-gates analog actions by controller and action so progressive
axis updates produce one scored input per pull; a release re-arms the action.
The V1 harness reserves Start for Response submission, Up/Down plus controller A
for Tactical Vamp Skill selection, and the shoulder buttons for temporary
backing-track comparison. Controller A also maps to Luthier's Down note, so the
harness must prioritize its confirmation meaning while Tactical Vamp is active;
character profiles still own which rhythm actions are valid for a performance.

### Scene and Resource editing

The repository normally hand-edits small `.tscn` and `.tres` changes as text.
Review diffs carefully because editor or automation rewrites can churn formatting
and UIDs. `*.uid` sidecars are ignored and regenerated by Godot.

## Optional Local Godot MCP

The primary machine has used `@coding-solo/godot-mcp` as a CLI wrapper around the
Godot executable. This is optional, machine-local tooling—not a repository
dependency or source of truth.

- It requires `GODOT_PATH` in the MCP server environment and a new session after
  changing that environment.
- It shells out per call; it has no persistent editor or live scene-tree access.
- It is suitable for project metadata, UID lookup, and one-off new-scene
  scaffolding.
- Its `run_project` command opens the game window, and `launch_editor` opens the
  editor GUI; neither belongs in autonomous headless verification.
- It does not replace the headless PowerShell test loop.
- Avoid using it to rewrite existing scenes because of formatting/UID churn.
