## Effect interface applied after a Skill's Character Performance is graded.
## Concrete effect Resources are adapters at this seam; CombatV1 does not branch
## on individual Skill identities or effect implementations.
class_name CombatV1SkillEffect
extends Resource

func apply(_encounter_state: RefCounted, _execution: int) -> bool:
	return false
