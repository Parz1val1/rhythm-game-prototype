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
	_check("input_map exists",              "input_map" in p,                         true)
	_check("chord_inputs exists",           "chord_inputs" in p,                      true)
	_check("chord_window_ms exists",        "chord_window_ms" in p,                   true)
	_check("scoring_mode exists",           "scoring_mode" in p,                      true)
	_check("attack_evaluator exists",       "attack_evaluator" in p,                  true)
	_check("defense_pattern_type exists",   "defense_pattern_type" in p,              true)

	_check("input_map default is empty",    p.input_map.is_empty(),                   true)
	_check("chord_window_ms default 30",    is_equal_approx(p.chord_window_ms, 30.0), true)
	_check("scoring_mode default",          p.scoring_mode == &"rhythm",              true)
	_check("attack_evaluator default",      p.attack_evaluator == &"passthrough",     true)
	_check("defense_pattern_type default",  p.defense_pattern_type == &"directional", true)

	# input_map stores action → alias pairs with StringName keys and values
	p.input_map = {&"rhythm_up": &"up", &"rhythm_down": &"down"}
	_check("input_map stores 2 entries",    p.input_map.size() == 2,                  true)
	_check("input_map key is StringName",   typeof(p.input_map.keys()[0]) == TYPE_STRING_NAME, true)
	_check("input_map value is StringName", typeof(p.input_map.values()[0]) == TYPE_STRING_NAME, true)
	_check("input_map rhythm_up → up",      p.input_map[&"rhythm_up"] == &"up",       true)

	# chord_inputs is Array[Array]
	p.chord_inputs = [[&"drum_left", &"drum_right"], [&"left", &"right"]]
	_check("chord_inputs stores 2 chords",  p.chord_inputs.size() == 2,               true)
	_check("chord[0] has 2 inputs",         p.chord_inputs[0].size() == 2,            true)

	# Luthier profile loads with correct input_map
	var lp = load("res://characters/luthier_profile.tres") as CharacterInputProfile
	_check("luthier_profile loads",         lp != null,                               true)
	_check("luthier input_map has 4 keys",  lp.input_map.size() == 4,                 true)
	_check("luthier rhythm_up → up",        lp.input_map.get(&"rhythm_up") == &"up",  true)
	_check("luthier rhythm_down → down",    lp.input_map.get(&"rhythm_down") == &"down", true)
	_check("luthier rhythm_left → left",    lp.input_map.get(&"rhythm_left") == &"left", true)
	_check("luthier rhythm_right → right",  lp.input_map.get(&"rhythm_right") == &"right", true)

	# Beatrice profile loads with correct input_map
	var bp = load("res://characters/beatrice_profile.tres") as CharacterInputProfile
	_check("beatrice_profile loads",        bp != null,                               true)
	_check("beatrice input_map has 2 keys", bp.input_map.size() == 2,                 true)
	_check("beatrice drum_left → drum_left", bp.input_map.get(&"drum_left") == &"drum_left", true)
	_check("beatrice drum_right → drum_right", bp.input_map.get(&"drum_right") == &"drum_right", true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
