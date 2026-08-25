## Restores shared Composure after a correctly executed support performance.
class_name CombatV1ComposureRecoverySkillEffect
extends "res://combat_v1/skill_effect.gd"

const EncounterState = preload("res://combat_v1/encounter_state.gd")

@export_range(0.0, 100.0, 1.0) var amount: float = 20.0

func apply(encounter_state: RefCounted, execution: int) -> bool:
	if execution != EncounterState.Execution.CORRECT:
		return false
	return encounter_state.restore_composure(amount)
