# test/test_decision_snap.gd
# Verifies beat-quantized DECISION execution:
#   - choose_action() during DECISION stores the pending action.
#   - Phase stays DECISION until DECISION_SNAP beats have elapsed.
#   - After snap, phase_changed fires and the phase transitions correctly.
#   - "attack" → ATTACK, "defend" → DEFEND with halved incoming damage.
# Run: godot --headless --path . -s res://test/test_decision_snap.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== beat-quantized DECISION snap tests ===")

	var combat_tscn = load("res://combat/combat_scene.tscn")
	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")

	# --- choose "attack" snaps to ATTACK after DECISION_SNAP beats ---
	var c1 = combat_tscn.instantiate(); root.add_child(c1)
	var hero1  = CharacterData.new(); hero1.max_hp = 100; hero1.hp = 100
	var enemy1 = EnemyData.new();     enemy1.max_hp = 50;  enemy1.hp = 50
	c1.setup([hero1], [enemy1], true)

	var phase_log1: Array = []
	c1.phase_changed.connect(func(p): phase_log1.append(p))

	c1.choose_action(&"attack")
	_check("phase still DECISION before first beat after choose",
		c1.get_phase_name() == &"DECISION", true)

	# DECISION_SNAP == 1: one _on_beat() call executes the action.
	c1.call("_on_beat", 1)
	_check("phase is ATTACK after 1 beat (DECISION_SNAP=1)",
		c1.get_phase_name() == &"ATTACK", true)
	_check("phase_changed emitted with ATTACK (0)",
		phase_log1.has(0), true)

	c1.queue_free()

	# --- choose "defend" → DEFEND phase + halved damage ---
	var c2 = combat_tscn.instantiate(); root.add_child(c2)
	var hero2  = CharacterData.new(); hero2.max_hp = 100; hero2.hp = 100
	var enemy2 = EnemyData.new();     enemy2.max_hp = 50;  enemy2.hp = 50; enemy2.attack_power = 20
	c2.setup([hero2], [enemy2], true)

	c2.choose_action(&"defend")
	c2.call("_on_beat", 1)
	_check("defend choice enters DEFEND phase",
		c2.get_phase_name() == &"DEFEND", true)

	# Simulate damage with defending_stance active: 20 * 0.5 = 10 damage.
	c2.call("_apply_damage_to_character", hero2, 20)
	_check("defending stance halves damage (100 - 10 = 90)",
		hero2.hp, 90)

	c2.queue_free()

	# --- unknown action does not crash ---
	var c3 = combat_tscn.instantiate(); root.add_child(c3)
	var hero3  = CharacterData.new(); hero3.max_hp = 100; hero3.hp = 100
	var enemy3 = EnemyData.new();     enemy3.max_hp = 50;  enemy3.hp = 50
	c3.setup([hero3], [enemy3], true)
	c3.choose_action(&"unknown_action")
	c3.call("_on_beat", 1)
	_check("unknown action stays in DECISION (no crash)",
		c3.get_phase_name() == &"DECISION", true)

	c3.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
