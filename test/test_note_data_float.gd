# test/test_note_data_float.gd
# Verifies that NoteData.beat_offset is a float and fractional values are stored
# correctly. Also confirms whole-beat (integer) values still compare correctly
# so existing encounter patterns are unaffected by the promotion.
# Run: godot --headless --path . -s res://test/test_note_data_float.gd
extends SceneTree

const NoteData = preload("res://rhythm_engine/note_data.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== NoteData beat_offset float tests ===")

	var n = NoteData.new()

	# Field type check
	_check("beat_offset default is 0.0",      n.beat_offset == 0.0,                     true)
	_check("beat_offset is float",             typeof(n.beat_offset) == TYPE_FLOAT,      true)

	# Fractional assignment
	n.beat_offset = 0.5
	_check("beat_offset stores 0.5",          is_equal_approx(n.beat_offset, 0.5),      true)
	n.beat_offset = 1.5
	_check("beat_offset stores 1.5",          is_equal_approx(n.beat_offset, 1.5),      true)

	# Whole-beat comparison: abs(note.beat_offset - float(beat_index)) < 0.01
	n.beat_offset = 2.0
	_check("whole-beat compare index=2",      abs(n.beat_offset - float(2)) < 0.01,     true)
	_check("whole-beat compare index=1 false",abs(n.beat_offset - float(1)) < 0.01,     false)

	# Integer assignment auto-promotes
	n.beat_offset = 3
	_check("int 3 promotes to float 3.0",     is_equal_approx(n.beat_offset, 3.0),      true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
