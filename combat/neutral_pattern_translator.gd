## Translates a NeutralHit (abstract: beat_offset + lane_count) into one or two
## NoteData objects using the defending character's defense_pattern_type.
##
## Direction resolution — seeded by beat_offset for determinism and replayability:
##
##   Directional (Luthier): cycle [up, right, down, left].
##     index = int(beat_offset) % 4  (whole-beat granularity).
##     lane_count 1 → that one arrow.
##     lane_count 2 → that arrow + the opposite: (index+2)%4.
##     Arrow Archer (8 whole beats) resolves to up/right/down/left/up/right/down/left —
##     identical to its original Luthier-authored pattern.
##
##   Percussive (Beatrice): cycle [drum_left, drum_right].
##     index = int(beat_offset * 2) % 2  (half-beat granularity).
##     lane_count 1 → that hand.
##     lane_count 2 → drum_both (always, regardless of beat_offset).
##
## The same NeutralHit + the same defense_type produces the same NoteData direction
## every call — no randomness, no shared state. Enemies are vocabulary-free; each
## character's translator gives them a distinct feel for free.
class_name NeutralPatternTranslator

const NoteData = preload("res://rhythm_engine/note_data.gd")

const _DIR_CYCLE  := ["up", "right", "down", "left"]
const _PERC_CYCLE := ["drum_left", "drum_right"]

## Returns an Array of NoteData (1 or 2 elements).
## defense_type should be &"percussive" or &"directional"; anything else → directional.
static func resolve_notes(hit: Resource, defense_type: StringName) -> Array:
	if defense_type == &"percussive":
		return _percussive(hit)
	return _directional(hit)

static func _percussive(hit: Resource) -> Array:
	var note := NoteData.new()
	note.beat_offset = hit.beat_offset
	note.mode = "targeted"
	if hit.lane_count >= 2:
		note.direction = "drum_both"
	else:
		note.direction = _PERC_CYCLE[int(hit.beat_offset * 2.0) % 2]
	return [note]

static func _directional(hit: Resource) -> Array:
	var idx: int = int(hit.beat_offset) % 4
	if hit.lane_count >= 2:
		var a := NoteData.new()
		a.beat_offset = hit.beat_offset
		a.mode = "targeted"
		a.direction = _DIR_CYCLE[idx]
		var b := NoteData.new()
		b.beat_offset = hit.beat_offset
		b.mode = "targeted"
		b.direction = _DIR_CYCLE[(idx + 2) % 4]
		return [a, b]
	var note := NoteData.new()
	note.beat_offset = hit.beat_offset
	note.mode = "targeted"
	note.direction = _DIR_CYCLE[idx]
	return [note]
