# combat/combat_scene.gd
extends Node

# Preload workarounds: autoloads load before global class_name scope is fully
# initialized in Godot 4.6, so typed arrays with class_name types in their
# annotation can cause parse errors. Using preload constants avoids that.
const CharacterData      = preload("res://characters/character_data.gd")
const EnemyData          = preload("res://characters/enemy_data.gd")
const NoteData           = preload("res://rhythm_engine/note_data.gd")
const SequenceEvaluator  = preload("res://combat/sequence_evaluator.gd")

# --- Signals ---
# Emitted when all enemies reach 0 HP.
signal combat_won()
# Emitted when all player characters reach 0 HP.
signal combat_lost()

## Fired `lookahead_beats` beats before a note is due during DEFEND.
## Note lane visualizers connect to this to spawn approaching note visuals.
## note:        the NoteData that will be due at target_beat_number
## target_beat: the BeatClock.beat_number value when the note must be pressed
signal note_approaching(note: NoteData, target_beat: int)

## Fired whenever the combat phase changes.
## new_phase matches the Phase enum: 0 = ATTACK, 1 = DEFEND
signal phase_changed(new_phase: int)

## Fires after each ATTACK phase input with current combo count and multiplier.
signal combo_updated(combo_count: int, multiplier: float)

## Fires when a character's limit_break_gauge first reaches 1.0.
signal limit_break_ready(character: CharacterData)
## Fires when the limit break phase begins.
signal limit_break_started(character: CharacterData)
## Fires when the limit break phase ends and gauge resets.
signal limit_break_ended()

# --- Configuration ---
## How many beats the player's ATTACK phase lasts before switching to DEFEND.
## Exported so it can be overridden per scene in the Inspector.
@export var player_phase_length: int = 4

## How many beats ahead to announce incoming notes via note_approaching.
## At 120 BPM, 2 beats = 1 second of visual approach time.
@export var lookahead_beats: int = 2

## Enable to print per-input and per-note timing diagnostics to Godot's Output panel.
## Shows inject timing, input offset, and whether each press consumed a note.
## Key to look for: "NO-NOTE" entries with negative offsets mean the player pressed
## before the note was active — the effective window is 0 → +good_ms, not ±good_ms.
@export var debug_timing: bool = false

# --- Phase enum ---
# Godot enums are scoped to the class. Reference as CombatScene.Phase.ATTACK
# or just Phase.ATTACK within this script.
enum Phase { ATTACK, DEFEND }

# --- Party state (injected via setup()) ---
var _player_party: Array = []
var _enemy_party:  Array = []
var _player_first: bool = true

# --- Phase state ---
var _current_phase: Phase = Phase.ATTACK
## How many beats have elapsed in the current phase (1-indexed; resets to 0 on transition).
var _phase_beat_count: int = 0
## Index into _enemy_party for the enemy currently in their DEFEND turn.
var _defend_index: int = 0
## Set to true the moment combat ends so duplicate-emit guards and _on_beat can bail out.
var _combat_ended: bool = false
## Tracks combo count and computes damage multiplier during ATTACK phase.
var _sequence := SequenceEvaluator.new()

var _limit_break_active: bool = false
var _limit_break_character = null   # CharacterData or null
var _default_phase_length: int = 4  # saved on setup(), restored after limit break

# --- Public API ---

## Initialize combat state and connect to global autoload signals.
## Called by EncounterManager immediately after adding this scene to the tree.
func setup(
    player_party: Array,
    enemy_party:  Array,
    player_first: bool = true
) -> void:
    _player_party = player_party
    _enemy_party  = enemy_party
    _player_first = player_first
    _current_phase = Phase.ATTACK if player_first else Phase.DEFEND
    _phase_beat_count = 0
    _defend_index     = 0
    _sequence.reset()
    _combat_ended = false
    _limit_break_active = false
    _limit_break_character = null
    _default_phase_length = player_phase_length

    # Connect to autoload signals.
    # In Godot 4, autoloads are accessed by their registered name as globals.
    BeatClock.beat.connect(_on_beat)
    # half_beat fires at beat_position=0.5, roughly one half-beat (~250ms at 120BPM)
    # before the next full beat. We use it to pre-inject DEFEND notes so the note
    # exists in RhythmInput before players press — fixing the asymmetric timing window.
    BeatClock.half_beat.connect(_on_half_beat)
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

## Activate limit break for the active character.
## Only works during ATTACK phase when the character's gauge is full.
## Returns true if activated, false otherwise.
func try_activate_limit_break() -> bool:
    if _current_phase != Phase.ATTACK or _limit_break_active or _combat_ended:
        return false
    var character = _get_active_character()
    if character == null or character.limit_break_gauge < 1.0:
        return false
    _limit_break_active = true
    _limit_break_character = character
    player_phase_length = character.limit_break_phase_length
    limit_break_started.emit(character)
    return true

# --- Beat handler ---

func _on_beat(beat_number: int) -> void:
    if _combat_ended:
        return
    _phase_beat_count += 1

    match _current_phase:
        Phase.ATTACK:
            # Phase ends one beat after player_phase_length beats have elapsed.
            if _phase_beat_count > player_phase_length:
                _end_attack_phase()
        Phase.DEFEND:
            var enemy = _get_defending_enemy_internal()
            if enemy == null:
                _end_defend_phase()
                return
            # Phase ends one beat after all pattern beats have elapsed.
            if _phase_beat_count > enemy.phase_length:
                _end_defend_phase()
                return
            # Notes are pre-injected at half_beat (~250ms early) via _on_half_beat().
            # No injection here — doing it again after a note is consumed causes
            # a phantom re-add that expires and deals double damage.
            var beat_index: int = _phase_beat_count - 1
            # Pre-announce notes due LOOKAHEAD_BEATS from now for visual spawning.
            var lookahead_index: int = beat_index + lookahead_beats
            for note: NoteData in enemy.pattern:
                if note.beat_offset == lookahead_index:
                    note_approaching.emit(note, beat_number + lookahead_beats)

# --- Half-beat pre-injection ---

## Fires at beat_position=0.5 (halfway through each beat).
## Pre-injects the NEXT beat's DEFEND notes into RhythmInput so they are active
## ~half_beat_duration ms before the player needs to press them.
## This symmetrises the effective window from (0 → +good_ms) to (−half_beat → +good_ms).
func _on_half_beat(_beat_number: int) -> void:
    if _combat_ended or _current_phase != Phase.DEFEND:
        return
    var enemy = _get_defending_enemy_internal()
    if enemy == null:
        return
    # _phase_beat_count will be incremented on the next full beat,
    # making beat_index = _phase_beat_count (the current value).
    var next_beat_index: int = _phase_beat_count
    if next_beat_index >= enemy.phase_length:
        return  # next beat ends (or already past) this DEFEND turn; nothing to pre-inject
    # Compute when the next beat is due so the note's expiry is beat-anchored.
    var half_beat_ms: int = int(float(60.0 / BeatClock.bpm) * 500.0)
    var due_ms: int = Time.get_ticks_msec() + half_beat_ms
    for note: NoteData in enemy.pattern:
        if note.beat_offset == next_beat_index:
            if RhythmInput.add_note(note, due_ms) and debug_timing:
                print("[PRE-INJECT] dir=%-5s  due in %d ms  window: −%d → +%.0f ms" % [
                    note.direction, half_beat_ms, half_beat_ms, RhythmInput.good_ms])

# --- Phase transitions ---

func _end_attack_phase() -> void:
    # Damage is applied per-hit in _on_input_scored; nothing to apply here.
    _phase_beat_count = 0

    # End limit break if it was active this phase.
    if _limit_break_active:
        _limit_break_active = false
        if _limit_break_character != null:
            _limit_break_character.limit_break_gauge = 0.0
        _limit_break_character = null
        player_phase_length = _default_phase_length
        limit_break_ended.emit()

    _defend_index = _first_living_enemy_index()
    RhythmInput.clear_notes()
    _current_phase = Phase.DEFEND
    phase_changed.emit(Phase.DEFEND)

    # Safety-net win check: normally triggered per-hit, but covers the edge
    # case where the phase boundary fires before the last scored signal arrives.
    if _all_enemies_dead() and not _combat_ended:
        _combat_ended = true
        teardown()
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
        _sequence.reset()
        _current_phase = Phase.ATTACK
        phase_changed.emit(Phase.ATTACK)

# --- Input handlers ---

func _on_input_scored(_direction: StringName, score: StringName, _offset_ms: float, note_consumed: bool) -> void:
    if _combat_ended:
        return
    match _current_phase:
        Phase.ATTACK:
            var character = _get_active_character()
            if character == null:
                return
            var multiplier: float = _sequence.record_hit(score)
            # Limit break multiplier stacks on top of combo multiplier.
            var lb_mult: float = character.limit_break_multiplier if _limit_break_active else 1.0
            var target = get_attack_target()
            match score:
                &"perfect":
                    if target != null:
                        target.hp = max(0, target.hp - int(float(character.attack_power) * multiplier * lb_mult))
                    # Charge gauge only when limit break is NOT active.
                    if not _limit_break_active:
                        var was_ready: bool = character.limit_break_gauge >= 1.0
                        character.limit_break_gauge = min(1.0, character.limit_break_gauge + character.charge_rate_perfect)
                        if not was_ready and character.limit_break_gauge >= 1.0:
                            limit_break_ready.emit(character)
                &"good":
                    if target != null:
                        target.hp = max(0, target.hp - int(float(character.attack_power) * 0.5 * multiplier * lb_mult))
                    if not _limit_break_active:
                        character.limit_break_gauge = min(1.0, character.limit_break_gauge + character.charge_rate_good)
                # miss: no damage, no gauge charge
            combo_updated.emit(_sequence.combo_count, _sequence.get_multiplier())
            # Apply win condition immediately so the enemy bar empties on the killing hit.
            if _all_enemies_dead() and not _combat_ended:
                _combat_ended = true
                teardown()
                combat_won.emit()

        Phase.DEFEND:
            if debug_timing:
                var tag := "CONSUMED" if note_consumed else "NO-NOTE (ignored — press early?)"
                print("[INPUT ] dir=%-5s  offset=%+.1f ms  score=%-8s  %s" % [
                    _direction, _offset_ms, score, tag])
            # Only respond to presses that consumed an active note.
            # Ignoring free-form presses prevents phantom blocking.
            if not note_consumed:
                return
            var enemy     = _get_defending_enemy_internal()
            var character = _get_active_character()
            if enemy == null or character == null:
                return
            match score:
                &"perfect":
                    pass  # fully blocked, no damage
                &"good":
                    _apply_damage_to_character(character, int(float(enemy.attack_power) * 0.5))
                &"miss":
                    _apply_damage_to_character(character, enemy.attack_power)

func _on_note_missed(_note) -> void:
    if debug_timing:
        print("[EXPIRE] dir=%-5s  note expired → full damage" % _note.direction)
    # A targeted note expired without a press — treat as a full miss in DEFEND phase.
    if _current_phase != Phase.DEFEND:
        return
    var enemy     = _get_defending_enemy_internal()
    var character = _get_active_character()
    if enemy == null or character == null:
        return
    _apply_damage_to_character(character, enemy.attack_power)

## Disconnects all autoload signal connections and flushes active notes.
## Called internally before combat_won/combat_lost emit.
## May also be called from _exit_tree() for explicit cleanup on scene removal.
func teardown() -> void:
    if BeatClock.beat.is_connected(_on_beat):
        BeatClock.beat.disconnect(_on_beat)
    if BeatClock.half_beat.is_connected(_on_half_beat):
        BeatClock.half_beat.disconnect(_on_half_beat)
    if RhythmInput.input_scored.is_connected(_on_input_scored):
        RhythmInput.input_scored.disconnect(_on_input_scored)
    if RhythmInput.note_missed.is_connected(_on_note_missed):
        RhythmInput.note_missed.disconnect(_on_note_missed)
    RhythmInput.clear_notes()

func _exit_tree() -> void:
    teardown()

# --- Helpers ---

## Applies damage and checks loss condition.
func _apply_damage_to_character(character, damage: int) -> void:
    if _combat_ended:
        return
    character.hp = max(0, character.hp - damage)
    if _all_characters_dead():
        _combat_ended = true
        teardown()
        combat_lost.emit()

## First living CharacterData in party (prototype: always the same character takes hits).
func _get_active_character():
    for c in _player_party:
        if c.hp > 0:
            return c
    return null

## Internal version for use within this script (no phase guard).
func _get_defending_enemy_internal():
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
