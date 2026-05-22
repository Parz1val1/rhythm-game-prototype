## Display name shown in the UI.
class_name EnemyData
extends Resource

@export var enemy_name: String = ""

@export var max_hp: int = 50
@export var hp: int = 50

## Damage dealt to the active player character per missed note during the DEFEND phase.
## Good blocks reduce damage by 50%. Perfect blocks deal 0 damage.
@export var attack_power: int = 8

## The repeating sequence of notes this enemy emits during its DEFEND phase.
## beat_offset values must be in range [0, phase_length - 1].
@export var pattern: Array[NoteData] = []

## How many beats this enemy's DEFEND phase lasts before cycling back.
@export var phase_length: int = 4
