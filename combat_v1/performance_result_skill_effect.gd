## Routes Character Performance execution through the existing encounter result.
class_name CombatV1PerformanceResultSkillEffect
extends "res://combat_v1/skill_effect.gd"

const EncounterState = preload("res://combat_v1/encounter_state.gd")

@export var tactical_effectiveness: int = EncounterState.TacticalEffectiveness.EFFECTIVE

func apply(encounter_state: RefCounted, execution: int) -> bool:
	return encounter_state.apply_performance_result(execution, tactical_effectiveness)
