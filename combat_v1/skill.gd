## Minimal authored action selected during Tactical Vamp.
class_name CombatV1Skill
extends Resource

const SkillEvent = preload("res://combat_v1/skill_event.gd")
const SkillEffect = preload("res://combat_v1/skill_effect.gd")
const BEATS_PER_BAR: int = 4

@export var skill_id: StringName = &""
@export var display_name: String = ""
@export var musical_contribution: StringName = &""
@export var interaction_summary: String = ""
@export var effect_summary: String = ""
@export_range(1, 8, 1) var bar_count: int = 2
@export var events: Array[SkillEvent] = []
@export var effects: Array[SkillEffect] = []

func get_duration_beats() -> int:
	return bar_count * BEATS_PER_BAR
