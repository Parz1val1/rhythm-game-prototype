# test/test_decision_phase.gd
# Verifies Phase.DECISION enum value, decision_started signal, choose_action()
# method, and that setup() enters DECISION when player_first=true.
# Run: godot --headless --path . -s res://test/test_decision_phase.gd
extends SceneTree

# Script-level members instead of _run()-local vars: GDScript lambdas capture
# local variables BY VALUE at creation time, so mutating a local inside a
# lambda does not propagate back to the enclosing function. Member vars are
# captured by reference (via `self`), so they work correctly here.
var _signal_fired := false
var _signal_actor = null

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== DECISION phase tests ===")

	var combat_tscn = load("res://combat/combat_scene.tscn")
	var combat = combat_tscn.instantiate()
	root.add_child(combat)

	# --- API existence ---
	_check("has decision_started signal",   combat.has_signal("decision_started"),   true)
	_check("has choose_action method",      combat.has_method("choose_action"),       true)
	_check("has get_phase_name method",     combat.has_method("get_phase_name"),      true)

	# --- Setup enters DECISION ---
	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")
	var hero  = CharacterData.new()
	hero.max_hp = 100; hero.hp = 100
	var enemy = EnemyData.new()
	enemy.max_hp = 50; enemy.hp = 50

	combat.decision_started.connect(func(a): _signal_fired = true; _signal_actor = a)

	combat.setup([hero], [enemy], true)

	_check("player_first=true starts in DECISION",
		combat.get_phase_name() == &"DECISION", true)
	_check("decision_started signal fired",
		_signal_fired, true)
	_check("decision_started actor is hero",
		_signal_actor == hero, true)

	# --- player_first=false starts in DEFEND ---
	var combat2 = combat_tscn.instantiate()
	root.add_child(combat2)
	var hero2  = CharacterData.new(); hero2.max_hp = 100; hero2.hp = 100
	var enemy2 = EnemyData.new();     enemy2.max_hp = 50;  enemy2.hp = 50
	combat2.setup([hero2], [enemy2], false)
	_check("player_first=false starts in DEFEND",
		combat2.get_phase_name() == &"DEFEND", true)

	# --- choose_action() does not crash ---
	combat.choose_action(&"attack")
	_check("choose_action attack does not crash", true, true)
	combat.choose_action(&"defend")
	_check("choose_action defend does not crash", true, true)

	combat.queue_free()
	combat2.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
