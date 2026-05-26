# combat/sequence_evaluator.gd
# Tracks rhythmic quality during the ATTACK phase and computes a damage multiplier.
# One instance lives per CombatScene; reset() is called at each ATTACK phase start.
class_name SequenceEvaluator
extends RefCounted

## Non-miss hits since the last miss.
var combo_count: int = 0
## Highest combo_count reached this combat (for end-of-battle display).
var max_combo: int = 0
## Consecutive perfect hits without a good or miss in between.
var _perfect_streak: int = 0

## Record one hit during the ATTACK phase and return the damage multiplier for that hit.
## Returns 0.0 on miss (caller should skip damage accumulation).
## Perfect and good hits return >= 1.0.
func record_hit(score: StringName) -> float:
    if score == &"miss":
        combo_count = 0
        _perfect_streak = 0
        return 0.0

    combo_count += 1
    max_combo = max(max_combo, combo_count)

    if score == &"perfect":
        _perfect_streak += 1
    else:
        _perfect_streak = 0   # good hit breaks perfect streak

    return get_multiplier()

## Current damage multiplier.
## Combo bonus: +0.1 per 4 hits, capped at +1.0.
## Perfect streak bonus: +0.1 per 2 perfects, capped at +0.5.
## Combined ceiling: 2.5x.
func get_multiplier() -> float:
    var combo_bonus:  float = min(float(combo_count / 4) * 0.1, 1.0)
    var streak_bonus: float = min(float(_perfect_streak / 2) * 0.1, 0.5)
    return 1.0 + combo_bonus + streak_bonus

## Call at the start of each new ATTACK phase.
func reset() -> void:
    combo_count = 0
    max_combo = 0
    _perfect_streak = 0
