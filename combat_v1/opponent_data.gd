## V1 opponent authoring data. This intentionally models musical identity and a
## phrase without inheriting legacy EnemyData combat statistics.
class_name OpponentData
extends Resource

const Phrase = preload("res://combat_v1/opponent_phrase.gd")

@export var opponent_id: StringName = &""
@export var display_name: String = ""
@export var phrase: Phrase
