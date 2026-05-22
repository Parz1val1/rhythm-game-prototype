# Rhythm Combat Prototype — Design Spec
**Date:** 2026-05-21  
**Engine:** Godot 4.6 (GDScript, GL Compatibility renderer)  
**Scope:** Core rhythm combat loop only — no overworld, menus, or story.  
**Goal:** Validate that the beat-timed attack/defend feel is fun before building around it.

---

## 1. Project Structure

```
res://
├── autoloads/
│   ├── beat_clock.gd          # Global beat timer, audio-synced
│   └── rhythm_input.gd        # Input capture + timing scorer
├── combat/
│   ├── combat_scene.tscn      # Root scene for a combat encounter
│   ├── combat_scene.gd        # Orchestrates phases, damage, turn order
│   └── encounter_manager.gd   # Generates enemy party, loads CombatScene
├── characters/
│   ├── character_data.gd      # Resource: player character stats
│   └── enemy_data.gd          # Resource: enemy stats + repeating pattern
├── rhythm_engine/
│   └── note_data.gd           # Resource: a single note in a pattern
├── audio/                     # Placeholder audio assets (.ogg, .wav)
└── ui/
    └── combat_ui.tscn         # Debug labels + HP display
```

Both `BeatClock` and `RhythmInput` are registered as **autoloads** in Project Settings so they are available globally across all scenes without manual instantiation.

---

## 2. Data Resources

All data types are `class_name` GDScript classes that extend `Resource`. This allows them to be authored as `.tres` files in the Godot editor later without any additional infrastructure.

### NoteData (`rhythm_engine/note_data.gd`)
Represents a single note within an enemy's repeating attack pattern.

| Field | Type | Description |
|---|---|---|
| `beat_offset` | `int` | Which beat within the pattern this note fires on (0-indexed). E.g. `1` = fires on beat 1 of the pattern. Stored as `int` because patterns fire on whole beats in this prototype; promote to `float` when half-beat notes are needed. |
| `direction` | `StringName` | `&"up"`, `&"down"`, `&"left"`, or `&"right"` |
| `mode` | `StringName` | `&"free_form"` (any press on beat counts) or `&"targeted"` (must press matching direction) |

### CharacterData (`characters/character_data.gd`)
Represents one player party member.

| Field | Type | Description |
|---|---|---|
| `character_name` | `String` | Display name |
| `max_hp` | `int` | Maximum HP |
| `hp` | `int` | Current HP |
| `attack_power` | `int` | Base damage dealt on Perfect hit |

### EnemyData (`characters/enemy_data.gd`)
Represents one enemy in the encounter.

| Field | Type | Description |
|---|---|---|
| `enemy_name` | `String` | Display name |
| `max_hp` | `int` | Maximum HP |
| `hp` | `int` | Current HP |
| `attack_power` | `int` | Base damage dealt to player on Miss during defend phase |
| `pattern` | `Array[NoteData]` | The repeating note sequence this enemy emits on its turn |
| `phase_length` | `int` | How many beats this enemy's attack phase lasts |

---

## 3. BeatClock Autoload (`autoloads/beat_clock.gd`)

The heartbeat of the entire system. Tracks musical time and emits signals other systems react to.

### Why AudioServer timing?
Godot's audio runs on a dedicated thread with a hardware output buffer. There is typically 50–120 ms of latency between when the engine *schedules* audio and when the player *hears* it. If beat position is calculated from `Time.get_ticks_msec()` alone, input scoring compares the player's keypress (OS time) against a beat derived from engine time — creating a systematic offset equal to the audio latency. The correct playback position is:

```gdscript
var audio_time := (stream_player.get_playback_position()
    + AudioServer.get_time_since_last_mix()
    - AudioServer.get_output_latency())
```

This gives the audio stream's **true perceived position** — what the player actually hears — so "on the beat" is accurate to human perception.

### Signals
| Signal | Args | Description |
|---|---|---|
| `beat` | `beat_number: int` | Fires once per beat |
| `half_beat` | `beat_number: int` | Fires at 0.5 of each beat |
| `quarter_beat` | `beat_number: int` | Fires at 0.25 and 0.75 of each beat |

### Public API
| Member | Type | Description |
|---|---|---|
| `bpm` | `float` | Beats per minute. Default `120.0`. Configurable at runtime. |
| `beat_number` | `int` | Current beat index since `start()` was called |
| `beat_position` | `float` | Position within current beat, `0.0`–`1.0` |
| `start(stream_player)` | method | Anchors timing to an `AudioStreamPlayer`. Call when combat begins. |
| `stop()` | method | Halts beat emission |
| `get_offset_ms()` | `-> float` | Milliseconds from the nearest beat. Negative = pressed early, positive = pressed late. Used by `RhythmInput` for scoring. |

### Implementation notes
- Beat tracking runs in `_process()` using the audio-corrected position, not accumulated `delta`, to prevent drift over long sessions.
- `beat`, `half_beat`, and `quarter_beat` signals are emitted by comparing the previous and current `beat_position` each frame to detect threshold crossings.

---

## 4. RhythmInput Autoload (`autoloads/rhythm_input.gd`)

Captures directional inputs, scores them against the current beat, and manages the lifecycle of active targeted notes.

### Inputs
Four actions must be defined in **Project → Input Map**:
- `rhythm_up`, `rhythm_down`, `rhythm_left`, `rhythm_right`

These default to arrow keys / WASD / controller face buttons — configurable per project.

### Signals
| Signal | Args | Description |
|---|---|---|
| `input_scored` | `direction: StringName, score: StringName, offset_ms: float` | Emitted on every valid press. `score` is `&"perfect"`, `&"good"`, or `&"miss"`. |
| `note_missed` | `note: NoteData` | Emitted when a targeted note expires without a matching press. |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `perfect_ms` | `float` | `50.0` | Max offset for a Perfect score |
| `good_ms` | `float` | `120.0` | Max offset for a Good score. Beyond this = Miss. |
| `active_notes` | `Array[NoteData]` | `[]` | Targeted notes currently in the scoring window. Populated by `CombatScene`. |

### Hybrid scoring logic (on each press)
1. Call `BeatClock.get_offset_ms()` → `offset_ms`
2. Search `active_notes` for a `&"targeted"` note whose `direction` matches the pressed direction and whose beat is within `good_ms`:
   - If found: score it, remove from `active_notes`, emit `input_scored`
   - If not found: treat as free-form — score `abs(offset_ms)` against thresholds, emit `input_scored`
3. Scoring: `abs(offset_ms) <= perfect_ms` → `&"perfect"`, `<= good_ms` → `&"good"`, else → `&"miss"`

### Note expiry
Each `_process()` frame, any targeted note whose beat has passed by more than `good_ms` is removed from `active_notes` and `note_missed` is emitted. `CombatScene` listens to `note_missed` to apply defend-phase damage.

### Public API
| Method | Description |
|---|---|
| `add_note(note: NoteData)` | Called by `CombatScene` to inject a note into the scoring window. `RhythmInput` records `Time.get_ticks_msec()` at injection as the note's expected beat time — expiry is checked against this timestamp. No changes to `NoteData` needed. |
| `clear_notes()` | Called at phase transitions to flush stale notes |

---

## 5. CombatScene (`combat/combat_scene.gd`)

The orchestrator. Owns all combat state and wires `BeatClock` signals to game logic.

### Entry point
```gdscript
func setup(
    player_party: Array[CharacterData],
    enemy_party: Array[EnemyData],
    player_first: bool = true
) -> void
```
Called by `EncounterManager` immediately after the scene is added to the tree.

### Phase structure

```
player_first = true:   [ATTACK] → [DEFEND x N enemies] → [ATTACK] → ...
player_first = false:  [DEFEND x N enemies] → [ATTACK] → [DEFEND x N enemies] → ...
```

One full cycle = one ATTACK phase + one DEFEND phase per living enemy. Enemies defend in order (`enemy_party` index 0 first). Dead enemies are skipped.

### ATTACK phase (players act)
- Duration: `player_phase_length` beats (default `4`, exported variable on `CombatScene`)
- No targeted notes are injected — all input is free-form
- `input_scored` listener: `&"perfect"` → accumulate `character.attack_power`, `&"good"` → accumulate `attack_power * 0.5`, `&"miss"` → accumulate `0`
- Accumulated damage is applied to `current_enemy.hp` at phase end (integer, rounded down)
- All player characters act as a single input stream in the prototype (party = one set of hands)

### DEFEND phase (one enemy acts)
- Duration: `current_enemy.phase_length` beats
- On each `BeatClock.beat` signal: check enemy's `pattern` for notes where `note.beat_offset == (beat_number % phase_length)` and call `RhythmInput.add_note(note)`
- `input_scored` listener:
  - `&"perfect"` → 0 damage to player
  - `&"good"` → `enemy.attack_power * 0.5` damage to active character
  - `&"miss"` → `enemy.attack_power` damage to active character
- `note_missed` listener → `enemy.attack_power` damage (same as miss)
- "Active character" = first living `CharacterData` in `player_party` (prototype simplification; multi-character targeting is future work)

### Phase transitions
- `RhythmInput.clear_notes()` is called at every phase boundary
- Accumulated attack damage is applied and reset at ATTACK → DEFEND transition
- After all living enemies have completed their DEFEND phase, cycle returns to ATTACK

### Win/loss conditions
| Condition | Signal emitted |
|---|---|
| All enemies at 0 HP | `combat_won()` |
| All characters at 0 HP | `combat_lost()` |

The scene does not handle these itself — it emits and waits for the caller (or future GameManager) to respond.

---

## 6. EncounterManager (`combat/encounter_manager.gd`)

Lightweight static helper. Generates an enemy party from an encounter ID and loads `CombatScene`.

```gdscript
static func start_combat(
    tree: SceneTree,
    player_party: Array[CharacterData],
    encounter_id: StringName,
    player_first: bool = true
) -> CombatScene
```

`_generate_enemies(encounter_id)` is a `match` block returning hardcoded `EnemyData` instances for the prototype. Example encounters:
- `&"goblin_single"` — one goblin, 4-beat pattern, fast tempo feel
- `&"orc_heavy"` — one orc, 8-beat pattern, slower but hits harder
- `&"goblin_pair"` — two goblins, different phase lengths, tests multi-enemy cycling

Returns the instantiated `CombatScene` node so the caller can connect to `combat_won` / `combat_lost` signals.

---

## 7. Test Scene

A minimal scene that exercises the full stack without any game infrastructure:

- `AudioStreamPlayer` playing a looping placeholder track (path: `res://audio/placeholder_beat.ogg`)
- `BeatClock.start()` called on scene ready
- Debug `Label` nodes displaying:
  - Current BPM
  - Current beat number
  - Last input direction + score + offset_ms
  - Enemy HP / Player HP
- One placeholder enemy (`&"goblin_single"`) loaded via `EncounterManager.start_combat()`
- `player_first` togglable via an exported variable on the test scene for surprise/ambush testing

---

## 8. System Diagram

```
EncounterManager.start_combat()
        │
        │  setup(player_party, enemy_party, player_first)
        ▼
   CombatScene
        │
        ├── listens to ──► BeatClock (autoload)
        │                      │ beat / half_beat / quarter_beat signals
        │                      │ get_offset_ms() for RhythmInput
        │
        ├── populates ───► RhythmInput (autoload)
        │   active_notes        │ input_scored signal
        │                       │ note_missed signal
        │                       ▼
        │               CombatScene resolves damage,
        │               advances phase, checks win/loss
        │
        └── owns ────────► Array[CharacterData]  (player party)
                           Array[EnemyData]       (enemy party)
                           phase_state, beat_counter, damage_accumulator
```

---

## 9. Key Godot Patterns Used

| Pattern | Where | Why |
|---|---|---|
| **Autoloads** | `BeatClock`, `RhythmInput` | Singletons available globally across scenes without manual node references. Registered in Project → Autoloads. |
| **Signals** | All inter-system communication | Godot's idiomatic loose coupling. Systems emit; listeners decide what to do. No direct method calls across system boundaries except for the `setup()` entry point. |
| **Resource subclasses** | `NoteData`, `CharacterData`, `EnemyData` | Plain data objects with no node lifecycle overhead. Can be serialized to `.tres` and edited in the Inspector for free. |
| **`_process()` for timing** | `BeatClock` | Audio-corrected playback position read every frame; threshold crossings emit beat signals. Avoids Timer node drift. |
| **`AudioServer` timing** | `BeatClock.get_offset_ms()` | Compensates for audio output latency so input scoring aligns with what the player hears, not engine time. |
| **Static helper** | `EncounterManager` | No node required; callable from anywhere. Appropriate for a factory function with no persistent state. |

---

## 10. Out of Scope (this prototype)

- Overworld, menus, save/load
- Animated characters or sprite sheets
- Multi-character targeting (damage always hits first living character)
- Enemy team attacks (all enemies share one DEFEND phase)
- Combo multipliers, status effects, elemental damage
- Chart/sequencer file format for note patterns
- Online or replay systems
