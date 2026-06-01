# test/test_defense_type_seam.gd
# Verifies the defense_pattern_type branch point in CombatScene:
#   - Default (no profile) routes through &"directional"
#   - Profile with &"directional" behaves identically to default
#   - Profile with &"percussive" is recognized without crashing
#   - get_defense_type() returns the active type for UI inspection
# Run: godot --headless --path . -s res://test/test_defense_type_seam.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== defense type seam tests ===")

	var combat_tscn = load("res://combat/combat_scene.tscn")
	var combat = combat_tscn.instantiate()
	root.add_child(combat)

	# API existence
	_check("get_defense_type method exists",
		combat.has_method("get_defense_type"), true)

	# Default (no profile) → &"directional"
	_check("default defense type is directional",
		combat.get_defense_type() == &"directional", true)

	# Set a directional profile → still &"directional"
	var CharacterInputProfile = load("res://characters/character_input_profile.gd")
	var dir_profile = CharacterInputProfile.new()
	dir_profile.defense_pattern_type = &"directional"
	combat.set_active_profile(dir_profile)
	_check("directional profile → type is directional",
		combat.get_defense_type() == &"directional", true)

	# Set a percussive profile → &"percussive" recognized, no crash
	var perc_profile = CharacterInputProfile.new()
	perc_profile.defense_pattern_type = &"percussive"
	combat.set_active_profile(perc_profile)
	_check("percussive profile → type is percussive",
		combat.get_defense_type() == &"percussive", true)

	# Clear profile → back to directional
	combat.set_active_profile(null)
	_check("after clear → type is directional",
		combat.get_defense_type() == &"directional", true)

	combat.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
