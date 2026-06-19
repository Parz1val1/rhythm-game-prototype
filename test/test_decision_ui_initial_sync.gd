# test/test_decision_ui_initial_sync.gd
# Regression test for a connect-after-emit ordering bug:
#   EncounterManager calls combat.setup() (which, for player_first=true,
#   synchronously emits decision_started) BEFORE the caller (test_scene.gd)
#   calls combat_ui.setup() to connect to that signal. The one-shot emission
#   is missed, so the DecisionMenu never shows for the combat's first turn.
# This test reproduces that exact call order — combat.setup() FIRST, then
# combat_ui.setup() SECOND — and verifies the UI still ends up showing the
# correct phase/menu state, via an immediate sync rather than relying solely
# on the signal having been heard.
# Run: godot --headless --path . -s res://test/test_decision_ui_initial_sync.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== DecisionMenu initial-sync (connect-after-emit) regression tests ===")

	var combat_tscn = load("res://combat/combat_scene.tscn")
	var ui_scene    = load("res://combat/combat_ui.tscn")
	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")

	# --- player_first=true: combat already in DECISION before UI connects ---
	var combat = combat_tscn.instantiate(); root.add_child(combat)
	var hero  = CharacterData.new(); hero.max_hp = 100; hero.hp = 100
	var enemy = EnemyData.new();     enemy.max_hp = 50;  enemy.hp = 50

	# Reproduce the real call order: combat.setup() (and its synchronous
	# decision_started emission) happens BEFORE any UI exists or connects.
	combat.setup([hero], [enemy], true)

	var ui = ui_scene.instantiate(); root.add_child(ui)
	ui.setup(combat, hero)  # connects signals AFTER the emission above already fired

	_check("DecisionMenu visible after late-connecting setup() (player_first=true)",
		ui.get_node("DecisionMenu").visible, true)

	combat.queue_free()
	ui.queue_free()

	# --- player_first=false: combat already in DEFEND before UI connects ---
	# (phase_changed is never emitted for the initial phase at all — this
	# covers the related latent gap for the ambush-start case.)
	var combat2 = combat_tscn.instantiate(); root.add_child(combat2)
	var hero2  = CharacterData.new(); hero2.max_hp = 100; hero2.hp = 100
	var enemy2 = EnemyData.new();     enemy2.max_hp = 50;  enemy2.hp = 50
	combat2.setup([hero2], [enemy2], false)

	var ui2 = ui_scene.instantiate(); root.add_child(ui2)
	ui2.setup(combat2, hero2)

	_check("DecisionMenu stays hidden when combat starts in DEFEND (player_first=false)",
		not ui2.get_node("DecisionMenu").visible, true)
	_check("PhaseLabel reflects DEFEND, not the stale .tscn default 'ATTACK'",
		ui2.get_node("BGPanel/HBoxTop/PhaseLabel").text == "DEFEND", true)

	combat2.queue_free()
	ui2.queue_free()

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
