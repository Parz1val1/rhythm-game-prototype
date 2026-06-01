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

	# Locate RhythmInput autoload node
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

	# Profile with valid_inputs = [&"up", &"down"]
	var CharacterInputProfile = load("res://characters/character_input_profile.gd")
	var profile = CharacterInputProfile.new()
	profile.valid_inputs = [&"up", &"down"]
	ri.set_active_profile(profile)

	_check("up allowed with profile",     ri.is_input_allowed(&"up"),    true)
	_check("down allowed with profile",   ri.is_input_allowed(&"down"),  true)
	_check("left blocked by profile",     ri.is_input_allowed(&"left"),  false)
	_check("right blocked by profile",    ri.is_input_allowed(&"right"), false)

	# Clear profile → all directions allowed (empty valid_inputs = no filter)
	ri.clear_profile()
	_check("up allowed after clear",      ri.is_input_allowed(&"up"),    true)
	_check("left allowed after clear",    ri.is_input_allowed(&"left"),  true)

	# Profile with empty valid_inputs = no filter (open)
	var open_profile = CharacterInputProfile.new()
	open_profile.valid_inputs = []
	ri.set_active_profile(open_profile)
	_check("all allowed when valid_inputs empty", ri.is_input_allowed(&"right"), true)

	ri.clear_profile()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
