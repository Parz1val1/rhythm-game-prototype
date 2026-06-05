## Display name shown in the UI.
class_name EnemyData
extends Resource

@export var enemy_name: String = ""

@export var max_hp: int = 50
@export var hp: int = 50

## Damage dealt to the active player character per missed note during the DEFEND phase.
## Good blocks reduce damage by 50%. Perfect blocks deal 0 damage.
@export var attack_power: int = 8

## The repeating sequence of abstract hits this enemy emits during its DEFEND phase.
## Each NeutralHit carries beat_offset (timing) and lane_count (1=single, 2=chord/pair).
## Directions are resolved at injection time via NeutralPatternTranslator using the
## defending character's defense_pattern_type, so any character can fight any enemy.
@export var neutral_pattern: Array[NeutralHit] = []

## How many beats this enemy's DEFEND phase lasts before cycling back.
@export var phase_length: int = 4
