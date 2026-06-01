# combat/passthrough_evaluator.gd
# Default AttackEvaluator — wraps SequenceEvaluator to preserve existing
# damage formula (perfect = attack_power × combo_mult, good = × 0.5 × combo_mult).
# All existing tests pass through this path unchanged.
class_name PassthroughEvaluator
extends "res://combat/attack_evaluator.gd"

const SequenceEvaluator = preload("res://combat/sequence_evaluator.gd")

var _sequence: SequenceEvaluator = SequenceEvaluator.new()

func record_hit(score: StringName, attack_power: int) -> int:
	var multiplier: float = _sequence.record_hit(score)
	match score:
		&"perfect":
			return int(float(attack_power) * multiplier)
		&"good":
			return int(float(attack_power) * 0.5 * multiplier)
	return 0   # miss

func get_multiplier() -> float:
	return _sequence.get_multiplier()

func get_combo_count() -> int:
	return _sequence.combo_count

func reset() -> void:
	_sequence.reset()
