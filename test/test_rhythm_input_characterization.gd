# test/test_rhythm_input_characterization.gd
# Safety-net characterization tests: captures the observable direction-alias
# output of RhythmInput._get_direction() for null, Luthier, and Beatrice profiles.
#
# These tests are designed to pass against BOTH the current code and the refactored
# code. They test behavior (output alias strings) through the actual .tres profile
# files rather than constructing profiles manually — so when those resources are
# updated during the refactor, the observable output stays identical.
#
# What is NOT tested here (behavior that changes intentionally during the refactor):
#   - is_input_allowed() for Luthier with drum keys: currently returns true (all
#     allowed when valid_inputs=[]), intentionally becomes false after input_map
#     makes the allowed set explicit. That contract is tested in test_rhythm_input_profile.gd.
#
# Run: godot --headless --path . -s res://test/test_rhythm_input_characterization.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== RhythmInput characterization tests ===")

	var ri = null
	for child in root.get_children():
		if child.name == "RhythmInput":
			ri = child
			break
	if ri == null:
		printerr("FAIL: RhythmInput autoload not found")
		return

	# InputEventAction.is_action_pressed(name) is purely data-based:
	# checks ev.action == name && ev.pressed. Works correctly in headless mode
	# without any InputMap configuration.

	# --- 1. Null profile → built-in default translation ---
	ri.clear_profile()
	_check("null: rhythm_up   → up",    ri._get_direction(_action(&"rhythm_up")),    &"up")
	_check("null: rhythm_down  → down",  ri._get_direction(_action(&"rhythm_down")),  &"down")
	_check("null: rhythm_left  → left",  ri._get_direction(_action(&"rhythm_left")),  &"left")
	_check("null: rhythm_right → right", ri._get_direction(_action(&"rhythm_right")), &"right")
	_check("null: drum_left    → empty", ri._get_direction(_action(&"drum_left")),    &"")
	_check("null: drum_right   → empty", ri._get_direction(_action(&"drum_right")),   &"")
	_check("null: bogus        → empty", ri._get_direction(_action(&"bogus")),         &"")

	# --- 2. Luthier profile → translated arrow aliases ---
	var luthier_profile = load("res://characters/luthier_profile.tres")
	ri.set_active_profile(luthier_profile)
	_check("luthier: rhythm_up   → up",    ri._get_direction(_action(&"rhythm_up")),    &"up")
	_check("luthier: rhythm_down  → down",  ri._get_direction(_action(&"rhythm_down")),  &"down")
	_check("luthier: rhythm_left  → left",  ri._get_direction(_action(&"rhythm_left")),  &"left")
	_check("luthier: rhythm_right → right", ri._get_direction(_action(&"rhythm_right")), &"right")
	_check("luthier: drum_left    → empty", ri._get_direction(_action(&"drum_left")),    &"")

	# --- 3. Beatrice profile → drum action names as direction aliases ---
	var beatrice_profile = load("res://characters/beatrice_profile.tres")
	ri.set_active_profile(beatrice_profile)
	_check("beatrice: drum_left   → drum_left",  ri._get_direction(_action(&"drum_left")),   &"drum_left")
	_check("beatrice: drum_right  → drum_right", ri._get_direction(_action(&"drum_right")),  &"drum_right")
	_check("beatrice: rhythm_up   → empty",      ri._get_direction(_action(&"rhythm_up")),   &"")

	# --- 4. is_input_allowed — behaviors preserved across refactor ---
	# Null profile: aliases in the default map are allowed.
	# NOTE: drum_left is NOT in _DEFAULT_INPUT_MAP so is_input_allowed(&"drum_left")
	# returns false after the refactor (was true before under "null = no filter").
	# That behavior change is intentional and is NOT captured here.
	ri.clear_profile()
	_check("null: up allowed",         ri.is_input_allowed(&"up"),        true)
	_check("null: down allowed",       ri.is_input_allowed(&"down"),      true)

	# Beatrice profile: drum aliases allowed, arrow aliases blocked.
	ri.set_active_profile(beatrice_profile)
	_check("beatrice: drum_left allowed",  ri.is_input_allowed(&"drum_left"),  true)
	_check("beatrice: drum_right allowed", ri.is_input_allowed(&"drum_right"), true)
	_check("beatrice: up blocked",         ri.is_input_allowed(&"up"),         false)
	_check("beatrice: right blocked",      ri.is_input_allowed(&"right"),      false)

	ri.clear_profile()
	print("=== done ===")

func _action(action_name: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	return ev

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
