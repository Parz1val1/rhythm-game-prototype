# test/test_character_input_profile.gd
# Verifies CharacterInputProfile resource fields and defaults.
# Run: godot --headless --path . -s res://test/test_character_input_profile.gd
extends SceneTree

const CharacterInputProfile = preload("res://characters/character_input_profile.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== CharacterInputProfile tests ===")

	var p = CharacterInputProfile.new()

	# Field existence and defaults
	_check("valid_inputs exists",           "valid_inputs" in p,                      true)
	_check("chord_inputs exists",           "chord_inputs" in p,                      true)
	_check("chord_window_ms exists",        "chord_window_ms" in p,                   true)
	_check("scoring_mode exists",           "scoring_mode" in p,                      true)
	_check("attack_evaluator exists",       "attack_evaluator" in p,                  true)
	_check("defense_pattern_type exists",   "defense_pattern_type" in p,              true)

	_check("chord_window_ms default 30",    is_equal_approx(p.chord_window_ms, 30.0), true)
	_check("scoring_mode default",          p.scoring_mode == &"rhythm",              true)
	_check("attack_evaluator default",      p.attack_evaluator == &"passthrough",     true)
	_check("defense_pattern_type default",  p.defense_pattern_type == &"directional", true)

	# valid_inputs is an Array[StringName]
	p.valid_inputs = [&"up", &"down", &"left", &"right"]
	_check("valid_inputs stores 4 entries", p.valid_inputs.size() == 4,               true)
	_check("valid_inputs first is StringName",
		typeof(p.valid_inputs[0]) == TYPE_STRING_NAME, true)

	# chord_inputs is Array[Array]
	p.chord_inputs = [[&"up", &"down"], [&"left", &"right"]]
	_check("chord_inputs stores 2 chords",  p.chord_inputs.size() == 2,               true)
	_check("chord[0] has 2 inputs",         p.chord_inputs[0].size() == 2,            true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
