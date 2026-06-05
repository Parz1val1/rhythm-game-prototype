# combat/luthier_evaluator.gd
# AttackEvaluator for Luthier Frett — 4-button pitched string player.
# Scores on two independent axes:
#   Timing accuracy  — combo/streak multiplier identical to SequenceEvaluator.
#   Melodic coherence — rewards melodic motion (stepwise / consonant intervals)
#     over same-note repetition.  Presses are always in-key by construction
#     (directions map to scale degrees), so coherence measures the *interval*
#     between consecutive pressed degrees.
# Damage = attack_power × timing_multiplier × coherence_multiplier.
class_name LuthierEvaluator
extends "res://combat/attack_evaluator.gd"

const SequenceEvaluator = preload("res://combat/sequence_evaluator.gd")

var _sequence: SequenceEvaluator = SequenceEvaluator.new()
# Coherence from the most recently recorded hit (held for get_coherence_mult / UI).
var _last_coherence: float = 1.0
# Direction index received from CombatScene just before record_hit().
var _curr_dir_idx: int = -1
# Direction index of the previous successful hit.
var _prev_dir_idx: int = -1

# direction → scale-degree index (matches audio_feedback.gd DIRECTION_INDEX).
const _DIR_IDX := {&"up": 0, &"right": 1, &"down": 2, &"left": 3}

# Coherence multiplier per interval size in scale degrees [0, 3]:
#   0 = unison (same note) → neutral (no bonus for mashing the same key)
#   1 = step               → maximum reward (melodic motion)
#   2 = skip               → good
#   3 = leap               → slight reward over unison
const _INTERVAL_MULT: Array = [1.0, 1.4, 1.3, 1.15]

## Called by CombatScene immediately before record_hit() to supply direction.
## Uses the same duck-type protocol as BeatriceEvaluator.set_beat_position().
func set_last_direction(dir: StringName) -> void:
	_curr_dir_idx = _DIR_IDX.get(dir, -1)

func record_hit(score: StringName, attack_power: int) -> int:
	var timing_mult: float = _sequence.record_hit(score)
	if score == &"miss":
		_last_coherence = 1.0
		_prev_dir_idx   = -1   # melodic line breaks on miss
		return 0
	_last_coherence = _compute_coherence()
	_prev_dir_idx   = _curr_dir_idx   # advance for next call
	var base: float = float(attack_power) * (0.5 if score == &"good" else 1.0)
	return int(base * timing_mult * _last_coherence)

## Timing (combo) multiplier.  Same formula as SequenceEvaluator.
func get_timing_multiplier() -> float:
	return _sequence.get_multiplier()

## Melodic coherence multiplier from the most recent hit.  Range [1.0, 1.4].
func get_coherence_mult() -> float:
	return _last_coherence

func get_multiplier() -> float:
	return get_timing_multiplier() * _last_coherence

func get_combo_count() -> int:
	return _sequence.combo_count

func reset() -> void:
	_sequence.reset()
	_last_coherence = 1.0
	_curr_dir_idx   = -1
	_prev_dir_idx   = -1

# ---------------------------------------------------------------------------

func _compute_coherence() -> float:
	if _prev_dir_idx < 0 or _curr_dir_idx < 0:
		return 1.0   # first note, or direction unknown — neutral
	var interval: int = absi(_curr_dir_idx - _prev_dir_idx)
	return _INTERVAL_MULT[interval]
