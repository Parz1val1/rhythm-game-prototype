# test/test_scoring.gd
# Headless verification for the score_timing() thresholds.
# Run with: godot --headless --path . -s res://test/test_scoring.gd
# Autoloads ARE active when launched with --path, so RhythmInput is available.
extends SceneTree

func _init() -> void:
	await process_frame   # let autoloads initialize
	_run()
	quit()

func _run() -> void:
	print("=== score_timing() tests ===")
	# Default thresholds: perfect_ms=50, good_ms=120
	# Access RhythmInput autoload through the scene tree
	# (Autoloads are children of the root node)
	var ri = null
	for child in root.get_children():
		if child.name == "RhythmInput":
			ri = child
			break

	if ri == null:
		printerr("FAIL: RhythmInput autoload not found!")
		return

	_check("exact beat",       ri.score_timing(0.0),   &"perfect")
	_check("perfect boundary", ri.score_timing(50.0),  &"perfect")
	_check("just over perfect",ri.score_timing(50.1),  &"good")
	_check("good mid",         ri.score_timing(85.0),  &"good")
	_check("good boundary",    ri.score_timing(120.0), &"good")
	_check("just over good",   ri.score_timing(120.1), &"miss")
	_check("clear miss",       ri.score_timing(200.0), &"miss")
	print("=== done ===")

func _check(label: String, got: StringName, expected: StringName) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
