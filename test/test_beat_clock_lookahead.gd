# test/test_beat_clock_lookahead.gd
# Verifies that CombatScene exposes note_approaching, phase_changed signals and lookahead_beats.
# Run: godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
#
# NOTE: Uses load() at runtime (not preload at parse-time) to avoid the parse-time
# dependency chain that fails before autoloads (BeatClock, RhythmInput) are initialized.
# Uses root.add_child() because current_scene is null in headless -s mode.
extends SceneTree

func _init() -> void:
	await process_frame   # let autoloads (BeatClock, RhythmInput) initialize
	_run()
	quit()

func _run() -> void:
	print("=== lookahead signal tests ===")

	# load() at runtime: combat_scene.gd is compiled AFTER autoloads exist.
	var combat_tscn = load("res://combat/combat_scene.tscn")
	if combat_tscn == null:
		printerr("FAIL: could not load combat_scene.tscn")
		return
	var combat = combat_tscn.instantiate()
	root.add_child(combat)   # current_scene is null in headless; root is always valid

	_check("note_approaching signal exists",
		combat.has_signal("note_approaching"), true)
	_check("phase_changed signal exists",
		combat.has_signal("phase_changed"), true)
	_check("combo_updated signal exists",
		combat.has_signal("combo_updated"), true)
	_check("lookahead_beats property exists",
		"lookahead_beats" in combat, true)
	_check("lookahead_beats default >= 1",
		combat.lookahead_beats >= 1, true)

	combat.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
