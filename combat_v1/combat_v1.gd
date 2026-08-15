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

## Typed commands accepted by player_intent(). Continue Round is the provisional
## Tactical Vamp choice until skills and party performances exist.
enum Intent {
	SUBMIT_RESPONSE,
	CONTINUE_ROUND,
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
const _STABLE_DIRECTION_ACTIONS: Array[StringName] = [
	&"up",
	&"right",
	&"down",
	&"left",
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
## Single source of truth for audio, text, and lane-preview phrase presentation.
## Expected actions come from the prepared Response targets for the active profile.
signal phrase_event_announced(event: PhraseEvent, expected_actions: Array[StringName])
## Presents one heard cue as one or more simultaneous scoreable actions in the
## active rhythm language.
signal response_target_announced(event: PhraseEvent, expected_actions: Array[StringName])
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
## Provisional amount of readable highway travel before the first Response target.
## This is playtest tuning, not a canonical phrase-duration rule.
@export_range(0.25, 8.0, 0.25) var response_visual_lead_beats: float = 2.0
## Provisional input-free rest between Enemy Phrase and visible Response notation.
## The fixed four-beat default is playtest tuning, not a final cadence rule.
@export_range(0.0, 16.0, 0.25) var response_handoff_beats: float = 4.0

var _beat_clock: Node = null
var _rhythm_input: Node = null
var _opponent: OpponentData = null
var _response_actions: Array[StringName] = []
var _response_targets: Array[Dictionary] = []
var _response_round_id: int = 0
var _response_schedule_lead_beats: float = 2.0
var _response_schedule_handoff_beats: float = 4.0
var _response_timeline_origin_beats: float = 0.0
var _response_handoff_complete: bool = true
var _announced_phrase_event_indices: Array[int] = []
var _response_grader = ResponseGrader.new()
var _last_response_summary: Dictionary = {}
var _cadence: Cadence = Cadence.IDLE
var _beats_in_cadence: int = 0
var _running: bool = false
var _last_intent: int = -1
var _next_round_pending: bool = false
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
	_response_round_id = 0
	_response_timeline_origin_beats = 0.0
	settle_bars = maxi(1, settle_length_bars)
	_cadence = Cadence.IDLE
	_beats_in_cadence = 0
	_last_intent = -1
	_next_round_pending = false
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
	_next_round_pending = false
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
	if _cadence == Cadence.RESPONSE:
		_update_response_handoff_boundary()
	if intent < Intent.SUBMIT_RESPONSE or intent > Intent.CONTINUE_ROUND:
		DebugLog.combat("[V1    ] intent=rejected  reason=unknown  value=%d" % intent)
		intent_rejected.emit(intent)
		return false

	var accepted := false
	match _cadence:
		Cadence.RESPONSE:
			if intent == Intent.SUBMIT_RESPONSE and _response_handoff_complete:
				_complete_response()
				if not bool(_encounter_state.get_state()[&"terminal"]):
					_set_cadence(Cadence.TACTICAL_VAMP)
				accepted = true
		Cadence.TACTICAL_VAMP:
			if intent == Intent.CONTINUE_ROUND and not _next_round_pending:
				_next_round_pending = true
				DebugLog.combat("[V1    ] next_round=pending  transition=next_beat")
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
	if phrase_position_beats < _response_schedule_handoff_beats:
		return false
	_complete_response_handoff(phrase_position_beats)
	var target_index := _find_closest_ungraded_response_target(action, phrase_position_beats)
	if target_index < 0:
		return false
	var target: Dictionary = _response_targets[target_index]
	var milliseconds_per_beat := _get_milliseconds_per_beat()
	var offset_ms := (
		phrase_position_beats - float(target[&"due_beat"])
	) * milliseconds_per_beat
	var result: Dictionary = _response_grader.grade_note(
		target[&"expected_action"],
		action,
		offset_ms
	)
	result[&"target_index"] = target_index
	result[&"target_id"] = target[&"target_id"]
	result[&"beat_offset"] = target[&"beat_offset"]
	result[&"due_beat"] = target[&"due_beat"]
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

## Return the complete active Response schedule and its current musical position.
## Presentation adapters poll this snapshot so BeatClock remains the only timing
## authority and late frames recover from current audio-corrected musical time.
func get_response_presentation() -> Dictionary:
	var presentation_targets: Array[Dictionary] = []
	if _cadence == Cadence.RESPONSE:
		for target in _response_targets:
			presentation_targets.append({
				&"target_id": target[&"target_id"],
				&"expected_action": target[&"expected_action"],
				&"beat_offset": target[&"beat_offset"],
				&"due_beat": target[&"due_beat"],
			})
	var phrase_duration_beats := 0.0
	if _opponent != null and _opponent.phrase != null:
		phrase_duration_beats = float(_opponent.phrase.get_duration_beats())
	var timeline_position_beats := _get_response_timeline_position()
	var handoff_active := _running and _cadence == Cadence.RESPONSE \
		and not _response_handoff_complete
	return {
		&"active": _running and _cadence == Cadence.RESPONSE,
		&"timeline_source": &"BeatClock",
		&"timeline_position_beats": timeline_position_beats,
		&"handoff_beats": _response_schedule_handoff_beats,
		&"handoff_active": handoff_active,
		&"visual_lead_beats": _response_schedule_lead_beats,
		&"phrase_duration_beats": phrase_duration_beats,
		&"timeline_duration_beats": _response_schedule_handoff_beats \
			+ _response_schedule_lead_beats + phrase_duration_beats,
		&"round_id": _response_round_id,
		&"targets": presentation_targets,
	}

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
	if _cadence == Cadence.TACTICAL_VAMP:
		if _next_round_pending:
			_next_round_pending = false
			_prepare_response_targets()
			_set_cadence(Cadence.ENEMY_PHRASE)
			_announce_phrase_events_at(0.0)
		return
	if _cadence != Cadence.SETTLE and _cadence != Cadence.ENEMY_PHRASE \
		and _cadence != Cadence.RESPONSE:
		return
	_beats_in_cadence += 1
	if _cadence == Cadence.RESPONSE:
		_update_response_handoff_boundary()
		_announce_response_targets_at(float(_beats_in_cadence))
		return
	if _cadence == Cadence.SETTLE \
		and _beats_in_cadence >= settle_bars * OpponentPhrase.BEATS_PER_BAR:
		_set_cadence(Cadence.ENEMY_PHRASE)
		_announce_phrase_events_at(0.0)
	elif _cadence == Cadence.ENEMY_PHRASE:
		if _beats_in_cadence >= _opponent.phrase.get_duration_beats():
			_set_cadence(Cadence.RESPONSE, float(_beat_number))
		else:
			_announce_phrase_events_at(float(_beats_in_cadence))

func _on_half_beat(_beat_number: int) -> void:
	if not _running:
		return
	if _cadence == Cadence.ENEMY_PHRASE:
		_announce_phrase_events_at(float(_beats_in_cadence) + 0.5)
	elif _cadence == Cadence.RESPONSE:
		_update_response_handoff_boundary()
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
		_update_response_handoff_boundary()
		_announce_response_targets_at(float(_beats_in_cadence) + exact_subdivision)

func _announce_phrase_events_at(phrase_position: float) -> void:
	if _opponent == null or _opponent.phrase == null:
		return
	for event_index in range(_opponent.phrase.events.size()):
		var event: PhraseEvent = _opponent.phrase.events[event_index]
		if event_index in _announced_phrase_event_indices \
			or not is_equal_approx(event.beat_offset, phrase_position):
			continue
		_announced_phrase_event_indices.append(event_index)
		var expected_actions := _get_expected_actions_for_event(event_index)
		DebugLog.timing("[PHRASE ] opponent=%s  phrase=%s  offset=%.2f  prompt=%s" % [
			_opponent.opponent_id, _opponent.phrase.phrase_id, event.beat_offset, event.prompt_id])
		phrase_event_announced.emit(event, expected_actions)

func _announce_response_targets_at(phrase_position: float) -> void:
	if _opponent == null or _opponent.phrase == null:
		return
	var event_indices: Array[int] = []
	for target in _response_targets:
		if not is_equal_approx(float(target[&"due_beat"]), phrase_position):
			continue
		var event_index: int = target[&"event_index"]
		if event_index not in event_indices:
			event_indices.append(event_index)
	for event_index in event_indices:
		var event: PhraseEvent = _opponent.phrase.events[event_index]
		var expected_actions := _get_expected_actions_for_event(event_index)
		DebugLog.timing("[RESPONSE] phrase=%s  offset=%.2f  actions=%s" % [
			_opponent.phrase.phrase_id,
			event.beat_offset,
			"+".join(expected_actions),
		])
		response_target_announced.emit(event, expected_actions)

func _get_expected_actions_for_event(event_index: int) -> Array[StringName]:
	var expected_actions: Array[StringName] = []
	for target in _response_targets:
		if int(target[&"event_index"]) == event_index:
			expected_actions.append(target[&"expected_action"])
	return expected_actions

func _prepare_response_targets() -> void:
	_response_targets.clear()
	_announced_phrase_event_indices.clear()
	if _opponent == null or _opponent.phrase == null:
		return
	_response_round_id += 1
	_response_schedule_lead_beats = maxf(0.25, response_visual_lead_beats)
	_response_schedule_handoff_beats = maxf(0.0, response_handoff_beats)
	_response_handoff_complete = _response_schedule_handoff_beats <= 0.0
	if _response_actions.is_empty():
		return
	for event_index in range(_opponent.phrase.events.size()):
		var event: PhraseEvent = _opponent.phrase.events[event_index]
		var lane_count := mini(clampi(event.lane_count, 1, 4), _response_actions.size())
		for chord_lane_index in range(lane_count):
			var target_index := _response_targets.size()
			_response_targets.append({
				&"target_id": StringName("%s:%d:%d" % [
					_opponent.phrase.phrase_id,
					_response_round_id,
					target_index,
				]),
				&"event": event,
				&"event_index": event_index,
				&"chord_lane_index": chord_lane_index,
				&"beat_offset": event.beat_offset,
				&"due_beat": _response_schedule_handoff_beats \
					+ _response_schedule_lead_beats + event.beat_offset,
				&"expected_action": _response_actions[
					(event_index + chord_lane_index) % _response_actions.size()
				],
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
			result[&"target_id"] = target[&"target_id"]
			result[&"beat_offset"] = target[&"beat_offset"]
			result[&"due_beat"] = target[&"due_beat"]
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

func _find_closest_ungraded_response_target(
	action: StringName,
	phrase_position_beats: float
) -> int:
	var closest_index := -1
	var closest_distance := INF
	for target_index in range(_response_targets.size()):
		var target: Dictionary = _response_targets[target_index]
		if bool(target[&"graded"]):
			continue
		var distance := absf(phrase_position_beats - float(target[&"due_beat"]))
		if distance < closest_distance:
			closest_distance = distance
			closest_index = target_index
	if closest_index < 0:
		return -1
	for target_index in range(_response_targets.size()):
		var target: Dictionary = _response_targets[target_index]
		if bool(target[&"graded"]) or target[&"expected_action"] != action:
			continue
		var distance := absf(phrase_position_beats - float(target[&"due_beat"]))
		if is_equal_approx(distance, closest_distance):
			return target_index
	return closest_index

func _get_milliseconds_per_beat() -> float:
	if _beat_clock != null:
		var raw_bpm: Variant = _beat_clock.get("bpm")
		if (typeof(raw_bpm) == TYPE_FLOAT or typeof(raw_bpm) == TYPE_INT) \
			and float(raw_bpm) > 0.0:
			return 60000.0 / float(raw_bpm)
	return 500.0

func _get_response_timeline_position() -> float:
	if not _running or _cadence != Cadence.RESPONSE:
		return 0.0
	var atomic_position := _get_atomic_beat_clock_position()
	if atomic_position >= 0.0:
		return maxf(0.0, atomic_position - _response_timeline_origin_beats)
	var beat_position := 0.0
	if _beat_clock != null:
		var raw_position: Variant = _beat_clock.get("beat_position")
		if typeof(raw_position) == TYPE_FLOAT or typeof(raw_position) == TYPE_INT:
			beat_position = float(raw_position)
	return float(_beats_in_cadence) + beat_position

func _get_atomic_beat_clock_position() -> float:
	if _beat_clock == null or not _beat_clock.has_method(&"is_running") \
		or not _beat_clock.has_method(&"get_musical_position_beats"):
		return -1.0
	if not bool(_beat_clock.call(&"is_running")):
		return -1.0
	var raw_position: Variant = _beat_clock.call(&"get_musical_position_beats")
	if typeof(raw_position) != TYPE_FLOAT and typeof(raw_position) != TYPE_INT:
		return -1.0
	return float(raw_position)

func _get_response_actions(profile: CharacterInputProfile) -> Array[StringName]:
	var mapped_actions: Array[StringName] = []
	if profile != null:
		for mapped_action in profile.input_map.values():
			var action := StringName(mapped_action)
			if action != &"" and action not in mapped_actions:
				mapped_actions.append(action)
	var actions: Array[StringName] = []
	for stable_action in _STABLE_DIRECTION_ACTIONS:
		if mapped_actions.is_empty() or stable_action in mapped_actions:
			actions.append(stable_action)
	var remaining_actions: Array[String] = []
	for mapped_action in mapped_actions:
		if mapped_action not in actions:
			remaining_actions.append(String(mapped_action))
	remaining_actions.sort()
	for remaining_action in remaining_actions:
		actions.append(StringName(remaining_action))
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
		submit_response_input(direction, _get_response_timeline_position())
	DebugLog.timing("[INPUT  ] v1_direction=%-5s  score=%-8s  offset=%+.1f ms" % [direction, score, offset_ms])
	rhythm_input_observed.emit(direction, score, offset_ms)

func _on_encounter_state_changed(state: Dictionary) -> void:
	encounter_state_changed.emit(state)

func _on_encounter_resolved(outcome: EncounterState.Outcome) -> void:
	_set_cadence(Cadence.RESOLUTION)
	resolved.emit(outcome)

func _set_cadence(
	next_cadence: Cadence,
	response_origin_beats: float = -1.0
) -> void:
	if _cadence == next_cadence:
		return
	_cadence = next_cadence
	_beats_in_cadence = 0
	if _cadence == Cadence.RESPONSE:
		var atomic_position := _get_atomic_beat_clock_position()
		_response_timeline_origin_beats = response_origin_beats \
			if response_origin_beats >= 0.0 else maxf(0.0, atomic_position)
	if _cadence == Cadence.SETTLE or _cadence == Cadence.ENEMY_PHRASE:
		_suppress_scoring_for_listening()
	elif _cadence != Cadence.RESPONSE or _response_schedule_handoff_beats <= 0.0:
		_restore_scoring_state()
	DebugLog.combat("[V1    ] cadence=%s" % get_cadence_name())
	cadence_changed.emit(_cadence)
	if _cadence == Cadence.RESPONSE:
		DebugLog.timing("[SCHEDULE] phrase=%s  round=%d  targets=%d  handoff=%.2f beats  lead=%.2f beats" % [
			_opponent.phrase.phrase_id,
			_response_round_id,
			_response_targets.size(),
			_response_schedule_handoff_beats,
			_response_schedule_lead_beats,
		])
		_update_response_handoff_boundary()
		_announce_response_targets_at(0.0)

func _update_response_handoff_boundary() -> void:
	if _cadence != Cadence.RESPONSE or _response_handoff_complete:
		return
	var timeline_position := _get_response_timeline_position()
	if timeline_position + 0.0001 < _response_schedule_handoff_beats:
		return
	_complete_response_handoff(timeline_position)

func _complete_response_handoff(timeline_position: float) -> void:
	if _response_handoff_complete:
		return
	_response_handoff_complete = true
	_restore_scoring_state()
	DebugLog.timing("[HANDOFF] response=ready  round=%d  boundary=%.2f  position=%.2f" % [
		_response_round_id,
		_response_schedule_handoff_beats,
		timeline_position,
	])

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
