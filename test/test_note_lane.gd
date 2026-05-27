# test/test_note_lane.gd
# Verifies that note_visual.tscn and note_lane.tscn load and have the correct
# structure for the directional approach layout.
# Run: godot --headless --path . -s res://test/test_note_lane.gd
extends SceneTree

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== note lane tests ===")

	# --- NoteVisual scene ---
	var nv_scene = load("res://combat/note_visual.tscn")
	_check("note_visual.tscn loads",           nv_scene != null,              true)
	if nv_scene != null:
		var nv = nv_scene.instantiate()
		root.add_child(nv)
		_check("NoteVisual has Body child",        nv.has_node("Body"),           true)
		_check("NoteVisual has DirectionLabel",    nv.has_node("DirectionLabel"), true)
		_check("NoteVisual has flash_result",      nv.has_method("flash_result"), true)
		_check("NoteVisual has init method",       nv.has_method("init"),         true)
		nv.queue_free()

	# --- NoteLane scene ---
	var nl_scene = load("res://combat/note_lane.tscn")
	_check("note_lane.tscn loads",             nl_scene != null, true)
	if nl_scene != null:
		var nl = nl_scene.instantiate()
		root.add_child(nl)

		# _ready() creates hit zones programmatically; they must exist after add_child.
		_check("NoteLane has HitZone_up",    nl.has_node("HitZone_up"),    true)
		_check("NoteLane has HitZone_down",  nl.has_node("HitZone_down"),  true)
		_check("NoteLane has HitZone_left",  nl.has_node("HitZone_left"),  true)
		_check("NoteLane has HitZone_right", nl.has_node("HitZone_right"), true)
		_check("NoteLane has PhaseInfo",     nl.has_node("PhaseInfo"),     true)
		_check("NoteLane has setup method",  nl.has_method("setup"),       true)

		# Hit zones are ColorRects; each should have exactly one Label child.
		for dir in ["up", "down", "left", "right"]:
			var hz = nl.get_node("HitZone_" + dir)
			_check("HitZone_%s is ColorRect" % dir, hz is ColorRect, true)
			_check("HitZone_%s has label child" % dir,
				hz.get_child_count() >= 1 and hz.get_child(0) is Label, true)

		nl.queue_free()

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
