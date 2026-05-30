# test/test_audio_feedback.gd
# Verifies audio_feedback.tscn structure and pitch calculation logic.
# Run: godot --headless --path . -s res://test/test_audio_feedback.gd
extends SceneTree

const CharacterData = preload("res://characters/character_data.gd")
const SoloStyle     = preload("res://characters/solo_style.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== AudioFeedback tests ===")

	# --- Scene structure ---
	var af_scene = load("res://combat/audio_feedback.tscn")
	_check("audio_feedback.tscn loads",        af_scene != null,               true)
	if af_scene == null:
		print("=== done (skipped — scene did not load) ===")
		return

	var af = af_scene.instantiate()
	root.add_child(af)

	_check("has PerfectPlayer",                af.has_node("PerfectPlayer"),    true)
	_check("has GoodPlayer",                   af.has_node("GoodPlayer"),       true)
	_check("has MissPlayer",                   af.has_node("MissPlayer"),       true)
	_check("has setup method",                 af.has_method("setup"),          true)

	# --- Pitch calculation without SoloStyle (should return 1.0) ---
	var c_bare := CharacterData.new()
	c_bare.solo_style = null
	af._active_character = c_bare
	_check("no style → pitch 1.0 (up)",        is_equal_approx(af._get_pitch(&"up"),    1.0), true)
	_check("no style → pitch 1.0 (invalid)",   is_equal_approx(af._get_pitch(&"???"),   1.0), true)

	# --- Pitch calculation with major pentatonic SoloStyle [0, 2, 7, 9] ---
	var style := SoloStyle.new()
	style.scale_steps = [0, 2, 7, 9]
	var c_styled := CharacterData.new()
	c_styled.solo_style = style
	af._active_character = c_styled

	# up → scale_steps[0] = 0 semitones → pitch = 1.0
	_check("up → 0 semitones → 1.0",          is_equal_approx(af._get_pitch(&"up"),    1.0),   true)
	# right → scale_steps[1] = 2 semitones → 2^(2/12) ≈ 1.1225
	_check("right → 2 semitones ≈ 1.1225",    af._get_pitch(&"right") > 1.1 and af._get_pitch(&"right") < 1.15, true)
	# down → scale_steps[2] = 7 semitones → 2^(7/12) ≈ 1.4983
	_check("down → 7 semitones ≈ 1.498",      af._get_pitch(&"down")  > 1.48 and af._get_pitch(&"down") < 1.52, true)
	# left → scale_steps[3] = 9 semitones → 2^(9/12) ≈ 1.6818
	_check("left → 9 semitones ≈ 1.682",      af._get_pitch(&"left")  > 1.67 and af._get_pitch(&"left") < 1.70, true)
	# unknown direction → idx defaults to 0 → pitch = 1.0
	_check("unknown dir → 1.0",               is_equal_approx(af._get_pitch(&"xyz"),   1.0),   true)

	af.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
