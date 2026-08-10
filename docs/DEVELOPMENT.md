# Development Guide

`AGENTS.md` is the canonical repository contract. This file keeps the operational
Godot details that are useful but too specialized for the entry point.

## Local Setup

The project has no package-manager dependencies. It requires Godot
`4.6.3-stable` Mono. The verified executable on the primary Windows machine is:

```powershell
$env:GODOT_PATH = "C:\Users\Tim\External Applications\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
& $env:GODOT_PATH --version
```

Expected version prefix: `4.6.3.stable.mono`.

Open the editor or run the configured main scene:

```powershell
& $env:GODOT_PATH --editor --path .
& $env:GODOT_PATH --path .
```

Run a headless import/parse smoke check without opening the GUI:

```powershell
& $env:GODOT_PATH --headless --editor --path . --quit
```

There is no `export_presets.cfg`, so the repository has no verified build/export
command. There are also no configured formatter, linter, separate type checker,
dependency scanner, or CI workflow.

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

### Verified audit baseline (2026-08-10)

- 35 discovered scripts.
- 406 visible `PASS` lines and 0 visible `FAIL` lines.
- 3 `SCRIPT ERROR` diagnostics, 2 `ERROR` diagnostics, and 2 missing completion
  markers; therefore the suite is **not green**.
- Affected scripts: `test_character_input_profile.gd`,
  `test_defend_percussive.gd`, and `test_string_golem.gd`.

Update this baseline and [ROADMAP.md](ROADMAP.md) when those tests are repaired.

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
