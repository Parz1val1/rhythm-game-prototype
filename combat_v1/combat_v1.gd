# combat_v1/combat_v1.gd
# Isolated Combat System v1 cadence and encounter-wide state seam.
# Later slices own authored performances and production of explicit state results.
class_name CombatV1
extends Node

const DebugLog = preload("res://autoloads/debug_log.gd")
const EncounterState = preload("res://combat_v1/encounter_state.gd")

## Public aliases keep encounter commands and configuration discoverable at the
## CombatV1 seam while EncounterState remains the single owner of their behavior.
const EncounterConfig = EncounterState.Config
const Execution = EncounterState.Execution
const TacticalEffectiveness = EncounterState.TacticalEffectiveness
const Outcome = EncounterState.Outcome

## Observable conversation cadence. The values are intentionally domain-specific and
## do not mirror the legacy combat phase graph.
enum Cadence {
	IDLE,
	SETTLE,
	ENEMY_PHRASE,
	RESPONSE,
	TACTICAL_VAMP,
	CHARACTER_PERFORMANCE,
	FULL_BAND_VAMP,
	RESOLUTION,
}

## Typed commands accepted by player_intent(). The final performance-sequence
## boundary is an inert Issue #9 placeholder for later party/performance slices.
enum Intent {
	SUBMIT_RESPONSE,
	SELECT_PERFORMANCE,
	COMPLETE_PERFORMANCE,
	COMPLETE_PERFORMANCE_SEQUENCE,
}

const _CADENCE_NAMES: Array[StringName] = [
	&"Idle",
	&"Settle",
	&"Enemy Phrase",
	&"Response",
	&"Tactical Vamp",
	&"Character Performance",
	&"Full-Band Vamp",
	&"Resolution",
]

## Emitted whenever the observable cadence changes. The payload is a typed Cadence value;
## use get_cadence_name() when a display label is needed.
signal cadence_changed(cadence: Cadence)
## Emitted for every accepted typed player intent.
signal player_intent_received(intent: Intent)
## Emitted when a known or unknown intent cannot be accepted in the current state.
signal intent_rejected(intent: Intent)
## Emitted when the shared timing/input seam reports a scored input.
signal rhythm_input_observed(direction: StringName, score: StringName, offset_ms: float)
## Emitted after an accepted performance result changes encounter-wide state.
signal encounter_state_changed(state: Dictionary)
## Emitted exactly once when Groove or Composure makes the encounter terminal.
signal resolved(outcome: EncounterState.Outcome)
## Emitted when this module begins listening to its dependencies.
signal started()
## Emitted when this module stops listening to its dependencies.
signal stopped()

## Number of beats spent in the initial Settle cadence.
@export var settle_beats: int = 2
## Number of beats spent presenting the authored Enemy Phrase placeholder.
@export var enemy_phrase_beats: int = 4

var _beat_clock: Node = null
var _rhythm_input: Node = null
var _cadence: Cadence = Cadence.IDLE
var _beats_in_cadence: int = 0
var _running: bool = false
var _last_intent: int = -1
var _encounter_state = EncounterState.new()

func _init() -> void:
	_encounter_state.state_changed.connect(_on_encounter_state_changed)
	_encounter_state.resolved.connect(_on_encounter_resolved)

## Bind the module to the existing timing and input infrastructure.
## Dependencies are injectable for headless tests; omitted dependencies resolve to
## the project's BeatClock and RhythmInput autoloads after this node enters the tree.
func setup(
	beat_clock: Node = null,
	rhythm_input: Node = null,
	settle_length: int = 2,
	enemy_phrase_length: int = 4,
	encounter_config: EncounterState.Config = null
) -> void:
	if _running:
		teardown()
	_beat_clock = beat_clock if beat_clock != null else _find_dependency(&"BeatClock")
	_rhythm_input = rhythm_input if rhythm_input != null else _find_dependency(&"RhythmInput")
	settle_beats = maxi(1, settle_length)
	enemy_phrase_beats = maxi(1, enemy_phrase_length)
	_cadence = Cadence.IDLE
	_beats_in_cadence = 0
	_last_intent = -1
	_encounter_state.setup(encounter_config)

## Start observing the injected timing and input dependencies.
## Returns false when the timing dependency is unavailable or when already running.
func start() -> bool:
	if _running:
		return false
	if _beat_clock == null:
		_beat_clock = _find_dependency(&"BeatClock")
	if _rhythm_input == null:
		_rhythm_input = _find_dependency(&"RhythmInput")
	if _beat_clock == null or not _beat_clock.has_signal(&"beat"):
		push_warning("CombatV1: cannot start without a BeatClock-compatible dependency")
		return false
	_running = true
	_beats_in_cadence = 0
	_last_intent = -1
	_encounter_state.reset()
	_connect_dependencies()
	DebugLog.combat("[V1    ] started | settle=%d  enemy_phrase=%d" % [settle_beats, enemy_phrase_beats])
	_set_cadence(Cadence.SETTLE)
	started.emit()
	return true

## Submit a typed intent at the current cadence. Unknown values and commands that are
## not valid for the current cadence return false and emit intent_rejected.
func player_intent(intent: Intent) -> bool:
	if not _running:
		return false
	if intent < Intent.SUBMIT_RESPONSE or intent > Intent.COMPLETE_PERFORMANCE_SEQUENCE:
		DebugLog.combat("[V1    ] intent=rejected  reason=unknown  value=%d" % intent)
		intent_rejected.emit(intent)
		return false

	var accepted := false
	match _cadence:
		Cadence.RESPONSE:
			if intent == Intent.SUBMIT_RESPONSE:
				_set_cadence(Cadence.TACTICAL_VAMP)
				accepted = true
		Cadence.TACTICAL_VAMP:
			if intent == Intent.SELECT_PERFORMANCE:
				_set_cadence(Cadence.CHARACTER_PERFORMANCE)
				accepted = true
			elif intent == Intent.COMPLETE_PERFORMANCE_SEQUENCE:
				# Later issues own party ordering; this explicit command is the only
				# Issue #9 placeholder boundary into Full-Band Vamp.
				_set_cadence(Cadence.FULL_BAND_VAMP)
				accepted = true
		Cadence.CHARACTER_PERFORMANCE:
			if intent == Intent.COMPLETE_PERFORMANCE:
				_set_cadence(Cadence.TACTICAL_VAMP)
				accepted = true
		_:
			pass

	if accepted:
		_last_intent = intent
		player_intent_received.emit(intent)
	else:
		DebugLog.combat("[V1    ] intent=rejected  reason=cadence  value=%d  cadence=%s" % [intent, get_cadence_name()])
		intent_rejected.emit(intent)
	return accepted

## Apply one explicit performance result through the owned encounter state model.
## Results are independent of cadence, input, timing, presentation, and legacy combat.
func apply_performance_result(
	execution: EncounterState.Execution,
	effectiveness: EncounterState.TacticalEffectiveness
) -> bool:
	if not _running:
		return false
	return _encounter_state.apply_performance_result(execution, effectiveness)

## Return a stable, public snapshot for UI and headless tests.
func get_state() -> Dictionary:
	var state: Dictionary = _encounter_state.get_state()
	state.merge({
		&"cadence": _cadence,
		&"cadence_name": get_cadence_name(),
		&"beat_count": _beats_in_cadence,
		&"running": _running,
		&"last_intent": _last_intent,
	})
	return state

## Return the enum value for consumers that prefer typed branching.
func get_cadence() -> Cadence:
	return _cadence

## Return the human-readable public cadence name.
func get_cadence_name() -> StringName:
	return _CADENCE_NAMES[_cadence]

func is_running() -> bool:
	return _running

## Disconnect only this module's listeners. It does not mutate shared input state.
## Safe to call repeatedly and also called from _exit_tree().
func teardown() -> void:
	_disconnect_dependencies()
	if not _running:
		return
	_running = false
	DebugLog.combat("[V1    ] stopped")
	_set_cadence(Cadence.IDLE)
	stopped.emit()

func _on_beat(_beat_number: int) -> void:
	if not _running:
		return
	if _cadence != Cadence.SETTLE and _cadence != Cadence.ENEMY_PHRASE:
		return
	_beats_in_cadence += 1
	if _cadence == Cadence.SETTLE and _beats_in_cadence >= settle_beats:
		_set_cadence(Cadence.ENEMY_PHRASE)
	elif _cadence == Cadence.ENEMY_PHRASE and _beats_in_cadence >= enemy_phrase_beats:
		_set_cadence(Cadence.RESPONSE)

func _on_input_scored(
	direction: StringName,
	score: StringName,
	offset_ms: float,
	_note_consumed: bool
) -> void:
	if _running:
		DebugLog.timing("[INPUT  ] v1_direction=%-5s  score=%-8s  offset=%+.1f ms" % [direction, score, offset_ms])
		rhythm_input_observed.emit(direction, score, offset_ms)

func _on_encounter_state_changed(state: Dictionary) -> void:
	encounter_state_changed.emit(state)

func _on_encounter_resolved(outcome: EncounterState.Outcome) -> void:
	_set_cadence(Cadence.RESOLUTION)
	resolved.emit(outcome)

func _set_cadence(next_cadence: Cadence) -> void:
	if _cadence == next_cadence:
		return
	_cadence = next_cadence
	_beats_in_cadence = 0
	DebugLog.combat("[V1    ] cadence=%s" % get_cadence_name())
	cadence_changed.emit(_cadence)

func _connect_dependencies() -> void:
	var beat_signal: Signal = Signal(_beat_clock, &"beat")
	if not beat_signal.is_connected(_on_beat):
		beat_signal.connect(_on_beat)
	if _rhythm_input != null and _rhythm_input.has_signal(&"input_scored"):
		var input_signal: Signal = Signal(_rhythm_input, &"input_scored")
		if not input_signal.is_connected(_on_input_scored):
			input_signal.connect(_on_input_scored)

func _disconnect_dependencies() -> void:
	if _beat_clock != null and _beat_clock.has_signal(&"beat"):
		var beat_signal: Signal = Signal(_beat_clock, &"beat")
		if beat_signal.is_connected(_on_beat):
			beat_signal.disconnect(_on_beat)
	if _rhythm_input != null and _rhythm_input.has_signal(&"input_scored"):
		var input_signal: Signal = Signal(_rhythm_input, &"input_scored")
		if input_signal.is_connected(_on_input_scored):
			input_signal.disconnect(_on_input_scored)

func _find_dependency(node_name: StringName) -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))

func _exit_tree() -> void:
	teardown()
