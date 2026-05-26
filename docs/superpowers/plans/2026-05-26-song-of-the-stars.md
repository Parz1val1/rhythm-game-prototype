# Song of the Stars: Development Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Starting from a working logic prototype, build a fully playable, visually polished combat prototype with one character and one enemy, then extend to a vertical slice covering one area of the String planet (overworld movement, encounters, a mini-dungeon, and a boss fight), proving the diegetic rhythm-RPG loop is publisher-ready.

**Architecture:** `BeatClock` (AudioServer-compensated timer autoload) is the single source of musical time — all animations, SFX, note spawning, and visual effects are slaves to it. Combat logic lives in `CombatScene` (phase state machine). Visual display is a separate `CombatUI` scene connected only through signals. Audio layers are managed by a new `AudioDirector` autoload that routes stems through AudioBus. Everything communicates through signals; nothing polls.

**Tech Stack:** Godot 4.6, GDScript primary, GL Compatibility renderer, AudioStreamPlayer + AudioBus for stem mixing, Tween API for beat-synced animation, headless SceneTree scripts for unit tests.

---

## Scope Note

This document covers two sequential phases that can be treated as separate projects:
- **Phase 1–2 (Tasks 1–9):** Combat Prototype Completion — produces a shippable demo of the combat loop.
- **Phase 3 (Tasks 10–20):** Vertical Slice — builds the world around the proven combat loop.

If the combat prototype needs publisher validation first, stop after Task 9, get feedback, then continue to Phase 3.

---

## Part 0: Prototype Audit

The previous plan ([`2026-05-21-rhythm-combat-prototype.md`](../plans/2026-05-21-rhythm-combat-prototype.md)) is **fully implemented**. All systems are functional. The following is an honest assessment of what was built and what needs to change before adding complexity.

### What's Production-Quality (don't touch)

| System | Assessment |
|---|---|
| `BeatClock._process()` | Correct AudioServer latency compensation. Sub-beat boundary-crossing with multi-beat lag-spike handling is solid. The `intro_offset_ms` support is a good addition not in the original spec. |
| `RhythmInput` hybrid model | The targeted-note-first, free-form fallthrough logic is correct and extensible. |
| `CombatScene.teardown()` | Signal disconnect guards and `_exit_tree()` safety are correct. The `_combat_ended` flag prevents double-emit. |
| `EncounterManager` static pattern | Right choice for a factory with no persistent state. |
| `NoteData / CharacterData / EnemyData` | Clean Resources. Correct use of `@export` for `.tres` compatibility. |

### Bugs to Fix Before Building Further

**Bug 1 — Phantom blocking during DEFEND phase** (Medium severity)  
When the player presses a direction with no matching active note during DEFEND, `RhythmInput` emits `input_scored` as a free-form press. `CombatScene._on_input_scored` then handles it as a DEFEND action — a perfect free-form press completely blocks damage that isn't in the queue. A player who mashes buttons rhythmically during a defend phase avoids all damage without responding to any notes.  
**Fix:** Add a `note_consumed: bool` parameter to `input_scored`. CombatScene only applies defend logic when `note_consumed == true`.

**Bug 2 — Notes injected on the beat they're due (no visual reaction time)**  
`RhythmInput.add_note()` is called at the exact beat frame when the note fires. The note expires 120ms later. There is no visual lookahead — the player has no time to react. This is the most critical gameplay feel issue.  
**Fix:** Add a `note_approaching` signal to `CombatScene`, emitted `lookahead_beats` beats before a note is due. The note lane visualizer (Task 6) subscribes to this and spawns the approaching visual.

**Bug 3 — Parallel arrays in RhythmInput are fragile**  
`active_notes: Array[NoteData]` and `_note_inject_times: Array[int]` must stay perfectly synchronized. Any future refactor that removes from one without the other causes an index crash.  
**Fix:** Replace with a typed struct `ActiveNote` that holds both fields together (Task 1).

**Bug 4 — Untyped party arrays in CombatScene**  
`_player_party: Array = []` and `_enemy_party: Array = []` are untyped due to the class_name parse-order workaround. The `_get_active_character()` return is `Variant`. This works but disables type-checking and IDE autocomplete.  
**Fix:** Use `preload()` constants as type annotations on local variables in `setup()` (Task 1).

### Prototype Limitations (Not Bugs — Known Design Gaps)

- No visual representation of notes during DEFEND — player is flying blind
- Attack phase has no combo or sequence tracking — any press accumulates flat damage
- No limit break system
- No character-specific feel (no SoloStyle differentiation)
- No audio feedback on hits/misses
- HP is displayed as text labels, not styled bars
- Damage-flash detection uses per-frame polling of HP deltas (fragile, should use signals)

---

## File Map (Full Project)

| File | Status | Role |
|---|---|---|
| `autoloads/beat_clock.gd` | **Exists** — no changes needed | AudioServer-synced beat timer |
| `autoloads/rhythm_input.gd` | **Modify** — add `note_consumed` param | Input scorer + note lifecycle |
| `rhythm_engine/note_data.gd` | **Exists** — no changes needed | Resource: single pattern note |
| `rhythm_engine/active_note.gd` | **Create** | Struct: note + inject timestamp |
| `characters/character_data.gd` | **Modify** — add limit break fields | Player character stats |
| `characters/enemy_data.gd` | **Exists** — no changes needed | Enemy stats + pattern |
| `characters/solo_style.gd` | **Create** | Resource: per-character feel/sound |
| `characters/luthier_frett.tres` | **Create** | Luthier Frett's SoloStyle resource |
| `combat/combat_scene.gd` | **Modify** — multiple changes | Phase state machine + damage |
| `combat/combat_scene.tscn` | **Modify** — add UI child | Bare combat scene root |
| `combat/combat_ui.gd` | **Create** | All visual combat display |
| `combat/combat_ui.tscn` | **Create** | HP bars, phase display, beat pulse |
| `combat/note_lane.gd` | **Create** | Note approach visualizer |
| `combat/note_lane.tscn` | **Create** | Defend-phase note lanes |
| `combat/note_visual.gd` | **Create** | Single approaching note sprite |
| `combat/note_visual.tscn` | **Create** | Note rectangle/icon |
| `combat/sequence_evaluator.gd` | **Create** | Combo + multiplier tracker |
| `combat/encounter_manager.gd` | **Modify** — add encounter types | Static enemy factory |
| `audio/audio_director.gd` | **Create** (Phase 3) | Stem-based diegetic music manager |
| `overworld/overworld_scene.gd` | **Create** (Phase 3) | Top-down movement + camera |
| `overworld/overworld_scene.tscn` | **Create** (Phase 3) | String planet area |
| `overworld/player_character.gd` | **Create** (Phase 3) | Overworld player controller |
| `overworld/encounter_zone.gd` | **Create** (Phase 3) | Triggers combat on overlap |
| `dungeon/dungeon_scene.gd` | **Create** (Phase 3) | Mini-dungeon orchestrator |
| `dungeon/musical_puzzle.gd` | **Create** (Phase 3) | BeatClock-synced puzzle |
| `world/world_state.gd` | **Create** (Phase 3) | Party/progress singleton |
| `test/test_scoring.gd` | **Exists** — working | Headless threshold tests |
| `test/test_active_note.gd` | **Create** | Headless struct tests |
| `test/test_sequence_evaluator.gd` | **Create** | Headless combo/multiplier tests |
| `test/test_beat_clock_lookahead.gd` | **Create** | Headless lookahead signal tests |
| `test_scene.gd` | **Modify** — wire new UI | Main test entry point |
| `test_scene.tscn` | **Modify** | Wires new combat_ui child |

---

## Phase 1: Foundation Hardening

### Task 1: ActiveNote Struct + Type Safety Cleanup

**This is done when:** All existing tests still pass; `RhythmInput` has no parallel arrays; `CombatScene._player_party` has typed iteration.

**Files:**
- Create: `rhythm_engine/active_note.gd`
- Create: `test/test_active_note.gd`
- Modify: `autoloads/rhythm_input.gd`
- Modify: `combat/combat_scene.gd` (typed iteration only)

- [ ] **Step 1.1: Write the failing test**

```gdscript
# test/test_active_note.gd
# Run: godot --headless --path . -s res://test/test_active_note.gd
extends SceneTree

const NoteData    = preload("res://rhythm_engine/note_data.gd")
const ActiveNote  = preload("res://rhythm_engine/active_note.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== ActiveNote tests ===")

    var note := NoteData.new()
    note.direction = &"up"
    note.mode = &"targeted"
    note.beat_offset = 0

    var inject_time := 12345
    var an := ActiveNote.new(note, inject_time)

    _check("stores note reference",     an.note == note,                  true)
    _check("stores inject_time",        an.inject_time_ms == inject_time, true)
    _check("note direction preserved",  an.note.direction == &"up",       true)
    _check("note mode preserved",       an.note.mode == &"targeted",      true)

    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
```

- [ ] **Step 1.2: Run the test — confirm it fails**

```
godot --headless --path . -s res://test/test_active_note.gd
```

Expected: Error about `active_note.gd` not found.

- [ ] **Step 1.3: Create `rhythm_engine/active_note.gd`**

```gdscript
# rhythm_engine/active_note.gd
# Holds a NoteData alongside the wall-clock timestamp of when it was injected
# into RhythmInput's scoring window. Replaces the fragile parallel-array pattern.
class_name ActiveNote
extends RefCounted

var note: NoteData
var inject_time_ms: int

func _init(p_note: NoteData, p_time: int) -> void:
    note = p_note
    inject_time_ms = p_time
```

- [ ] **Step 1.4: Run the test — confirm it passes**

```
godot --headless --path . -s res://test/test_active_note.gd
```

Expected: All PASS.

- [ ] **Step 1.5: Update `autoloads/rhythm_input.gd` to use ActiveNote**

Replace the two parallel array declarations and all usages:

```gdscript
# autoloads/rhythm_input.gd
extends Node

const NoteData    = preload("res://rhythm_engine/note_data.gd")
const ActiveNote  = preload("res://rhythm_engine/active_note.gd")

# --- Signals ---
signal input_scored(direction: StringName, score: StringName, offset_ms: float, note_consumed: bool)
signal note_missed(note: NoteData)

# --- Configurable thresholds ---
@export var perfect_ms: float = 50.0
@export var good_ms: float = 120.0

# --- Active note queue ---
# Single array of ActiveNote structs — no parallel arrays to desync.
var _active: Array = []   # Array[ActiveNote], untyped due to preload workaround

# --- Public API ---

func score_timing(abs_offset_ms: float) -> StringName:
    if abs_offset_ms <= perfect_ms:
        return &"perfect"
    elif abs_offset_ms <= good_ms:
        return &"good"
    else:
        return &"miss"

func add_note(note: NoteData) -> void:
    _active.append(ActiveNote.new(note, Time.get_ticks_msec()))

func clear_notes() -> void:
    _active.clear()

# --- Input handling ---

func _unhandled_input(event: InputEvent) -> void:
    var direction := _get_direction(event)
    if direction == &"":
        return

    get_viewport().set_input_as_handled()

    var offset_ms: float = BeatClock.get_offset_ms()
    var abs_offset: float = abs(offset_ms)

    # Targeted note takes priority.
    for i in range(_active.size() - 1, -1, -1):
        var an = _active[i]   # ActiveNote
        if an.note.mode == &"targeted" and an.note.direction == direction:
            var score: StringName = score_timing(abs_offset)
            _active.remove_at(i)
            input_scored.emit(direction, score, offset_ms, true)   # note_consumed = true
            return

    # Free-form fallthrough — no matching targeted note.
    var score: StringName = score_timing(abs_offset)
    input_scored.emit(direction, score, offset_ms, false)          # note_consumed = false

# --- Note expiry ---

func _process(_delta: float) -> void:
    var now: int = Time.get_ticks_msec()
    for i in range(_active.size() - 1, -1, -1):
        var an = _active[i]   # ActiveNote
        if an.note.mode != &"targeted":
            continue
        var age_ms: float = float(now - an.inject_time_ms)
        if age_ms > good_ms:
            var expired: NoteData = an.note
            _active.remove_at(i)
            note_missed.emit(expired)

# --- Helpers ---

func _get_direction(event: InputEvent) -> StringName:
    if event.is_action_pressed(&"rhythm_up"):    return &"up"
    if event.is_action_pressed(&"rhythm_down"):  return &"down"
    if event.is_action_pressed(&"rhythm_left"):  return &"left"
    if event.is_action_pressed(&"rhythm_right"): return &"right"
    return &""
```

- [ ] **Step 1.6: Update `combat_scene.gd` signal connections for new `input_scored` signature**

The `_on_input_scored` handler now receives a `note_consumed: bool` fourth argument. Update the function signature and add the defend-phase phantom block fix:

```gdscript
# In combat/combat_scene.gd — update this function signature and body:

func _on_input_scored(_direction: StringName, score: StringName, _offset_ms: float, note_consumed: bool) -> void:
    if _combat_ended:
        return
    match _current_phase:
        Phase.ATTACK:
            # Attack phase: every press counts (free-form expression).
            var character = _get_active_character()
            if character == null:
                return
            match score:
                &"perfect":
                    _damage_accumulator += float(character.attack_power)
                &"good":
                    _damage_accumulator += float(character.attack_power) * 0.5
                # miss: accumulate nothing

        Phase.DEFEND:
            # Defend phase: only act if this press consumed an active note.
            # Pressing freely between notes no longer blocks phantom damage.
            if not note_consumed:
                return
            var enemy     = _get_defending_enemy_internal()
            var character = _get_active_character()
            if enemy == null or character == null:
                return
            match score:
                &"perfect":
                    pass  # fully blocked
                &"good":
                    _apply_damage_to_character(character, int(float(enemy.attack_power) * 0.5))
                &"miss":
                    _apply_damage_to_character(character, enemy.attack_power)
```

- [ ] **Step 1.7: Update `test_scene.gd` for new signal signature**

```gdscript
# In test_scene.gd — update the connected handler:
func _on_input_scored(direction: StringName, score: StringName, offset_ms: float, _note_consumed: bool) -> void:
    _score_label.text = "Last: %-5s  %-7s  (%+.1f ms)" % [direction, score, offset_ms]
```

- [ ] **Step 1.8: Run all existing tests**

```
godot --headless --path . -s res://test/test_scoring.gd
godot --headless --path . -s res://test/test_active_note.gd
```

Both should output all PASS.

- [ ] **Step 1.9: Manual smoke test**

Run the game (F5). Verify:
- Beat label still flashes yellow
- Pressing arrows during ATTACK still accumulates damage
- During DEFEND, pressing an unrelated direction does NOT show any score change in PhaseLabel or HP
- During DEFEND, pressing the correct direction on-beat still blocks damage

- [ ] **Step 1.10: Commit**

```
git add rhythm_engine/active_note.gd autoloads/rhythm_input.gd combat/combat_scene.gd test_scene.gd test/test_active_note.gd
git commit -m "fix: replace parallel note arrays with ActiveNote struct; fix phantom blocking in DEFEND phase"
```

---

### Task 2: Note Lookahead + CombatScene Signals

**This is done when:** During DEFEND, `note_approaching` fires `lookahead_beats` beats before each note is due; the test verifies timing.

**Files:**
- Modify: `combat/combat_scene.gd` — add lookahead signal
- Create: `test/test_beat_clock_lookahead.gd`

- [ ] **Step 2.1: Write the failing test**

```gdscript
# test/test_beat_clock_lookahead.gd
# Verifies that note_approaching fires before add_note for the same note.
# Run: godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
extends SceneTree

const CharacterData    = preload("res://characters/character_data.gd")
const EnemyData        = preload("res://characters/enemy_data.gd")
const NoteData         = preload("res://rhythm_engine/note_data.gd")
const EncounterManager = preload("res://combat/encounter_manager.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== lookahead signal tests ===")

    # Build minimal combat
    var hero := CharacterData.new()
    hero.max_hp = 100; hero.hp = 100; hero.attack_power = 1
    var party: Array[CharacterData] = [hero]
    var combat = EncounterManager.start_combat(self, party, &"goblin_single", true)

    # Check the combat scene has the lookahead signal
    _check("note_approaching signal exists",
        combat.has_signal("note_approaching"), true)
    _check("lookahead_beats property exists",
        "lookahead_beats" in combat, true)
    _check("lookahead_beats default >= 1",
        combat.lookahead_beats >= 1, true)

    combat.queue_free()
    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
```

- [ ] **Step 2.2: Run the test — confirm it fails**

```
godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
```

Expected: FAIL on signal and property existence checks.

- [ ] **Step 2.3: Add lookahead to `combat/combat_scene.gd`**

Add to the top of the class (after existing signals):

```gdscript
## Fired `lookahead_beats` beats before a note is due during DEFEND.
## Note lane visualizers connect to this to spawn approaching note visuals.
## note:        the NoteData that will be due at target_beat_number
## target_beat: the BeatClock.beat_number value when the note must be pressed
signal note_approaching(note: NoteData, target_beat: int)

## How many beats ahead to announce incoming notes.
## At 120 BPM, 2 beats = 1 second of visual approach time.
@export var lookahead_beats: int = 2
```

Add a `phase_changed` signal for the UI (needed in Task 5):

```gdscript
## Fired whenever the combat phase changes.
## new_phase: Phase.ATTACK or Phase.DEFEND
signal phase_changed(new_phase: int)
```

Update `_on_beat` to emit `note_approaching` ahead of schedule, and update both `_end_*_phase` functions to emit `phase_changed`:

```gdscript
func _on_beat(beat_number: int) -> void:
    if _combat_ended:
        return
    _phase_beat_count += 1

    match _current_phase:
        Phase.ATTACK:
            if _phase_beat_count > player_phase_length:
                _end_attack_phase()
        Phase.DEFEND:
            var enemy = _get_defending_enemy_internal()
            if enemy == null:
                _end_defend_phase()
                return
            if _phase_beat_count > enemy.phase_length:
                _end_defend_phase()
                return

            var beat_index: int = _phase_beat_count - 1

            # Inject notes due RIGHT NOW into the scoring window.
            for note: NoteData in enemy.pattern:
                if note.beat_offset == beat_index:
                    RhythmInput.add_note(note)

            # Pre-announce notes due LOOKAHEAD_BEATS from now for visual spawning.
            var lookahead_index: int = beat_index + lookahead_beats
            for note: NoteData in enemy.pattern:
                if note.beat_offset == lookahead_index:
                    note_approaching.emit(note, beat_number + lookahead_beats)

func _end_attack_phase() -> void:
    var target = get_attack_target()
    if target != null:
        target.hp = max(0, target.hp - int(_damage_accumulator))

    _damage_accumulator = 0.0
    _phase_beat_count   = 0
    _defend_index       = _first_living_enemy_index()
    RhythmInput.clear_notes()
    _current_phase = Phase.DEFEND
    phase_changed.emit(Phase.DEFEND)      # ← new

    if _all_enemies_dead() and not _combat_ended:
        _combat_ended = true
        teardown()
        combat_won.emit()

func _end_defend_phase() -> void:
    RhythmInput.clear_notes()
    _phase_beat_count = 0
    _defend_index += 1
    while _defend_index < _enemy_party.size() and _enemy_party[_defend_index].hp <= 0:
        _defend_index += 1

    if _defend_index >= _enemy_party.size():
        _current_phase = Phase.ATTACK
        phase_changed.emit(Phase.ATTACK)  # ← new
```

- [ ] **Step 2.4: Run all tests**

```
godot --headless --path . -s res://test/test_scoring.gd
godot --headless --path . -s res://test/test_active_note.gd
godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
```

All should PASS.

- [ ] **Step 2.5: Commit**

```
git add combat/combat_scene.gd test/test_beat_clock_lookahead.gd
git commit -m "feat: add note_approaching lookahead signal and phase_changed signal to CombatScene"
```

---

## Phase 2: Combat Prototype Completion

### Task 3: Sequence Evaluator (Combo Multiplier)

**This is done when:** Consecutive perfect hits increase a multiplier that boosts attack damage; the multiplier resets on miss; headless tests verify the formula.

**Files:**
- Create: `combat/sequence_evaluator.gd`
- Create: `test/test_sequence_evaluator.gd`
- Modify: `combat/combat_scene.gd` — integrate evaluator in ATTACK phase

- [ ] **Step 3.1: Write the failing test**

```gdscript
# test/test_sequence_evaluator.gd
# Run: godot --headless --path . -s res://test/test_sequence_evaluator.gd
extends SceneTree

const SequenceEvaluator = preload("res://combat/sequence_evaluator.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== SequenceEvaluator tests ===")
    var ev := SequenceEvaluator.new()

    # First perfect hit: multiplier starts at 1.0 (no combo bonus yet)
    var m := ev.record_hit(&"perfect")
    _check("first perfect multiplier == 1.0",        is_equal_approx(m, 1.0),  true)
    _check("combo_count after 1 perfect == 1",        ev.combo_count == 1,      true)

    # Four perfects in a row: combo_count=4, should add 0.1 bonus
    ev.record_hit(&"perfect")
    ev.record_hit(&"perfect")
    m = ev.record_hit(&"perfect")   # combo_count = 4
    _check("multiplier after 4 perfects >= 1.1",      m >= 1.1,                 true)

    # Good hit: combo continues, but perfect streak resets
    var streak_before := ev._perfect_streak
    m = ev.record_hit(&"good")
    _check("good hit keeps combo going",               ev.combo_count == 5,      true)
    _check("good hit resets perfect streak",           ev._perfect_streak == 0,  true)

    # Miss: combo resets to 0
    m = ev.record_hit(&"miss")
    _check("miss returns 0.0",                        is_equal_approx(m, 0.0),  true)
    _check("combo_count after miss == 0",              ev.combo_count == 0,      true)
    _check("max_combo preserved after miss",           ev.max_combo >= 5,        true)

    # reset() clears everything
    ev.reset()
    _check("reset clears combo_count",                 ev.combo_count == 0,      true)
    _check("reset clears max_combo",                   ev.max_combo == 0,        true)

    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
```

- [ ] **Step 3.2: Run test — confirm fail**

```
godot --headless --path . -s res://test/test_sequence_evaluator.gd
```

Expected: Error, file not found.

- [ ] **Step 3.3: Create `combat/sequence_evaluator.gd`**

```gdscript
# combat/sequence_evaluator.gd
# Tracks rhythmic quality during the ATTACK phase and computes a damage multiplier.
# One instance lives per combat; reset() is called at the start of each ATTACK phase.
class_name SequenceEvaluator
extends RefCounted

## How many non-miss hits the player has landed since the last miss.
var combo_count: int = 0
## Highest combo_count reached this combat (for end-of-battle display).
var max_combo: int = 0
## How many consecutive perfect hits without a good or miss.
var _perfect_streak: int = 0

## Record one hit during the ATTACK phase and return the damage multiplier for that hit.
## Returns 0.0 on miss (caller should skip damage accumulation).
## Perfect/good hits return >= 1.0; longer streaks yield higher multipliers.
func record_hit(score: StringName) -> float:
    if score == &"miss":
        combo_count = 0
        _perfect_streak = 0
        return 0.0

    combo_count += 1
    max_combo = max(max_combo, combo_count)

    if score == &"perfect":
        _perfect_streak += 1
    else:
        _perfect_streak = 0   # good hit breaks perfect streak

    return get_multiplier()

## Current damage multiplier based on combo and perfect streak.
## Base: 1.0. Combo adds up to +1.0 (every 4 hits = +0.1, max +1.0).
## Perfect streak adds up to +0.5 (every 2 perfects = +0.1, max +0.5).
## Combined ceiling: 2.5x.
func get_multiplier() -> float:
    var combo_bonus:  float = min(float(combo_count / 4) * 0.1, 1.0)
    var streak_bonus: float = min(float(_perfect_streak / 2) * 0.1, 0.5)
    return 1.0 + combo_bonus + streak_bonus

## Call at the start of each new ATTACK phase (not at each hit).
func reset() -> void:
    combo_count = 0
    max_combo = 0
    _perfect_streak = 0
```

- [ ] **Step 3.4: Run test — confirm pass**

```
godot --headless --path . -s res://test/test_sequence_evaluator.gd
```

All PASS.

- [ ] **Step 3.5: Integrate into `combat/combat_scene.gd`**

Add to top of file (after existing preloads):

```gdscript
const SequenceEvaluator = preload("res://combat/sequence_evaluator.gd")
```

Add instance variable:

```gdscript
var _sequence: SequenceEvaluator = SequenceEvaluator.new()
```

Add a new signal for combo display:

```gdscript
## Fires after each ATTACK phase hit with current combo count and multiplier.
signal combo_updated(combo_count: int, multiplier: float)
```

Update `_on_input_scored` ATTACK branch:

```gdscript
Phase.ATTACK:
    var character = _get_active_character()
    if character == null:
        return
    var multiplier: float = _sequence.record_hit(score)
    match score:
        &"perfect":
            _damage_accumulator += float(character.attack_power) * multiplier
        &"good":
            _damage_accumulator += float(character.attack_power) * 0.5 * multiplier
        # miss: multiplier is 0.0, combo resets — nothing accumulated
    combo_updated.emit(_sequence.combo_count, _sequence.get_multiplier())
```

Reset in `_end_attack_phase()` (add after `_phase_beat_count = 0`):

```gdscript
_sequence.reset()
```

- [ ] **Step 3.6: Run all headless tests**

```
godot --headless --path . -s res://test/test_scoring.gd
godot --headless --path . -s res://test/test_active_note.gd
godot --headless --path . -s res://test/test_sequence_evaluator.gd
godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
```

All PASS.

- [ ] **Step 3.7: Manual verification**

Run the game. During ATTACK, spam arrows rapidly — confirm the EnemyHP drops faster on sustained perfect hits than on random off-beat mashing. On a miss, combo should reset (no multiplier boost visible in HP delta).

- [ ] **Step 3.8: Commit**

```
git add combat/sequence_evaluator.gd combat/combat_scene.gd test/test_sequence_evaluator.gd
git commit -m "feat: add SequenceEvaluator with combo multiplier; integrate into ATTACK phase damage"
```

---

### Task 4: Limit Break System

**This is done when:** `CharacterData` has a `limit_break_gauge` that fills on perfect hits; when full, a `limit_break_ready` signal fires on `CombatScene`; pressing a designated action triggers an extended ATTACK phase; the gauge resets after use.

**Files:**
- Modify: `characters/character_data.gd`
- Modify: `combat/combat_scene.gd`
- Create: `test/test_limit_break.gd`

- [ ] **Step 4.1: Write the failing test**

```gdscript
# test/test_limit_break.gd
# Run: godot --headless --path . -s res://test/test_limit_break.gd
extends SceneTree

const CharacterData = preload("res://characters/character_data.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== Limit Break tests ===")
    var c := CharacterData.new()
    c.max_hp = 100; c.hp = 100

    _check("gauge starts at 0.0",          is_equal_approx(c.limit_break_gauge, 0.0), true)
    _check("charge_rate_perfect exists",   c.charge_rate_perfect > 0.0,               true)
    _check("charge_rate_good exists",      c.charge_rate_good > 0.0,                  true)

    # Simulate charging
    c.limit_break_gauge = min(1.0, c.limit_break_gauge + c.charge_rate_perfect)
    _check("gauge increases on charge",    c.limit_break_gauge > 0.0,                 true)

    # Fill the gauge
    c.limit_break_gauge = 1.0
    _check("gauge can reach 1.0",          is_equal_approx(c.limit_break_gauge, 1.0), true)

    # Discharge
    c.limit_break_gauge = 0.0
    _check("gauge resets to 0.0",          is_equal_approx(c.limit_break_gauge, 0.0), true)

    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
```

- [ ] **Step 4.2: Run test — confirm fail**

```
godot --headless --path . -s res://test/test_limit_break.gd
```

Expected: FAIL on field existence checks.

- [ ] **Step 4.3: Update `characters/character_data.gd`**

```gdscript
# characters/character_data.gd
class_name CharacterData
extends Resource

@export var character_name: String = ""
@export var max_hp: int = 100
@export var hp: int = 100

## Base damage on perfect hit during ATTACK phase.
@export var attack_power: int = 10

## Current limit break charge. Range [0.0, 1.0]. At 1.0, limit break is available.
@export var limit_break_gauge: float = 0.0

## How much the gauge fills on a perfect hit (0.0–1.0).
@export var charge_rate_perfect: float = 0.08

## How much the gauge fills on a good hit (0.0–1.0).
@export var charge_rate_good: float = 0.03

## How many beats the limit break ATTACK phase lasts (longer than normal).
@export var limit_break_phase_length: int = 8

## Damage multiplier applied during limit break phase.
@export var limit_break_multiplier: float = 2.5
```

- [ ] **Step 4.4: Run test — confirm pass**

```
godot --headless --path . -s res://test/test_limit_break.gd
```

All PASS.

- [ ] **Step 4.5: Integrate limit break into `combat/combat_scene.gd`**

Add to signals section:

```gdscript
## Fires when a character's limit_break_gauge reaches 1.0 for the first time.
signal limit_break_ready(character: CharacterData)
## Fires when the limit break phase begins.
signal limit_break_started(character: CharacterData)
## Fires when the limit break phase ends.
signal limit_break_ended()
```

Add instance variable:

```gdscript
var _limit_break_active: bool = false
var _limit_break_character = null  # CharacterData
```

In `_on_input_scored`, after accumulating damage during ATTACK, add gauge charging:

```gdscript
Phase.ATTACK:
    var character = _get_active_character()
    if character == null:
        return
    var multiplier: float = _sequence.record_hit(score)

    # Apply limit break multiplier if active
    var lb_mult: float = character.limit_break_multiplier if _limit_break_active else 1.0

    match score:
        &"perfect":
            _damage_accumulator += float(character.attack_power) * multiplier * lb_mult
            # Charge gauge
            if not _limit_break_active:
                var was_full := character.limit_break_gauge >= 1.0
                character.limit_break_gauge = min(1.0, character.limit_break_gauge + character.charge_rate_perfect)
                if not was_full and character.limit_break_gauge >= 1.0:
                    limit_break_ready.emit(character)
        &"good":
            _damage_accumulator += float(character.attack_power) * 0.5 * multiplier * lb_mult
            if not _limit_break_active:
                character.limit_break_gauge = min(1.0, character.limit_break_gauge + character.charge_rate_good)
        # miss: no damage, no charge
    combo_updated.emit(_sequence.combo_count, _sequence.get_multiplier())
```

Add public method to trigger limit break (called from UI action button or input):

```gdscript
## Call when the player activates their limit break.
## Only effective during ATTACK phase when gauge is full.
func try_activate_limit_break() -> bool:
    if _current_phase != Phase.ATTACK:
        return false
    var character = _get_active_character()
    if character == null or character.limit_break_gauge < 1.0:
        return false
    _limit_break_active = true
    _limit_break_character = character
    player_phase_length = character.limit_break_phase_length
    limit_break_started.emit(character)
    return true
```

In `_end_attack_phase()`, after reset, clear limit break state:

```gdscript
if _limit_break_active:
    _limit_break_active = false
    if _limit_break_character != null:
        _limit_break_character.limit_break_gauge = 0.0
        _limit_break_character = null
    player_phase_length = 4   # restore default; or pull from a saved default
    limit_break_ended.emit()
```

Add input action `limit_break` in `project.godot` [input] section (Space bar = keycode 32):

```ini
limit_break={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
```

Wire the action in `test_scene.gd` (add to `_unhandled_input` or a new `_process` check):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"limit_break"):
        _combat.try_activate_limit_break()
```

- [ ] **Step 4.6: Run all headless tests**

```
godot --headless --path . -s res://test/test_scoring.gd
godot --headless --path . -s res://test/test_active_note.gd
godot --headless --path . -s res://test/test_sequence_evaluator.gd
godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
godot --headless --path . -s res://test/test_limit_break.gd
```

All PASS.

- [ ] **Step 4.7: Manual verification**

Run the game. After several perfect hits, press Space. Verify: combat phase extends, damage is visibly much higher per hit. After limit break ends, pressing Space again does nothing (gauge at 0).

- [ ] **Step 4.8: Commit**

```
git add characters/character_data.gd combat/combat_scene.gd project.godot test_scene.gd test/test_limit_break.gd
git commit -m "feat: add limit break gauge to CharacterData; integrate activation and extended attack phase"
```

---

### Task 5: SoloStyle Resource + Luthier Frett

**This is done when:** A `SoloStyle` resource type exists; Luthier Frett's stats and style are defined as a `.tres` file; the test scene uses him instead of the anonymous "Hero".

**Files:**
- Create: `characters/solo_style.gd`
- Create: `characters/luthier_frett.tres`
- Modify: `test_scene.gd` — load Luthier from resource

- [ ] **Step 5.1: Create `characters/solo_style.gd`**

```gdscript
# characters/solo_style.gd
# Per-character visual and musical identity during the ATTACK phase.
# A SoloStyle resource is attached to CharacterData and read by the combat UI
# to tint the stage, route audio to the correct instrument bus, and label the
# on-screen input map with instrument-appropriate direction names.
class_name SoloStyle
extends Resource

## Human-readable instrument name shown in UI (e.g. "Lute", "Drum", "Flute").
@export var instrument_name: String = "Instrument"

## AudioBus name to route attack-phase SFX through. Must exist in AudioServer.
## Allows per-character reverb/EQ while sharing the same BeatClock.
@export var audio_bus: String = "Master"

## Notes in the character's musical scale, as semitone offsets from root.
## The four directions map to scale degrees:
##   up    → scale_steps[0]  (root or tonic)
##   right → scale_steps[1]  (second/third)
##   down  → scale_steps[2]  (fourth/fifth)
##   left  → scale_steps[3]  (sixth/seventh)
## For major pentatonic: [0, 2, 7, 9] (C, D, G, A)
## For minor scale:      [0, 3, 7, 10] (C, Eb, G, Bb)
@export var scale_steps: Array[int] = [0, 2, 7, 9]

## MIDI root note (60 = middle C). Direction inputs play scale_steps[i] + root_note.
@export var root_note: int = 60

## UI accent color for this character's phase (used in HP bar, phase label).
@export var accent_color: Color = Color(1.0, 1.0, 1.0)

## Short flavor text shown in the phase transition label (e.g. "Luthier takes the stage!").
@export var phase_intro_text: String = "Your turn!"
```

- [ ] **Step 5.2: Update `characters/character_data.gd` to reference SoloStyle**

Add one field after `limit_break_multiplier`:

```gdscript
## The character's musical and visual identity during combat.
## Null = generic (prototype fallback). Set this for all named characters.
@export var solo_style: SoloStyle = null
```

- [ ] **Step 5.3: Create `characters/luthier_frett.tres`**

This is a `.tres` file authored in the Godot editor. Create it manually:

1. In the Godot editor FileSystem panel, right-click `characters/` → New Resource
2. Select `CharacterData`, save as `luthier_frett.tres`
3. Set fields in Inspector:
   - `character_name`: `"Luthier Frett"`
   - `max_hp`: `120`
   - `hp`: `120`
   - `attack_power`: `14`
   - `charge_rate_perfect`: `0.08`
   - `charge_rate_good`: `0.03`
   - `limit_break_phase_length`: `8`
   - `limit_break_multiplier`: `2.5`
4. Right-click `characters/` → New Resource → `SoloStyle`, save as `luthier_solo_style.tres`
5. Set fields:
   - `instrument_name`: `"Lute"`
   - `audio_bus`: `"Strings"` (create this AudioBus in Project → Audio)
   - `scale_steps`: `[0, 2, 7, 9]` (major pentatonic)
   - `root_note`: `57` (A3 — banjo open tuning feel)
   - `accent_color`: `Color(0.85, 0.65, 0.25, 1.0)` (warm banjo gold)
   - `phase_intro_text`: `"Luthier takes the stage!"`
6. Assign `luthier_solo_style.tres` to `luthier_frett.tres`'s `solo_style` field

**Alternative (scripted resource creation):** Create a one-shot script `tools/create_luthier.gd` with `@tool extends EditorScript` that creates and saves the `.tres` files programmatically, then run it from the Editor Script window.

- [ ] **Step 5.4: Update `test_scene.gd` to load Luthier from resource**

Replace the anonymous hero construction in `_ready()`:

```gdscript
# Remove:
# _hero = CharacterData.new()
# _hero.character_name = "Hero"
# _hero.max_hp = 100 ...

# Replace with:
_hero = load("res://characters/luthier_frett.tres") as CharacterData
if _hero == null:
    push_error("test_scene: Failed to load luthier_frett.tres — falling back to anonymous hero")
    _hero = CharacterData.new()
    _hero.character_name = "Hero"
    _hero.max_hp = 100
    _hero.hp = 100
    _hero.attack_power = 12
```

- [ ] **Step 5.5: Manual verification**

Run the game. Verify player HP shows 120 (Luthier's max HP). Combat should play identically to before.

- [ ] **Step 5.6: Commit**

```
git add characters/solo_style.gd characters/character_data.gd characters/luthier_frett.tres characters/luthier_solo_style.tres test_scene.gd
git commit -m "feat: add SoloStyle resource; define Luthier Frett with stats and banjo pentatonic style"
```

---

### Task 6: Note Lane Visualizer (Defend Phase)

**This is done when:** During DEFEND, colored note rectangles scroll toward a hit zone from `lookahead_beats` beats away; they flash green on perfect hit, yellow on good, red on miss/expire; the beat pulse glows on each beat.

**Files:**
- Create: `combat/note_visual.gd`
- Create: `combat/note_visual.tscn`
- Create: `combat/note_lane.gd`
- Create: `combat/note_lane.tscn`
- Modify: `combat/combat_scene.tscn` — add NoteLane as child
- Modify: `test_scene.tscn` — enable canvas layer for NoteLane

- [ ] **Step 6.1: Create `combat/note_visual.tscn`**

In the Godot editor:
1. Create new scene → root node: `Control`, rename to `NoteVisual`
2. Add child `ColorRect`, rename to `Body` — size `(28, 28)`, color `Color(0.9, 0.8, 0.2)`
3. Add child `Label`, rename to `DirectionLabel` — text `↑`, anchored center, font size 18
4. Attach script `combat/note_visual.gd`
5. Save as `combat/note_visual.tscn`

```gdscript
# combat/note_visual.gd
# A single approaching note during the DEFEND phase.
# Spawned by NoteLane when note_approaching fires on CombatScene.
extends Control

@onready var _body: ColorRect = $Body
@onready var _label: Label = $DirectionLabel

# Direction-to-arrow glyph map.
const ARROW := {
    &"up":    "↑",
    &"down":  "↓",
    &"left":  "←",
    &"right": "→",
}

# Colors
const COLOR_NORMAL  := Color(0.9, 0.8, 0.2)   # gold
const COLOR_PERFECT := Color(0.4, 1.0, 0.5)   # green
const COLOR_GOOD    := Color(1.0, 0.85, 0.3)   # amber
const COLOR_MISS    := Color(1.0, 0.25, 0.25)  # red

func init(direction: StringName) -> void:
    _label.text = ARROW.get(direction, "?")

## Flash the appropriate color feedback, then free the node.
func flash_result(score: StringName) -> void:
    var color: Color
    match score:
        &"perfect": color = COLOR_PERFECT
        &"good":    color = COLOR_GOOD
        _:          color = COLOR_MISS
    _body.color = color
    var tween := create_tween()
    tween.tween_interval(0.12)
    tween.tween_callback(queue_free)
```

- [ ] **Step 6.2: Create `combat/note_lane.tscn`**

In the Godot editor:
1. Create new scene → root node `Control`, rename to `NoteLane`, set custom minimum size `(500, 200)`
2. Add `Panel` child for background
3. Add `VBoxContainer` child, rename `Lanes`, anchored to fill parent with margin
4. Inside `Lanes`, add four `Control` children, each `40px` tall, named `UpLane`, `DownLane`, `LeftLane`, `RightLane`
5. Inside each lane, add:
   - `Label` named `LaneLabel` (text: `↑ / ↓ / ← / →`)
   - `ColorRect` named `HitZone` — `x: 10, y: 5, width: 30, height: 30` — dark yellow
6. Add `Label` child to root named `PhaseInfo` for "DEFEND vs [Enemy]" text
7. Attach script `combat/note_lane.gd`
8. Save as `combat/note_lane.tscn`

```gdscript
# combat/note_lane.gd
# Visualizes incoming notes during the DEFEND phase.
# Connect to a CombatScene instance via setup() after EncounterManager.start_combat().
extends Control

const NoteVisual = preload("res://combat/note_visual.tscn")
const EnemyData  = preload("res://characters/enemy_data.gd")
const NoteData   = preload("res://rhythm_engine/note_data.gd")

@onready var _phase_info: Label = $PhaseInfo
@onready var _lanes: Dictionary = {
    &"up":    $Lanes/UpLane,
    &"down":  $Lanes/DownLane,
    &"left":  $Lanes/LeftLane,
    &"right": $Lanes/RightLane,
}
@onready var _hit_zones: Dictionary = {
    &"up":    $Lanes/UpLane/HitZone,
    &"down":  $Lanes/DownLane/HitZone,
    &"left":  $Lanes/LeftLane/HitZone,
    &"right": $Lanes/RightLane/HitZone,
}

# Maps NoteData (by identity) to the NoteVisual currently travelling for it.
# Used so we can flash/remove the correct visual when input_scored fires.
var _visuals: Dictionary = {}

# How many beats ahead notes were announced (copied from CombatScene.lookahead_beats).
var _lookahead_beats: int = 2

## Wire this lane to a CombatScene after start_combat() returns.
## combat: the Node returned by EncounterManager.start_combat()
func setup(combat: Node) -> void:
    _lookahead_beats = combat.lookahead_beats
    combat.note_approaching.connect(_on_note_approaching)
    combat.phase_changed.connect(_on_phase_changed)
    RhythmInput.input_scored.connect(_on_input_scored)
    RhythmInput.note_missed.connect(_on_note_missed)
    visible = false   # hidden until DEFEND starts

func _on_phase_changed(new_phase: int) -> void:
    # CombatScene.Phase: 0 = ATTACK, 1 = DEFEND
    visible = (new_phase == 1)
    if new_phase == 1:
        _phase_info.text = "DEFEND"
    else:
        _visuals.clear()   # clear any orphaned references on phase switch

func _on_note_approaching(note: NoteData, _target_beat: int) -> void:
    var lane = _lanes.get(note.direction)
    if lane == null:
        return

    # Spawn a NoteVisual at the RIGHT side of the lane (far from hit zone).
    var visual: Control = NoteVisual.instantiate()
    lane.add_child(visual)
    visual.init(note.direction)

    # Position: start at x = lane width, travel to x = hit zone x position.
    # Hit zone is at x=10 (set in scene). Note spawns at x = lane.size.x - 40.
    var start_x: float = lane.size.x - 40.0
    var end_x:   float = 10.0
    visual.position = Vector2(start_x, 5.0)

    var travel_time: float = float(_lookahead_beats) * (60.0 / BeatClock.bpm)
    var tween := create_tween()
    tween.tween_property(visual, "position:x", end_x, travel_time)
    # If not hit in time, the note visual auto-queues_free when it arrives.
    # note_missed signal will handle the red flash at that point.
    tween.tween_callback(visual.queue_free)
    tween.tween_callback(func(): _visuals.erase(note))

    # Track it so input_scored can find and flash it.
    _visuals[note] = visual

func _on_input_scored(_direction: StringName, score: StringName, _offset: float, note_consumed: bool) -> void:
    if not note_consumed:
        return
    # Flash the most recently queued visual for any direction.
    # (In practice, the consumed note's visual is whichever one is farthest along.)
    # A more precise approach would emit the NoteData from input_scored, but
    # this is sufficient for prototype purposes.
    for note in _visuals.keys():
        var visual = _visuals.get(note)
        if is_instance_valid(visual):
            _visuals.erase(note)
            visual.flash_result(score)
            return
    # Flash the hit zone instead if the visual already disappeared.
    _flash_hit_zone(score)

func _on_note_missed(note: NoteData) -> void:
    var visual = _visuals.get(note)
    if is_instance_valid(visual):
        _visuals.erase(note)
        visual.flash_result(&"miss")
    _flash_hit_zone(&"miss")

func _flash_hit_zone(score: StringName) -> void:
    var color: Color
    match score:
        &"perfect": color = Color(0.4, 1.0, 0.5)
        &"good":    color = Color(1.0, 0.85, 0.3)
        _:          color = Color(1.0, 0.25, 0.25)
    for hz in _hit_zones.values():
        hz.color = color
    await get_tree().create_timer(0.1).timeout
    if not is_instance_valid(self):
        return
    for hz in _hit_zones.values():
        hz.color = Color(0.4, 0.35, 0.1)   # restore dim gold
```

- [ ] **Step 6.3: Wire NoteLane into test scene**

In `test_scene.tscn`, add a `NoteLane` instance as a child (position it in the lower half of the screen, e.g. offset `(0, 300)`).

In `test_scene.gd`, add to `_ready()`:

```gdscript
@onready var _note_lane: Node = $NoteLane   # or wherever it's placed in scene

# In _ready(), after _combat is assigned:
_note_lane.setup(_combat)
```

- [ ] **Step 6.4: Manual verification**

Run the game with `encounter_id = &"goblin_single"`. During ATTACK phase, NoteLane panel is hidden. When DEFEND phase begins, it becomes visible. Gold notes scroll from right toward the hit zone. On correct direction press, the visual flashes green. On miss, it flashes red.

> **Acceptance criteria:** A first-time player can see the note coming 1+ second before it arrives and has enough time to react. At 120 BPM with 2 beat lookahead, notes appear 1 second early.

- [ ] **Step 6.5: Commit**

```
git add combat/note_visual.gd combat/note_visual.tscn combat/note_lane.gd combat/note_lane.tscn test_scene.gd test_scene.tscn
git commit -m "feat: add note lane visualizer with lookahead-synced approach animation"
```

---

### Task 7: Combat UI (HP Bars, Phase Display, Beat Pulse)

**This is done when:** HP bars are styled visual bars (not raw text), a beat pulse animates on each `BeatClock.beat`, and the phase label transitions with a brief color flash.

**Files:**
- Create: `combat/combat_ui.gd`
- Create: `combat/combat_ui.tscn`
- Modify: `test_scene.gd` — delegate UI to CombatUI
- Modify: `test_scene.tscn` — add CombatUI child

- [ ] **Step 7.1: Create `combat/combat_ui.tscn` in the editor**

Scene structure:
```
CombatUI (CanvasLayer)
  ├── BGPanel (Panel) — full-width dark overlay at top
  ├── HBoxTop (HBoxContainer) — row for turn info
  │   ├── PhaseLabel (Label) — "ATTACK" / "DEFEND"
  │   ├── BeatPulse (ColorRect) — 20×20 dot, flashes on beat
  │   └── ComboLabel (Label) — "Combo: 0  ×1.0"
  ├── PlayerBar (VBoxContainer)
  │   ├── PlayerName (Label)
  │   ├── HPBarBG (Panel, width 200, height 18)
  │   │   └── HPBarFill (ColorRect, anchored left, same height)
  │   └── HPNumbers (Label) — "120 / 120"
  ├── EnemyBar (VBoxContainer) — same structure
  └── LimitBar (VBoxContainer)
      ├── LimitLabel (Label) — "LIMIT"
      ├── LimitBarBG (Panel, width 200, height 10)
      │   └── LimitBarFill (ColorRect)
      └── LimitReady (Label) — "READY!" (hidden when not full)
```

- [ ] **Step 7.2: Create `combat/combat_ui.gd`**

```gdscript
# combat/combat_ui.gd
# Displays all combat state: HP bars, phase, combo, limit break gauge, beat pulse.
# Call setup(combat, player_character) once after the combat scene is ready.
extends CanvasLayer

const EnemyData     = preload("res://characters/enemy_data.gd")
const CharacterData = preload("res://characters/character_data.gd")

@onready var _phase_label:     Label     = $BGPanel/HBoxTop/PhaseLabel
@onready var _beat_pulse:      ColorRect = $BGPanel/HBoxTop/BeatPulse
@onready var _combo_label:     Label     = $BGPanel/HBoxTop/ComboLabel
@onready var _player_name:     Label     = $PlayerBar/PlayerName
@onready var _player_fill:     ColorRect = $PlayerBar/HPBarBG/HPBarFill
@onready var _player_numbers:  Label     = $PlayerBar/HPNumbers
@onready var _enemy_name:      Label     = $EnemyBar/PlayerName
@onready var _enemy_fill:      ColorRect = $EnemyBar/HPBarBG/HPBarFill
@onready var _enemy_numbers:   Label     = $EnemyBar/HPNumbers
@onready var _limit_fill:      ColorRect = $LimitBar/LimitBarBG/LimitBarFill
@onready var _limit_ready:     Label     = $LimitBar/LimitReady

var _combat = null      # CombatScene node
var _hero: CharacterData = null
var _bar_max_width: float = 200.0

func setup(combat: Node, hero: CharacterData) -> void:
    _combat = combat
    _hero = hero
    _player_name.text = hero.character_name

    # Apply SoloStyle accent color if available
    if hero.solo_style != null:
        _phase_label.add_theme_color_override("font_color", hero.solo_style.accent_color)

    combat.phase_changed.connect(_on_phase_changed)
    combat.combo_updated.connect(_on_combo_updated)
    combat.limit_break_ready.connect(_on_limit_break_ready)
    combat.limit_break_ended.connect(_on_limit_break_ended)
    BeatClock.beat.connect(_on_beat)

func _process(_delta: float) -> void:
    if _hero == null or _combat == null:
        return

    # Player HP bar
    var hp_ratio: float = float(_hero.hp) / float(_hero.max_hp)
    _player_fill.size.x = _bar_max_width * clampf(hp_ratio, 0.0, 1.0)
    _player_numbers.text = "%d / %d" % [_hero.hp, _hero.max_hp]
    _player_fill.color = _hp_color(hp_ratio)

    # Enemy HP bar — show current attack target
    var enemy = _combat.get_attack_target()
    if enemy != null:
        _enemy_name.text = enemy.enemy_name
        var e_ratio: float = float(enemy.hp) / float(enemy.max_hp)
        _enemy_fill.size.x = _bar_max_width * clampf(e_ratio, 0.0, 1.0)
        _enemy_numbers.text = "%d / %d" % [enemy.hp, enemy.max_hp]
        _enemy_fill.color = _hp_color(e_ratio)
    else:
        _enemy_name.text = "—"
        _enemy_fill.size.x = 0.0
        _enemy_numbers.text = ""

    # Limit break bar
    var lb_ratio: float = clampf(_hero.limit_break_gauge, 0.0, 1.0)
    _limit_fill.size.x = _bar_max_width * lb_ratio
    _limit_fill.color = Color(0.9, 0.7, 0.1) if lb_ratio < 1.0 else Color(1.0, 0.95, 0.2)

func _on_phase_changed(new_phase: int) -> void:
    # Phase.ATTACK = 0, Phase.DEFEND = 1
    _phase_label.text = "ATTACK" if new_phase == 0 else "DEFEND"
    var tween := create_tween()
    tween.tween_property(_phase_label, "modulate", Color(1.5, 1.5, 0.5), 0.0)
    tween.tween_property(_phase_label, "modulate", Color.WHITE, 0.3)

func _on_combo_updated(combo: int, multiplier: float) -> void:
    if combo <= 0:
        _combo_label.text = ""
        return
    _combo_label.text = "Combo: %d  ×%.1f" % [combo, multiplier]

func _on_limit_break_ready(_char: CharacterData) -> void:
    _limit_ready.visible = true
    _limit_ready.text = "SPACE → LIMIT BREAK!"

func _on_limit_break_ended() -> void:
    _limit_ready.visible = false

func _on_beat(_beat_number: int) -> void:
    _beat_pulse.color = Color(1.0, 1.0, 0.3)
    var tween := create_tween()
    tween.tween_property(_beat_pulse, "color", Color(0.2, 0.2, 0.2), 0.08)

# --- Helpers ---

func _hp_color(ratio: float) -> Color:
    if ratio > 0.5:
        return Color(0.2, 0.85, 0.3)   # green
    elif ratio > 0.25:
        return Color(0.95, 0.75, 0.1)  # yellow
    else:
        return Color(0.9, 0.2, 0.2)    # red
```

- [ ] **Step 7.3: Update `test_scene.gd` to use CombatUI**

Remove the old debug label code and delegate everything to CombatUI:

```gdscript
# test_scene.gd — stripped down, delegates display to CombatUI
extends Node2D

const CharacterData    = preload("res://characters/character_data.gd")
const EncounterManager = preload("res://combat/encounter_manager.gd")

@export var player_first: bool = true
@export var encounter_id: StringName = &"goblin_single"

@onready var _audio:      AudioStreamPlayer = $AudioStreamPlayer
@onready var _combat_ui:  Node              = $CombatUI
@onready var _note_lane:  Node              = $NoteLane

var _hero:   CharacterData
var _combat: Node

func _ready() -> void:
    _hero = load("res://characters/luthier_frett.tres") as CharacterData
    if _hero == null:
        _hero = CharacterData.new()
        _hero.character_name = "Hero"
        _hero.max_hp = 100; _hero.hp = 100; _hero.attack_power = 12

    BeatClock.bpm = 130.0
    BeatClock.intro_offset_ms = 1200.0
    _audio.play()
    BeatClock.start(_audio)

    var party: Array[CharacterData] = [_hero]
    _combat = EncounterManager.start_combat(get_tree(), party, encounter_id, player_first)
    _combat.combat_won.connect(_on_combat_won)
    _combat.combat_lost.connect(_on_combat_lost)

    _combat_ui.setup(_combat, _hero)
    _note_lane.setup(_combat)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"limit_break"):
        _combat.try_activate_limit_break()

func _on_combat_won() -> void:
    BeatClock.stop()
    _audio.stop()

func _on_combat_lost() -> void:
    BeatClock.stop()
    _audio.stop()
```

- [ ] **Step 7.4: Manual verification**

Run game. Verify:
- HP bars fill/shrink as damage is taken (no text labels needed)
- Beat pulse dot flashes yellow every beat
- Phase label flashes bright on ATTACK→DEFEND transition
- Combo counter appears during sustained perfect hits
- Limit break bar fills; "READY!" appears; pressing Space triggers extended attack phase

> **Acceptance criteria:** A person watching over your shoulder can understand what's happening in the game without any labels or explanation.

- [ ] **Step 7.5: Commit**

```
git add combat/combat_ui.gd combat/combat_ui.tscn test_scene.gd test_scene.tscn
git commit -m "feat: add CombatUI with HP bars, beat pulse, combo display, and limit break indicator"
```

---

### Task 8: Audio Feedback Layer

**This is done when:** Distinct sounds play on perfect/good/miss hits during both ATTACK and DEFEND phases; sounds are pitched by the character's SoloStyle scale when available.

**Files:**
- Create: `combat/audio_feedback.gd`
- Create: `combat/audio_feedback.tscn`
- Modify: `test_scene.tscn` — add AudioFeedback child

> **Note on audio assets:** This task requires instrument sound samples. Use royalty-free single-note samples from sites like Freesound.org — a single lute/banjo pluck for perfect, a softer one for good, a muted thud for miss. Place them in `audio/sfx/` as `.ogg` files.

- [ ] **Step 8.1: Create placeholder audio assets**

Place these files in `audio/sfx/`:
- `hit_perfect.ogg` — bright banjo pluck
- `hit_good.ogg` — softer pluck (lower velocity)
- `hit_miss.ogg` — muted thud or string slap
- `note_approaching.ogg` — very quiet soft pluck (optional, for approaching note tick)

If you don't have assets yet, create silent placeholder `.ogg` files. The system will still function; swap real audio in later.

- [ ] **Step 8.2: Create `combat/audio_feedback.gd`**

```gdscript
# combat/audio_feedback.gd
# Plays instrument-appropriate SFX in response to rhythm input scoring.
# Connects to RhythmInput.input_scored and optionally pitches the sound
# based on the active character's SoloStyle scale.
extends Node

const CharacterData = preload("res://characters/character_data.gd")

# AudioStreamPlayers — one per voice to allow polyphonic playback.
# In the scene, these are children: PerfectPlayer, GoodPlayer, MissPlayer.
@onready var _perfect_player:   AudioStreamPlayer = $PerfectPlayer
@onready var _good_player:      AudioStreamPlayer = $GoodPlayer
@onready var _miss_player:      AudioStreamPlayer = $MissPlayer

# Optional: the character whose scale determines note pitch.
var _active_character: CharacterData = null

# Direction-to-scale-index mapping for pitch shifting.
const DIRECTION_INDEX := {
    &"up": 0, &"right": 1, &"down": 2, &"left": 3,
}

func setup(character: CharacterData) -> void:
    _active_character = character
    RhythmInput.input_scored.connect(_on_input_scored)

func _on_input_scored(direction: StringName, score: StringName, _offset: float, _consumed: bool) -> void:
    var pitch: float = _get_pitch(direction)
    match score:
        &"perfect":
            _perfect_player.pitch_scale = pitch
            _perfect_player.play()
        &"good":
            _good_player.pitch_scale = pitch
            _good_player.play()
        &"miss":
            _miss_player.pitch_scale = 1.0
            _miss_player.play()

## Converts a direction to a playback pitch based on SoloStyle scale.
## Returns 1.0 (no pitch shift) if no SoloStyle is set.
func _get_pitch(direction: StringName) -> float:
    if _active_character == null or _active_character.solo_style == null:
        return 1.0
    var style := _active_character.solo_style
    var idx: int = DIRECTION_INDEX.get(direction, 0)
    if idx >= style.scale_steps.size():
        return 1.0
    var semitones: int = style.scale_steps[idx]
    # Convert semitone offset to pitch multiplier: 2^(semitones/12)
    return pow(2.0, float(semitones) / 12.0)
```

- [ ] **Step 8.3: Create `combat/audio_feedback.tscn`**

In the editor:
1. Root: `Node`, renamed `AudioFeedback`, script attached
2. Three children: `AudioStreamPlayer` nodes named `PerfectPlayer`, `GoodPlayer`, `MissPlayer`
3. Set each player's `Stream` to the corresponding `.ogg` file from `audio/sfx/`
4. Set each player's `Bus` to `"Strings"` (or `"Master"` if the Strings bus isn't created yet)
5. Save as `combat/audio_feedback.tscn`

- [ ] **Step 8.4: Add AudioFeedback to test scene**

In `test_scene.tscn`: add `AudioFeedback` as a child node (instance the `.tscn`).

In `test_scene.gd`, add `@onready`:

```gdscript
@onready var _audio_feedback: Node = $AudioFeedback
```

In `_ready()`, after `_hero` is loaded, call setup:

```gdscript
_audio_feedback.setup(_hero)
```

- [ ] **Step 8.5: Manual verification**

Run the game. Press arrow keys on and off the beat. Verify:
- Perfect hits play a bright, higher-pitched sound (scale step 0 = root)
- Up/right/down/left play progressively different pitches based on pentatonic scale
- Misses play a dull thud
- During DEFEND, blocking a note plays a defensive block sound

> **Acceptance criteria:** With eyes closed, you can tell what score you got purely from the sound. Each direction sounds like a different note in a scale.

- [ ] **Step 8.6: Commit**

```
git add combat/audio_feedback.gd combat/audio_feedback.tscn audio/sfx/ test_scene.gd test_scene.tscn
git commit -m "feat: add AudioFeedback with pitch-shifted instrument sounds per SoloStyle scale"
```

---

### Task 9: Prototype Integration Pass

**This is done when:** The full combat prototype can be played end-to-end: start → attack → defend → win or loss → stop. All visual and audio feedback systems work together. A person who has never seen the game can play one fight without explanation.

**Files:**
- Modify: `combat/encounter_manager.gd` — add a harder encounter for testing
- Modify: `test_scene.tscn` — final layout and sizing pass

- [ ] **Step 9.1: Add a boss-difficulty prototype encounter to EncounterManager**

```gdscript
# In encounter_manager.gd, add to _generate_enemies() match block:
&"string_golem":
    return [_make_string_golem()]

# Add constructor:
static func _make_string_golem() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "String Golem"
    e.max_hp       = 120
    e.hp           = 120
    e.attack_power = 18
    e.phase_length = 8

    # Alternating up/down pairs, then a left+right flourish
    var dirs: Array[StringName] = [&"up", &"down", &"up", &"down", &"left", &"right", &"left", &"right"]
    var notes: Array[NoteData] = []
    for i in range(8):
        var n := NoteData.new()
        n.beat_offset = i
        n.direction   = dirs[i]
        n.mode        = &"targeted"
        notes.append(n)
    e.pattern = notes
    return e
```

- [ ] **Step 9.2: Full end-to-end test session (manual)**

Play three complete fights:
1. `goblin_single` — easy, teaches the basics
2. `orc_heavy` — longer defend patterns, harder
3. `string_golem` — all 8 beats targeted, uses limit break to survive

For each fight, verify:
- [ ] Beat pulse is visible and correctly timed to the audio
- [ ] Notes appear 2 beats early during DEFEND
- [ ] Hitting correct direction blocks damage (HP bar stays green)
- [ ] Missing notes causes red HP bar damage
- [ ] Combo counter rises and shows multiplier during sustained perfect attacking
- [ ] Limit break fills over ~13 perfect hits; Space activates it; damage doubles during activation
- [ ] On win: music stops, HP bars freeze
- [ ] On loss: music stops, all bars show final state

- [ ] **Step 9.3: Fix any integration issues found in Step 9.2**

Common issues to watch for:
- `is_instance_valid()` errors from tweens running after node freed — add guards
- Phase transition leaves stale note visuals — call `_visuals.clear()` in NoteLane's `_on_phase_changed`
- Limit break doesn't reset `player_phase_length` if goblin fight is too short — ensure the default is restored

- [ ] **Step 9.4: Final commit**

```
git add .
git commit -m "feat: combat prototype complete — visuals, audio, combo, limit break all integrated"
```

> **Prototype acceptance criteria:** A first-time player can sit down, press arrow keys, and understand that timing matters; they can see notes coming; they hear musical feedback; they feel the difference between a perfect combo and a fumble. The limit break is satisfying. **This is the publisher demo checkpoint.**

---

## Phase 3: Vertical Slice

> Each task below is a larger building block. Detailed step-by-step implementation is scoped to the acceptance criteria and key architecture decisions; the same TDD pattern from Phase 2 applies throughout.

---

### Task 10: AudioDirector — Diegetic Stem System

**This is done when:** Background music plays as layered stems controlled by `AudioDirector`; stems fade in/out on beat boundaries; adding/removing a character from the party changes which stems are active; volume drops to near-zero when entering a dungeon.

**Files to create:**
- `autoloads/audio_director.gd` — register as autoload `AudioDirector` in project.godot
- `audio/layer_config.gd` — resource defining a set of stems for one location
- `audio/string_planet_overworld.tres` — LayerConfig for the overworld

**Architecture:**

`AudioDirector` holds an array of `AudioStreamPlayer` nodes (one per stem) and a `current_config: LayerConfig`. It reads `BeatClock.beat` and applies queued layer changes on the next beat boundary to prevent phasing. It exposes:

```gdscript
func set_config(config: LayerConfig, crossfade_beats: int = 4) -> void
func set_layer_active(layer_name: StringName, active: bool) -> void
func approach_source(source_id: StringName, distance: float) -> void
```

`LayerConfig` resource:
```gdscript
class_name LayerConfig
extends Resource

@export var bpm: float = 120.0
@export var intro_offset_ms: float = 0.0
@export var layers: Array[AudioLayerEntry] = []
```

`AudioLayerEntry` sub-resource:
```gdscript
class_name AudioLayerEntry
extends Resource

@export var layer_name: StringName = &"base"
@export var stream: AudioStream = null
@export var default_active: bool = true
@export var bus: String = "Master"
@export var base_volume_db: float = 0.0
```

**Key design constraint:** All stem transitions happen at beat boundaries (on `BeatClock.beat`). Never crossfade mid-beat. This ensures seamless looping.

**Acceptance criteria:**
- Overworld music plays with a base layer always active
- When Luthier is the only party member, only the Strings stem plays
- Adding a second character activates their stem on the next beat
- Entering a dungeon triggers a 4-beat crossfade to the dungeon version
- Exiting combat resumes the overworld stems without restarting (seamless resume)

---

### Task 11: Scene Transition System

**This is done when:** Moving from overworld to combat back to overworld works without restarting music; the transition uses a brief screen-fade animation timed to BeatClock.

**Files to create:**
- `world/scene_manager.gd` — autoload `SceneManager`
- `world/transition_overlay.tscn` — full-screen fade rect

**Architecture:**

`SceneManager` manages a stack of "active contexts" (overworld, combat, dungeon). Transitions always wait for the current beat to complete before swapping. The `AudioDirector` is paused/resumed rather than stopped.

```gdscript
## Transition to combat without stopping the music.
## On combat_won/combat_lost, call return_from_combat().
func enter_combat(encounter_id: StringName, at_position: Vector2) -> void

## Return to overworld after combat, resuming music from where it left off.
func return_from_combat() -> void
```

**Acceptance criteria:**
- Walking into an encounter zone fades the screen to black over half a beat
- Combat scene appears; overworld music transitions to combat arrangement (add percussion stems)
- On win/loss, screen fades; overworld resumes without skipping or restarting
- The beat counter never resets across transitions (only resets on full game restart)

---

### Task 12: Overworld Scene (String Planet — Dusty Crossroads)

**This is done when:** A top-down 2D area is playable with Luthier Frett walking around; collision with buildings/trees works; the camera follows the player; encounter zones exist.

**Files to create:**
- `overworld/overworld_scene.gd`
- `overworld/overworld_scene.tscn`
- `overworld/player_character.gd`
- `overworld/player_character.tscn`
- `overworld/encounter_zone.gd`
- `overworld/encounter_zone.tscn`

**Player movement:**
```gdscript
# overworld/player_character.gd
extends CharacterBody2D

@export var move_speed: float = 120.0

func _physics_process(delta: float) -> void:
    var direction := Input.get_vector(
        &"ui_left", &"ui_right", &"ui_up", &"ui_down")
    velocity = direction * move_speed
    move_and_slide()
    # Animate: 4-directional sprite, walk cycle synced to BeatClock.half_beat
```

The walk animation steps on `BeatClock.half_beat` to stay musical.

**EncounterZone:**
```gdscript
# overworld/encounter_zone.gd
extends Area2D

@export var encounter_id: StringName = &"goblin_single"
@export var player_first: bool = true
signal triggered(encounter_id: StringName, player_first: bool)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        triggered.emit(encounter_id, player_first)
```

**Acceptance criteria:**
- Arrow keys / WASD move Luthier in 4 directions
- Collision prevents walking through walls and trees
- Camera follows player with slight lookahead in movement direction
- Walking over an encounter zone triggers combat (via SceneManager)
- After combat, Luthier is back in the overworld at the same position

---

### Task 13: World State Manager

**This is done when:** The party's current HP, limit break gauges, and which enemies have been defeated persist across scene transitions within one play session.

**Files to create:**
- `world/world_state.gd` — autoload `WorldState`

**Architecture:**

`WorldState` is a global autoload holding:

```gdscript
var party: Array[CharacterData] = []        # active party members
var defeated_encounters: Array[StringName] = []  # encounter IDs cleared this session
var current_area: StringName = &"crossroads"
```

`EncounterManager.start_combat()` already takes a `party: Array[CharacterData]` — just pass `WorldState.party` from now on.

After combat ends (won), `WorldState.defeated_encounters.append(encounter_id)`. `EncounterZone` checks `WorldState.defeated_encounters` before triggering — cleared enemies don't re-fight.

**Acceptance criteria:**
- Damage taken in combat persists when returning to overworld (HP doesn't reset)
- Defeated encounter zones no longer trigger combat
- Limit break gauges persist between fights (carry into next combat)
- Party HP can be "rested" at a rest point (HP restored to max, gauges reset)

---

### Task 14: Dungeon Scene — The Resonance Cave

**This is done when:** A small indoor area (5–8 rooms) is explorable with locked doors that open after clearing encounters or solving puzzles.

**Files to create:**
- `dungeon/dungeon_scene.gd`
- `dungeon/dungeon_scene.tscn`
- `dungeon/door.gd` — locked door node
- `dungeon/door.tscn`

**Architecture:**

The dungeon is a single large tilemap scene with door nodes. Each door has an `unlock_condition: StringName` that references either an encounter ID (`&"goblin_single"`) or a puzzle ID (`&"resonance_puzzle_1"`). Doors check `WorldState.defeated_encounters` on ready and on the global `WorldState.encounter_cleared` signal.

**Acceptance criteria:**
- Player enters dungeon through an overworld door
- Music transitions to dungeon arrangement (same BPM, fewer stems)
- Combat encounters inside the dungeon function identically to overworld encounters
- Completing all encounters in a room unlocks the door to the next room
- Reaching the final room triggers the boss encounter

---

### Task 15: Musical Puzzle System

**This is done when:** One puzzle exists where the player must press arrow keys in a specific rhythmic sequence (a musical phrase) to unlock a door; the puzzle plays back each note pressed as a sound and shows a visual sequence.

**Files to create:**
- `dungeon/musical_puzzle.gd`
- `dungeon/musical_puzzle.tscn`

**Architecture:**

The puzzle defines a target sequence (e.g. `[&"up", &"up", &"right", &"down"]`) timed to BeatClock beats. The player presses directions in order; each press plays a note through `AudioFeedback`'s pitch system. The puzzle tracks:

1. **Presentation phase:** The target sequence plays automatically (one note per beat), showing lit-up arrows.
2. **Input phase:** Player repeats the sequence; `RhythmInput.input_scored` is captured, matched against the target.
3. **Success:** All notes matched in order (direction + approximate timing) → door unlocks.
4. **Failure:** Wrong direction or too late → sequence restarts from beginning.

```gdscript
# dungeon/musical_puzzle.gd
class_name MusicalPuzzle
extends Node

@export var target_sequence: Array[StringName] = [&"up", &"right", &"down", &"left"]
@export var beats_per_note: int = 1

signal puzzle_solved()
signal puzzle_failed()

enum State { PRESENTING, WAITING_INPUT, SOLVED }
var _state: State = State.PRESENTING
var _current_index: int = 0
```

**Acceptance criteria:**
- Player can see and hear the sequence they need to repeat
- Pressing the right directions in the right order triggers success animation and unlocks door
- Wrong press resets with a visual/audio "wrong" indicator
- The sequence is musically satisfying — it should sound like a short melody

---

### Task 16: Boss Encounter — The String Warden

**This is done when:** A boss fight exists with two distinct phases (normal attack → enrage at 50% HP), a unique 16-beat defend pattern, a pre-fight cutscene line, and a post-fight reward.

**Files to create:**
- `combat/boss_phase.gd` — extends CombatScene behavior for phase transitions at HP thresholds
- `characters/string_warden.tres` — EnemyData resource

**Architecture:**

`BossPhase` is a node added as a child to the boss's CombatScene. It connects to `phase_changed` and monitors enemy HP. When the boss hits 50% HP during an ATTACK phase, it emits `boss_enraged`, which:
- Increases enemy `attack_power` by 50%
- Changes the enemy pattern to a denser 16-beat sequence
- Triggers a screen flash and audio stem change

```gdscript
# combat/boss_phase.gd
extends Node

signal boss_enraged(enemy: EnemyData)

@export var enrage_threshold: float = 0.5
var _enraged: bool = false
var _combat: Node
var _boss_enemy: EnemyData

func setup(combat: Node, boss: EnemyData) -> void:
    _combat = combat
    _boss_enemy = boss
    combat.phase_changed.connect(_check_enrage)

func _check_enrage(_phase: int) -> void:
    if _enraged:
        return
    if float(_boss_enemy.hp) / float(_boss_enemy.max_hp) <= enrage_threshold:
        _enraged = true
        _boss_enemy.attack_power = int(_boss_enemy.attack_power * 1.5)
        # Swap to harder pattern — defined inline here
        _boss_enemy.pattern = _make_enraged_pattern()
        _boss_enemy.phase_length = 16
        boss_enraged.emit(_boss_enemy)

static func _make_enraged_pattern() -> Array[NoteData]:
    # 16 beats, every beat is targeted, cycling through all four directions twice
    var dirs: Array[StringName] = [&"up", &"right", &"down", &"left",
                                    &"up", &"right", &"down", &"left",
                                    &"right", &"up", &"left", &"down",
                                    &"right", &"up", &"left", &"down"]
    var notes: Array[NoteData] = []
    for i in range(16):
        var n := NoteData.new()
        n.beat_offset = i; n.direction = dirs[i]; n.mode = &"targeted"
        notes.append(n)
    return notes
```

**Acceptance criteria:**
- Boss fight starts with a 4-beat intro "pre-pattern" (all free-form, establishes rhythm)
- Boss HP bar has a distinct color from regular enemies
- At 50% HP, screen flashes, music intensity increases (add percussion stems via AudioDirector)
- New 16-beat pattern is significantly harder — player must use limit break to survive
- On win: cutscene dialogue triggers, area unlocks

---

### Task 17: String Planet Audio Pass

**This is done when:** All in-game audio is from real (or near-real) string/banjo instruments; the overworld track has at least 3 stem layers; combat music is a re-arrangement of the same theme; all SFX use plucked string sounds.

**Audio asset list to acquire or create:**

| File | Description |
|---|---|
| `audio/overworld_base.ogg` | Solo banjo/lute rhythm loop, 8 bars at target BPM |
| `audio/overworld_melody.ogg` | Lute melody over the same progression |
| `audio/overworld_rhythm.ogg` | Acoustic guitar strumming layer |
| `audio/combat_base.ogg` | Same chord progression, more urgent tempo feel |
| `audio/combat_percussion.ogg` | Stomp/body-tap percussion stem |
| `audio/dungeon_base.ogg` | Stripped version (single lute, minor mode) |
| `audio/boss_base.ogg` | Full arrangement with drone |
| `audio/boss_enrage.ogg` | Additional high-energy layer for enrage phase |
| `audio/sfx/hit_perfect.ogg` | Bright banjo pluck, mid pitch |
| `audio/sfx/hit_good.ogg` | Softer banjo pluck |
| `audio/sfx/hit_miss.ogg` | Muted string slap |
| `audio/sfx/level_up.ogg` | Ascending banjo flourish |
| `audio/sfx/door_unlock.ogg` | String harmonic chime |

**BPM sync requirement:** All looping tracks must be exactly `N * beat_duration` long so they loop without BeatClock drift. At 120 BPM, 8 bars = 32 beats = 16 seconds exactly.

**Acceptance criteria:**
- All music is diegetic (comes from visible sources in the world — musician NPCs, instruments in scenes)
- Walking toward a musician NPC increases volume (use `AudioStreamPlayer2D` with `max_distance` = approach range)
- Combat music is the same theme as overworld, not a different track
- Every SFX is made from a real instrument sound, not a synthesized beep

---

### Task 18: String Planet Art Pass

**This is done when:** The vertical slice has consistent placeholder art that communicates the String planet aesthetic; a publisher can watch a 5-minute playthrough and understand the visual direction.

**Asset requirements:**

| Asset | Format | Description |
|---|---|---|
| Luthier Frett sprite | 4-direction walk cycle, 4 frames each | Rural traveler, worn lute on back |
| Goblin enemy sprite | Idle + attack animations | Small, stringy (visual pun) |
| String Warden boss sprite | Large, multi-frame | Musical guardian entity |
| Overworld tileset | 16×16 or 32×32 tiles | Dusty crossroads, ring-shaped horizon |
| Dungeon tileset | 16×16 tiles | Cave with crystalline string formations |
| UI skin | Panel backgrounds, bar frames | Warm wood grain aesthetic |
| Combat stage background | 640×360 bg image | Performance stage with planet ring silhouette |

**Godot-specific notes:**
- Use `AnimatedSprite2D` for character animations with named animation states (`"walk_up"`, `"walk_down"`, etc.)
- `CharacterBody2D` for player + `CollisionShape2D` (capsule, not rectangle — prevents corner-catching)
- All sprites use `Nearest` texture filter (pixel art) set via `Project → Rendering → Textures → Default Texture Filter`

**Acceptance criteria:**
- Each element has a consistent aesthetic language (warm, folk, hand-drawn feel)
- An animation plays when notes are hit (Luthier plays a strum on perfect)
- The HP bars use the "volume slider" visual metaphor from the design doc
- Overworld environment has a sense of place — the ring in the sky, distant mountains, a dusty road

---

### Task 19: Vertical Slice Integration + Polish Pass

**This is done when:** The complete vertical slice plays from start (overworld) through dungeon to boss fight; all transitions are seamless; audio never restarts; a first-time player can complete it in 15–20 minutes.

**Polish items:**

- [ ] Title card on launch — just the logo and "Press any key" for 1 second
- [ ] Save/load: serialize `WorldState` to `user://save.dat` using `ResourceSaver` (Godot built-in)
- [ ] Settings: audio volume sliders for Music/SFX; optional input remapping
- [ ] Feedback juicing: screen shake on boss hits (use `Camera2D.offset` tween); particle burst on perfect notes
- [ ] Game-over screen: "The Silence falls..." with restart option
- [ ] Victory screen: short fanfare + "String Planet liberated!" title card

**Performance targets:**
- Stable 60fps on a mid-range 2020 PC at 1080p GL Compatibility renderer
- Audio latency < 50ms (achievable with careful AudioServer buffer tuning)
- No frame drops during beat signal emission (profile `_process` in BeatClock; it must be < 1ms)

**Acceptance criteria (publisher demo):**
- [ ] The game boots in < 5 seconds and reaches the title card
- [ ] All audio is diegetic and musical
- [ ] The rhythm combat loop can be understood in one fight without tutorial text
- [ ] The boss fight requires engagement with all systems (blocking, attacking, limit break)
- [ ] The game can be completed in one sitting (15–20 min)
- [ ] No crashes or visible errors during a full playthrough

---

## Architecture Recommendations

These decisions should be locked in **now**, before implementing Phase 2 or 3, to avoid painful refactors later.

### 1. BeatClock is a clock, not a game master

`BeatClock` should remain a pure timing utility with no game logic. Never add combat-aware methods to it. Any system that needs "beat N from now" should do that math locally using `BeatClock.beat_number` and `BeatClock.bpm`.

Rationale: The BeatClock will eventually need to transition between tempos (boss fight BPM change, slow-mo on perfect), change BPM mid-track, or pause. Keeping it clean makes these changes safe.

### 2. Every audio transition must be beat-locked

This is the rule that makes the music feel diegetic. Never call `stream_player.play()` at an arbitrary frame. Always queue audio changes to fire on `BeatClock.beat`. The `AudioDirector` enforces this with a "pending changes" queue that flushes on each beat signal.

If you add a combat-start transition that feels wrong, the bug is almost always "transition triggered mid-beat."

### 3. Design CharacterData as a mutable game-state object, not a data template

The current `CharacterData.hp` is mutable, which is correct. When you add save/load (Task 13), serialize `WorldState.party` directly. Do **not** create separate "save data" vs "runtime data" versions of CharacterData — that duplication is where sync bugs live.

However: `.tres` resource files in the editor are **shared references** by default. Loading `luthier_frett.tres` directly gives you the same resource object every time. If you mutate `.hp` on that object, it affects the resource file on save. Protect against this with:

```gdscript
# Always duplicate the resource when starting a new game session:
_hero = load("res://characters/luthier_frett.tres").duplicate(true) as CharacterData
```

The `true` parameter on `duplicate()` recursively duplicates sub-resources (including `SoloStyle`).

### 4. Enemy patterns should become .tres resources, not inline constructors

`EncounterManager`'s inline `_make_goblin()` constructors are fine for the prototype, but they'll be painful to balance. Before building the vertical slice encounters, convert each enemy to a `.tres` file:

```
characters/enemies/goblin.tres
characters/enemies/orc.tres
characters/enemies/string_golem.tres
characters/enemies/string_warden.tres
```

Then `EncounterManager._generate_enemies()` becomes a simple `load("res://characters/enemies/%s.tres" % encounter_id)` call. This lets you balance enemies in the Godot editor without touching code.

### 5. The note pattern format should support fractional beats before vertical slice

The current `NoteData.beat_offset: int` only supports whole-beat patterns. Before building Boss phase 2's dense 16-beat pattern, promote `beat_offset` to `float`:

```gdscript
@export var beat_offset: float = 0.0
```

Half-beat notes (`beat_offset = 0.5`) add syncopation critical for the drum planet. Changing this late means rewriting all pattern injection logic in `CombatScene._on_beat`. Change it now while there are only 3 enemy patterns.

Also update the beat injection check:

```gdscript
# Instead of: if note.beat_offset == beat_index
# Use: if abs(note.beat_offset - float(beat_index)) < 0.01
```

### 6. Plan the AudioBus layout now

In `Project → Audio`, create this bus hierarchy before Phase 3:

```
Master
├── Music          (volume control, music reverb send)
│   ├── Strings    (for Luthier's lute sounds)
│   ├── Drums      (for Beatrice's percussion — future)
│   └── Winds      (for Reed's flute — future)
└── SFX            (volume control, dry)
    ├── Hit        (combat feedback sounds)
    └── UI         (menu clicks, etc.)
```

Each character's `SoloStyle.audio_bus` routes to their instrument sub-bus. The Music bus has a global compressor/limiter to prevent clipping when all stems play. SFX is separate so music ducking doesn't affect combat feedback.

### 7. Build the save system around `WorldState` only

The typical mistake is saving every node's state. For Song of the Stars, all meaningful state lives in:
- `WorldState.party` (array of CharacterData — HP, gauge, unlocks)
- `WorldState.defeated_encounters` (which fights are done)
- `WorldState.current_area` (where to resume)
- Player position (Vector2)

Use `ResourceSaver.save("user://save.dat", world_state)` where `WorldState extends Resource`. This gives you free serialization to JSON-friendly format with no custom parser.

---

## Godot 4 Risks & Mitigations

### Risk 1: Audio latency varies 50–150ms across platforms and drivers

**Symptom:** On some machines, "perfect" hits feel late or early even though the AudioServer compensation code is correct. The hardware output latency (`AudioServer.get_output_latency()`) may report 80ms on Windows WASAPI but 20ms on Windows ASIO.

**Mitigation:** Add a calibration screen. Allow the player to adjust an `input_offset_ms` bias in Settings that shifts the `BeatClock.get_offset_ms()` return value globally. Implement this in `BeatClock.get_offset_ms()`:

```gdscript
@export var input_offset_ms: float = 0.0   # user-adjustable calibration bias

func get_offset_ms() -> float:
    # ... existing calculation ...
    return raw_offset + input_offset_ms
```

Many commercial rhythm games offer a "tap to calibrate" screen that measures the round-trip audio delay.

### Risk 2: Frame rate affects beat detection precision

**Symptom:** At 30fps, `_process` runs every 33ms. A beat crossing can be detected up to 33ms late. For `perfect_ms = 50`, this eats 66% of the window before the player even presses.

**Mitigation:**
- Set `Engine.max_fps = 0` in `project.godot` to run uncapped: `ProjectSettings.set("application/run/max_fps", 0)`
- Beat detection should use audio-corrected position (already done) — the precision of *detection* is fine; the input scoring window can tolerate the frame lag because `RhythmInput._unhandled_input` is called immediately on the input event (not on the next frame)
- Minimum spec should be 60fps. Consider adding a warning if `Engine.get_frames_per_second() < 55`

### Risk 3: `class_name` global scope resolves after autoloads

**Symptom (already mitigated):** Typed arrays like `Array[NoteData]` in autoload scripts cause parse errors because `NoteData`'s `class_name` isn't in global scope when the autoload parses.

**Current mitigation:** The codebase already uses `const NoteData = preload(...)` and untyped `Array` in autoloads. This is correct. **Keep this pattern** — don't "fix" it by removing the preload. This is a known Godot 4.x limitation that may improve in future versions.

**Rule of thumb:** In any autoload script, use `preload()` constants for all cross-file types; in scene scripts (which load after autoloads), `class_name` types work fine.

### Risk 4: Resource sharing mutates shared .tres files

**Symptom:** You edit Luthier's HP in combat, then the `.tres` file on disk shows 0 HP.

**Mitigation:** Always `duplicate(true)` loaded character resources before use (covered in Architecture Recommendations #3). Add this as a project coding rule.

Corollary: Enemy patterns in EnemyData use `Array[NoteData]`. If you create NoteData objects in `_make_goblin()` using `NoteData.new()` inline (as EncounterManager currently does), they are fresh each call. This is safe. When you switch to `.tres` loading, the same `duplicate(true)` rule applies.

### Risk 5: `create_tween()` timing drifts from audio time

**Symptom:** Note visuals arrive at the hit zone a few frames early or late because Tween uses engine time (`delta` accumulation) while `BeatClock` uses audio time.

**Mitigation:** This drift is typically < 20ms per beat and is not perceptible. However, for critical timing (e.g. a note that must hit *exactly* on beat), calculate the tween duration not from a fixed constant but from the remaining time to the target beat:

```gdscript
# Instead of: travel_time = lookahead_beats * (60.0 / BeatClock.bpm)
# Use audio-corrected remaining time:
var beats_remaining: float = float(lookahead_beats) - BeatClock.beat_position
var travel_time: float = beats_remaining * (60.0 / BeatClock.bpm)
```

This recalculates the travel time accounting for the current position within the beat, so notes spawned mid-beat still arrive on time.

### Risk 6: Signal connections from combat scenes persist across reloads

**Symptom:** After combat ends and the scene is freed, old signal connections to `BeatClock` or `RhythmInput` from the freed node fire a one-frame garbage error.

**Mitigation:** The existing `teardown()` and `_exit_tree()` pattern correctly handles this. Maintain the pattern in all new scenes: disconnect all autoload signals in `_exit_tree`. Never rely on garbage collection to clean up signal connections.

### Risk 7: AudioStreamPlayer seeks on `play()` losing loop sync

**Symptom:** When returning from combat to overworld, calling `audio_player.play()` restarts the track from 0 instead of resuming. BeatClock drifts because `get_playback_position()` resets.

**Mitigation:** Never call `play()` on the overworld track when resuming from combat. Instead, call `pause()` / `resume()` (not available directly — use `stream_player.stream_paused = true/false`). Or: keep the overworld `AudioStreamPlayer` in a persistent "world audio" scene that is never freed during combat. Add combat audio as a separate player that stops and frees after combat; the world audio plays continuously underneath.

### Risk 8: Godot 4 tilemaps have performance issues with large maps

**Symptom:** Overworld scenes with large TileMap layers can have significant _process overhead and stuttering, especially with physics layers enabled.

**Mitigation:**
- Use a single `TileMap` node with separate layers for ground, decoration, and collision (not multiple TileMap nodes)
- Enable `TileMap.use_parent_material = false` and `TileMap.rendering_quadrant_size = 16` for chunking
- Use `NavigationRegion2D` for pathfinding (NPC AI in vertical slice) rather than per-tile collision bodies
- Keep the overworld area small (one screen's worth of rooms) for the vertical slice

### Risk 9: Console export requires additional AudioServer tuning

**Symptom:** Audio latency on Switch or PS5 differs significantly from PC. The `input_offset_ms` calibration system from Risk 1 is required.

**Mitigation:** Plan for platform-specific default `input_offset_ms` values:
- Windows WASAPI: ~0ms calibration offset
- Windows DirectSound: ~15ms
- macOS Core Audio: ~5ms
- Linux PulseAudio: ~20–40ms
- Console: test individually

Gather these values from your target platforms during the vertical slice testing phase.

---

## Estimated Timeline

| Phase | Tasks | Estimated Duration |
|---|---|---|
| Phase 1: Foundation Hardening | 1–2 | 1 day |
| Phase 2: Combat Prototype | 3–9 | 5–7 days |
| **Publisher Demo Checkpoint** | — | End of Task 9 |
| Phase 3: Vertical Slice | 10–19 | 6–8 weeks |
| Total | 19 tasks | ~9 weeks |

---

*Plan saved: 2026-05-26. Next review checkpoint: end of Task 9 (prototype complete).*
