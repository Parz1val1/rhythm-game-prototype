# test/test_combat_ui.gd
# Verifies combat_ui.tscn loads and has the required node structure.
# Run: godot --headless --path . -s res://test/test_combat_ui.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== CombatUI tests ===")

	var ui_scene = load("res://combat/combat_ui.tscn")
	_check("combat_ui.tscn loads",            ui_scene != null,                                    true)
	if ui_scene == null:
		print("=== done (skipped — scene did not load) ===")
		return

	var ui = ui_scene.instantiate()
	root.add_child(ui)

	_check("CombatUI has BGPanel",            ui.has_node("BGPanel"),                              true)
	_check("BGPanel has HBoxTop",             ui.has_node("BGPanel/HBoxTop"),                      true)
	_check("HBoxTop has PhaseLabel",          ui.has_node("BGPanel/HBoxTop/PhaseLabel"),           true)
	_check("HBoxTop has BeatPulse",           ui.has_node("BGPanel/HBoxTop/BeatPulse"),            true)
	_check("HBoxTop has ComboLabel",          ui.has_node("BGPanel/HBoxTop/ComboLabel"),           true)
	_check("CombatUI has PlayerBar",          ui.has_node("PlayerBar"),                            true)
	_check("PlayerBar has PlayerName",        ui.has_node("PlayerBar/PlayerName"),                 true)
	_check("PlayerBar has HPBarBG",           ui.has_node("PlayerBar/HPBarBG"),                    true)
	_check("PlayerBar has HPBarFill",         ui.has_node("PlayerBar/HPBarBG/HPBarFill"),          true)
	_check("PlayerBar has HPNumbers",         ui.has_node("PlayerBar/HPNumbers"),                  true)
	_check("CombatUI has EnemyBar",           ui.has_node("EnemyBar"),                             true)
	_check("EnemyBar has PlayerName",         ui.has_node("EnemyBar/PlayerName"),                  true)
	_check("EnemyBar has HPBarFill",          ui.has_node("EnemyBar/HPBarBG/HPBarFill"),           true)
	_check("EnemyBar has HPNumbers",          ui.has_node("EnemyBar/HPNumbers"),                   true)
	_check("CombatUI has LimitBar",           ui.has_node("LimitBar"),                             true)
	_check("LimitBar has LimitBarBG",         ui.has_node("LimitBar/LimitBarBG"),                  true)
	_check("LimitBar has LimitBarFill",       ui.has_node("LimitBar/LimitBarBG/LimitBarFill"),     true)
	_check("LimitBar has LimitReady",         ui.has_node("LimitBar/LimitReady"),                  true)
	_check("LimitReady is hidden by default", not ui.get_node("LimitBar/LimitReady").visible,      true)
	_check("CombatUI has setup method",       ui.has_method("setup"),                              true)

	ui.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
