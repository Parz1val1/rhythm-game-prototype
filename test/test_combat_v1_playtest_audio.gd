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
	var prototype = load("res://combat_v1/combat_v1_prototype.tscn").instantiate()
	root.add_child(prototype)

	_check(
		"playtester can compare three named backing tracks",
		prototype.get_playtest_track_options(),
		["Campfire Strings", "Stonebeat", "Starcurrent"]
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

	prototype.teardown()
	prototype.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
