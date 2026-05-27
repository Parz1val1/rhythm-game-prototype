## Which beat within the repeating pattern this note fires on (0-indexed, whole beats only).
## E.g. beat_offset=2 fires on beat index 2 of a 4-beat pattern.
## Stored as int because patterns fire on whole beats in this prototype.
## Promote to float when half-beat notes are needed.
class_name NoteData
extends Resource

@export var beat_offset: int = 0

## Direction the player must press.
## In free_form mode this still drives the pitch of the audio feedback sound.
@export_enum("up", "down", "left", "right") var direction: String = "up"

## Scoring mode for this note.
## targeted  — player must press the matching direction within the timing window.
## free_form — any press near the beat counts regardless of direction.
@export_enum("targeted", "free_form") var mode: String = "free_form"
