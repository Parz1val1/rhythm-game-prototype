# Rhythm Game Prototype — Claude Code Guide

## Godot Executable
```
C:\Users\Tim\External Applications\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe
```

## Running Tests
```powershell
$godot = "C:\Users\Tim\External Applications\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
$proj  = "C:\Users\Tim\Development\Godot\rhythm-game-prototype"

# Run all tests
$tests = Get-ChildItem "$proj\test\test_*.gd" | ForEach-Object { "res://test/$($_.Name)" }
foreach ($t in $tests) {
    & $godot --headless --path $proj -s $t 2>&1 | Select-String "  PASS  |  FAIL  |==="
}
```
All tests must pass (currently 126 PASS, 0 FAIL) before committing.

## Architecture Overview

| System | File(s) | Responsibility |
|--------|---------|---------------|
| Beat clock | `autoloads/beat_clock.gd` | Audio-corrected beat signal source |
| Rhythm input | `autoloads/rhythm_input.gd` | Note queue, input scoring, expiry |
| Debug logging | `autoloads/debug_log.gd` | Centralised toggleable logging (see below) |
| Combat logic | `combat/combat_scene.gd` | ATTACK/DEFEND state machine, damage |
| Encounter setup | `combat/encounter_manager.gd` | Wires combat scene to encounter data |
| Note lane | `combat/note_lane.gd` | Approach visuals during DEFEND |
| Combat UI | `combat/combat_ui.gd` | HP bars, combo, beat pulse |
| Audio feedback | `combat/audio_feedback.gd` | Pitch-shifted SFX per score |
| Encounter data | `encounters/*.tres` | Editable Resource files (Inspector-friendly) |

## Debug Logging

**All new code must include `DebugLog` calls at meaningful event boundaries.**
Logging is how we debug alongside Claude — structured logs let Claude diagnose issues
from a paste of output rather than requiring a live session.

### The four categories

| Method | `DebugLog` property | Use for |
|--------|---------------------|---------|
| `DebugLog.timing(msg)` | `beat_timing` | Beat events, note pre-injection, press offsets, note expiry |
| `DebugLog.combat(msg)` | `combat_events` | Phase transitions, damage dealt, HP changes, win/loss, limit break |
| `DebugLog.visual(msg)` | `note_visuals` | Note visual spawning, hit-zone flashes |
| `DebugLog.audio(msg)` | `audio_events` | Audio cue playback |

### Enabling logs
`DebugLog` uses `static var` (not an autoload node), so there is no Inspector toggle.
Set flags in code before the relevant system initialises — `test_scene.gd`'s `_ready()`
is the natural place:
```gdscript
func _ready() -> void:
    DebugLog.enable_all()          # all categories — comment out to silence
    # DebugLog.enabled = true
    # DebugLog.combat_events = true  # single category
    ...
```

### Log format convention
```
[TAG    ] key=value  key=value  ...
```
- Tags are **left-padded to 7 chars** so columns align in the Output panel.
- Include the values that matter at that event boundary.
- Examples from existing code:
  ```
  [PRE-INJ] dir=up     due in 250 ms  window: −250 → +120 ms
  [ATTACK ] perfect | Luthier → Orc for 24 | hp 100 → 76  (×1.5 combo)
  [DEFEND ] Luthier took 20 dmg | hp 80 → 60/100
  [PHASE  ] ATTACK → DEFEND | defending: Orc
  [SPAWN  ] dir=up     travel=1000 ms
  [SFX    ] score=perfect   dir=up     pitch=1.12
  ```

### Rules for adding logs
- **Log at event boundaries**, not per-frame (`_process` logs are almost always wrong).
- **Log state changes** — every meaningful transition, damage application, resource load.
- **Log at system handoffs** — when one system passes data to another (e.g., note injected
  into RhythmInput, visual spawned in NoteLane).
- Choose the **most specific category**: timing for beat/note lifecycle, combat for game
  state, visual for UI, audio for sound.
- Keep messages **short and scannable** — one line, aligned columns.

## Code Conventions

### Preload pattern (autoload workaround)
Godot 4.6 autoloads parse before `class_name` global scope is fully resolved, and
before other autoload names are registered. Two consequences:

1. **Type annotations** using `class_name` types fail in autoloads — use `preload` constants:
```gdscript
const NoteData = preload("res://rhythm_engine/note_data.gd")
# NOT: var note: NoteData  ← parse error in autoloads
```

2. **`DebugLog`** (a static `class_name` utility) must also be preloaded in autoload scripts:
```gdscript
const DebugLog = preload("res://autoloads/debug_log.gd")
```
Regular scene scripts can use `DebugLog.timing(...)` directly via class_name — no preload needed.

### String vs StringName in Dictionaries
`String` and `StringName` have different hash values. When a signal passes a `StringName`
and your Dictionary uses `String` keys, always convert explicitly:
```gdscript
var dir := String(note.direction)   # note.direction is StringName
_hit_zones[dir]                     # dict keyed by String — safe
```

### Typed Array assignment
`Array[NoteData]` cannot be assigned an untyped literal. Use `append()`:
```gdscript
e.pattern.append(_note(0, "up", "targeted"))  # ✓
e.pattern = [_note(...)]                       # ✗ — type error at runtime
```

### Scene reload persistence
`static var` survives `get_tree().reload_current_scene()` but resets on F5.
Use it for data that must survive a replay (e.g., the selected encounter).

### Signal cleanup
Always disconnect in `teardown()` / `_exit_tree()` and guard with `is_connected()`.
Stale connections cause hard-to-reproduce double-fire bugs.

## Resource Loading Rule

**Always call `.duplicate(true)` when loading a CharacterData (or any gameplay Resource) for use in a live combat.** This prevents runtime HP / gauge mutations from corrupting the cached asset between fights.

```gdscript
_hero = load("res://characters/luthier_frett.tres").duplicate(true) as CharacterData
```

`EncounterManager.start_combat_from_definition` already does this for enemies. Follow the same pattern anywhere else a Resource is loaded for gameplay.

## Adding a New Feature — Checklist
1. Write a failing headless test in `test/test_<feature>.gd` first.
2. Implement the feature.
3. Add `DebugLog` calls at every event boundary (see rules above).
4. Run the full test suite — all 126 (+ new) tests must pass.
5. Commit with a descriptive message.
