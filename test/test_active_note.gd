# test/test_active_note.gd
# Run: godot --headless --path . -s res://test/test_active_note.gd
extends SceneTree

const NoteData    = preload("res://rhythm_engine/note_data.gd")
const ActiveNote  = preload("res://rhythm_engine/active_note.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== ActiveNote tests ===")

    var note := NoteData.new()
    note.direction = &"up"
    note.mode = &"targeted"
    note.beat_offset = 0

    var inject_time := 12345
    var an := ActiveNote.new(note, inject_time)

    _check("stores note reference",     an.note == note,                  true)
    _check("stores inject_time",        an.inject_time_ms == inject_time, true)
    _check("note direction preserved",  an.note.direction == &"up",       true)
    _check("note mode preserved",       an.note.mode == &"targeted",      true)

    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
