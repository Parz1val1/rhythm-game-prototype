# Verifies replaceable audible Response feedback through its public adapter seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	await _run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Response feedback tests ===")
	var feedback_path := "res://combat_v1/response_performance_feedback.tscn"
	_check("the replaceable Response feedback adapter exists", FileAccess.file_exists(feedback_path), true)
	if not FileAccess.file_exists(feedback_path):
		print("=== done ===")
		return

	var feedback = load(feedback_path).instantiate()
	root.add_child(feedback)
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)
	var beat_clock: Node = root.get_node("BeatClock")
	module.setup(
		beat_clock,
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.start()
	feedback.setup(module)
	for beat_number in range(1, 5):
		beat_clock.beat.emit(beat_number)
	beat_clock.quarter_beat.emit(4, 0.75)
	beat_clock.beat.emit(5)
	beat_clock.half_beat.emit(5)
	beat_clock.beat.emit(6)
	beat_clock.half_beat.emit(6)
	beat_clock.beat.emit(7)
	var heard_preview: Array = feedback.get_feedback_snapshot().get(&"preview_events", [])
	var preview_facts: Array[Dictionary] = []
	for preview in heard_preview:
		preview_facts.append({
			&"prompt_id": preview[&"prompt_id"],
			&"beat_offset": preview[&"beat_offset"],
			&"lanes": preview[&"lanes"],
			&"pitch_hz": preview[&"pitch_hz"],
			&"timbre": preview[&"timbre"],
		})
	_check(
		"Enemy Phrase highlights play the mapped melody and chord before Response",
		preview_facts,
		[
			{
				&"prompt_id": &"drum_left",
				&"beat_offset": 0.0,
				&"lanes": [&"up"],
				&"pitch_hz": [329.63],
				&"timbre": &"preview_pluck",
			},
			{
				&"prompt_id": &"drum_right",
				&"beat_offset": 0.75,
				&"lanes": [&"right"],
				&"pitch_hz": [392.0],
				&"timbre": &"preview_pluck",
			},
			{
				&"prompt_id": &"drum_left",
				&"beat_offset": 1.5,
				&"lanes": [&"down"],
				&"pitch_hz": [293.66],
				&"timbre": &"preview_pluck",
			},
			{
				&"prompt_id": &"drum_right",
				&"beat_offset": 2.5,
				&"lanes": [&"left"],
				&"pitch_hz": [261.63],
				&"timbre": &"preview_pluck",
			},
			{
				&"prompt_id": &"drum_both",
				&"beat_offset": 3.0,
				&"lanes": [&"up", &"right"],
				&"pitch_hz": [329.63, 392.0],
				&"timbre": &"preview_pluck",
			},
		]
	)
	beat_clock.beat.emit(8)
	_check(
		"the audible lesson clears before the player reproduces it",
		feedback.get_feedback_snapshot()[&"preview_events"].is_empty(),
		true
	)

	var presentation: Dictionary = module.get_response_presentation()
	for target_index in range(4):
		var target: Dictionary = presentation[&"targets"][target_index]
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	var snapshot: Dictionary = feedback.get_feedback_snapshot()
	var routed_lanes: Array[StringName] = []
	var routed_pitches: Array[float] = []
	for event in snapshot[&"routed_events"]:
		routed_lanes.append(event[&"lane"])
		routed_pitches.append(event[&"pitch_hz"])
	_check(
		"accepted actions route to four distinct matching lane pitches",
		{
			&"lanes": routed_lanes,
			&"unique_pitch_count": _unique_float_count(routed_pitches),
		},
		{
			&"lanes": [&"up", &"right", &"down", &"left"],
			&"unique_pitch_count": 4,
		}
	)

	var first_chord_target: Dictionary = presentation[&"targets"][4]
	var second_chord_target: Dictionary = presentation[&"targets"][5]
	module.submit_response_input(
		first_chord_target[&"expected_action"],
		first_chord_target[&"due_beat"]
	)
	module.submit_response_input(
		second_chord_target[&"expected_action"],
		float(second_chord_target[&"due_beat"]) + 0.4
	)
	var chord_events: Array = feedback.get_feedback_snapshot()[&"routed_events"].slice(4, 6)
	var strong_event: Dictionary = chord_events[0]
	var missed_event: Dictionary = chord_events[1]
	_check(
		"feedback preserves result truth and gives a timing miss a restrained audible character",
		{
			&"target_ids": [strong_event[&"target_id"], missed_event[&"target_id"]],
			&"expected_actions": [
				strong_event[&"expected_action"],
				missed_event[&"expected_action"],
			],
			&"actual_actions": [strong_event[&"actual_action"], missed_event[&"actual_action"]],
			&"lanes": [strong_event[&"lane"], missed_event[&"lane"]],
			&"same_group": strong_event[&"group_id"] == missed_event[&"group_id"],
			&"signed_offsets": [
				is_zero_approx(float(strong_event[&"offset_ms"])),
				is_equal_approx(float(missed_event[&"offset_ms"]), 200.0),
			],
			&"grades": [strong_event[&"grade_name"], missed_event[&"grade_name"]],
			&"quality_bands": [
				strong_event.get(&"quality_band", &""),
				missed_event.get(&"quality_band", &""),
			],
			&"timbres": [strong_event.get(&"timbre", &""), missed_event.get(&"timbre", &"")],
		},
		{
			&"target_ids": [first_chord_target[&"target_id"], second_chord_target[&"target_id"]],
			&"expected_actions": [&"up", &"right"],
			&"actual_actions": [&"up", &"right"],
			&"lanes": [&"up", &"right"],
			&"same_group": true,
			&"signed_offsets": [true, true],
			&"grades": [&"perfect", &"miss"],
			&"quality_bands": [&"strong", &"missed"],
			&"timbres": [&"clear_pluck", &"muted_pluck"],
		}
	)

	var first_round_id: int = presentation[&"round_id"]
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var cleared_after_response: bool = feedback.get_feedback_snapshot()[&"routed_events"].is_empty()
	module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	beat_clock.beat.emit(13)
	for beat_number in range(14, 18):
		beat_clock.beat.emit(beat_number)
	var next_presentation: Dictionary = module.get_response_presentation()
	var next_target: Dictionary = next_presentation[&"targets"][0]
	module.submit_response_input(next_target[&"expected_action"], next_target[&"due_beat"])
	var fresh_events: Array = feedback.get_feedback_snapshot()[&"routed_events"]
	for result_index in range(8):
		if module.get_state()[&"terminal"]:
			break
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		)
	var cleared_at_resolution: bool = feedback.get_feedback_snapshot()[&"routed_events"].is_empty()
	feedback.teardown()
	feedback.teardown()
	module.response_note_graded.emit({
		&"target_id": &"after_teardown",
		&"expected_action": &"left",
		&"actual_action": &"left",
		&"offset_ms": 0.0,
		&"lane": &"left",
		&"group_id": &"after_teardown_group",
		&"group_size": 1,
		&"grade_name": &"perfect",
	})
	_check(
		"feedback clears across cadence, rounds, resolution, and guarded teardown",
		{
			&"cleared_after_response": cleared_after_response,
			&"fresh_event_count": fresh_events.size(),
			&"fresh_round": int(next_presentation[&"round_id"]) > first_round_id,
			&"cleared_at_resolution": cleared_at_resolution,
			&"ignored_after_teardown": feedback.get_feedback_snapshot()[&"routed_events"].is_empty(),
		},
		{
			&"cleared_after_response": true,
			&"fresh_event_count": 1,
			&"fresh_round": true,
			&"cleared_at_resolution": true,
			&"ignored_after_teardown": true,
		}
	)

	module.teardown()
	feedback.free()
	module.free()
	print("=== done ===")

func _unique_float_count(values: Array[float]) -> int:
	var unique: Array[float] = []
	for value in values:
		if value not in unique:
			unique.append(value)
	return unique.size()

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
