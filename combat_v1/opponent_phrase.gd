## Inspector-authored musical statement performed during Enemy Phrase.
class_name OpponentPhrase
extends Resource

const PhraseEvent = preload("res://combat_v1/phrase_event.gd")
const BEATS_PER_BAR: int = 4

@export var phrase_id: StringName = &""
@export var display_name: String = ""
@export_range(1, 4, 1) var bar_count: int = 1
@export var events: Array[PhraseEvent] = []

func get_duration_beats() -> int:
	return bar_count * BEATS_PER_BAR
