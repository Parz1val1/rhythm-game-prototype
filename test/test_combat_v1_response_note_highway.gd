# Verifies the Response note highway through its public presentation interface.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	await _run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Response note-highway tests ===")
	var highway_path := "res://combat_v1/response_note_highway.tscn"
	_check("the Response note-highway scene exists", FileAccess.file_exists(highway_path), true)
	if not FileAccess.file_exists(highway_path):
		print("=== done ===")
		return

	var highway = load(highway_path).instantiate()
	root.add_child(highway)
	_check("the highway exposes setup", highway.has_method(&"setup"), true)
	_check("the highway exposes guarded teardown", highway.has_method(&"teardown"), true)
	_check("the highway exposes a read-only presentation snapshot", highway.has_method(&"get_presentation_snapshot"), true)
	if highway.has_method(&"get_presentation_snapshot"):
		var snapshot: Dictionary = highway.get_presentation_snapshot()
		_check(
			"the board keeps four stable directional lanes",
			snapshot[&"lane_order"],
			[&"left", &"down", &"up", &"right"]
		)

	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)
	var beat_clock: Node = root.get_node("BeatClock")
	beat_clock.beat_position = 0.0
	module.setup(
		beat_clock,
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.start()
	highway.set_anchors_preset(Control.PRESET_TOP_LEFT)
	highway.size = Vector2(640.0, 300.0)
	highway.setup(module)
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var response_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("the complete schedule includes both lanes of the final chord", response_snapshot[&"targets"].size(), 6)
	_check("the note highway is active before the first target is due", response_snapshot[&"active"], true)
	var target_lanes: Array[StringName] = []
	var lane_indices: Array[int] = []
	for target in response_snapshot[&"targets"]:
		target_lanes.append(target[&"lane"])
		lane_indices.append(target[&"lane_index"])
	_check("every expected action uses its matching stable lane", target_lanes, [&"up", &"right", &"down", &"left", &"up", &"right"])
	_check("stable lane placement is left/down/up/right", lane_indices, [2, 3, 1, 0, 2, 3])
	_check("the final chord shares one scoreable time", response_snapshot[&"targets"][4][&"due_beat"], response_snapshot[&"targets"][5][&"due_beat"])
	_check("the first target starts at the configured lead distance", response_snapshot[&"targets"][0][&"progress"], 0.0)
	_check("later targets remain hidden until their own lead window", response_snapshot[&"targets"][1][&"visible"], false)

	beat_clock.beat_position = 0.5
	await process_frame
	var half_beat_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("audio-corrected half-beat position advances the target one quarter of its path", half_beat_snapshot[&"targets"][0][&"progress"], 0.25)

	# BeatClock can recover several boundaries on one late frame. No presentation
	# frame is processed between these emissions, so accumulated delta would drift.
	beat_clock.beat.emit(9)
	beat_clock.beat.emit(10)
	beat_clock.beat_position = 0.0
	await process_frame
	var due_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("the target reaches the hit line at its scoreable BeatClock time", due_snapshot[&"targets"][0][&"progress"], 1.0)
	_check(
		"late-frame recovery derives position from current musical time",
		is_equal_approx(due_snapshot[&"targets"][0][&"y"], due_snapshot[&"hit_line_y"]),
		true
	)
	var first_target: Dictionary = due_snapshot[&"targets"][0]
	module.submit_response_input(first_target[&"expected_action"], first_target[&"due_beat"])
	var graded_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("note feedback appears at the matching lane", graded_snapshot[&"lane_feedback"].has(&"up"), true)
	_check("note feedback keeps the graded target identity", graded_snapshot[&"lane_feedback"][&"up"][&"target_id"], first_target[&"target_id"])
	_check("note feedback shows the matching grade", graded_snapshot[&"lane_feedback"][&"up"][&"grade_name"], &"perfect")
	_check("grading removes only the matching travelling target", graded_snapshot[&"targets"][0][&"visible"], false)

	var first_round_ids: Array[StringName] = []
	for target in graded_snapshot[&"targets"]:
		first_round_ids.append(target[&"target_id"])
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var cleared_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("leaving Response clears scheduled visuals", cleared_snapshot[&"targets"].is_empty(), true)
	_check("leaving Response clears lane feedback", cleared_snapshot[&"lane_feedback"].is_empty(), true)

	module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	beat_clock.beat.emit(11)
	_check("the next round clears visuals while the opponent performs", highway.get_presentation_snapshot()[&"targets"].is_empty(), true)
	for beat_number in range(12, 16):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var repeated_snapshot: Dictionary = highway.get_presentation_snapshot()
	var repeated_ids: Array[StringName] = []
	for target in repeated_snapshot[&"targets"]:
		repeated_ids.append(target[&"target_id"])
	_check("a repeated round owns exactly one fresh visual schedule", repeated_snapshot[&"targets"].size(), 6)
	_check("a repeated round retains no stale target identities", _arrays_overlap(first_round_ids, repeated_ids), false)
	_check("a repeated round starts with cleared feedback", repeated_snapshot[&"lane_feedback"].is_empty(), true)
	_check(
		"the highway owns one cadence connection",
		_is_connected(module, &"cadence_changed", highway, &"_on_cadence_changed"),
		true
	)
	_check(
		"the highway owns one grade connection",
		_is_connected(module, &"response_note_graded", highway, &"_on_response_note_graded"),
		true
	)
	for result_index in range(8):
		if module.get_state()[&"terminal"]:
			break
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		)
	var resolved_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("encounter resolution clears scheduled visuals", resolved_snapshot[&"targets"].is_empty(), true)
	_check("encounter resolution clears lane feedback", resolved_snapshot[&"lane_feedback"].is_empty(), true)

	highway.teardown()
	highway.teardown()
	_check(
		"guarded teardown disconnects the cadence signal",
		_is_connected(module, &"cadence_changed", highway, &"_on_cadence_changed"),
		false
	)
	_check(
		"guarded teardown disconnects the grade signal",
		_is_connected(module, &"response_note_graded", highway, &"_on_response_note_graded"),
		false
	)
	_check("teardown clears all presentation state", highway.get_presentation_snapshot()[&"targets"].is_empty(), true)
	module.teardown()
	module.free()
	highway.free()

	var four_lane_opponent = load("res://combat_v1/opponents/drum_golem.tres").duplicate(true)
	four_lane_opponent.phrase.events[-1].lane_count = 4
	var four_lane_module = CombatV1Script.new()
	root.add_child(four_lane_module)
	four_lane_module.setup(
		beat_clock,
		root.get_node("RhythmInput"),
		four_lane_opponent,
		1
	)
	four_lane_module.start()
	var four_lane_highway = load(highway_path).instantiate()
	root.add_child(four_lane_highway)
	four_lane_highway.set_anchors_preset(Control.PRESET_TOP_LEFT)
	four_lane_highway.size = Vector2(640.0, 300.0)
	four_lane_highway.setup(four_lane_module)
	for beat_number in range(20, 28):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var simultaneous_lanes: Array[StringName] = []
	for target in four_lane_highway.get_presentation_snapshot()[&"targets"]:
		if is_equal_approx(float(target[&"beat_offset"]), 3.0):
			simultaneous_lanes.append(target[&"lane"])
	_check(
		"one cue can render all four track inputs at the same time",
		simultaneous_lanes,
		[&"up", &"right", &"down", &"left"]
	)
	four_lane_highway.teardown()
	four_lane_module.teardown()
	four_lane_highway.free()
	four_lane_module.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])

func _arrays_overlap(first: Array[StringName], second: Array[StringName]) -> bool:
	for value in first:
		if value in second:
			return true
	return false

func _is_connected(
	source: Object,
	signal_name: StringName,
	target: Object,
	method_name: StringName
) -> bool:
	return Signal(source, signal_name).is_connected(Callable(target, method_name))
