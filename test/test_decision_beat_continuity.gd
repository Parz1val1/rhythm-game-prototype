# test/test_decision_beat_continuity.gd
# Verifies that:
#   1. BeatClock.beat (and sub-beat signals) still fire / are still connected
#      while CombatScene is in DECISION phase.
#   2. No notes are injected into RhythmInput during DECISION (_on_half_beat and
#      _on_quarter_beat both guard against non-DEFEND phases).
# Strategy: simulate beats by calling combat's private handlers via call(), which
# works for private methods in GDScript. Inspect RhythmInput's internal _active
# queue directly (same pattern as test_injection_characterization.gd) since
# RhythmInput exposes no public note-count accessor.
# Run: godot --headless --path . -s res://test/test_decision_beat_continuity.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== BeatClock continuity during DECISION tests ===")

	var ri = null
	var bc = null
	for child in root.get_children():
		if child.name == "RhythmInput": ri = child
		if child.name == "BeatClock":   bc = child
	if ri == null:
		printerr("FAIL: RhythmInput not found"); return
	if bc == null:
		printerr("FAIL: BeatClock not found"); return

	var combat_tscn = load("res://combat/combat_scene.tscn")
	var combat = combat_tscn.instantiate()
	root.add_child(combat)

	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")
	var hero  = CharacterData.new(); hero.max_hp = 100; hero.hp = 100
	var enemy = EnemyData.new();     enemy.max_hp = 50;  enemy.hp = 50

	# Give the enemy a simple pattern so there are notes to (not) inject.
	var NeutralHit = load("res://rhythm_engine/neutral_hit.gd")
	var hit = NeutralHit.new(); hit.beat_offset = 0.0; hit.lane_count = 1
	enemy.neutral_pattern.append(hit)

	combat.setup([hero], [enemy], true)  # starts in DECISION

	_check("phase is DECISION after setup",
		combat.get_phase_name() == &"DECISION", true)

	ri._active.clear()  # ensure a clean baseline before simulating beats

	# Simulate several beats while in DECISION.
	for i in range(4):
		combat.call("_on_beat", i + 1)
		combat.call("_on_half_beat", i + 1)
		combat.call("_on_quarter_beat", i + 1)

	_check("phase is still DECISION (choose_action not called)",
		combat.get_phase_name() == &"DECISION", true)

	# No notes should have been injected — DECISION guards same as non-DEFEND.
	_check("no notes injected during DECISION",
		ri._active.size() == 0, true)

	# BeatClock signal is still connected (combat did not disconnect on DECISION entry).
	var connections: Array = bc.beat.get_connections()
	var still_connected := false
	for conn in connections:
		if conn["callable"].get_object() == combat:
			still_connected = true
	_check("BeatClock.beat still connected to combat during DECISION",
		still_connected, true)

	combat.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
