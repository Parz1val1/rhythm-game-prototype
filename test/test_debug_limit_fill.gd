# test/test_debug_limit_fill.gd
# Debug affordance for limit-break work: CombatScene.debug_fill_limit_gauge()
# instantly fills the active character's limit gauge and emits limit_break_ready
# (so the UI reflects it), without grinding a perfect combo. The trigger key lives
# only in the prototype test scene, so this never leaks into real gameplay.
# Run: godot --headless --path . -s res://test/test_debug_limit_fill.gd
extends SceneTree

var _fail_count: int = 0

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _fail_count > 0 else 0)

func _run() -> void:
	print("=== debug limit-break fill tests ===")

	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")

	var combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)

	_check("debug_fill_limit_gauge method exists",
		combat.has_method("debug_fill_limit_gauge"), true)

	var hero = CharacterData.new()
	hero.character_name = "Hero"; hero.max_hp = 100; hero.hp = 100
	hero.limit_break_gauge = 0.0
	var enemy = EnemyData.new()
	enemy.enemy_name = "Dummy"; enemy.max_hp = 50; enemy.hp = 50
	combat.setup([hero], [enemy], true)

	var ready_emits: Array = []
	combat.limit_break_ready.connect(func(c): ready_emits.append(c))

	# Fill from empty: gauge maxes and limit_break_ready fires once.
	combat.debug_fill_limit_gauge()
	_check("gauge filled to 1.0", is_equal_approx(hero.limit_break_gauge, 1.0), true)
	_check("limit_break_ready emitted once", ready_emits.size(), 1)
	_check("emitted with the active character", ready_emits.size() == 1 and ready_emits[0] == hero, true)

	# Calling again while already full must not re-emit (matches charge-path guard).
	combat.debug_fill_limit_gauge()
	_check("gauge still 1.0 after second fill", is_equal_approx(hero.limit_break_gauge, 1.0), true)
	_check("no duplicate limit_break_ready", ready_emits.size(), 1)

	combat.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
