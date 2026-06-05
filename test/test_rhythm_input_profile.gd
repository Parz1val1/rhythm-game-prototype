# test/test_rhythm_input_profile.gd
# Verifies that RhythmInput respects an active CharacterInputProfile.
# Run: godot --headless --path . -s res://test/test_rhythm_input_profile.gd
extends SceneTree

func _init() -> void:
	await process_frame   # let autoloads initialize
	_run()
	quit()

func _run() -> void:
	print("=== RhythmInput profile tests ===")

	var ri = null
	for child in root.get_children():
		if child.name == "RhythmInput":
			ri = child
			break
	if ri == null:
		printerr("FAIL: RhythmInput autoload not found")
		return

	# API existence
	_check("set_active_profile method exists",   ri.has_method("set_active_profile"), true)
	_check("clear_profile method exists",         ri.has_method("clear_profile"),      true)
	_check("is_input_allowed method exists",      ri.has_method("is_input_allowed"),   true)
	_check("input_chord signal exists",           ri.has_signal("input_chord"),        true)

	var CharacterInputProfile = load("res://characters/character_input_profile.gd")

	# Profile with input_map mapping two directions only
	var profile = CharacterInputProfile.new()
	profile.input_map = {&"rhythm_up": &"up", &"rhythm_down": &"down"}
	ri.set_active_profile(profile)

	_check("up allowed with profile",     ri.is_input_allowed(&"up"),    true)
	_check("down allowed with profile",   ri.is_input_allowed(&"down"),  true)
	_check("left blocked by profile",     ri.is_input_allowed(&"left"),  false)
	_check("right blocked by profile",    ri.is_input_allowed(&"right"), false)

	# Drum aliases are also blocked when profile maps only directional aliases
	_check("drum_left blocked by profile", ri.is_input_allowed(&"drum_left"), false)

	# Clear profile → all directions allowed (built-in default map)
	ri.clear_profile()
	_check("up allowed after clear",      ri.is_input_allowed(&"up"),    true)
	_check("left allowed after clear",    ri.is_input_allowed(&"left"),  true)
	# Built-in default does not map drum actions, but is_input_allowed checks values —
	# drum_left is not a value in _DEFAULT_INPUT_MAP so it is not allowed.
	_check("drum_left not in default map", ri.is_input_allowed(&"drum_left"), false)

	# Profile with empty input_map → falls back to default map (open for directional)
	var open_profile = CharacterInputProfile.new()
	open_profile.input_map = {}
	ri.set_active_profile(open_profile)
	_check("up allowed when input_map empty",    ri.is_input_allowed(&"up"),    true)
	_check("right allowed when input_map empty", ri.is_input_allowed(&"right"), true)

	# Previously-unrepresentable case: directional-only profile rejects drum keys.
	# With input_map this is now fully expressible — no special-case needed.
	var dir_only = CharacterInputProfile.new()
	dir_only.input_map = {
		&"rhythm_up":    &"up",
		&"rhythm_down":  &"down",
		&"rhythm_left":  &"left",
		&"rhythm_right": &"right",
	}
	ri.set_active_profile(dir_only)
	_check("directional-only: up allowed",         ri.is_input_allowed(&"up"),        true)
	_check("directional-only: right allowed",      ri.is_input_allowed(&"right"),     true)
	_check("directional-only: drum_left blocked",  ri.is_input_allowed(&"drum_left"), false)
	_check("directional-only: drum_right blocked", ri.is_input_allowed(&"drum_right"),false)

	# _get_direction with directional-only profile rejects drum_left action
	var drum_ev := InputEventAction.new()
	drum_ev.action = &"drum_left"
	drum_ev.pressed = true
	_check("directional-only: drum_left action → empty dir", ri._get_direction(drum_ev), &"")

	var up_ev := InputEventAction.new()
	up_ev.action = &"rhythm_up"
	up_ev.pressed = true
	_check("directional-only: rhythm_up action → up alias", ri._get_direction(up_ev), &"up")

	ri.clear_profile()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
