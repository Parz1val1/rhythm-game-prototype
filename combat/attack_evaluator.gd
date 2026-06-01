# combat/attack_evaluator.gd
# Base interface for all ATTACK phase evaluators.
# Subclass this to implement character-specific scoring logic (rhythm timing,
# pitch matching, etc.). CombatScene holds one instance and calls record_hit()
# for each scored input during the ATTACK phase.
class_name AttackEvaluator
extends RefCounted

## Record one hit and return the damage to deal.
## score:        &"perfect", &"good", or &"miss"
## attack_power: base damage stat of the attacking character
## Returns 0 on miss or when no damage should be applied.
func record_hit(_score: StringName, _attack_power: int) -> int:
	return 0

## Current damage multiplier (used by UI for display purposes).
func get_multiplier() -> float:
	return 1.0

## Current combo count (consecutive non-miss hits). Used by combo_updated signal.
func get_combo_count() -> int:
	return 0

## Reset all combo/streak state — called at the start of each ATTACK phase.
func reset() -> void:
	pass
