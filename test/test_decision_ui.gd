# test/test_decision_ui.gd
# Verifies the DecisionMenu node structure in combat_ui.tscn and that the
# show_decision_menu / hide_decision_menu methods exist.
# Run: godot --headless --path . -s res://test/test_decision_ui.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== DecisionMenu UI tests ===")

	var ui_scene = load("res://combat/combat_ui.tscn")
	_check("combat_ui.tscn loads", ui_scene != null, true)
	if ui_scene == null:
		print("=== done (skipped) ===")
		return

	var ui = ui_scene.instantiate()
	root.add_child(ui)

	_check("CombatUI has DecisionMenu",                  ui.has_node("DecisionMenu"),                              true)
	_check("DecisionMenu has AttackButton",              ui.has_node("DecisionMenu/AttackButton"),                 true)
	_check("DecisionMenu has DefendButton",              ui.has_node("DecisionMenu/DefendButton"),                 true)
	_check("DecisionMenu has ItemButton",                ui.has_node("DecisionMenu/ItemButton"),                   true)
	_check("DecisionMenu has RunButton",                 ui.has_node("DecisionMenu/RunButton"),                    true)
	_check("DecisionMenu hidden by default",             not ui.get_node("DecisionMenu").visible,                  true)
	_check("has show_decision_menu method",              ui.has_method("show_decision_menu"),                      true)
	_check("has hide_decision_menu method",               ui.has_method("hide_decision_menu"),                     true)

	# show/hide work.
	ui.show_decision_menu()
	_check("show_decision_menu makes it visible",        ui.get_node("DecisionMenu").visible,                      true)
	ui.hide_decision_menu()
	_check("hide_decision_menu hides it",                not ui.get_node("DecisionMenu").visible,                  true)

	ui.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
