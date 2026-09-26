## Routes Character Performance execution through the existing encounter result.
class_name CombatV1PerformanceResultSkillEffect
extends "res://combat_v1/skill_effect.gd"

const EncounterState = preload("res://combat_v1/encounter_state.gd")

## Retains support Skills that intentionally produce no direct Groove. Effective
## effects multiply Groove by the encounter's resolved opponent preference.
@export var tactical_effectiveness: int = EncounterState.TacticalEffectiveness.EFFECTIVE

func apply(
	encounter_state: RefCounted,
	execution: int,
	groove_effectiveness: float = 1.0
) -> bool:
	var resolved_effectiveness := groove_effectiveness
	if tactical_effectiveness == EncounterState.TacticalEffectiveness.INEFFECTIVE:
		resolved_effectiveness = 0.0
	return encounter_state.apply_scaled_performance_result(execution, resolved_effectiveness)
