# Rhythm Game Prototype — Codebase Summary

> Paste this into a new Claude Code session to get up to speed instantly.
> Keep it updated as the codebase evolves.
> Last updated: 2026-05-31

---

## What This Is

A Godot 4.6 rhythm-combat prototype. The player fights enemies in ATTACK/DEFEND turns — pressing arrow keys on the beat during ATTACK deals damage; matching incoming note patterns during DEFEND blocks it. One playable character (Luthier Frett), four encounter types. All code is GDScript; C# / Mono is enabled but unused.

**Branch:** `feat/combat-prototype-completion` → open PR #2 on GitHub.  
**Main scene:** `test_scene.tscn` (F5 to run).  
**126 tests, 0 failures.** Run before every commit (see CLAUDE.md for the PowerShell command).

---

## File Structure

```
autoloads/
  beat_clock.gd        ← autoload "BeatClock"  — audio-corrected beat signals
  rhythm_input.gd      ← autoload "RhythmInput" — note queue, input scoring, expiry
  debug_log.gd         ← class_name DebugLog (NOT an autoload) — static logging utility

characters/
  character_data.gd    ← Resource: player stats + limit break fields
  enemy_data.gd        ← Resource: enemy stats + note pattern array
  luthier_frett.tres   ← the one playable character
  solo_style.gd        ← Resource: scale_steps[4] + accent_color for a character's "voice"

combat/
  combat_scene.gd      ← core state machine (ATTACK/DEFEND phases, damage, signals)
  combat_scene.tscn    ← minimal scene; instantiated at runtime by EncounterManager
  encounter_manager.gd ← static helper; wires a combat scene to encounter data
  combat_ui.gd/.tscn   ← HP bars (ColorRect fill), beat pulse, combo label, limit gauge
  note_lane.gd/.tscn   ← DEFEND visuals: 4 hit zones + approaching note visuals
  note_visual.gd/.tscn ← individual 34×34 note arrow widget
  audio_feedback.gd/.tscn ← pitch-shifts SFX on input score (streams NOT assigned yet)
  replay_ui.gd/.tscn   ← post-combat overlay: win/loss, encounter dropdown, Play Again
  sequence_evaluator.gd ← combo counter + streak multiplier (1.0–2.5×)

encounters/
  encounter_definition.gd ← Resource: encounter_id + Array[EnemyData]
  goblin_single.tres   ← 1 goblin, 40 HP, 4-beat pattern
  goblin_pair.tres     ← 2 goblins
  orc_heavy.tres       ← 1 orc, 150 HP, 8-beat pattern (up/right/down/left)
  string_golem.tres    ← 1 golem, 120 HP, 6-beat repeating pattern (hardest)

rhythm_engine/
  note_data.gd         ← Resource: beat_offset, direction (String), mode (String)
  active_note.gd       ← RefCounted: wraps NoteData with inject_time_ms + due_time_ms

test/
  test_*.gd            ← 10 headless SceneTree test scripts (126 checks total)

tools/
  create_encounter_resources.gd  ← one-shot generator that wrote the .tres files
  create_luthier_resources.gd    ← one-shot generator for Luthier + SoloStyle

audio/
  *.mp3                ← one backing track (130 BPM, 1200ms intro)
  sfx/                 ← EMPTY — instrument SFX not yet added

docs/
  codebase-summary.md  ← this file
  superpowers/plans/   ← implementation plan documents

test_scene.gd/.tscn    ← prototype entry point; F5 runs this
CLAUDE.md              ← project conventions (read this first)
```

---

## Autoloads (registered in project.godot)

### BeatClock
Emits beat signals anchored to what the player **hears**, not what the engine computed.

```gdscript
BeatClock.beat.connect(_on_beat)          # fires once per beat
BeatClock.half_beat.connect(_on_half)     # fires at beat_position == 0.5
BeatClock.quarter_beat.connect(_on_qtr)  # fires at 0.25 and 0.75
BeatClock.get_offset_ms() → float        # negative=early, positive=late
BeatClock.beat_number   → int            # current beat index
BeatClock.beat_position → float          # 0.0–1.0 within current beat
BeatClock.bpm           → float          # changeable at runtime
```

Audio correction: `playback_position + time_since_last_mix − output_latency`. Falls back to wall-clock if no audio stream.

### RhythmInput
Manages an `_active: Array` of `ActiveNote` objects and scores keypresses against them.

```gdscript
RhythmInput.add_note(note: NoteData, due_time_ms: int = 0) → bool
RhythmInput.clear_notes()
RhythmInput.score_timing(abs_offset_ms) → StringName  # &"perfect"/&"good"/&"miss"
# Signals:
signal input_scored(direction: StringName, score: StringName, offset_ms: float, note_consumed: bool)
signal note_missed(note: NoteData)
```

**Thresholds:** perfect ≤ 50ms, good ≤ 120ms.  
**Expiry:** targeted notes expire `good_ms` (120ms) after `due_time_ms`. Non-targeted (free_form) notes never expire.

### DebugLog (NOT an autoload)
`class_name DebugLog` with `static var` flags. Use directly in regular scripts; preload in autoload scripts.

```gdscript
# Regular scene script — class_name is in scope:
DebugLog.timing("...")
DebugLog.combat("...")
DebugLog.visual("...")
DebugLog.audio("...")

# Autoload script — must preload:
const DebugLog = preload("res://autoloads/debug_log.gd")
```

Enable in `test_scene.gd._ready()` via Inspector checkboxes (`log_enabled`, `log_beat_timing`, etc.) or in code: `DebugLog.enable_all()`.

---

## Key Design Decisions

### 1. Note pre-injection at half_beat
Notes are injected into `RhythmInput._active` at `BeatClock.half_beat` (~250ms before the beat), not at the beat itself. This makes the effective consumable window symmetric (±120ms) instead of asymmetric (0→+120ms). `due_time_ms` is set to the actual beat moment so expiry is beat-anchored.

**Why it matters:** If you add new inject logic, call `RhythmInput.add_note(note, due_ms)` at `half_beat` with `due_ms = Time.get_ticks_msec() + half_beat_ms`. Never re-inject from `_on_beat` or the note gets added a second time after being consumed, causing phantom damage.

### 2. `_visuals` cleanup ownership in NoteLane
`note_lane._visuals: Dictionary` maps `NoteData → Control`. The tween callback only `queue_free`s the node — it does **not** erase from `_visuals`. Only `_on_input_scored` and `_on_note_missed` erase. This prevents a late press (after the visual's tween finishes) from wrongly consuming a later same-direction visual that is still travelling.

### 3. Encounter data as editable Resources
Enemies and their patterns are `.tres` files (editable in the Godot Inspector). `EncounterManager.start_combat_from_definition()` deep-copies (`duplicate(true)`) each EnemyData so runtime HP mutations don't corrupt the cached asset.

### 4. Static scene reload via `pending_encounter`
`test_scene.gd` has `static var pending_encounter: EncounterDefinition`. When the player hits Play Again, the selection is stashed here, `reload_current_scene()` is called, and `_ready()` reads it back. Static vars survive `reload_current_scene()` but reset on F5.

### 5. Turn structure
- **ATTACK phase:** `player_phase_length` beats (default 4). Player presses freely; every direction maps to a scale degree. Damage = `attack_power × combo_mult × lb_mult`.
- **DEFEND phase:** Each living enemy takes a turn. Enemy's `pattern: Array[NoteData]` is played out over `phase_length` beats. Notes are pre-announced `lookahead_beats` (default 2) beats early via `note_approaching` signal.
- Phases cycle until win/loss. `CombatScene.teardown()` disconnects all signals.

### 6. First-beat DEFEND visual fix
Notes at `beat_offset < lookahead_beats` in an enemy's pattern can't be announced during ATTACK (their lookahead window falls before the phase starts). `_end_attack_phase()` emits `note_approaching` for these immediately at the transition, using `BeatClock.beat_number + 1 + note.beat_offset` as `target_beat`. `note_lane` uses `target_beat - BeatClock.beat_number` for travel time so these arrive at the hit zone exactly when due, just with less approach time.

---

## What's Implemented vs Stubbed

| Area | Status | Notes |
|------|--------|-------|
| BeatClock | ✅ Complete | Audio-corrected, all sub-beat signals |
| RhythmInput | ✅ Complete | Pre-injection, expiry, dedup |
| Combat state machine | ✅ Complete | ATTACK/DEFEND/limit break |
| Damage formula | ✅ Complete | timing × combo (1–2.5×) × lb (2.5×) |
| Combo/streak multiplier | ✅ Complete | SequenceEvaluator, resets on miss |
| Limit break | ✅ Complete | Gauge, activation, extended phase |
| DEFEND note visuals | ✅ Complete | Approach from matching edge, flash on hit |
| HP bars + beat pulse | ✅ Complete | Color-coded, animates in _process |
| Replay UI | ✅ Complete | Encounter dropdown, win/loss, reload |
| DebugLog system | ✅ Complete | 4 categories, Inspector toggles |
| Encounter data | ✅ Complete | 4 .tres files, Inspector-editable |
| Per-hit score display | ❌ Not started | No "Perfect +12ms" on-screen text |
| Instrument SFX | ❌ Stub | Infrastructure ready; `audio/sfx/` empty |
| Enemy attack audio | ❌ Not started | No audio connected to DEFEND phase |
| Sprite / character art | ❌ Not started | All visuals are ColorRect + Label |
| Melody coherence scoring | ❌ Not started | No harmonic/sequence analysis |
| Backing track | ✅ Complete | One 130 BPM .mp3 in `audio/` |

---

## Gotchas and Non-Obvious Choices

### Autoload parse-time scope (Godot 4.6)
Autoload scripts parse before `class_name` globals are resolved AND before other autoload names are registered. Two rules:
1. Never use `class_name` type annotations in autoloads — use `const X = preload(...)` instead.
2. `DebugLog` is a `class_name`, not an autoload node, so autoload scripts must `const DebugLog = preload(...)`.

### String vs StringName in Dictionaries
`String` and `StringName` have different hash values. Signal parameters are often `StringName`; Dictionary keys in this project are `String`. Always convert: `var dir := String(note.direction)`.

### Typed Array assignment
`Array[NoteData]` cannot be assigned from an untyped Array literal. Use `.append()`.

### `var old_hp := target.hp` type inference
`target` is untyped (returned from a function returning `Object`). `:=` inference fails — use `var old_hp: int = target.hp`.

### Ternary type inference
`var x := a if condition else "fallback"` fails if `a` is from an untyped source. Use `var x: String = ...`.

### `add_note()` returns bool
`RhythmInput.add_note()` returns `false` if the note is already in `_active` (duplicate guard). The caller should check this return when logging; don't use the return value to conditionally apply damage.

### No injection in `_on_beat` during DEFEND
The `_on_beat` handler intentionally has no `RhythmInput.add_note()` call during DEFEND. All injection is at `_on_half_beat`. Adding it back causes phantom double-damage: the note gets re-added after being consumed, then expires.

### Signal cleanup pattern
Every system connects in `setup()` and disconnects in `teardown()` / `_exit_tree()`, always guarded with `is_instance_valid()` + `is_connected()`. `CombatScene.teardown()` is called before emitting `combat_won`/`combat_lost` to prevent double-fires on the same frame.

### `.duplicate(true)` on encounter data
`EncounterManager` deep-copies EnemyData resources. Without this, `enemy.hp` changes during combat corrupt the `.tres` asset in memory and the next fight starts with depleted HP.

### Headless tests
All tests are `extends SceneTree`, launched with `godot --headless --path . -s res://test/file.gd`. Use `root.add_child()`, not `current_scene.add_child()` (current_scene is null in headless mode). Await `process_frame` before running so autoloads are ready.

### UID files
`*.uid` files are in `.gitignore`. Godot auto-regenerates them on project open.
