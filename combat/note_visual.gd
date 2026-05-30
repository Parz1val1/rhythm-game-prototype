# combat/note_visual.gd
# A single approaching note during the DEFEND phase.
# Spawned by NoteLane when note_approaching fires on CombatScene.
extends Control

@onready var _body: ColorRect = $Body
@onready var _label: Label = $DirectionLabel

# Direction-to-arrow glyph map.
const ARROW := {
	&"up":    "↑",
	&"down":  "↓",
	&"left":  "←",
	&"right": "→",
}

# Colors
const COLOR_NORMAL  := Color(0.9, 0.8, 0.2)   # gold
const COLOR_PERFECT := Color(0.4, 1.0, 0.5)   # green
const COLOR_GOOD    := Color(1.0, 0.85, 0.3)  # amber
const COLOR_MISS    := Color(1.0, 0.25, 0.25) # red

## Called immediately after instantiation by NoteLane to set the direction glyph.
func init(direction: StringName) -> void:
	_label.text = ARROW.get(direction, "?")

## Flash the result color then free this node.
func flash_result(score: StringName) -> void:
	var color: Color
	match score:
		&"perfect": color = COLOR_PERFECT
		&"good":    color = COLOR_GOOD
		_:          color = COLOR_MISS
	_body.color = color
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(queue_free)
