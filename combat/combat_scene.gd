# combat/combat_scene.gd
extends Node

# Preload workarounds: autoloads load before global class_name scope is fully
# initialized in Godot 4.6, so typed arrays with class_name types in their
# annotation can cause parse errors. Using preload constants avoids that.
const CharacterData         = preload("res://characters/character_data.gd")
const EnemyData             = preload("res://characters/enemy_data.gd")
const NoteData              = preload("res://rhythm_engine/note_data.gd")
const SequenceEvaluator     = preload("res://combat/sequence_evaluator.gd")
const CharacterInputProfile = preload("res://characters/character_input_profile.gd")
const AttackEvaluator       = preload("res://combat/attack_evaluator.gd")
const PassthroughEvaluator  = preload("res://combat/passthrough_evaluator.gd")
const BeatriceEvaluator     = preload("res://combat/beatrice_evaluator.gd")
const LuthierEvaluator      = preload("res://combat/luthier_evaluator.gd")

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
## Active character input profile (may be null = default 4-direction Luthier behavior).
var _active_profile = null   # CharacterInputProfile or null
## Evaluator for ATTACK phase damage. Replaced when a profile is set via set_active_profile().
## Default is PassthroughEvaluator, which preserves the existing SequenceEvaluator behavior.
var _evaluator: AttackEvaluator = PassthroughEvaluator.new()

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
    _evaluator.reset()
    _combat_ended = false
    _limit_break_active = false
    _limit_break_character = null
    _default_phase_length = player_phase_length

    var enemy_names := ", ".join(_enemy_party.map(func(e: EnemyData): return e.enemy_name))
    var player_names := ", ".join(_player_party.map(func(c: CharacterData): return c.character_name))
    DebugLog.combat("[SETUP  ] combat started | players: [%s] | enemies: [%s] | player_first=%s" % [
        player_names, enemy_names, player_first])

    # Connect to autoload signals.
    # In Godot 4, autoloads are accessed by their registered name as globals.
    BeatClock.beat.connect(_on_beat)
    # half_beat fires at beat_position=0.5 — used to pre-inject both next-full-beat
    # notes and notes due right at the half-beat (beat_offset X.5).
    BeatClock.half_beat.connect(_on_half_beat)
    # quarter_beat fires at 0.25 and 0.75 — supports X.25 and X.75 beat_offset notes.
    BeatClock.quarter_beat.connect(_on_quarter_beat)
    RhythmInput.input_scored.connect(_on_input_scored)
    RhythmInput.note_missed.connect(_on_note_missed)
    RhythmInput.input_chord.connect(_on_input_chord)

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
    for e: EnemyData in _enemy_party:
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
    DebugLog.combat("[LB     ] started | %s | phase_len=%d  mult=×%.1f" % [
        character.character_name, character.limit_break_phase_length,
        character.limit_break_multiplier])
    limit_break_started.emit(character)
    return true

## Set the active CharacterInputProfile for this combat.
## Configures both the attack evaluator (from profile.attack_evaluator) and
## the defense type seam (from profile.defense_pattern_type).
## Also calls RhythmInput.set_active_profile so input filtering matches.
func set_active_profile(profile) -> void:
    _active_profile = profile
    if profile == null:
        _evaluator = PassthroughEvaluator.new()
        RhythmInput.clear_profile()
    else:
        _evaluator = _create_evaluator(profile.attack_evaluator)
        RhythmInput.set_active_profile(profile)
    _evaluator.reset()

## Returns the active defense pattern type.
## &"directional" = arrow-matching (current default).
## &"percussive"  = timing-only (Beatrice's path, not yet implemented).
func get_defense_type() -> StringName:
    if _active_profile == null:
        return &"directional"
    return _active_profile.defense_pattern_type

## Factory: returns the named evaluator, defaulting to PassthroughEvaluator.
## Add new evaluator classes to this match block when implementing new characters.
func _create_evaluator(name: StringName) -> AttackEvaluator:
    match name:
        &"passthrough":
            return PassthroughEvaluator.new()
        &"beatrice_rhythm":
            return BeatriceEvaluator.new()
        &"luthier_pitch":
            return LuthierEvaluator.new()
        _:
            push_warning("CombatScene: unknown evaluator '%s', using passthrough" % name)
            return PassthroughEvaluator.new()

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
            var lookahead_index: float = float(beat_index + lookahead_beats)
            for note: NoteData in enemy.pattern:
                if abs(note.beat_offset - lookahead_index) < 0.01:
                    note_approaching.emit(note, beat_number + lookahead_beats)

# --- Half-beat pre-injection ---

## Fires at beat_position=0.5 (halfway through each beat).
## Drives two injection calls:
##   1. Pre-inject next whole-beat notes (due half a beat from now) so their
##      expiry window is anchored to the beat moment, not to when they were queued.
##   2. Inject notes due at the current half-beat position (right now).
func _on_half_beat(_beat_number: int) -> void:
    if _combat_ended or _current_phase != Phase.DEFEND:
        return
    var enemy: EnemyData = _get_defending_enemy_internal()
    if enemy == null:
        return
    var half_beat_ms: int = int(float(60.0 / BeatClock.bpm) * 500.0)
    var next_beat_index: int = _phase_beat_count
    # Pre-inject next whole-beat notes only while that beat is within the phase.
    # beat_offset = float(next_beat_index) exists only for beat_index 0..phase_length-1.
    if next_beat_index < enemy.phase_length:
        _inject_notes_due(float(next_beat_index), Time.get_ticks_msec() + half_beat_ms)
    # Inject the current half-beat position regardless of whether the next full beat
    # is within the phase. This fixes the off-by-one that silently dropped the note
    # at beat_offset = phase_length - 0.5 (the last half-beat of the last beat).
    # Guard: pre-phase half_beat (pbc=0) gives half_pos=-0.5 which no real note has.
    var half_pos: float = float(_phase_beat_count - 1) + 0.5
    if half_pos >= 0.0:
        _inject_notes_due(half_pos, Time.get_ticks_msec())

## Fires at beat_position 0.25 and 0.75.
## Injects notes whose beat_offset matches the current quarter-beat position.
func _on_quarter_beat(_beat_number: int) -> void:
    if _combat_ended or _current_phase != Phase.DEFEND:
        return
    var beat_idx: int = _phase_beat_count - 1
    if beat_idx < 0:
        return
    var is_three_quarter: bool = BeatClock.beat_position >= 0.5
    var qb_pos: float = float(beat_idx) + (0.75 if is_three_quarter else 0.25)
    _inject_notes_due(qb_pos, Time.get_ticks_msec())

## Handles chord inputs (e.g. drum_both) in the same way as directional input_scored.
## Emitted by RhythmInput after chord detection; chord_name is the output action name.
func _on_input_chord(chord_name: StringName, score: StringName) -> void:
    if _combat_ended or _current_phase != Phase.DEFEND:
        return
    # input_scored already fired for this chord (with note_consumed state).
    # _on_input_chord is for evaluators / UI only — don't double-handle damage here.

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
        DebugLog.combat("[LB     ] ended — gauge reset")
        limit_break_ended.emit()

    _defend_index = _first_living_enemy_index()
    RhythmInput.clear_notes()
    _current_phase = Phase.DEFEND
    var defending_name: String = _enemy_party[_defend_index].enemy_name if _defend_index < _enemy_party.size() else "?"
    DebugLog.combat("[PHASE  ] ATTACK → DEFEND | defending: %s" % defending_name)
    phase_changed.emit(Phase.DEFEND)

    # Announce DEFEND notes whose normal lookahead window falls before the phase start.
    # note_approaching for beat_offset=k normally fires at beat_index = k - lookahead_beats,
    # which is negative for the first lookahead_beats notes — so they'd never get a visual.
    # Emit them now from the transition beat; note_lane uses target_beat for travel time
    # so the visual duration correctly reflects how long until the note is actually due.
    var early_enemy = _get_defending_enemy_internal()
    if early_enemy != null:
        for note: NoteData in early_enemy.pattern:
            if note.beat_offset < float(lookahead_beats):
                var target_beat: int = BeatClock.beat_number + 1 + note.beat_offset
                note_approaching.emit(note, target_beat)
                DebugLog.timing("[EARLY-A] dir=%-5s  target_beat=%d  (first-beat lookahead, travel=%d beat(s))" % [
                    note.direction, target_beat, note.beat_offset + 1])

    # Safety-net win check: normally triggered per-hit, but covers the edge
    # case where the phase boundary fires before the last scored signal arrives.
    if _all_enemies_dead() and not _combat_ended:
        _combat_ended = true
        teardown()
        DebugLog.combat("[WIN    ] all enemies defeated (safety-net check at phase boundary)")
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
        _evaluator.reset()
        _current_phase = Phase.ATTACK
        DebugLog.combat("[PHASE  ] DEFEND → ATTACK")
        phase_changed.emit(Phase.ATTACK)
    else:
        DebugLog.combat("[PHASE  ] DEFEND turn done | next: %s" % _enemy_party[_defend_index].enemy_name)

# --- Input handlers ---

func _on_input_scored(_direction: StringName, score: StringName, _offset_ms: float, note_consumed: bool) -> void:
    if _combat_ended:
        return
    match _current_phase:
        Phase.ATTACK:
            var character = _get_active_character()
            if character == null:
                return
            # Limit break multiplier stacks on top of the evaluator's combo multiplier.
            var lb_mult: float = character.limit_break_multiplier if _limit_break_active else 1.0
            # Push beat state / direction to evaluators that use them (optional protocol).
            if _evaluator.has_method("set_beat_position"):
                _evaluator.set_beat_position(BeatClock.beat_position)
            if _evaluator.has_method("set_last_direction"):
                _evaluator.set_last_direction(_direction)
            var base_dmg: int = _evaluator.record_hit(score, character.attack_power)
            var target = get_attack_target()
            if base_dmg > 0 and target != null:
                var dmg := int(float(base_dmg) * lb_mult)
                var old_hp: int = target.hp
                target.hp = max(0, old_hp - dmg)
                DebugLog.combat("[ATTACK ] %s | %s → %s for %d | hp %d → %d  (×%.1f combo)" % [
                    score, character.character_name, target.enemy_name, dmg, old_hp, target.hp,
                    _evaluator.get_multiplier()])
            # Charge limit break gauge (only when not in limit break, and only on hit)
            if not _limit_break_active and score != &"miss":
                var was_ready: bool = character.limit_break_gauge >= 1.0
                var charge: float = character.charge_rate_perfect if score == &"perfect" else character.charge_rate_good
                character.limit_break_gauge = min(1.0, character.limit_break_gauge + charge)
                if not was_ready and character.limit_break_gauge >= 1.0:
                    DebugLog.combat("[LB     ] gauge full — %s can activate limit break" % character.character_name)
                    limit_break_ready.emit(character)
            combo_updated.emit(_evaluator.get_combo_count(), _evaluator.get_multiplier())
            # Apply win condition immediately so the enemy bar empties on the killing hit.
            if _all_enemies_dead() and not _combat_ended:
                _combat_ended = true
                teardown()
                DebugLog.combat("[WIN    ] all enemies defeated")
                combat_won.emit()

        Phase.DEFEND:
            var tag := "CONSUMED" if note_consumed else "NO-NOTE (ignored)"
            DebugLog.timing("[INPUT  ] dir=%-5s  offset=%+.1f ms  score=%-8s  %s" % [
                _direction, _offset_ms, score, tag])
            # Route to the appropriate defend handler based on defense_pattern_type.
            match get_defense_type():
                &"directional":
                    _handle_defend_directional(_direction, score, _offset_ms, note_consumed)
                &"percussive":
                    _handle_defend_percussive(_direction, score, _offset_ms, note_consumed)
                _:
                    _handle_defend_directional(_direction, score, _offset_ms, note_consumed)

func _on_note_missed(_note) -> void:
    DebugLog.timing("[EXPIRE ] dir=%-5s  note expired without a press" % _note.direction)
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
    if BeatClock.quarter_beat.is_connected(_on_quarter_beat):
        BeatClock.quarter_beat.disconnect(_on_quarter_beat)
    if RhythmInput.input_scored.is_connected(_on_input_scored):
        RhythmInput.input_scored.disconnect(_on_input_scored)
    if RhythmInput.note_missed.is_connected(_on_note_missed):
        RhythmInput.note_missed.disconnect(_on_note_missed)
    if RhythmInput.input_chord.is_connected(_on_input_chord):
        RhythmInput.input_chord.disconnect(_on_input_chord)
    RhythmInput.clear_notes()

func _exit_tree() -> void:
    teardown()

# --- Helpers ---

## Inject every note in the current enemy's pattern whose beat_offset matches
## phase_pos (within 0.01) into RhythmInput.
## due_time_ms anchors the note's expiry window; pass now for immediate-due notes
## or now+half_beat_ms for pre-injected next-beat notes.
## Single injection path — called by _on_half_beat and _on_quarter_beat.
func _inject_notes_due(phase_pos: float, due_time_ms: int) -> void:
    var enemy: EnemyData = _get_defending_enemy_internal()
    if enemy == null:
        return
    for note: NoteData in enemy.pattern:
        if abs(note.beat_offset - phase_pos) < 0.01:
            if RhythmInput.add_note(note, due_time_ms):
                DebugLog.timing("[INJ    ] dir=%-5s  offset=%.2f" % [note.direction, phase_pos])

## DEFEND handler for defense_pattern_type == &"percussive" (Beatrice Styx).
## Hand-matching: note_consumed == true means the pressed button matched the active
## note's direction. Wrong hand or no note → no block (note will expire → damage).
## Correct hand + perfect timing → full block + small counter-damage to enemy.
## Correct hand + good timing   → full block, no damage either way.
## Correct hand + miss timing   → partial damage to character (50%).
func _handle_defend_percussive(_direction: StringName, score: StringName, _offset_ms: float, note_consumed: bool) -> void:
    if not note_consumed:
        return   # wrong hand or no active note — note will expire → note_missed handles damage
    var enemy     = _get_defending_enemy_internal()
    var character = _get_active_character()
    if enemy == null or character == null:
        return
    match score:
        &"perfect":
            # Block AND deal counter-damage to the enemy.
            var counter: int = max(1, int(float(enemy.attack_power) * 0.25))
            enemy.hp = max(0, enemy.hp - counter)
            DebugLog.combat("[DEFEND ] percussive PERFECT | %s counters %s for %d" % [
                character.character_name, enemy.enemy_name, counter])
            if _all_enemies_dead() and not _combat_ended:
                _combat_ended = true
                teardown()
                DebugLog.combat("[WIN    ] enemy defeated by percussive counter")
                combat_won.emit()
        &"good":
            DebugLog.combat("[DEFEND ] percussive good block | %s ← %s" % [
                character.character_name, enemy.enemy_name])
        &"miss":
            _apply_damage_to_character(character, int(float(enemy.attack_power) * 0.5))

## DEFEND handler for defense_pattern_type == &"directional" (current default).
## Requires note_consumed == true; free-form presses are ignored.
func _handle_defend_directional(_direction: StringName, score: StringName, _offset_ms: float, note_consumed: bool) -> void:
    if not note_consumed:
        return
    var enemy     = _get_defending_enemy_internal()
    var character = _get_active_character()
    if enemy == null or character == null:
        return
    match score:
        &"perfect":
            DebugLog.combat("[DEFEND ] perfect block | %s ← %s | no damage" % [
                character.character_name, enemy.enemy_name])
        &"good":
            _apply_damage_to_character(character, int(float(enemy.attack_power) * 0.5))
        &"miss":
            _apply_damage_to_character(character, enemy.attack_power)

## Applies damage and checks loss condition.
func _apply_damage_to_character(character: CharacterData, damage: int) -> void:
    if _combat_ended:
        return
    var old_hp: int = character.hp
    character.hp = max(0, old_hp - damage)
    DebugLog.combat("[DEFEND ] %s took %d dmg | hp %d → %d/%d" % [
        character.character_name, damage, old_hp, character.hp, character.max_hp])
    if _all_characters_dead():
        _combat_ended = true
        teardown()
        DebugLog.combat("[LOST   ] all player characters defeated")
        combat_lost.emit()

## First living CharacterData in party (prototype: always the same character takes hits).
func _get_active_character() -> CharacterData:
    for c: CharacterData in _player_party:
        if c.hp > 0:
            return c
    return null

## Internal version for use within this script (no phase guard).
func _get_defending_enemy_internal() -> EnemyData:
    if _defend_index < _enemy_party.size():
        var e: EnemyData = _enemy_party[_defend_index]
        if e.hp > 0:
            return e
    return null

func _first_living_enemy_index() -> int:
    for i in range(_enemy_party.size()):
        var e: EnemyData = _enemy_party[i]
        if e.hp > 0:
            return i
    return _enemy_party.size()  # all dead

func _all_enemies_dead() -> bool:
    for e: EnemyData in _enemy_party:
        if e.hp > 0:
            return false
    return true

func _all_characters_dead() -> bool:
    for c: CharacterData in _player_party:
        if c.hp > 0:
            return false
    return true
