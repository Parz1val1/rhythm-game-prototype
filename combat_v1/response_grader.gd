## Deterministic note- and phrase-level execution grading for Combat V1 Response.
class_name CombatV1ResponseGrader
extends RefCounted

enum Grade {
	PERFECT,
	GREAT,
	GOOD,
	NEAR_MISS,
	MISS,
	MAJOR_MISTAKE,
}

const _GRADE_NAMES: Array[StringName] = [
	&"perfect",
	&"great",
	&"good",
	&"near_miss",
	&"miss",
	&"major_mistake",
]

class Config extends RefCounted:
	var perfect_ms: float = 50.0
	var great_ms: float = 80.0
	var good_ms: float = 120.0
	var near_miss_ms: float = 170.0
	var miss_ms: float = 240.0
	var phrase_perfect_min_score: float = 5.0
	var phrase_great_min_score: float = 4.0
	var phrase_good_min_score: float = 3.0
	var phrase_near_miss_min_score: float = 2.0
	var phrase_miss_min_score: float = 1.0
	var major_mistakes_to_break_phrase: int = 2

var _perfect_ms: float = 50.0
var _great_ms: float = 80.0
var _good_ms: float = 120.0
var _near_miss_ms: float = 170.0
var _miss_ms: float = 240.0
var _phrase_perfect_min_score: float = 5.0
var _phrase_great_min_score: float = 4.0
var _phrase_good_min_score: float = 3.0
var _phrase_near_miss_min_score: float = 2.0
var _phrase_miss_min_score: float = 1.0
var _major_mistakes_to_break_phrase: int = 2

## Copy configuration into the live grader so later caller mutation cannot change it.
func setup(config: Config = null) -> void:
	var source: Config = config if config != null else Config.new()
	_perfect_ms = maxf(source.perfect_ms, 0.0)
	_great_ms = maxf(source.great_ms, _perfect_ms)
	_good_ms = maxf(source.good_ms, _great_ms)
	_near_miss_ms = maxf(source.near_miss_ms, _good_ms)
	_miss_ms = maxf(source.miss_ms, _near_miss_ms)
	_phrase_miss_min_score = clampf(source.phrase_miss_min_score, 0.0, 5.0)
	_phrase_near_miss_min_score = clampf(
		source.phrase_near_miss_min_score,
		_phrase_miss_min_score,
		5.0
	)
	_phrase_good_min_score = clampf(
		source.phrase_good_min_score,
		_phrase_near_miss_min_score,
		5.0
	)
	_phrase_great_min_score = clampf(
		source.phrase_great_min_score,
		_phrase_good_min_score,
		5.0
	)
	_phrase_perfect_min_score = clampf(
		source.phrase_perfect_min_score,
		_phrase_great_min_score,
		5.0
	)
	_major_mistakes_to_break_phrase = maxi(source.major_mistakes_to_break_phrase, 1)

## Grade one expected action against one performed action and signed timing offset.
func grade_note(
	expected_action: StringName,
	actual_action: StringName,
	offset_ms: float
) -> Dictionary:
	var absolute_offset := absf(offset_ms)
	var grade := Grade.MAJOR_MISTAKE
	if absolute_offset <= _perfect_ms:
		grade = Grade.PERFECT
	elif absolute_offset <= _great_ms:
		grade = Grade.GREAT
	elif absolute_offset <= _good_ms:
		grade = Grade.GOOD
	elif absolute_offset <= _near_miss_ms:
		grade = Grade.NEAR_MISS
	elif absolute_offset <= _miss_ms:
		grade = Grade.MISS
	if actual_action != expected_action:
		grade = maxi(grade, Grade.MISS)
	return {
		&"expected_action": expected_action,
		&"actual_action": actual_action,
		&"offset_ms": offset_ms,
		&"grade": grade,
		&"grade_name": _GRADE_NAMES[grade],
	}

## Combine ordered note results into one immutable-by-convention phrase summary.
func summarize(note_results: Array[Dictionary]) -> Dictionary:
	var score_total := 0.0
	var major_mistake_count := 0
	var grade_counts := {}
	for grade_name in _GRADE_NAMES:
		grade_counts[grade_name] = 0
	for result in note_results:
		var note_grade: Grade = result[&"grade"]
		score_total += float(5 - int(note_grade))
		var grade_name: StringName = _GRADE_NAMES[note_grade]
		grade_counts[grade_name] = int(grade_counts[grade_name]) + 1
		if note_grade == Grade.MAJOR_MISTAKE:
			major_mistake_count += 1
	var average_score := score_total / float(note_results.size()) if not note_results.is_empty() else 0.0
	var phrase_grade := Grade.MAJOR_MISTAKE
	if average_score >= _phrase_perfect_min_score:
		phrase_grade = Grade.PERFECT
	elif average_score >= _phrase_great_min_score:
		phrase_grade = Grade.GREAT
	elif average_score >= _phrase_good_min_score:
		phrase_grade = Grade.GOOD
	elif average_score >= _phrase_near_miss_min_score:
		phrase_grade = Grade.NEAR_MISS
	elif average_score >= _phrase_miss_min_score:
		phrase_grade = Grade.MISS
	if major_mistake_count >= _major_mistakes_to_break_phrase:
		phrase_grade = Grade.MAJOR_MISTAKE
	return {
		&"grade": phrase_grade,
		&"grade_name": _GRADE_NAMES[phrase_grade],
		&"note_results": note_results.duplicate(true),
		&"total_notes": note_results.size(),
		&"average_score": average_score,
		&"grade_counts": grade_counts,
		&"major_mistake_count": major_mistake_count,
		&"broken": phrase_grade == Grade.MAJOR_MISTAKE,
	}
