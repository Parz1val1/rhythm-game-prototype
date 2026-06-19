# test/test_run_failed_ui.gd
# Verifies the run-failed message label in combat_ui:
#   - MessageLabel node exists, hidden by default.
#   - Calling the run_failed handler shows it with non-empty text.
#   - _apply_phase_display() (called on any real phase transition, including
#     the forced DEFEND after the message window) hides it again.
# Run: godot --headless --path . -s res://test/test_run_failed_ui.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== run-failed message UI tests ===")

	var ui_scene = load("res://combat/combat_ui.tscn")
	_check("combat_ui.tscn loads", ui_scene != null, true)
	if ui_scene == null:
		print("=== done (skipped) ===")
		return

	var ui = ui_scene.instantiate()
	root.add_child(ui)

	_check("CombatUI has MessageLabel",          ui.has_node("MessageLabel"),                    true)
	_check("MessageLabel hidden by default",     not ui.get_node("MessageLabel").visible,        true)

	ui.call("_on_run_failed")
	_check("run_failed handler shows the label", ui.get_node("MessageLabel").visible,             true)
	_check("run_failed handler sets non-empty text",
		ui.get_node("MessageLabel").text.length() > 0, true)

	ui.call("_apply_phase_display", 1)  # simulates the forced DEFEND transition
	_check("phase display update hides the message again",
		not ui.get_node("MessageLabel").visible, true)

	ui.queue_free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
