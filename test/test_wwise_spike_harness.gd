# Scene-contract regression tests for the executable Wwise spike harness.
# Run: godot --headless --path . -s res://test/test_wwise_spike_harness.gd
extends SceneTree

var _has_failures: bool = false


func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)


func _run() -> void:
	print("=== Wwise spike harness tests ===")
	var harness_scene := load("res://spikes/wwise/wwise_spike_harness.tscn") as PackedScene
	_check("Wwise spike harness scene is available", harness_scene != null, true)
	if harness_scene == null:
		print("=== done ===")
		return

	var harness := harness_scene.instantiate()
	var listeners := harness.find_children("*", "AkListener2D", true, false)
	_check("harness provides one Wwise listener", listeners.size(), 1)
	if listeners.size() == 1:
		_check(
			"harness listener is a default listener",
			bool(listeners[0].get("is_default_listener")),
			true
		)
	harness.free()
	print("=== done ===")


func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
