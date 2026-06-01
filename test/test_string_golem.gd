# test/test_string_golem.gd
# Verifies the String Golem encounter: 8 all-targeted notes, correct directions, stats.
# Run: godot --headless --path . -s res://test/test_string_golem.gd
extends SceneTree

const EncounterManager = preload("res://combat/encounter_manager.gd")
const NoteData         = preload("res://rhythm_engine/note_data.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== String Golem encounter tests ===")

	# Access the enemy via the static method
	var enemies = EncounterManager._generate_enemies(&"string_golem")
	_check("returns 1 enemy",                enemies.size() == 1,             true)
	if enemies.size() == 0:
		print("=== done (skipped) ==="); return

	var golem = enemies[0]
	_check("enemy_name is String Golem",     golem.enemy_name == "String Golem", true)
	_check("max_hp == 120",                  golem.max_hp == 120,              true)
	_check("attack_power >= 15",             golem.attack_power >= 15,         true)
	_check("phase_length == 8",              golem.phase_length == 8,          true)
	_check("pattern has 8 notes",            golem.pattern.size() == 8,        true)

	# Verify all notes are targeted
	var all_targeted := true
	for note in golem.pattern:
		if note.mode != &"targeted":
			all_targeted = false
	_check("all notes are targeted",         all_targeted,                     true)

	# Verify beat_offset 0..7 are all represented exactly once
	var offsets: Array = []
	for note in golem.pattern:
		offsets.append(note.beat_offset)
	offsets.sort()
	_check("beat offsets are 0..7",          offsets == [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0], true)

	# Verify direction pattern: up,down,up,down,left,right,left,right
	var expected_dirs: Array[StringName] = [
		&"up", &"down", &"up", &"down",
		&"left", &"right", &"left", &"right",
	]
	var dirs_match := true
	for i in range(golem.pattern.size()):
		if golem.pattern[i].direction != expected_dirs[i]:
			dirs_match = false
	_check("directions match alternating pattern", dirs_match,                true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
