# rhythm_engine/active_note.gd
# Holds a NoteData alongside the wall-clock timestamp of when it was injected
# into RhythmInput's scoring window. Replaces the fragile parallel-array pattern.
class_name ActiveNote
extends RefCounted

var note: NoteData
var inject_time_ms: int

func _init(p_note: NoteData, p_time: int) -> void:
    note = p_note
    inject_time_ms = p_time
