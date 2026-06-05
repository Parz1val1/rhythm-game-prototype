## Translates a NeutralHit (abstract: beat_offset + lane_count) into one or two
## NoteData objects using the defending character's defense_pattern_type.
##
## Percussive (Beatrice) — single hits alternate right/left by sequence_index:
##   sequence_index % 2 == 0 → drum_right  (right-hand lead)
##   sequence_index % 2 == 1 → drum_left
##   lane_count 2            → drum_both (always, regardless of index)
##
##   Using sequence_index (hit's position in the pattern array) instead of beat_offset
##   arithmetic ensures correct alternation for any beat spacing — whole-beat patterns
##   like String Golem (0,1,2,...,7) alternate just as cleanly as half-beat patterns.
##
## Directional (Luthier) — single hits cycle [up, right, down, left] by beat_offset:
##   index = int(beat_offset) % 4
##   lane_count 2 → that arrow + its opposite (index+2)%4.
##
## Both paths are pure functions of their inputs — no randomness, fully deterministic
## and replayable. Same enemy + same character + same sequence_index → same notes.
class_name NeutralPatternTranslator

const NoteData = preload("res://rhythm_engine/note_data.gd")

const _DIR_CYCLE  := ["up", "right", "down", "left"]
# Right-first: index 0 → drum_right so every pattern starts on the strong hand.
const _PERC_CYCLE := ["drum_right", "drum_left"]

## Returns an Array of NoteData (1 or 2 elements).
## hit:            the NeutralHit to translate.
## defense_type:   &"percussive" or &"directional"; anything else → directional.
## sequence_index: hit's position in the pattern array (0-based). Used by percussive
##                 to alternate hands independent of beat_offset spacing.
static func resolve_notes(hit: Resource, defense_type: StringName, sequence_index: int = 0) -> Array:
	if defense_type == &"percussive":
		return _percussive(hit, sequence_index)
	return _directional(hit)

static func _percussive(hit: Resource, sequence_index: int) -> Array:
	var note := NoteData.new()
	note.beat_offset = hit.beat_offset
	note.mode = "targeted"
	if hit.lane_count >= 2:
		note.direction = "drum_both"
	else:
		note.direction = _PERC_CYCLE[sequence_index % 2]
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
