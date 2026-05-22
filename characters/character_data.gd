## Display name shown in the UI.
class_name CharacterData
extends Resource

@export var character_name: String = ""

@export var max_hp: int = 100
@export var hp: int = 100

## Base damage dealt to the current enemy on a Perfect hit during the ATTACK phase.
## Good hits deal attack_power * 0.5 (rounded down). Misses deal 0.
@export var attack_power: int = 10
