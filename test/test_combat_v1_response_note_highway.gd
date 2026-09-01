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
	var chord_groups: Array = response_snapshot.get(&"chord_groups", [])
	var final_chord: Dictionary = chord_groups[0] if not chord_groups.is_empty() else {}
	_check(
		"simultaneous targets expose one shared connector-and-pulse treatment",
		{
			&"group_count": chord_groups.size(),
			&"group_id": final_chord.get(&"group_id", &""),
			&"target_ids": final_chord.get(&"target_ids", []),
			&"lanes": final_chord.get(&"lanes", []),
			&"treatment": final_chord.get(&"treatment", &""),
			&"shared_color": final_chord.get(&"color", Color.TRANSPARENT),
		},
		{
			&"group_count": 1,
			&"group_id": &"opening_call:1:group:4",
			&"target_ids": [&"opening_call:1:4", &"opening_call:1:5"],
			&"lanes": [&"up", &"right"],
			&"treatment": &"connector_pulse",
			&"shared_color": Color("c69cff"),
		}
	)
	_check("the first target is hidden throughout the handoff", response_snapshot[&"targets"][0][&"visible"], false)
	_check("later targets remain hidden until their own lead window", response_snapshot[&"targets"][1][&"visible"], false)
	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var approach_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("the first target starts at the configured lead distance after the handoff", approach_snapshot[&"targets"][0][&"progress"], 0.0)

	beat_clock.beat_position = 0.5
	await process_frame
	var half_beat_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("audio-corrected half-beat position advances the target one quarter of its path", half_beat_snapshot[&"targets"][0][&"progress"], 0.25)

	# BeatClock can recover several boundaries on one late frame. No presentation
	# frame is processed between these emissions, so accumulated delta would drift.
	beat_clock.beat.emit(13)
	beat_clock.beat.emit(14)
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

	var source_targets: Array = module.get_response_presentation()[&"targets"]
	var first_chord_target: Dictionary = source_targets[4]
	var second_chord_target: Dictionary = source_targets[5]
	module.submit_response_input(first_chord_target[&"expected_action"], first_chord_target[&"due_beat"])
	module.submit_response_input(
		second_chord_target[&"expected_action"],
		float(second_chord_target[&"due_beat"]) + 0.4
	)
	var chord_result_snapshot: Dictionary = highway.get_presentation_snapshot()
	var feedback_by_target: Dictionary = chord_result_snapshot.get(&"target_feedback", {})
	var first_chord_feedback: Dictionary = feedback_by_target.get(first_chord_target[&"target_id"], {})
	var second_chord_feedback: Dictionary = feedback_by_target.get(second_chord_target[&"target_id"], {})
	_check(
		"chord components keep independent lane results with non-text quality cues",
		{
			&"target_ids": [
				first_chord_feedback.get(&"target_id", &""),
				second_chord_feedback.get(&"target_id", &""),
			],
			&"lanes": [
				first_chord_feedback.get(&"lane", &""),
				second_chord_feedback.get(&"lane", &""),
			],
			&"expected_actions": [
				first_chord_feedback.get(&"expected_action", &""),
				second_chord_feedback.get(&"expected_action", &""),
			],
			&"actual_actions": [
				first_chord_feedback.get(&"actual_action", &""),
				second_chord_feedback.get(&"actual_action", &""),
			],
			&"signed_offsets": [
				is_zero_approx(float(first_chord_feedback.get(&"offset_ms", INF))),
				is_equal_approx(float(second_chord_feedback.get(&"offset_ms", INF)), 200.0),
			],
			&"grades": [
				first_chord_feedback.get(&"grade_name", &""),
				second_chord_feedback.get(&"grade_name", &""),
			],
			&"visual_cues": [
				first_chord_feedback.get(&"visual_cue", &""),
				second_chord_feedback.get(&"visual_cue", &""),
			],
		},
		{
			&"target_ids": [first_chord_target[&"target_id"], second_chord_target[&"target_id"]],
			&"lanes": [&"up", &"right"],
			&"expected_actions": [&"up", &"right"],
			&"actual_actions": [&"up", &"right"],
			&"signed_offsets": [true, true],
			&"grades": [&"perfect", &"miss"],
			&"visual_cues": [&"strong_burst", &"miss_ring"],
		}
	)

	var first_round_ids: Array[StringName] = []
	for target in graded_snapshot[&"targets"]:
		first_round_ids.append(target[&"target_id"])
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var cleared_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check("leaving Response clears scheduled visuals", cleared_snapshot[&"targets"].is_empty(), true)
	_check("leaving Response clears chord grouping", cleared_snapshot[&"chord_groups"].is_empty(), true)
	_check("leaving Response clears lane feedback", cleared_snapshot[&"lane_feedback"].is_empty(), true)
	_check("leaving Response clears target feedback", cleared_snapshot[&"target_feedback"].is_empty(), true)

	module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	for beat_number in range(15, 19):
		beat_clock.beat.emit(beat_number)
	_check("the next-round count-in keeps Response visuals clear", highway.get_presentation_snapshot()[&"targets"].is_empty(), true)
	beat_clock.beat.emit(19)
	for beat_number in range(20, 24):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var repeated_snapshot: Dictionary = highway.get_presentation_snapshot()
	var repeated_ids: Array[StringName] = []
	for target in repeated_snapshot[&"targets"]:
		repeated_ids.append(target[&"target_id"])
	_check("a repeated round owns exactly one fresh visual schedule", repeated_snapshot[&"targets"].size(), 6)
	_check("a repeated round retains no stale target identities", _arrays_overlap(first_round_ids, repeated_ids), false)
	_check("a repeated round starts with cleared feedback", repeated_snapshot[&"lane_feedback"].is_empty(), true)
	_check("a repeated round starts with no stale target feedback", repeated_snapshot[&"target_feedback"].is_empty(), true)
	_check(
		"the highway owns one cadence connection",
		_is_connected(module, &"cadence_changed", highway, &"_on_cadence_changed"),
		true
	)
	_check(
		"the highway owns one active-character connection",
		_is_connected(
			module,
			&"active_character_changed",
			highway,
			&"_on_active_character_changed"
		),
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
	_check("encounter resolution clears target feedback", resolved_snapshot[&"target_feedback"].is_empty(), true)

	highway.teardown()
	highway.teardown()
	_check(
		"guarded teardown disconnects the cadence signal",
		_is_connected(module, &"cadence_changed", highway, &"_on_cadence_changed"),
		false
	)
	_check(
		"guarded teardown disconnects the active-character signal",
		_is_connected(
			module,
			&"active_character_changed",
			highway,
			&"_on_active_character_changed"
		),
		false
	)
	_check(
		"guarded teardown disconnects the grade signal",
		_is_connected(module, &"response_note_graded", highway, &"_on_response_note_graded"),
		false
	)
	_check("teardown clears all presentation state", highway.get_presentation_snapshot()[&"targets"].is_empty(), true)
	_check("teardown clears all per-target feedback", highway.get_presentation_snapshot()[&"target_feedback"].is_empty(), true)
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

	beat_clock.stop()
	beat_clock.beat_position = 0.0
	var beatrice_module = CombatV1Script.new()
	root.add_child(beatrice_module)
	var beatrice_session = CombatV1Script.SessionState.new()
	beatrice_module.bind_party(
		beatrice_session,
		[load("res://combat_v1/party/beatrice_styx.tres")]
	)
	beatrice_module.setup(
		beat_clock,
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	beatrice_module.start()
	var beatrice_highway = load(highway_path).instantiate()
	root.add_child(beatrice_highway)
	beatrice_highway.set_anchors_preset(Control.PRESET_TOP_LEFT)
	beatrice_highway.size = Vector2(640.0, 300.0)
	beatrice_highway.setup(beatrice_module)
	var beatrice_beat_number := 40
	while beatrice_module.get_cadence() != CombatV1Script.Cadence.RESPONSE \
			and beatrice_beat_number < 64:
		beat_clock.beat.emit(beatrice_beat_number)
		beatrice_beat_number += 1
	for beat_advance in range(4):
		beat_clock.beat.emit(beatrice_beat_number + beat_advance)
	await process_frame
	var beatrice_authored_slots: Dictionary = {}
	for slot in beatrice_highway.get_presentation_snapshot()[&"measure_wheel"][&"slots"]:
		var actions: Array = slot[&"actions"]
		if not actions.is_empty():
			beatrice_authored_slots[int(slot[&"slot_index"])] = actions
	_check(
		"Beatrice's Response wheel places hits at scoreable due beats after the handoff",
		beatrice_authored_slots,
		{
			8: [&"drum_left"],
			11: [&"drum_right"],
			14: [&"drum_left"],
		}
	)
	beatrice_highway.teardown()
	beatrice_module.teardown()
	beatrice_highway.free()
	beatrice_module.free()
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
