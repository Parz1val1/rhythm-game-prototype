# combat_v1/combat_v1.gd
# Isolated Combat System v1 cadence and encounter-wide state seam.
# Later slices own authored performances and production of explicit state results.
class_name CombatV1
extends Node

const DebugLog = preload("res://autoloads/debug_log.gd")
const EncounterState = preload("res://combat_v1/encounter_state.gd")
const OpponentData = preload("res://combat_v1/opponent_data.gd")
const OpponentPhrase = preload("res://combat_v1/opponent_phrase.gd")
const PhraseEvent = preload("res://combat_v1/phrase_event.gd")
const CharacterInputProfile = preload("res://characters/character_input_profile.gd")
const ResponseGrader = preload("res://combat_v1/response_grader.gd")
const DEFAULT_OPPONENT: OpponentData = preload("res://combat_v1/opponents/drum_golem.tres")
const DEFAULT_RESPONSE_PROFILE: CharacterInputProfile = preload("res://characters/luthier_profile.tres")

## Public aliases keep encounter commands and configuration discoverable at the
## CombatV1 seam while EncounterState remains the single owner of their behavior.
const EncounterConfig = EncounterState.Config
const Execution = EncounterState.Execution
const TacticalEffectiveness = EncounterState.TacticalEffectiveness
const Outcome = EncounterState.Outcome
const ResponseConfig = ResponseGrader.Config
const ResponseGrade = ResponseGrader.Grade

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
## Single source of truth for both audio and visual phrase presentation.
signal phrase_event_announced(event: PhraseEvent)
## Presents the heard phrase as scoreable actions in the active rhythm language.
signal response_target_announced(event: PhraseEvent, expected_action: StringName)
## Emitted after an accepted Response action receives its six-level note grade.
signal response_note_graded(result: Dictionary)
## Emitted once when Response is submitted, after every target has a note result.
signal response_phrase_graded(summary: Dictionary)
## Emitted after an accepted performance result changes encounter-wide state.
signal encounter_state_changed(state: Dictionary)
## Emitted exactly once when Groove or Composure makes the encounter terminal.
signal resolved(outcome: EncounterState.Outcome)
## Emitted when this module begins listening to its dependencies.
signal started()
## Emitted when this module stops listening to its dependencies.
signal stopped()

## Number of four-beat bars spent in the input-free initial Settle cadence.
@export_range(1, 8, 1) var settle_bars: int = 2

var _beat_clock: Node = null
var _rhythm_input: Node = null
var _opponent: OpponentData = null
var _response_actions: Array[StringName] = []
var _response_targets: Array[Dictionary] = []
var _response_grader = ResponseGrader.new()
var _last_response_summary: Dictionary = {}
var _cadence: Cadence = Cadence.IDLE
var _beats_in_cadence: int = 0
var _running: bool = false
var _last_intent: int = -1
var _scoring_suppressed: bool = false
var _previous_scoring_enabled: bool = true
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
	opponent_data: OpponentData = null,
	settle_length_bars: int = 2,
	encounter_config: EncounterState.Config = null,
	response_profile: CharacterInputProfile = null,
	response_config: ResponseGrader.Config = null
) -> void:
	if _running:
		teardown()
	_beat_clock = beat_clock if beat_clock != null else _find_dependency(&"BeatClock")
	_rhythm_input = rhythm_input if rhythm_input != null else _find_dependency(&"RhythmInput")
	var opponent_template: OpponentData = opponent_data if opponent_data != null else DEFAULT_OPPONENT
	_opponent = opponent_template.duplicate(true) as OpponentData
	var profile_template: CharacterInputProfile = \
		response_profile if response_profile != null else DEFAULT_RESPONSE_PROFILE
	var live_response_profile := profile_template.duplicate(true) as CharacterInputProfile
	_response_actions = _get_response_actions(live_response_profile)
	_response_grader.setup(response_config)
	_last_response_summary.clear()
	settle_bars = maxi(1, settle_length_bars)
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
	if _opponent == null or _opponent.phrase == null:
		push_warning("CombatV1: cannot start without an authored opponent phrase")
		return false
	_running = true
	_beats_in_cadence = 0
	_last_intent = -1
	_encounter_state.reset()
	_prepare_response_targets()
	_last_response_summary.clear()
	_connect_dependencies()
	DebugLog.combat("[V1    ] status=started  settle_bars=%d  opponent=%s  phrase=%s" % [
		settle_bars, _opponent.opponent_id, _opponent.phrase.phrase_id])
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
				_complete_response()
				if not bool(_encounter_state.get_state()[&"terminal"]):
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

## Record one action at an absolute beat offset within the active Response phrase.
## Returns false outside Response; grading is owned by the Response grader seam.
func submit_response_input(action: StringName, phrase_position_beats: float) -> bool:
	if not _running or _cadence != Cadence.RESPONSE:
		return false
	var target_index := _find_closest_ungraded_response_target(phrase_position_beats)
	if target_index < 0:
		return false
	var target: Dictionary = _response_targets[target_index]
	var milliseconds_per_beat := _get_milliseconds_per_beat()
	var offset_ms := (
		phrase_position_beats - float(target[&"beat_offset"])
	) * milliseconds_per_beat
	var result: Dictionary = _response_grader.grade_note(
		target[&"expected_action"],
		action,
		offset_ms
	)
	result[&"target_index"] = target_index
	result[&"beat_offset"] = target[&"beat_offset"]
	target[&"graded"] = true
	target[&"result"] = result.duplicate(true)
	_response_targets[target_index] = target
	DebugLog.timing("[GRADE  ] target=%d  expected=%s  actual=%s  offset=%+.1f ms  grade=%s" % [
		target_index,
		target[&"expected_action"],
		action,
		offset_ms,
		result[&"grade_name"],
	])
	response_note_graded.emit(result.duplicate(true))
	return true

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
	var opponent_id: StringName = &""
	var opponent_name := ""
	var phrase_id: StringName = &""
	var phrase_name := ""
	var phrase_duration_beats := 0
	if _opponent != null:
		opponent_id = _opponent.opponent_id
		opponent_name = _opponent.display_name
		if _opponent.phrase != null:
			phrase_id = _opponent.phrase.phrase_id
			phrase_name = _opponent.phrase.display_name
			phrase_duration_beats = _opponent.phrase.get_duration_beats()
	state.merge({
		&"cadence": _cadence,
		&"cadence_name": get_cadence_name(),
		&"beat_count": _beats_in_cadence,
		&"settle_bars": settle_bars,
		&"settle_duration_beats": settle_bars * OpponentPhrase.BEATS_PER_BAR,
		&"opponent_id": opponent_id,
		&"opponent_name": opponent_name,
		&"phrase_id": phrase_id,
		&"phrase_name": phrase_name,
		&"phrase_duration_beats": phrase_duration_beats,
		&"response_summary": _last_response_summary.duplicate(true),
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

## Disconnect only this module's listeners and restore the prior shared scoring
## state without changing the active input profile. Safe to call repeatedly and
## also called from _exit_tree().
func teardown() -> void:
	_disconnect_dependencies()
	_restore_scoring_state()
	if not _running:
		return
	_running = false
	DebugLog.combat("[V1    ] stopped")
	_set_cadence(Cadence.IDLE)
	stopped.emit()

func _on_beat(_beat_number: int) -> void:
	if not _running:
		return
	if _cadence != Cadence.SETTLE and _cadence != Cadence.ENEMY_PHRASE \
		and _cadence != Cadence.RESPONSE:
		return
	_beats_in_cadence += 1
	if _cadence == Cadence.RESPONSE:
		if _beats_in_cadence < _opponent.phrase.get_duration_beats():
			_announce_response_targets_at(float(_beats_in_cadence))
		return
	if _cadence == Cadence.SETTLE \
		and _beats_in_cadence >= settle_bars * OpponentPhrase.BEATS_PER_BAR:
		_set_cadence(Cadence.ENEMY_PHRASE)
		_announce_phrase_events_at(0.0)
	elif _cadence == Cadence.ENEMY_PHRASE:
		if _beats_in_cadence >= _opponent.phrase.get_duration_beats():
			_set_cadence(Cadence.RESPONSE)
		else:
			_announce_phrase_events_at(float(_beats_in_cadence))

func _on_half_beat(_beat_number: int) -> void:
	if not _running:
		return
	if _cadence == Cadence.ENEMY_PHRASE:
		_announce_phrase_events_at(float(_beats_in_cadence) + 0.5)
	elif _cadence == Cadence.RESPONSE:
		_announce_response_targets_at(float(_beats_in_cadence) + 0.5)

func _on_quarter_beat(_beat_number: int, subdivision: float = -1.0) -> void:
	if not _running or (_cadence != Cadence.ENEMY_PHRASE and _cadence != Cadence.RESPONSE):
		return
	var exact_subdivision := subdivision
	if exact_subdivision < 0.0:
		var raw_position: Variant = _beat_clock.get("beat_position")
		if typeof(raw_position) != TYPE_FLOAT and typeof(raw_position) != TYPE_INT:
			return
		exact_subdivision = 0.25 if float(raw_position) < 0.5 else 0.75
	if _cadence == Cadence.ENEMY_PHRASE:
		_announce_phrase_events_at(float(_beats_in_cadence) + exact_subdivision)
	else:
		_announce_response_targets_at(float(_beats_in_cadence) + exact_subdivision)

func _announce_phrase_events_at(phrase_position: float) -> void:
	if _opponent == null or _opponent.phrase == null:
		return
	for event in _opponent.phrase.events:
		if not is_equal_approx(event.beat_offset, phrase_position):
			continue
		DebugLog.timing("[PHRASE ] opponent=%s  phrase=%s  offset=%.2f  prompt=%s" % [
			_opponent.opponent_id, _opponent.phrase.phrase_id, event.beat_offset, event.prompt_id])
		phrase_event_announced.emit(event)

func _announce_response_targets_at(phrase_position: float) -> void:
	if _opponent == null or _opponent.phrase == null:
		return
	for target in _response_targets:
		if not is_equal_approx(float(target[&"beat_offset"]), phrase_position):
			continue
		var event: PhraseEvent = target[&"event"]
		var expected_action: StringName = target[&"expected_action"]
		DebugLog.timing("[RESPONSE] phrase=%s  offset=%.2f  action=%s" % [
			_opponent.phrase.phrase_id, event.beat_offset, expected_action])
		response_target_announced.emit(event, expected_action)

func _prepare_response_targets() -> void:
	_response_targets.clear()
	if _opponent == null or _opponent.phrase == null:
		return
	for event_index in range(_opponent.phrase.events.size()):
		var event: PhraseEvent = _opponent.phrase.events[event_index]
		_response_targets.append({
			&"event": event,
			&"beat_offset": event.beat_offset,
			&"expected_action": _response_actions[event_index % _response_actions.size()],
			&"graded": false,
		})

func _complete_response() -> Dictionary:
	var ordered_results: Array[Dictionary] = []
	for target_index in range(_response_targets.size()):
		var target: Dictionary = _response_targets[target_index]
		var result: Dictionary
		if bool(target[&"graded"]):
			result = target[&"result"]
		else:
			result = _response_grader.grade_note(
				target[&"expected_action"],
				&"",
				INF
			)
			result[&"target_index"] = target_index
			result[&"beat_offset"] = target[&"beat_offset"]
			target[&"graded"] = true
			target[&"result"] = result.duplicate(true)
			_response_targets[target_index] = target
			response_note_graded.emit(result.duplicate(true))
		ordered_results.append(result.duplicate(true))
	_last_response_summary = _response_grader.summarize(ordered_results)
	DebugLog.combat("[RESPONSE] phrase=%s  grade=%d  notes=%d  broken=%s" % [
		_opponent.phrase.phrase_id,
		_last_response_summary[&"grade"],
		_last_response_summary[&"total_notes"],
		_last_response_summary[&"broken"],
	])
	_encounter_state.apply_performance_result(
		_get_execution_for_response_grade(_last_response_summary[&"grade"]),
		EncounterState.TacticalEffectiveness.EFFECTIVE
	)
	response_phrase_graded.emit(_last_response_summary.duplicate(true))
	return _last_response_summary.duplicate(true)

func _get_execution_for_response_grade(grade: ResponseGrader.Grade) -> EncounterState.Execution:
	match grade:
		ResponseGrader.Grade.PERFECT, ResponseGrader.Grade.GREAT, ResponseGrader.Grade.GOOD:
			return EncounterState.Execution.CORRECT
		ResponseGrader.Grade.NEAR_MISS:
			return EncounterState.Execution.NEAR_MISS
		ResponseGrader.Grade.MISS:
			return EncounterState.Execution.MISTAKE
		_:
			return EncounterState.Execution.MAJOR_MISTAKE

func _find_closest_ungraded_response_target(phrase_position_beats: float) -> int:
	var closest_index := -1
	var closest_distance := INF
	for target_index in range(_response_targets.size()):
		var target: Dictionary = _response_targets[target_index]
		if bool(target[&"graded"]):
			continue
		var distance := absf(phrase_position_beats - float(target[&"beat_offset"]))
		if distance < closest_distance:
			closest_distance = distance
			closest_index = target_index
	return closest_index

func _get_milliseconds_per_beat() -> float:
	if _beat_clock != null:
		var raw_bpm: Variant = _beat_clock.get("bpm")
		if (typeof(raw_bpm) == TYPE_FLOAT or typeof(raw_bpm) == TYPE_INT) \
			and float(raw_bpm) > 0.0:
			return 60000.0 / float(raw_bpm)
	return 500.0

func _get_response_actions(profile: CharacterInputProfile) -> Array[StringName]:
	var actions: Array[StringName] = []
	if profile != null:
		for mapped_action in profile.input_map.values():
			var action := StringName(mapped_action)
			if action != &"" and action not in actions:
				actions.append(action)
	if actions.is_empty():
		actions.append(&"up")
		actions.append(&"right")
		actions.append(&"down")
		actions.append(&"left")
	else:
		actions.sort()
	return actions

func _on_input_scored(
	direction: StringName,
	score: StringName,
	offset_ms: float,
	_note_consumed: bool
) -> void:
	if not _running:
		return
	if _cadence == Cadence.SETTLE or _cadence == Cadence.ENEMY_PHRASE:
		DebugLog.timing("[INPUT  ] v1_direction=%-5s  cadence=%s  ignored=true" % [
			direction, get_cadence_name()])
		return
	if _cadence == Cadence.RESPONSE:
		var beat_position := 0.0
		if _beat_clock != null:
			var raw_position: Variant = _beat_clock.get("beat_position")
			if typeof(raw_position) == TYPE_FLOAT or typeof(raw_position) == TYPE_INT:
				beat_position = float(raw_position)
		submit_response_input(direction, float(_beats_in_cadence) + beat_position)
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
	if _cadence == Cadence.SETTLE or _cadence == Cadence.ENEMY_PHRASE:
		_suppress_scoring_for_listening()
	else:
		_restore_scoring_state()
	DebugLog.combat("[V1    ] cadence=%s" % get_cadence_name())
	cadence_changed.emit(_cadence)
	if _cadence == Cadence.RESPONSE:
		_announce_response_targets_at(0.0)

func _suppress_scoring_for_listening() -> void:
	if _scoring_suppressed or _rhythm_input == null \
		or not _rhythm_input.has_method(&"set_scoring_enabled"):
		return
	_previous_scoring_enabled = true
	if _rhythm_input.has_method(&"is_scoring_enabled"):
		_previous_scoring_enabled = bool(_rhythm_input.call(&"is_scoring_enabled"))
	_rhythm_input.call(&"set_scoring_enabled", false)
	_scoring_suppressed = true
	DebugLog.timing("[INPUT  ] scoring=disabled  reason=listening")

func _restore_scoring_state() -> void:
	if not _scoring_suppressed:
		return
	if _rhythm_input != null and _rhythm_input.has_method(&"set_scoring_enabled"):
		_rhythm_input.call(&"set_scoring_enabled", _previous_scoring_enabled)
	DebugLog.timing("[INPUT  ] scoring=%s  reason=restore" % [
		"enabled" if _previous_scoring_enabled else "disabled"])
	_scoring_suppressed = false

func _connect_dependencies() -> void:
	var beat_signal: Signal = Signal(_beat_clock, &"beat")
	if not beat_signal.is_connected(_on_beat):
		beat_signal.connect(_on_beat)
	if _beat_clock.has_signal(&"half_beat"):
		var half_beat_signal: Signal = Signal(_beat_clock, &"half_beat")
		if not half_beat_signal.is_connected(_on_half_beat):
			half_beat_signal.connect(_on_half_beat)
	if _beat_clock.has_signal(&"quarter_beat"):
		var quarter_beat_signal: Signal = Signal(_beat_clock, &"quarter_beat")
		if not quarter_beat_signal.is_connected(_on_quarter_beat):
			quarter_beat_signal.connect(_on_quarter_beat)
	if _rhythm_input != null and _rhythm_input.has_signal(&"input_scored"):
		var input_signal: Signal = Signal(_rhythm_input, &"input_scored")
		if not input_signal.is_connected(_on_input_scored):
			input_signal.connect(_on_input_scored)

func _disconnect_dependencies() -> void:
	if _beat_clock != null and _beat_clock.has_signal(&"beat"):
		var beat_signal: Signal = Signal(_beat_clock, &"beat")
		if beat_signal.is_connected(_on_beat):
			beat_signal.disconnect(_on_beat)
	if _beat_clock != null and _beat_clock.has_signal(&"half_beat"):
		var half_beat_signal: Signal = Signal(_beat_clock, &"half_beat")
		if half_beat_signal.is_connected(_on_half_beat):
			half_beat_signal.disconnect(_on_half_beat)
	if _beat_clock != null and _beat_clock.has_signal(&"quarter_beat"):
		var quarter_beat_signal: Signal = Signal(_beat_clock, &"quarter_beat")
		if quarter_beat_signal.is_connected(_on_quarter_beat):
			quarter_beat_signal.disconnect(_on_quarter_beat)
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
