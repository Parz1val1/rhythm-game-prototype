# Verifies Response presentation, execution, and state integration through CombatV1.
extends SceneTree

var _response_targets: Array[Dictionary] = []
var _note_results: Array[Dictionary] = []
var _phrase_summaries: Array[Dictionary] = []
var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Response integration tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var response_profile = load("res://characters/luthier_profile.tres")
	var module = CombatV1Script.new()
	root.add_child(module)

	if not module.has_signal(&"response_target_announced"):
		_check("CombatV1 exposes Response targets", false, true)
		module.queue_free()
		print("=== done ===")
		return
	if not module.has_signal(&"response_note_graded"):
		_check("CombatV1 exposes Response note grades", false, true)
		module.queue_free()
		print("=== done ===")
		return
	if not module.has_signal(&"response_phrase_graded"):
		_check("CombatV1 exposes Response phrase summaries", false, true)
		module.queue_free()
		print("=== done ===")
		return

	module.response_note_graded.connect(_on_response_note_graded)
	module.response_phrase_graded.connect(_on_response_phrase_graded)
	module.setup(beat_clock, rhythm_input, opponent, 1, null, response_profile)
	module.start()
	_check(
		"Response input is rejected before the listening phase completes",
		module.submit_response_input(&"up", 0.0),
		false
	)
	for beat_number in range(1, 8):
		beat_clock.beat.emit(beat_number)
	_check("no Response schedule is exposed while the player is listening", module.get_response_presentation()[&"targets"].size(), 0)
	beat_clock.beat.emit(8)
	_response_targets = _targets_from_presentation(module.get_response_presentation())
	_check("the complete Response schedule appears when Response begins", _response_targets.size(), 6)
	var first_action: StringName = _response_targets[0][&"action"]
	_check("Response accepts a performed target action", module.submit_response_input(first_action, _response_targets[0][&"due"]), true)
	_check("Response exposes its note grade", _note_results[0][&"grade_name"], &"perfect")
	beat_clock.beat.emit(9)
	beat_clock.beat.emit(10)
	beat_clock.beat_position = 0.75
	var second_action: StringName = _response_targets[1][&"action"]
	rhythm_input.input_scored.emit(second_action, &"miss", 999.0, false)
	_check("the shared input seam feeds Response grading", _note_results.size(), 2)
	var response_offsets: Array[float] = []
	for target in _response_targets:
		response_offsets.append(target[&"offset"])
	_check(
		"Response replays every heard phrase offset",
		response_offsets,
		[0.0, 0.75, 1.5, 2.5, 3.0, 3.0]
	)
	var response_actions: Array[StringName] = []
	for target in _response_targets:
		var action: StringName = target[&"action"]
		if action not in response_actions:
			response_actions.append(action)
	_check("Response uses all four actions in Luthier's rhythm language", response_actions.size(), 4)
	_check(
		"submitting Response completes its phrase",
		module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE),
		true
	)
	_check("Response emits one phrase summary", _phrase_summaries.size(), 1)
	_check("the phrase summary includes every target note", _phrase_summaries[0][&"total_notes"], 6)
	_check(
		"CombatV1 state exposes the latest phrase grade",
		module.get_state()[&"response_summary"][&"grade_name"],
		&"major_mistake"
	)
	_check("a broken Response reduces shared Composure", module.get_state()[&"composure"], 70.0)
	module.teardown()
	module.free()

	_response_targets.clear()
	_note_results.clear()
	_phrase_summaries.clear()
	beat_clock.bpm = 100.0
	var near_state_config = CombatV1Script.EncounterConfig.new()
	near_state_config.near_miss_groove_gain = 3.0
	near_state_config.near_miss_composure_loss = 4.0
	var near_response_config = CombatV1Script.ResponseConfig.new()
	near_response_config.perfect_ms = 40.0
	near_response_config.great_ms = 70.0
	near_response_config.good_ms = 110.0
	near_response_config.near_miss_ms = 160.0
	near_response_config.miss_ms = 230.0
	var near_module = CombatV1Script.new()
	root.add_child(near_module)
	near_module.response_note_graded.connect(_on_response_note_graded)
	near_module.response_phrase_graded.connect(_on_response_phrase_graded)
	near_module.setup(
		beat_clock,
		rhythm_input,
		opponent,
		1,
		near_state_config,
		response_profile,
		near_response_config
	)
	near_module.start()
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	_response_targets = _targets_from_presentation(near_module.get_response_presentation())
	for target in _response_targets:
		var near_position: float = float(target[&"due"]) + (130.0 / 600.0)
		near_module.submit_response_input(target[&"action"], near_position)
	near_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	_check("a uniformly shaky Response receives Near Miss", _phrase_summaries[0][&"grade_name"], &"near_miss")
	_check("Near Miss produces configurable small Groove gain", near_module.get_state()[&"groove"], 3.0)
	_check("Near Miss also produces configurable small Composure loss", near_module.get_state()[&"composure"], 96.0)
	near_module.teardown()
	near_module.free()

	_response_targets.clear()
	_note_results.clear()
	_phrase_summaries.clear()
	var recovery_state_config = CombatV1Script.EncounterConfig.new()
	recovery_state_config.correct_groove_gain = 10.0
	var recovery_module = CombatV1Script.new()
	root.add_child(recovery_module)
	recovery_module.response_note_graded.connect(_on_response_note_graded)
	recovery_module.response_phrase_graded.connect(_on_response_phrase_graded)
	recovery_module.setup(
		beat_clock,
		rhythm_input,
		opponent,
		1,
		recovery_state_config,
		response_profile
	)
	recovery_module.start()
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	_response_targets = _targets_from_presentation(recovery_module.get_response_presentation())
	for target_index in range(_response_targets.size()):
		var recovery_target: Dictionary = _response_targets[target_index]
		var performed_action: StringName = recovery_target[&"action"]
		if target_index == 1:
			performed_action = _response_targets[0][&"action"]
		recovery_module.submit_response_input(
			performed_action,
			float(recovery_target[&"due"])
		)
	recovery_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	_check("later notes recover an integrated Response after one Miss", _phrase_summaries[0][&"grade_name"], &"great")
	_check("the recovered Response gains Groove", recovery_module.get_state()[&"groove"], 10.0)
	_check("the recovered Response does not lose Composure", recovery_module.get_state()[&"composure"], 100.0)
	_check("the recovered Response builds shared Multiplier", recovery_module.get_state()[&"multiplier"], 1.5)
	recovery_module.teardown()
	recovery_module.free()
	print("=== done ===")

func _targets_from_presentation(presentation: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for scheduled_target in presentation[&"targets"]:
		targets.append({
			&"offset": scheduled_target[&"beat_offset"],
			&"due": scheduled_target[&"due_beat"],
			&"action": scheduled_target[&"expected_action"],
		})
	return targets

func _on_response_note_graded(result: Dictionary) -> void:
	_note_results.append(result)

func _on_response_phrase_graded(summary: Dictionary) -> void:
	_phrase_summaries.append(summary)

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
