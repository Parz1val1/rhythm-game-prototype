# rhythm_engine/active_note.gd
# Holds a NoteData alongside the wall-clock timestamp of when it was injected
# into RhythmInput's scoring window. Replaces the fragile parallel-array pattern.
class_name ActiveNote
extends RefCounted

var note: NoteData
var inject_time_ms: int
## Wall-clock ms when the note is ideally due for pressing.
## Expiry fires `good_ms` after this value, not after inject_time_ms,
## so pre-injected notes (inserted before the beat) still expire correctly.
var due_time_ms: int

## p_due defaults to p_time (backward-compat: injected exactly when due).
func _init(p_note: NoteData, p_time: int, p_due: int = 0) -> void:
    note = p_note
    inject_time_ms = p_time
    due_time_ms = p_due if p_due > 0 else p_time
