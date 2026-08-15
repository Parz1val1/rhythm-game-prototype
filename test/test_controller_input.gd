# test/test_controller_input.gd
# Verifies player-facing controller mappings through Godot's public InputMap.
# Run: godot --headless --path . -s res://test/test_controller_input.gd
extends SceneTree

var _has_failures: bool = false
var _observed_drum_inputs: Array[StringName] = []

func _init() -> void:
	await process_frame
	await _run()
	await create_timer(0.25).timeout
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Controller input tests ===")
	var luthier_controls: Array[Array] = [
		[&"rhythm_up", JOY_BUTTON_DPAD_UP, JOY_BUTTON_Y],
		[&"rhythm_down", JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A],
		[&"rhythm_left", JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_X],
		[&"rhythm_right", JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_B],
	]
	for control in luthier_controls:
		var action: StringName = control[0]
		_check(
			"%s accepts its D-pad direction" % action,
			_joy_button(control[1]).is_action_pressed(action),
			true
		)
		_check(
			"%s accepts its positionally matching face button" % action,
			_joy_button(control[2]).is_action_pressed(action),
			true
		)
	_check(
		"Beatrice's left drum accepts the left trigger",
		_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0).is_action_pressed(&"drum_left"),
		true
	)
	_check(
		"Beatrice's right drum accepts the right trigger",
		_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0).is_action_pressed(&"drum_right"),
		true
	)
	_check(
		"Start is reserved for advancing the V1 playtest cadence",
		_joy_button(JOY_BUTTON_START).is_action_pressed(&"playtest_advance"),
		true
	)
	_check(
		"left shoulder selects the previous playtest backing track",
		_joy_button(JOY_BUTTON_LEFT_SHOULDER).is_action_pressed(&"playtest_audio_previous"),
		true
	)
	_check(
		"right shoulder selects the next playtest backing track",
		_joy_button(JOY_BUTTON_RIGHT_SHOULDER).is_action_pressed(&"playtest_audio_next"),
		true
	)

	var rhythm_input: Node = root.get_node("RhythmInput")
	rhythm_input.set_active_profile(load("res://characters/beatrice_profile.tres"))
	rhythm_input.set_scoring_enabled(true)
	rhythm_input.clear_notes()
	rhythm_input.input_scored.connect(_on_drum_input_scored)
	rhythm_input._unhandled_input(_joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.6))
	rhythm_input._unhandled_input(_joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.8))
	rhythm_input._unhandled_input(_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	_check(
		"one progressive trigger pull produces one drum hit",
		_observed_drum_inputs,
		[&"drum_left"]
	)
	rhythm_input._unhandled_input(_joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	rhythm_input._unhandled_input(_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	_check(
		"releasing the trigger rearms the drum input",
		_observed_drum_inputs,
		[&"drum_left", &"drum_left"]
	)
	rhythm_input.input_scored.disconnect(_on_drum_input_scored)
	rhythm_input.clear_profile()

	var prototype = load("res://combat_v1/combat_v1_prototype.tscn").instantiate()
	prototype.settle_bars = 1
	root.add_child(prototype)
	var next_track := _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	Input.parse_input_event(next_track)
	await process_frame
	_check(
		"right shoulder cycles the backing track during play",
		prototype.get_selected_playtest_track_name(),
		"Stonebeat"
	)

	var module = prototype.get("_combat_v1")
	# This test drives cadence signals manually, so stop the audio-derived clock and
	# use CombatV1's deterministic headless position fallback for the handoff.
	root.get_node("BeatClock").stop()
	root.get_node("BeatClock").beat_position = 0.0
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	_check(
		"controller test reaches Response",
		module.get_cadence(),
		CombatV1Script.Cadence.RESPONSE
	)
	var advance := _joy_button(JOY_BUTTON_START)
	Input.parse_input_event(advance)
	await process_frame
	_check(
		"Start cannot submit Response during the input-free handoff",
		module.get_cadence(),
		CombatV1Script.Cadence.RESPONSE
	)
	for beat_number in range(9, 13):
		root.get_node("BeatClock").beat.emit(beat_number)
	var release_advance := _joy_button(JOY_BUTTON_START)
	release_advance.pressed = false
	Input.parse_input_event(release_advance)
	Input.parse_input_event(_joy_button(JOY_BUTTON_START))
	await process_frame
	_check(
		"Start submits the Response after the handoff without using musical input",
		module.get_cadence(),
		CombatV1Script.Cadence.TACTICAL_VAMP
	)
	prototype.teardown()
	prototype.free()
	print("=== done ===")

func _joy_button(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event

func _joy_axis(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

func _on_drum_input_scored(
	direction: StringName,
	_score: StringName,
	_offset_ms: float,
	_note_consumed: bool
) -> void:
	_observed_drum_inputs.append(direction)

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
