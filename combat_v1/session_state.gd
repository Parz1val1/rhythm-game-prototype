## Character-owned Combat V1 progression that survives encounter boundaries.
class_name CombatV1SessionState
extends RefCounted

const DebugLog = preload("res://autoloads/debug_log.gd")

signal inspiration_changed(character_state: Dictionary)

class Config extends RefCounted:
	var max_inspiration: float = 100.0
	var min_inspiration: float = 20.0
	var initial_inspiration: float = 50.0
	var successful_note_gain: float = 3.0
	var great_note_bonus: float = 1.0
	var perfect_note_bonus: float = 2.0
	var successful_phrase_gain: float = 12.0
	var great_phrase_bonus: float = 4.0
	var perfect_phrase_bonus: float = 8.0

var _characters: Dictionary = {}
var _generation: Dictionary = {}

## Register one character without mutating a gameplay Resource template.
func register_character(
	character_id: StringName,
	display_name: String,
	config: Config = null
) -> bool:
	if character_id == &"" or _characters.has(character_id):
		return false
	var source: Config = config if config != null else Config.new()
	var maximum := maxf(source.max_inspiration, 0.0)
	var minimum := clampf(source.min_inspiration, 0.0, maximum)
	_characters[character_id] = {
		&"character_id": character_id,
		&"character_name": display_name,
		&"inspiration": clampf(source.initial_inspiration, minimum, maximum),
		&"min_inspiration": minimum,
		&"max_inspiration": maximum,
	}
	_generation[character_id] = {
		&"successful_note_gain": maxf(source.successful_note_gain, 0.0),
		&"great_note_bonus": maxf(source.great_note_bonus, 0.0),
		&"perfect_note_bonus": maxf(source.perfect_note_bonus, 0.0),
		&"successful_phrase_gain": maxf(source.successful_phrase_gain, 0.0),
		&"great_phrase_bonus": maxf(source.great_phrase_bonus, 0.0),
		&"perfect_phrase_bonus": maxf(source.perfect_phrase_bonus, 0.0),
	}
	return true

## Award the configured base and stronger-grade bonus to one party member.
func record_performance_grade(
	character_id: StringName,
	grade_name: StringName,
	source: StringName
) -> bool:
	if not _characters.has(character_id) or source not in [&"note", &"phrase"]:
		return false
	if grade_name not in [&"good", &"great", &"perfect"]:
		return false
	var generation: Dictionary = _generation[character_id]
	var source_name := String(source)
	var amount: float = generation[StringName("successful_%s_gain" % source_name)]
	if grade_name == &"great":
		amount += generation[StringName("great_%s_bonus" % source_name)]
	elif grade_name == &"perfect":
		amount += generation[StringName("perfect_%s_bonus" % source_name)]
	var character: Dictionary = _characters[character_id]
	var previous: float = character[&"inspiration"]
	character[&"inspiration"] = clampf(
		previous + amount,
		0.0,
		float(character[&"max_inspiration"])
	)
	if not is_equal_approx(previous, float(character[&"inspiration"])):
		DebugLog.combat("[INSPIRE] character=%s  source=%s  grade=%s  amount=%.1f->%.1f" % [
			character_id,
			source,
			grade_name,
			previous,
			character[&"inspiration"],
		])
		inspiration_changed.emit(get_character_state(character_id))
	return true

## Commit a cost when the visible balance covers it. The encounter-start floor is
## restored separately so every displayed Inspiration point remains spendable.
func spend_inspiration(character_id: StringName, cost: float) -> bool:
	if not can_afford(character_id, cost):
		return false
	var character: Dictionary = _characters[character_id]
	var remaining := float(character[&"inspiration"]) - cost
	var previous: float = character[&"inspiration"]
	character[&"inspiration"] = remaining
	if not is_equal_approx(previous, remaining):
		DebugLog.combat("[INSPIRE] character=%s  source=skill  amount=%.1f->%.1f" % [
			character_id,
			previous,
			remaining,
		])
		inspiration_changed.emit(get_character_state(character_id))
	return true

## Evaluate a Skill cost without changing the session.
func can_afford(character_id: StringName, cost: float) -> bool:
	if not _characters.has(character_id) or cost < 0.0:
		return false
	var character: Dictionary = _characters[character_id]
	return float(character[&"inspiration"]) >= cost

## Restore the configured safety floor at the start of a new encounter without
## reserving that amount from Skills during the encounter itself.
func restore_encounter_floor(character_id: StringName) -> bool:
	if not _characters.has(character_id):
		return false
	var character: Dictionary = _characters[character_id]
	var previous: float = character[&"inspiration"]
	var restored := maxf(previous, float(character[&"min_inspiration"]))
	character[&"inspiration"] = restored
	if not is_equal_approx(previous, restored):
		DebugLog.combat("[INSPIRE] character=%s  source=encounter_floor  amount=%.1f->%.1f" % [
			character_id,
			previous,
			restored,
		])
		inspiration_changed.emit(get_character_state(character_id))
	return true

## Return an independently owned public snapshot for one party member.
func get_character_state(character_id: StringName) -> Dictionary:
	if not _characters.has(character_id):
		return {}
	return (_characters[character_id] as Dictionary).duplicate(true)

## Snapshot every registered party member in stable registration order.
func get_party_state() -> Array[Dictionary]:
	var party: Array[Dictionary] = []
	for character_id in _characters:
		party.append(get_character_state(character_id))
	return party
