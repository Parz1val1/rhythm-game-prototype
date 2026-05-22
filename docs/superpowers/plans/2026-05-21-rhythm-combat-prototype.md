# Rhythm Combat Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold a Godot 4.6 GDScript rhythm RPG prototype with a BeatClock autoload, RhythmInput autoload, and a CombatScene that validates the beat-timed attack/defend loop with multiple enemies.

**Architecture:** Two global autoloads (`BeatClock`, `RhythmInput`) provide timing and input scoring to a scene-local `CombatScene` orchestrator. Combat phases (ATTACK/DEFEND) alternate on a fixed beat schedule; each enemy carries its own repeating note pattern. `EncounterManager` is a static helper that generates enemy parties and instantiates `CombatScene`.

**Tech Stack:** Godot 4.6, GDScript, AudioServer timing API, Godot Resource system, Godot Input Map.

---

## File Map

| File | Role |
|---|---|
| `project.godot` | Modified: add autoloads + input actions + main scene |
| `autoloads/beat_clock.gd` | Global beat timer, AudioServer-synced |
| `autoloads/rhythm_input.gd` | Input capture, hybrid timing scorer, note lifecycle |
| `rhythm_engine/note_data.gd` | Resource: single note in an enemy pattern |
| `characters/character_data.gd` | Resource: player character stats |
| `characters/enemy_data.gd` | Resource: enemy stats + repeating pattern |
| `combat/encounter_manager.gd` | Static helper: generates enemy party, loads CombatScene |
| `combat/combat_scene.gd` | Scene script: phases, damage, win/loss |
| `combat/combat_scene.tscn` | Bare Node scene with combat_scene.gd attached |
| `test/test_scoring.gd` | Headless test script: verifies scoring thresholds |
| `test_scene.gd` | Main test scene script: debug labels, wires signals |
| `test_scene.tscn` | Main scene: AudioStreamPlayer + CanvasLayer debug UI |

---

## Task 1: Project Scaffolding

**Files:**
- Modify: `project.godot`
- Create directories: `autoloads/`, `combat/`, `characters/`, `rhythm_engine/`, `audio/`, `ui/`, `test/`

- [ ] **Step 1: Create directory structure**

From the project root, create the following empty `.gitkeep` files to establish the folder layout (Godot tracks directories that contain files):

```
autoloads/.gitkeep
combat/.gitkeep
characters/.gitkeep
rhythm_engine/.gitkeep
audio/.gitkeep
ui/.gitkeep
test/.gitkeep
```

Run in project root:
```bash
mkdir -p autoloads combat characters rhythm_engine audio ui test
touch autoloads/.gitkeep combat/.gitkeep characters/.gitkeep rhythm_engine/.gitkeep audio/.gitkeep ui/.gitkeep test/.gitkeep
```

- [ ] **Step 2: Add autoloads and input actions to project.godot**

Open `project.godot` and append the following sections (place each section after any existing content, before the final newline). Do not duplicate existing section headers.

```ini
[autoload]

BeatClock="*res://autoloads/beat_clock.gd"
RhythmInput="*res://autoloads/rhythm_input.gd"

[input]

rhythm_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
rhythm_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
rhythm_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
rhythm_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Input actions use arrow keys (Up=4194320, Down=4194322, Left=4194319, Right=4194321). These can be rebound later in Project → Input Map.

The main scene will be set in Task 7 once `test_scene.tscn` exists.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat: scaffold project structure and configure autoloads + input map"
```

---

## Task 2: Data Resources

**Files:**
- Create: `rhythm_engine/note_data.gd`
- Create: `characters/character_data.gd`
- Create: `characters/enemy_data.gd`

These are pure data containers — no logic, no nodes. `class_name` lets Godot register them as typed resources that can be used with `Array[NoteData]` etc. throughout the project.

- [ ] **Step 1: Create NoteData**

```gdscript
# rhythm_engine/note_data.gd
class_name NoteData
extends Resource

## Which beat within the repeating pattern this note fires on (0-indexed, whole beats only).
## E.g. beat_offset=2 fires on beat index 2 of a 4-beat pattern.
## Stored as int because patterns fire on whole beats in this prototype.
## Promote to float when half-beat notes are needed.
@export var beat_offset: int = 0

## Direction the player must press. One of: &"up", &"down", &"left", &"right"
@export var direction: StringName = &"up"

## Scoring mode for this note.
## &"free_form" — any press near the beat counts regardless of direction.
## &"targeted"  — player must press the matching direction within the timing window.
@export var mode: StringName = &"free_form"
```

- [ ] **Step 2: Create CharacterData**

```gdscript
# characters/character_data.gd
class_name CharacterData
extends Resource

## Display name shown in the UI.
@export var character_name: String = ""

@export var max_hp: int = 100
@export var hp: int = 100

## Base damage dealt to the current enemy on a Perfect hit during the ATTACK phase.
## Good hits deal attack_power * 0.5 (rounded down). Misses deal 0.
@export var attack_power: int = 10
```

- [ ] **Step 3: Create EnemyData**

```gdscript
# characters/enemy_data.gd
class_name EnemyData
extends Resource

## Display name shown in the UI.
@export var enemy_name: String = ""

@export var max_hp: int = 50
@export var hp: int = 50

## Damage dealt to the active player character per missed note during the DEFEND phase.
## Good blocks reduce damage by 50%. Perfect blocks deal 0 damage.
@export var attack_power: int = 8

## The repeating sequence of notes this enemy emits during its DEFEND phase.
## beat_offset values must be in range [0, phase_length - 1].
@export var pattern: Array[NoteData] = []

## How many beats this enemy's DEFEND phase lasts before cycling back.
@export var phase_length: int = 4
```

- [ ] **Step 4: Commit**

```bash
git add rhythm_engine/note_data.gd characters/character_data.gd characters/enemy_data.gd
git commit -m "feat: add NoteData, CharacterData, EnemyData resources"
```

---

## Task 3: BeatClock Autoload

**Files:**
- Create: `autoloads/beat_clock.gd`

`BeatClock` is the timing foundation. Everything else reacts to its signals. It uses the AudioServer's true perceived playback position (not engine time) to keep input scoring aligned with what the player hears.

- [ ] **Step 1: Write beat_clock.gd**

```gdscript
# autoloads/beat_clock.gd
# Registered as autoload "BeatClock" in project.godot.
# This node is added to the scene tree automatically before any other scene loads.
# Access it from any script as: BeatClock.bpm, BeatClock.beat, etc.
extends Node

# --- Signals ---
# In Godot, signals are the idiomatic way to notify other systems of events
# without creating hard dependencies. Connect to these from CombatScene or UI.

## Fires once per beat. beat_number increments from 0 at start().
signal beat(beat_number: int)
## Fires at the midpoint of each beat (beat_position == 0.5).
signal half_beat(beat_number: int)
## Fires at beat_position 0.25 and 0.75.
signal quarter_beat(beat_number: int)

# --- Public state ---

## Beats per minute. Change at runtime to affect tempo immediately.
@export var bpm: float = 120.0

## Current beat index since start() was called. Increments on each beat signal.
var beat_number: int = 0

## Fractional position within the current beat: 0.0 (on the beat) → 1.0 (next beat).
var beat_position: float = 0.0

# --- Private state ---

var _stream_player: AudioStreamPlayer = null
var _running: bool = false
var _prev_beat_position: float = 0.0
var _seconds_per_beat: float = 0.5   # 60.0 / bpm, updated in start()
var _start_ticks_ms: int = 0          # fallback origin when no audio stream

# --- Public API ---

## Anchor BeatClock to an AudioStreamPlayer and begin emitting beat signals.
## Call this after audio_player.play() in your scene's _ready().
## stream_player may have no stream set; BeatClock will fall back to wall-clock time
## (less accurate but still functional for prototyping without audio files).
func start(stream_player: AudioStreamPlayer) -> void:
    _stream_player = stream_player
    _seconds_per_beat = 60.0 / bpm
    _running = true
    beat_number = 0
    beat_position = 0.0
    _prev_beat_position = 0.0
    _start_ticks_ms = Time.get_ticks_msec()

## Stop emitting beat signals. Call on combat end or scene transition.
func stop() -> void:
    _running = false
    _stream_player = null

## Returns how far (in milliseconds) the current moment is from the nearest beat.
## Negative  = player pressed early (before the beat).
## Positive  = player pressed late (after the beat).
## Zero      = perfect timing.
## Used by RhythmInput on every keypress to produce a timing score.
func get_offset_ms() -> float:
    if not _running:
        return 0.0
    # beat_position <= 0.5: we're closer to the current beat (positive = late)
    # beat_position >  0.5: we're closer to the next beat (negative = early)
    if beat_position <= 0.5:
        return beat_position * _seconds_per_beat * 1000.0
    else:
        return (beat_position - 1.0) * _seconds_per_beat * 1000.0

# --- Internal ---

func _process(_delta: float) -> void:
    if not _running:
        return

    # --- Why AudioServer timing? ---
    # Godot's audio subsystem runs on its own thread with a hardware output buffer.
    # The player hears audio 50–120ms AFTER the engine schedules it.
    # AudioServer.get_time_since_last_mix() gives the time since the audio thread
    # last mixed a buffer. AudioServer.get_output_latency() gives the hardware delay.
    # Together with get_playback_position() they yield the stream's true perceived
    # position — what the player actually hears right now — not what the engine
    # computed some frames ago. Without this correction, beat_position would be
    # systematically ahead of the audio, making "on the beat" presses score as early.

    var audio_time: float
    if _stream_player != null and _stream_player.playing:
        # Audio-corrected perceived playback position:
        audio_time = (
            _stream_player.get_playback_position()
            + AudioServer.get_time_since_last_mix()
            - AudioServer.get_output_latency()
        )
    else:
        # Fallback: wall-clock time since start() (no audio sync, but functional).
        audio_time = float(Time.get_ticks_msec() - _start_ticks_ms) / 1000.0

    _seconds_per_beat = 60.0 / bpm  # support live BPM changes
    var total_beats: float = audio_time / _seconds_per_beat
    var new_beat_number: int = int(total_beats)
    var new_beat_position: float = fmod(total_beats, 1.0)

    # Beat crossing — emit once per beat boundary.
    if new_beat_number > beat_number:
        beat_number = new_beat_number
        beat.emit(beat_number)

    # Half-beat crossing (position crosses 0.5 within the same beat).
    if _prev_beat_position < 0.5 and new_beat_position >= 0.5:
        half_beat.emit(beat_number)

    # Quarter-beat crossings (0.25 and 0.75).
    if _prev_beat_position < 0.25 and new_beat_position >= 0.25:
        quarter_beat.emit(beat_number)
    if _prev_beat_position < 0.75 and new_beat_position >= 0.75:
        quarter_beat.emit(beat_number)

    _prev_beat_position = new_beat_position
    beat_position = new_beat_position
```

- [ ] **Step 2: Commit**

```bash
git add autoloads/beat_clock.gd
git commit -m "feat: add BeatClock autoload with AudioServer timing"
```

---

## Task 4: RhythmInput Autoload + Scoring Test

**Files:**
- Create: `autoloads/rhythm_input.gd`
- Create: `test/test_scoring.gd`

`RhythmInput` has two jobs: (1) capture the four directional actions and score them against the nearest beat; (2) manage the lifecycle of active targeted notes, emitting `note_missed` when they expire. The scoring logic is exposed as a public method (`score_timing`) so it can be verified in isolation.

- [ ] **Step 1: Write the scoring test first**

```gdscript
# test/test_scoring.gd
# Headless verification for the score_timing() thresholds.
# Run with: godot --headless --path . -s res://test/test_scoring.gd
# Autoloads ARE active when launched with --path, so RhythmInput is available.
extends SceneTree

func _init() -> void:
    await process_frame   # let autoloads initialize
    _run()
    quit()

func _run() -> void:
    print("=== score_timing() tests ===")
    # Default thresholds: perfect_ms=50, good_ms=120
    _check("exact beat",       RhythmInput.score_timing(0.0),   &"perfect")
    _check("perfect boundary", RhythmInput.score_timing(50.0),  &"perfect")
    _check("just over perfect",RhythmInput.score_timing(50.1),  &"good")
    _check("good mid",         RhythmInput.score_timing(85.0),  &"good")
    _check("good boundary",    RhythmInput.score_timing(120.0), &"good")
    _check("just over good",   RhythmInput.score_timing(120.1), &"miss")
    _check("clear miss",       RhythmInput.score_timing(200.0), &"miss")
    print("=== done ===")

func _check(label: String, got: StringName, expected: StringName) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
```

- [ ] **Step 2: Write rhythm_input.gd**

```gdscript
# autoloads/rhythm_input.gd
# Registered as autoload "RhythmInput" in project.godot.
# Receives input events before any scene node because autoloads sit at the top
# of the scene tree. _unhandled_input fires only for events not consumed by UI.
extends Node

# --- Signals ---

## Emitted on every scored directional press.
## direction: &"up" / &"down" / &"left" / &"right"
## score:     &"perfect" / &"good" / &"miss"
## offset_ms: signed ms from nearest beat (negative=early, positive=late)
signal input_scored(direction: StringName, score: StringName, offset_ms: float)

## Emitted when a targeted note expires without a matching press.
## CombatScene listens to this to apply full defend-phase damage.
signal note_missed(note: NoteData)

# --- Configurable thresholds ---

## Absolute offset ≤ perfect_ms scores as "perfect".
@export var perfect_ms: float = 50.0

## Absolute offset ≤ good_ms scores as "good". Beyond this = "miss".
@export var good_ms: float = 120.0

# --- Active note queue ---

## Targeted notes currently in the scoring window.
## Populated by CombatScene via add_note(). Expired notes emit note_missed.
var active_notes: Array[NoteData] = []

## Parallel array: the Time.get_ticks_msec() value when each note was injected.
## Used to detect expiry without modifying NoteData.
var _note_inject_times: Array[int] = []

# --- Public API ---

## Score an absolute timing offset against the configured thresholds.
## abs_offset_ms must be >= 0 (pass abs(BeatClock.get_offset_ms())).
## Returns &"perfect", &"good", or &"miss".
## Public (no underscore) so test/test_scoring.gd can call it directly.
func score_timing(abs_offset_ms: float) -> StringName:
    if abs_offset_ms <= perfect_ms:
        return &"perfect"
    elif abs_offset_ms <= good_ms:
        return &"good"
    else:
        return &"miss"

## Inject a note into the active window. Called by CombatScene on each beat signal.
## Records the injection timestamp for expiry checking — NoteData is not mutated.
func add_note(note: NoteData) -> void:
    active_notes.append(note)
    _note_inject_times.append(Time.get_ticks_msec())

## Flush all active notes without scoring. Call at phase transitions.
func clear_notes() -> void:
    active_notes.clear()
    _note_inject_times.clear()

# --- Input handling ---

## Called by Godot for every InputEvent not consumed by a UI control.
## Scores the press against active targeted notes first (hybrid model), then
## falls back to free-form beat scoring if no targeted note matches.
func _unhandled_input(event: InputEvent) -> void:
    var direction := _get_direction(event)
    if direction == &"":
        return

    # Mark as handled so no other node processes this rhythm input.
    get_viewport().set_input_as_handled()

    var offset_ms: float = BeatClock.get_offset_ms()
    var abs_offset: float = abs(offset_ms)

    # --- Hybrid scoring: targeted note takes priority over free-form ---
    # Search active_notes in reverse so removal by index is safe.
    for i in range(active_notes.size() - 1, -1, -1):
        var note: NoteData = active_notes[i]
        if note.mode == &"targeted" and note.direction == direction:
            # Found a matching targeted note — score it and remove from queue.
            var score: StringName = score_timing(abs_offset)
            active_notes.remove_at(i)
            _note_inject_times.remove_at(i)
            input_scored.emit(direction, score, offset_ms)
            return

    # No matching targeted note — treat as free-form beat press.
    var score: StringName = score_timing(abs_offset)
    input_scored.emit(direction, score, offset_ms)

# --- Note expiry ---

## Each frame, check whether any targeted note's timing window has closed.
## A note expires when more than good_ms has elapsed since it was injected.
func _process(_delta: float) -> void:
    var now: int = Time.get_ticks_msec()
    # Iterate in reverse so removal by index doesn't skip entries.
    for i in range(active_notes.size() - 1, -1, -1):
        if active_notes[i].mode != &"targeted":
            continue
        var age_ms: float = float(now - _note_inject_times[i])
        if age_ms > good_ms:
            var expired: NoteData = active_notes[i]
            active_notes.remove_at(i)
            _note_inject_times.remove_at(i)
            note_missed.emit(expired)

# --- Helpers ---

func _get_direction(event: InputEvent) -> StringName:
    # is_action_pressed() returns true only on the initial press, not hold.
    if event.is_action_pressed(&"rhythm_up"):    return &"up"
    if event.is_action_pressed(&"rhythm_down"):  return &"down"
    if event.is_action_pressed(&"rhythm_left"):  return &"left"
    if event.is_action_pressed(&"rhythm_right"): return &"right"
    return &""
```

- [ ] **Step 3: Run the scoring test**

```bash
godot --headless --path . -s res://test/test_scoring.gd
```

Expected output:
```
=== score_timing() tests ===
  PASS  exact beat
  PASS  perfect boundary
  PASS  just over perfect
  PASS  good mid
  PASS  good boundary
  PASS  just over good
  PASS  clear miss
=== done ===
```

If any line shows `FAIL`, check `perfect_ms` and `good_ms` defaults in `rhythm_input.gd` — the thresholds use `<=` (inclusive boundaries).

- [ ] **Step 4: Commit**

```bash
git add autoloads/rhythm_input.gd test/test_scoring.gd
git commit -m "feat: add RhythmInput autoload and scoring threshold test"
```

---

## Task 5: EncounterManager

**Files:**
- Create: `combat/encounter_manager.gd`

Static helper — no node required. Defines three prototype encounters with distinct enemy patterns to test multi-enemy phase cycling.

- [ ] **Step 1: Write encounter_manager.gd**

```gdscript
# combat/encounter_manager.gd
# Static helper — instantiate nothing, just call EncounterManager.start_combat().
# "Static" here means all methods use the `static` keyword; the class itself is
# not instantiated. In Godot 4, static methods on a non-node class are called
# as EncounterManager.method_name() after preloading or via class_name lookup.
class_name EncounterManager

## Load and initialize a CombatScene from an encounter definition.
##
## tree:         The active SceneTree (pass get_tree() from your calling scene).
## player_party: Array of CharacterData representing the player's current party.
## encounter_id: StringName key for the enemy configuration (see _generate_enemies).
## player_first: true = players attack first (surprise); false = enemies first (ambush).
##
## Returns the instantiated CombatScene node so the caller can connect to
## combat_won / combat_lost signals before the first beat fires.
static func start_combat(
    tree: SceneTree,
    player_party: Array[CharacterData],
    encounter_id: StringName,
    player_first: bool = true
) -> Node:
    var enemy_party: Array[EnemyData] = _generate_enemies(encounter_id)
    # preload() resolves the path at script-parse time — safe for static methods.
    var scene: Node = preload("res://combat/combat_scene.tscn").instantiate()
    # Add to the current scene so it receives _process and input events.
    tree.current_scene.add_child(scene)
    scene.setup(player_party, enemy_party, player_first)
    return scene

## Build an enemy party from a hardcoded encounter id.
## Extend this match block to add more encounter types.
static func _generate_enemies(encounter_id: StringName) -> Array[EnemyData]:
    match encounter_id:
        &"goblin_single":
            return [_make_goblin()]
        &"orc_heavy":
            return [_make_orc()]
        &"goblin_pair":
            return [_make_goblin(), _make_goblin_scout()]
        _:
            push_warning("EncounterManager: unknown encounter_id '%s', defaulting to goblin_single" % encounter_id)
            return [_make_goblin()]

# --- Enemy constructors ---
# Each returns a fully initialized EnemyData Resource.
# Patterns use beat_offset values in range [0, phase_length - 1].

## Standard goblin: 4-beat pattern mixing targeted and free-form notes.
static func _make_goblin() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Goblin"
    e.max_hp       = 40
    e.hp           = 40
    e.attack_power = 8
    e.phase_length = 4

    # Beat 0: targeted up   — player must press Up
    var n0 := NoteData.new()
    n0.beat_offset = 0; n0.direction = &"up";   n0.mode = &"targeted"
    # Beat 2: targeted down — player must press Down
    var n1 := NoteData.new()
    n1.beat_offset = 2; n1.direction = &"down"; n1.mode = &"targeted"
    # Beat 3: free-form     — any press on the beat counts
    var n2 := NoteData.new()
    n2.beat_offset = 3; n2.direction = &"up";   n2.mode = &"free_form"

    e.pattern = [n0, n1, n2]
    return e

## Heavy orc: 8-beat pattern of four targeted notes on every other beat.
## Hits harder; tests that longer phase_length cycles correctly.
static func _make_orc() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Orc"
    e.max_hp       = 80
    e.hp           = 80
    e.attack_power = 15
    e.phase_length = 8

    var dirs: Array[StringName] = [&"up", &"right", &"down", &"left"]
    var notes: Array[NoteData] = []
    for i in range(4):
        var n := NoteData.new()
        n.beat_offset = i * 2   # beats 0, 2, 4, 6
        n.direction   = dirs[i]
        n.mode        = &"targeted"
        notes.append(n)

    e.pattern = notes
    return e

## Fast goblin scout: 2-beat pattern, low HP, tests rapid defend-phase cycling.
static func _make_goblin_scout() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Goblin Scout"
    e.max_hp       = 25
    e.hp           = 25
    e.attack_power = 5
    e.phase_length = 2

    var n0 := NoteData.new()
    n0.beat_offset = 0; n0.direction = &"left";  n0.mode = &"targeted"
    var n1 := NoteData.new()
    n1.beat_offset = 1; n1.direction = &"right"; n1.mode = &"targeted"

    e.pattern = [n0, n1]
    return e
```

- [ ] **Step 2: Commit**

```bash
git add combat/encounter_manager.gd
git commit -m "feat: add EncounterManager with goblin, orc, and goblin_pair encounters"
```

---

## Task 6: CombatScene

**Files:**
- Create: `combat/combat_scene.gd`
- Create: `combat/combat_scene.tscn`

The orchestrator. Connects to `BeatClock.beat`, manages phase state, injects notes into `RhythmInput`, resolves damage, and detects win/loss.

**Phase timing note:** Phases use a "one trailing beat" model. For a 4-beat defend phase, notes fire on beat indices 0–3 (beat counts 1–4), and the phase ends on count 5. This gives the last note a full beat of window before `clear_notes()` is called. The same applies to the attack phase.

- [ ] **Step 1: Write combat_scene.gd**

```gdscript
# combat/combat_scene.gd
extends Node

# --- Signals ---
# Emitted when all enemies reach 0 HP.
signal combat_won()
# Emitted when all player characters reach 0 HP.
signal combat_lost()

# --- Configuration ---
## How many beats the player's ATTACK phase lasts before switching to DEFEND.
## Exported so it can be overridden per scene in the Inspector.
@export var player_phase_length: int = 4

# --- Phase enum ---
# Godot enums are scoped to the class. Reference as CombatScene.Phase.ATTACK
# or just Phase.ATTACK within this script.
enum Phase { ATTACK, DEFEND }

# --- Party state (injected via setup()) ---
var _player_party: Array[CharacterData] = []
var _enemy_party:  Array[EnemyData]     = []
var _player_first: bool = true

# --- Phase state ---
var _current_phase: Phase = Phase.ATTACK
## How many beats have elapsed in the current phase (1-indexed; resets to 0 on transition).
var _phase_beat_count: int = 0
## Index into _enemy_party for the enemy currently in their DEFEND turn.
var _defend_index: int = 0
## Accumulated damage from the current ATTACK phase (applied at phase end).
var _damage_accumulator: float = 0.0

# --- Public API ---

## Initialize combat state and connect to global autoload signals.
## Called by EncounterManager immediately after adding this scene to the tree.
func setup(
    player_party: Array[CharacterData],
    enemy_party:  Array[EnemyData],
    player_first: bool = true
) -> void:
    _player_party = player_party
    _enemy_party  = enemy_party
    _player_first = player_first
    _current_phase = Phase.ATTACK if player_first else Phase.DEFEND
    _phase_beat_count = 0
    _defend_index     = 0
    _damage_accumulator = 0.0

    # Connect to autoload signals.
    # In Godot 4, autoloads are accessed by their registered name as globals.
    BeatClock.beat.connect(_on_beat)
    RhythmInput.input_scored.connect(_on_input_scored)
    RhythmInput.note_missed.connect(_on_note_missed)

## Returns the enemy currently taking their DEFEND turn (nil if none).
## Used by test_scene.gd for HP display.
func get_current_defending_enemy() -> EnemyData:
    if _current_phase != Phase.DEFEND:
        return null
    if _defend_index < _enemy_party.size():
        return _enemy_party[_defend_index]
    return null

## Returns the first living enemy (the player's attack target).
func get_attack_target() -> EnemyData:
    for e in _enemy_party:
        if e.hp > 0:
            return e
    return null

## Returns &"ATTACK" or &"DEFEND" for UI display.
func get_phase_name() -> StringName:
    return &"ATTACK" if _current_phase == Phase.ATTACK else &"DEFEND"

# --- Beat handler ---

func _on_beat(_beat_number: int) -> void:
    _phase_beat_count += 1

    match _current_phase:
        Phase.ATTACK:
            # Phase ends one beat after player_phase_length beats have elapsed.
            if _phase_beat_count > player_phase_length:
                _end_attack_phase()
        Phase.DEFEND:
            var enemy := _get_defending_enemy_internal()
            if enemy == null:
                _end_defend_phase()
                return
            # Phase ends one beat after all pattern beats have elapsed.
            if _phase_beat_count > enemy.phase_length:
                _end_defend_phase()
                return
            # Inject notes for beat index (_phase_beat_count - 1).
            # beat_count=1 → beat_index=0 (first note in pattern), etc.
            var beat_index: int = _phase_beat_count - 1
            for note: NoteData in enemy.pattern:
                if note.beat_offset == beat_index:
                    RhythmInput.add_note(note)

# --- Phase transitions ---

func _end_attack_phase() -> void:
    # Apply accumulated damage to the first living enemy.
    var target := get_attack_target()
    if target != null:
        var damage: int = int(_damage_accumulator)
        target.hp = max(0, target.hp - damage)

    _damage_accumulator = 0.0
    _phase_beat_count   = 0
    _defend_index       = _first_living_enemy_index()
    RhythmInput.clear_notes()
    _current_phase = Phase.DEFEND

    # Check win condition after applying damage.
    if _all_enemies_dead():
        combat_won.emit()

func _end_defend_phase() -> void:
    RhythmInput.clear_notes()
    _phase_beat_count = 0

    # Advance to the next living enemy for their DEFEND turn.
    _defend_index += 1
    while _defend_index < _enemy_party.size() and _enemy_party[_defend_index].hp <= 0:
        _defend_index += 1

    # All living enemies have had their turn — back to ATTACK.
    if _defend_index >= _enemy_party.size():
        _current_phase = Phase.ATTACK

# --- Input handlers ---

func _on_input_scored(_direction: StringName, score: StringName, _offset_ms: float) -> void:
    match _current_phase:
        Phase.ATTACK:
            var character := _get_active_character()
            if character == null:
                return
            match score:
                &"perfect":
                    _damage_accumulator += float(character.attack_power)
                &"good":
                    _damage_accumulator += float(character.attack_power) * 0.5
                # miss: accumulate nothing

        Phase.DEFEND:
            var enemy     := _get_defending_enemy_internal()
            var character := _get_active_character()
            if enemy == null or character == null:
                return
            match score:
                &"perfect":
                    pass  # fully blocked, no damage
                &"good":
                    _apply_damage_to_character(character, int(float(enemy.attack_power) * 0.5))
                &"miss":
                    _apply_damage_to_character(character, enemy.attack_power)

func _on_note_missed(_note: NoteData) -> void:
    # A targeted note expired without a press — treat as a full miss in DEFEND phase.
    if _current_phase != Phase.DEFEND:
        return
    var enemy     := _get_defending_enemy_internal()
    var character := _get_active_character()
    if enemy == null or character == null:
        return
    _apply_damage_to_character(character, enemy.attack_power)

# --- Helpers ---

## Applies damage and checks loss condition.
func _apply_damage_to_character(character: CharacterData, damage: int) -> void:
    character.hp = max(0, character.hp - damage)
    if _all_characters_dead():
        combat_lost.emit()

## First living CharacterData in party (prototype: always the same character takes hits).
func _get_active_character() -> CharacterData:
    for c in _player_party:
        if c.hp > 0:
            return c
    return null

## Internal version for use within this script (no phase guard).
func _get_defending_enemy_internal() -> EnemyData:
    if _defend_index < _enemy_party.size() and _enemy_party[_defend_index].hp > 0:
        return _enemy_party[_defend_index]
    return null

func _first_living_enemy_index() -> int:
    for i in range(_enemy_party.size()):
        if _enemy_party[i].hp > 0:
            return i
    return _enemy_party.size()  # all dead

func _all_enemies_dead() -> bool:
    for e in _enemy_party:
        if e.hp > 0:
            return false
    return true

func _all_characters_dead() -> bool:
    for c in _player_party:
        if c.hp > 0:
            return false
    return true
```

- [ ] **Step 2: Create combat_scene.tscn**

Create the file `combat/combat_scene.tscn` with this content. Godot will assign a UID the first time it opens the project.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://combat/combat_scene.gd" id="1"]

[node name="CombatScene" type="Node"]
script = ExtResource("1")
player_phase_length = 4
```

- [ ] **Step 3: Commit**

```bash
git add combat/combat_scene.gd combat/combat_scene.tscn
git commit -m "feat: add CombatScene with ATTACK/DEFEND phase management and damage resolution"
```

---

## Task 7: Test Scene + Integration Verification

**Files:**
- Create: `test_scene.gd`
- Create: `test_scene.tscn`
- Modify: `project.godot` (set main scene)

Wires debug labels to all signals. The beat label flashes yellow on each beat as a visual pulse. Toggle `player_first` in the Inspector to test surprise vs. ambush turn order. Change `encounter_id` to test different enemy patterns.

- [ ] **Step 1: Write test_scene.gd**

```gdscript
# test_scene.gd
# The prototype's main scene. Exercises the full rhythm combat stack:
# BeatClock → CombatScene ← RhythmInput
# Run in Godot (F5) and press arrow keys on the beat to see scoring.
extends Node2D

## Set to false to test ambush (enemies attack first).
@export var player_first: bool = true

## Change to &"orc_heavy" or &"goblin_pair" to test other encounters.
@export var encounter_id: StringName = &"goblin_single"

# Node references — @onready populates these after _ready() begins.
# The $ shorthand is equivalent to get_node("NodePath").
@onready var _audio:        AudioStreamPlayer = $AudioStreamPlayer
@onready var _bpm_label:    Label = $CanvasLayer/VBox/BPMLabel
@onready var _beat_label:   Label = $CanvasLayer/VBox/BeatLabel
@onready var _score_label:  Label = $CanvasLayer/VBox/ScoreLabel
@onready var _phase_label:  Label = $CanvasLayer/VBox/PhaseLabel
@onready var _enemy_label:  Label = $CanvasLayer/VBox/EnemyHPLabel
@onready var _player_label: Label = $CanvasLayer/VBox/PlayerHPLabel

var _hero:   CharacterData
var _combat: Node   # CombatScene instance

func _ready() -> void:
    # Build a default player character for the prototype.
    _hero                 = CharacterData.new()
    _hero.character_name  = "Hero"
    _hero.max_hp          = 100
    _hero.hp              = 100
    _hero.attack_power    = 12

    # Start audio then anchor BeatClock to it.
    # If res://audio/placeholder_beat.ogg does not exist, audio_player.play()
    # silently fails and BeatClock falls back to wall-clock time automatically.
    _audio.play()
    BeatClock.start(_audio)

    # Load the encounter. EncounterManager adds CombatScene as a child of this scene.
    _combat = EncounterManager.start_combat(get_tree(), [_hero], encounter_id, player_first)
    _combat.combat_won.connect(_on_combat_won)
    _combat.combat_lost.connect(_on_combat_lost)

    # Connect beat flash and input display.
    BeatClock.beat.connect(_on_beat)
    RhythmInput.input_scored.connect(_on_input_scored)

func _process(_delta: float) -> void:
    _bpm_label.text   = "BPM: %.0f" % BeatClock.bpm
    _beat_label.text  = "Beat: %d  (pos: %.2f)" % [BeatClock.beat_number, BeatClock.beat_position]
    _phase_label.text = "Phase: %s" % _combat.get_phase_name()
    _player_label.text = "Player HP: %d / %d" % [_hero.hp, _hero.max_hp]

    var target: EnemyData = _combat.get_attack_target()
    if target != null:
        _enemy_label.text = "Enemy: %s  HP: %d / %d" % [target.enemy_name, target.hp, target.max_hp]
    else:
        _enemy_label.text = "Enemy: none"

func _on_beat(_beat_number: int) -> void:
    # Visual pulse: flash the beat label yellow for 0.1 seconds.
    _beat_label.modulate = Color.YELLOW
    # create_timer() is a one-shot timer that auto-frees — no Timer node needed.
    await get_tree().create_timer(0.1).timeout
    _beat_label.modulate = Color.WHITE

func _on_input_scored(direction: StringName, score: StringName, offset_ms: float) -> void:
    _score_label.text = "Last: %-5s  %-7s  (%+.1f ms)" % [direction, score, offset_ms]

func _on_combat_won() -> void:
    _score_label.text = "*** VICTORY! ***"
    BeatClock.stop()

func _on_combat_lost() -> void:
    _score_label.text = "*** DEFEAT! ***"
    BeatClock.stop()
```

- [ ] **Step 2: Create test_scene.tscn**

Create the file `test_scene.tscn` in the project root with this content:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test_scene.gd" id="1"]

[node name="TestScene" type="Node2D"]
script = ExtResource("1")
player_first = true

[node name="AudioStreamPlayer" type="AudioStreamPlayer" parent="."]

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="VBox" type="VBoxContainer" parent="CanvasLayer"]
offset_right = 500.0
offset_bottom = 250.0

[node name="BPMLabel" type="Label" parent="CanvasLayer/VBox"]
text = "BPM: --"

[node name="BeatLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Beat: --"

[node name="ScoreLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Last: --"

[node name="PhaseLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Phase: --"

[node name="EnemyHPLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Enemy: --"

[node name="PlayerHPLabel" type="Label" parent="CanvasLayer/VBox"]
text = "Player HP: --"
```

- [ ] **Step 3: Set test_scene.tscn as the main scene**

In `project.godot`, add this line inside the `[application]` section (after the existing `config/icon` line):

```ini
config/run/main_scene="res://test_scene.tscn"
```

- [ ] **Step 4: Add a placeholder audio file (optional but recommended)**

Place any short looping `.ogg` file at `res://audio/placeholder_beat.ogg`. A free 120 BPM click track works well. If no file is added, BeatClock falls back to wall-clock time — the labels still update and inputs still score, but timing won't be audio-synced.

If you have an `.ogg` file, also set it on the AudioStreamPlayer node: in the Inspector, set `Stream` to your file and enable `Autoplay` if desired (or leave `_audio.play()` in `_ready()` as-is).

- [ ] **Step 5: Integration verification**

Run the project in Godot (F5 or the Play button).

Check each of the following in the Output panel and on screen:

| Check | Expected |
|---|---|
| BPMLabel | Shows "BPM: 120" |
| BeatLabel | Increments every 0.5s at 120 BPM; flashes yellow |
| PhaseLabel | Shows "ATTACK" at start (player_first=true) |
| Press Up arrow on beat | ScoreLabel shows "up  perfect  (+X ms)" with small offset |
| Press Up arrow off beat | ScoreLabel shows "up  miss  (+XXX ms)" with large offset |
| After 5 beats of ATTACK | PhaseLabel switches to "DEFEND" |
| During DEFEND, miss all notes | PlayerHP decreases by enemy.attack_power per note |
| During DEFEND, press correct direction on beat | PlayerHP unchanged (perfect block) |
| Kill enemy (enough perfect attacks) | "VICTORY!" shown, beat stops |

- [ ] **Step 6: Test ambush mode**

In the Inspector on TestScene, set `player_first = false`. Re-run (F6 to run current scene).
Expected: PhaseLabel shows "DEFEND" first. Goblin notes appear before player can deal damage.

- [ ] **Step 7: Test multi-enemy encounter**

In the Inspector, set `encounter_id = &"goblin_pair"`. Re-run.
Expected: After killing the first goblin (or depleting its turn), the second enemy (Goblin Scout) takes over the DEFEND phase with its 2-beat pattern.

- [ ] **Step 8: Commit**

```bash
git add test_scene.gd test_scene.tscn project.godot
git commit -m "feat: add test scene with debug UI and full combat loop integration"
```

---

## Self-Review Notes

**Spec coverage:** All spec sections are implemented:
- ✅ Folder structure (Task 1)
- ✅ BeatClock with AudioServer timing + explained (Task 3)
- ✅ RhythmInput with 4 inputs, Perfect/Good/Miss, configurable thresholds (Task 4)
- ✅ Hybrid per-note mode (free_form / targeted) (Task 4)
- ✅ Repeating enemy patterns, multiple enemies (Tasks 5–6)
- ✅ Phase-based turn order, player_first flag (Task 6)
- ✅ ATTACK miss = no damage; DEFEND miss = HP loss (Task 6)
- ✅ Test scene with debug labels, BPM, beat number, last score, HP (Task 7)
- ✅ Autoloads registered in project.godot (Task 1)
- ✅ Godot patterns commented throughout

**Known prototype limitations (documented in spec §10, not bugs):**
- One-beat trailing "rest" at the end of each phase before transition fires.
- Player always attacks the first living enemy (no targeting UI).
- All player characters take damage simultaneously through the first living character.
