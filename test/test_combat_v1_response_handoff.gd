# Verifies the input-free Response handoff through CombatV1's public seams.
extends SceneTree

var _has_failures: bool = false
var _note_results: Array[Dictionary] = []

class BeatClockStub extends Node:
	signal beat(beat_number: int)
	signal half_beat(beat_number: int)
	signal quarter_beat(beat_number: int, subdivision: float)

	var bpm: float = 120.0
	var beat_position: float = 0.0
	var musical_position_beats: float = 0.0

	func is_running() -> bool:
		return true

	func get_musical_position_beats() -> float:
		return musical_position_beats

class RhythmInputStub extends Node:
	signal input_scored(
		direction: StringName,
		score: StringName,
		offset_ms: float,
		note_consumed: bool
	)

	var _scoring_enabled: bool = true

	func set_scoring_enabled(enabled: bool) -> void:
		_scoring_enabled = enabled

	func is_scoring_enabled() -> bool:
		return _scoring_enabled

	func perform_input(direction: StringName) -> void:
		if _scoring_enabled:
			input_scored.emit(direction, &"perfect", 0.0, false)

func _init() -> void:
	await process_frame
	await _run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Response handoff tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock := BeatClockStub.new()
	var rhythm_input := RhythmInputStub.new()
	var module = CombatV1Script.new()
	root.add_child(beat_clock)
	root.add_child(rhythm_input)
	root.add_child(module)
	module.response_note_graded.connect(
		func(result: Dictionary) -> void: _note_results.append(result)
	)
	module.setup(
		beat_clock,
		rhythm_input,
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.start()
	for beat_number in range(1, 9):
		beat_clock.musical_position_beats = float(beat_number)
		beat_clock.beat.emit(beat_number)

	var presentation: Dictionary = module.get_response_presentation()
	var first_target: Dictionary = presentation[&"targets"][0]
	var highway = load("res://combat_v1/response_note_highway.tscn").instantiate()
	root.add_child(highway)
	highway.set_anchors_preset(Control.PRESET_TOP_LEFT)
	highway.size = Vector2(640.0, 300.0)
	highway.setup(module)
	_check("the provisional Response handoff is one four-beat bar", presentation[&"handoff_beats"], 4.0)
	_check("the existing approach lead remains two beats", presentation[&"visual_lead_beats"], 2.0)
	_check("Response begins inside the input-free handoff", presentation[&"handoff_active"], true)
	_check("the first target is due after handoff plus approach", first_target[&"due_beat"], 6.0)
	_check("live scoring remains disabled during the handoff", rhythm_input.is_scoring_enabled(), false)
	_check("no Response target is visible when the handoff begins", highway.get_presentation_snapshot()[&"targets"][0][&"visible"], false)
	rhythm_input.perform_input(first_target[&"expected_action"])
	_check("live handoff input produces no note grade", _note_results.size(), 0)
	_check(
		"headless input during the handoff cannot consume a future target",
		module.submit_response_input(first_target[&"expected_action"], 3.999),
		false
	)
	_check("handoff input produces no note grade", _note_results.size(), 0)
	_check(
		"submit intent during the handoff cannot grade future targets",
		module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE),
		false
	)
	_check("handoff submit intent keeps Response active", module.get_cadence(), CombatV1Script.Cadence.RESPONSE)
	_check("handoff submit intent produces no note grades", _note_results.size(), 0)

	for beat_number in range(9, 12):
		beat_clock.musical_position_beats = float(beat_number)
		beat_clock.beat.emit(beat_number)
	beat_clock.musical_position_beats = 11.999
	await process_frame
	_check("the first target stays hidden for the complete bar", highway.get_presentation_snapshot()[&"targets"][0][&"visible"], false)
	beat_clock.musical_position_beats = 12.0
	beat_clock.beat.emit(12)
	await process_frame
	var boundary_presentation: Dictionary = module.get_response_presentation()
	_check("the handoff ends at its BeatClock boundary", boundary_presentation[&"handoff_active"], false)
	_check("live scoring resumes at the handoff boundary", rhythm_input.is_scoring_enabled(), true)
	var approach_start: Dictionary = highway.get_presentation_snapshot()[&"targets"][0]
	_check("the first target appears only after one provisional bar", approach_start[&"visible"], true)
	_check("the first target begins at the start of its approach", is_equal_approx(float(approach_start[&"progress"]), 0.0), true)
	beat_clock.musical_position_beats = 14.0
	beat_clock.beat.emit(14)
	await process_frame
	_check("the first target receives its complete two-beat approach", is_equal_approx(float(highway.get_presentation_snapshot()[&"targets"][0][&"progress"]), 1.0), true)
	rhythm_input.perform_input(first_target[&"expected_action"])
	_check("live input grades against the presented due time", _note_results[0][&"grade_name"], &"perfect")
	_check("live grading preserves the presented due time", _note_results[0][&"due_beat"], first_target[&"due_beat"])

	highway.teardown()
	module.teardown()
	highway.free()
	module.free()
	rhythm_input.free()
	beat_clock.free()

	var recovered_clock := BeatClockStub.new()
	var recovered_input := RhythmInputStub.new()
	var recovered_module = CombatV1Script.new()
	root.add_child(recovered_clock)
	root.add_child(recovered_input)
	root.add_child(recovered_module)
	recovered_module.response_handoff_beats = 3.0
	recovered_module.response_visual_lead_beats = 1.25
	recovered_module.setup(
		recovered_clock,
		recovered_input,
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	recovered_module.start()
	for beat_number in range(1, 9):
		recovered_clock.musical_position_beats = float(beat_number)
		recovered_clock.beat.emit(beat_number)
	var tuned_presentation: Dictionary = recovered_module.get_response_presentation()
	_check("the handoff remains independently configurable", tuned_presentation[&"handoff_beats"], 3.0)
	_check("the approach remains independently configurable", tuned_presentation[&"visual_lead_beats"], 1.25)
	_check("independent tuning composes into one due time", tuned_presentation[&"targets"][0][&"due_beat"], 4.25)
	recovered_clock.musical_position_beats = 12.5
	for recovered_beat in range(9, 13):
		recovered_clock.beat.emit(recovered_beat)
	var recovered_presentation: Dictionary = recovered_module.get_response_presentation()
	_check(
		"late-frame recovery keeps the absolute Response position",
		is_equal_approx(float(recovered_presentation[&"timeline_position_beats"]), 4.5),
		true
	)
	_check("late-frame recovery crosses the configured handoff", recovered_presentation[&"handoff_active"], false)
	_check("late-frame recovery restores live scoring", recovered_input.is_scoring_enabled(), true)
	recovered_module.teardown()
	recovered_module.free()
	recovered_input.free()
	recovered_clock.free()

	var headless_clock := BeatClockStub.new()
	var headless_input := RhythmInputStub.new()
	var headless_module = CombatV1Script.new()
	root.add_child(headless_clock)
	root.add_child(headless_input)
	root.add_child(headless_module)
	headless_module.setup(
		headless_clock,
		headless_input,
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	headless_module.start()
	for beat_number in range(1, 9):
		headless_clock.musical_position_beats = float(beat_number)
		headless_clock.beat.emit(beat_number)
	var headless_presentation: Dictionary = headless_module.get_response_presentation()
	var headless_target: Dictionary = headless_presentation[&"targets"][0]
	_check(
		"headless submission uses the presented Response timeline",
		headless_module.submit_response_input(
			headless_target[&"expected_action"],
			headless_target[&"due_beat"]
		),
		true
	)
	_check("headless timeline input completes the handoff", headless_module.get_response_presentation()[&"handoff_active"], false)
	_check("headless timeline input restores scoring state", headless_input.is_scoring_enabled(), true)
	_check(
		"headless Response can be submitted after timeline input",
		headless_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE),
		true
	)
	headless_module.teardown()
	headless_module.free()
	headless_input.free()
	headless_clock.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
