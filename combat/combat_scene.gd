# combat/combat_scene.gd
extends Node

# Preload workarounds: autoloads load before global class_name scope is fully
# initialized in Godot 4.6, so typed arrays with class_name types in their
# annotation can cause parse errors. Using preload constants avoids that.
const CharacterData = preload("res://characters/character_data.gd")
const EnemyData     = preload("res://characters/enemy_data.gd")
const NoteData      = preload("res://rhythm_engine/note_data.gd")

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
var _player_party: Array = []
var _enemy_party:  Array = []
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
            var enemy = _get_defending_enemy_internal()
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
            for note in enemy.pattern:
                if note.beat_offset == beat_index:
                    RhythmInput.add_note(note)

# --- Phase transitions ---

func _end_attack_phase() -> void:
    # Apply accumulated damage to the first living enemy.
    var target = get_attack_target()
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
    # A targeted note expired without a press — treat as a full miss in DEFEND phase.
    if _current_phase != Phase.DEFEND:
        return
    var enemy     = _get_defending_enemy_internal()
    var character = _get_active_character()
    if enemy == null or character == null:
        return
    _apply_damage_to_character(character, enemy.attack_power)

# --- Helpers ---

## Applies damage and checks loss condition.
func _apply_damage_to_character(character, damage: int) -> void:
    character.hp = max(0, character.hp - damage)
    if _all_characters_dead():
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
