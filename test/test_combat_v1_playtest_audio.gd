# test/test_combat_v1_playtest_audio.gd
# Verifies the player-facing backing-track comparison seam in the V1 harness.
# Run: godot --headless --path . -s res://test/test_combat_v1_playtest_audio.gd
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	await _run()
	await create_timer(0.25).timeout
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 playtest audio tests ===")
	var debug_log = load("res://autoloads/debug_log.gd")
	_disable_debug_logging(debug_log)
	var prototype = load("res://combat_v1/combat_v1_prototype.tscn").instantiate()
	var has_debug_toggle := _has_property(prototype, &"enable_debug_logging")
	if has_debug_toggle:
		prototype.set(&"enable_debug_logging", true)
	root.add_child(prototype)
	_check(
		"playtester can enable all debug logging from the Inspector",
		has_debug_toggle and _all_debug_logging_enabled(debug_log),
		true
	)

	_check(
		"playtester can compare three named backing tracks",
		prototype.get_playtest_track_options(),
		["Campfire Strings", "Stonebeat", "Starcurrent"]
	)
	_check(
		"Stonebeat is the default backing track",
		prototype.get_selected_playtest_track_name(),
		"Stonebeat"
	)
	var beat_number_before_switch: int = root.get_node("BeatClock").beat_number
	_check("playtester can select Stonebeat", prototype.select_playtest_track(1), true)
	_check(
		"selected backing track is observable by name",
		prototype.get_selected_playtest_track_name(),
		"Stonebeat"
	)
	_check(
		"backing-track comparison does not reset musical time",
		root.get_node("BeatClock").beat_number,
		beat_number_before_switch
	)
	_check(
		"selected backing track keeps playing",
		prototype.get_node("AudioStreamPlayer").playing,
		true
	)
	var option_three := InputEventKey.new()
	option_three.pressed = true
	option_three.keycode = KEY_3
	Input.parse_input_event(option_three)
	await process_frame
	_check(
		"number keys switch backing tracks during play",
		prototype.get_selected_playtest_track_name(),
		"Starcurrent"
	)
	_check(
		"playtester can see the selected track and comparison controls",
		prototype.get_node("CombatV1HUD/InstructionPanel/AudioTrackLabel").text,
		"AUDIO  3  STARCURRENT  |  1 / 2 / 3 OR SHOULDERS"
	)

	var feedback = prototype.get_node_or_null("ResponsePerformanceFeedback")
	var module = prototype.get_node_or_null("CombatV1")
	var backing_player: AudioStreamPlayer = prototype.get_node("AudioStreamPlayer")
	var has_clock_source_snapshot := root.get_node("BeatClock").has_method(&"get_audio_source_instance_id")
	var source_before: int = root.get_node("BeatClock").call(&"get_audio_source_instance_id") \
		if has_clock_source_snapshot else 0
	var backing_stream_before: AudioStream = backing_player.stream
	var schedule_before: Array[Dictionary] = []
	var feedback_count: int = 0
	if feedback != null and module != null:
		for beat_number in range(1, 13):
			root.get_node("BeatClock").beat.emit(beat_number)
		var presentation: Dictionary = module.get_response_presentation()
		schedule_before = _schedule_facts(presentation)
		if not presentation[&"targets"].is_empty():
			var target: Dictionary = presentation[&"targets"][0]
			module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
		feedback_count = feedback.get_feedback_snapshot()[&"routed_events"].size()
	var source_after: int = root.get_node("BeatClock").call(&"get_audio_source_instance_id") \
		if has_clock_source_snapshot else -1
	var schedule_after: Array[Dictionary] = []
	if module != null:
		schedule_after = _schedule_facts(module.get_response_presentation())
	_check(
		"Response feedback leaves the backing source, playback, and score schedule untouched",
		{
			&"adapter_present": feedback != null,
			&"clock_source_observable": has_clock_source_snapshot,
			&"source_before": source_before,
			&"source_after": source_after,
			&"backing_player": backing_player.get_instance_id(),
			&"backing_stream_unchanged": backing_player.stream == backing_stream_before,
			&"backing_playing": backing_player.playing,
			&"feedback_count": feedback_count,
			&"schedule_unchanged": schedule_after == schedule_before,
		},
		{
			&"adapter_present": true,
			&"clock_source_observable": true,
			&"source_before": backing_player.get_instance_id(),
			&"source_after": backing_player.get_instance_id(),
			&"backing_player": backing_player.get_instance_id(),
			&"backing_stream_unchanged": true,
			&"backing_playing": true,
			&"feedback_count": 1,
			&"schedule_unchanged": true,
		}
	)

	prototype.teardown()
	prototype.free()
	_disable_debug_logging(debug_log)
	print("=== done ===")

func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if property[&"name"] == property_name:
			return true
	return false

func _all_debug_logging_enabled(debug_log) -> bool:
	return debug_log.enabled \
		and debug_log.beat_timing \
		and debug_log.combat_events \
		and debug_log.note_visuals \
		and debug_log.audio_events

func _disable_debug_logging(debug_log) -> void:
	debug_log.enabled = false
	debug_log.beat_timing = false
	debug_log.combat_events = false
	debug_log.note_visuals = false
	debug_log.audio_events = false

func _schedule_facts(presentation: Dictionary) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	for target in presentation.get(&"targets", []):
		facts.append({
			&"target_id": target[&"target_id"],
			&"expected_action": target[&"expected_action"],
			&"group_id": target[&"group_id"],
			&"due_beat": target[&"due_beat"],
		})
	return facts

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
