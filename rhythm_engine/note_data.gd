## Which beat within the repeating pattern this note fires on (0-indexed, whole beats only).
## E.g. beat_offset=2 fires on beat index 2 of a 4-beat pattern.
## Stored as int because patterns fire on whole beats in this prototype.
## Promote to float when half-beat notes are needed.
class_name NoteData
extends Resource

@export var beat_offset: int = 0

## Direction the player must press. One of: &"up", &"down", &"left", &"right"
@export var direction: StringName = &"up"

## Scoring mode for this note.
## &"free_form" — any press near the beat counts regardless of direction.
## &"targeted"  — player must press the matching direction within the timing window.
@export var mode: StringName = &"free_form"
