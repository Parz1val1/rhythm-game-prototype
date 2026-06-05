# test/test_string_golem.gd
# Verifies the String Golem encounter: 8 all-single neutral hits, correct beat_offsets, stats.
# Run: godot --headless --path . -s res://test/test_string_golem.gd
extends SceneTree

const EncounterManager = preload("res://combat/encounter_manager.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== String Golem encounter tests ===")

	var enemies = EncounterManager._generate_enemies(&"string_golem")
	_check("returns 1 enemy",                enemies.size() == 1,             true)
	if enemies.size() == 0:
		print("=== done (skipped) ==="); return

	var golem = enemies[0]
	_check("enemy_name is String Golem",     golem.enemy_name == "String Golem", true)
	_check("max_hp == 120",                  golem.max_hp == 120,              true)
	_check("attack_power >= 15",             golem.attack_power >= 15,         true)
	_check("phase_length == 8",              golem.phase_length == 8,          true)
	_check("neutral_pattern has 8 hits",     golem.neutral_pattern.size() == 8, true)

	# All hits are single-lane (lane_count 1)
	var all_single := true
	for hit in golem.neutral_pattern:
		if hit.lane_count != 1:
			all_single = false
	_check("all hits are single-lane",       all_single,                       true)

	# Beat offsets 0..7 are all represented exactly once
	var offsets: Array = []
	for hit in golem.neutral_pattern:
		offsets.append(hit.beat_offset)
	offsets.sort()
	_check("beat offsets are 0.0..7.0",      offsets == [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0], true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
