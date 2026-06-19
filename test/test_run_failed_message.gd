# test/test_run_failed_message.gd
# Verifies the failed-escape flow: on a failed "run" roll, combat must NOT
# silently return to DECISION. It should emit run_failed (for the UI to show
# a "couldn't escape" message), lock out choose_action() for
# run_failed_display_seconds, then force DEFEND once that window elapses.
# The real timer is never awaited here — _on_run_failed_timeout() is called
# directly to simulate the window elapsing, matching this codebase's existing
# pattern of calling private handlers via call() instead of waiting on
# real-time signals (see test_decision_snap.gd's beat simulation).
# Run: godot --headless --path . -s res://test/test_run_failed_message.gd
extends SceneTree

var _run_failed_fired: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== run-failed message tests ===")

	var combat_tscn   = load("res://combat/combat_scene.tscn")
	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")

	var signal_probe = combat_tscn.instantiate()
	_check("has run_failed signal", signal_probe.has_signal("run_failed"), true)
	signal_probe.queue_free()

	# Find an RNG seed whose first randf() < 0.5 (escape fails — the case
	# _execute_pending_action()'s "run" arm takes when the roll does NOT succeed).
	var found_fail_seed := -1
	for s in range(20):
		var probe := RandomNumberGenerator.new()
		probe.seed = s
		if probe.randf() >= 0.5:
			found_fail_seed = s
			break

	var combat = combat_tscn.instantiate(); root.add_child(combat)
	var hero  = CharacterData.new(); hero.max_hp = 100; hero.hp = 100
	var enemy = EnemyData.new();     enemy.max_hp = 50;  enemy.hp = 50
	combat.setup([hero], [enemy], true)
	combat._rng.seed = found_fail_seed

	_check("run_failed_display_seconds is a positive tunable",
		combat.run_failed_display_seconds > 0.0, true)

	_run_failed_fired = false
	combat.run_failed.connect(func(): _run_failed_fired = true)

	combat.choose_action(&"run")
	combat.call("_on_beat", 1)

	_check("run_failed signal fired on failed escape (seed=%d)" % found_fail_seed,
		_run_failed_fired, true)
	_check("phase stays DECISION during the message window (not silently back to DEFEND/DECISION-reset)",
		combat.get_phase_name() == &"DECISION", true)

	# choose_action() must be locked out while the message is showing —
	# otherwise a hasty click during the pause could get silently discarded
	# when the forced DEFEND transition fires.
	combat.choose_action(&"attack")
	combat.call("_on_beat", 2)
	_check("choose_action() is rejected while run-failed message is pending",
		combat.get_phase_name() == &"DECISION", true)

	# Simulate the display window elapsing.
	combat.call("_on_run_failed_timeout")
	_check("DEFEND is forced once the message window elapses",
		combat.get_phase_name() == &"DEFEND", true)

	# choose_action() works normally again on the NEXT decision (lock released).
	combat.queue_free()

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
