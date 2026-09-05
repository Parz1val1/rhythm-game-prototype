## Authored Combat V1 identity and Character Performance loadout for one party member.
class_name CombatV1PartyMember
extends Resource

const CharacterInputProfile = preload("res://characters/character_input_profile.gd")
const SoloStyle = preload("res://characters/solo_style.gd")
const Skill = preload("res://combat_v1/skill.gd")

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var rhythm_language: StringName = &""
@export var performance_presentation: StringName = &"directional_highway"
@export var input_profile: CharacterInputProfile = null
@export var presentation_style: SoloStyle = null
@export var skills: Array[Skill] = []

## Build a live graph without retaining aliases to externally authored nested
## Resources. Resource.duplicate(true) alone does not copy external references.
func create_live_copy() -> Resource:
	var live := duplicate(false)
	live.set(
		"input_profile",
		input_profile.duplicate(true) as CharacterInputProfile \
			if input_profile != null else null
	)
	live.set(
		"presentation_style",
		presentation_style.duplicate(true) as SoloStyle \
			if presentation_style != null else null
	)
	var live_skills: Array[Skill] = []
	for skill_template in skills:
		live_skills.append(skill_template.duplicate(true) as Skill)
	live.set("skills", live_skills)
	return live
