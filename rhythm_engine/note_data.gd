## Which beat within the repeating pattern this note fires on (0-indexed).
## Float so sub-beat patterns (e.g. 0.5, 1.5) work for rapid drumming / simultaneous hits.
## Whole-beat patterns (0, 1, 2 …) continue to work unchanged.
class_name NoteData
extends Resource

@export var beat_offset: float = 0.0

## Direction the player must press.
## Directional (Luthier): up / down / left / right.
## Percussive (Beatrice): drum_left / drum_right / drum_both.
@export_enum("up", "down", "left", "right", "drum_left", "drum_right", "drum_both") var direction: String = "up"

## Scoring mode for this note.
## targeted  — player must press the matching direction within the timing window.
## free_form — any press near the beat counts regardless of direction.
@export_enum("targeted", "free_form") var mode: String = "free_form"
