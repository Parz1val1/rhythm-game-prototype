# combat/note_lane.gd
# Visualizes incoming notes during the DEFEND phase.
# Call setup(combat) once after EncounterManager.start_combat() returns.
extends Control

const NoteVisualScene = preload("res://combat/note_visual.tscn")
const NoteData        = preload("res://rhythm_engine/note_data.gd")

@onready var _phase_info: Label = $PhaseInfo

# Populated in _ready() after node tree is available.
var _lanes: Dictionary = {}       # direction StringName → Control lane node
var _hit_zones: Dictionary = {}   # direction StringName → ColorRect HitZone node

# Maps NoteData (by object identity) to the NoteVisual currently travelling.
var _visuals: Dictionary = {}

# Beats ahead that notes were announced (copied from CombatScene.lookahead_beats).
var _lookahead_beats: int = 2

func _ready() -> void:
	_lanes = {
		&"up":    $Lanes/UpLane,
		&"down":  $Lanes/DownLane,
		&"left":  $Lanes/LeftLane,
		&"right": $Lanes/RightLane,
	}
	_hit_zones = {
		&"up":    $Lanes/UpLane/HitZone,
		&"down":  $Lanes/DownLane/HitZone,
		&"left":  $Lanes/LeftLane/HitZone,
		&"right": $Lanes/RightLane/HitZone,
	}

## Wire this lane to a CombatScene after start_combat() returns.
func setup(combat: Node) -> void:
	_lookahead_beats = combat.lookahead_beats
	combat.note_approaching.connect(_on_note_approaching)
	combat.phase_changed.connect(_on_phase_changed)
	RhythmInput.input_scored.connect(_on_input_scored)
	RhythmInput.note_missed.connect(_on_note_missed)
	visible = false   # hidden until DEFEND starts

func _on_phase_changed(new_phase: int) -> void:
	# Phase.ATTACK = 0, Phase.DEFEND = 1
	visible = (new_phase == 1)
	if new_phase == 1:
		_phase_info.text = "DEFEND"
	else:
		for visual in _visuals.values():
			if is_instance_valid(visual):
				visual.queue_free()
		_visuals.clear()

func _on_note_approaching(note: NoteData, _target_beat: int) -> void:
	var lane = _lanes.get(note.direction)
	if lane == null:
		return

	# Spawn a NoteVisual at the right edge of the lane.
	var visual: Control = NoteVisualScene.instantiate()
	lane.add_child(visual)
	visual.init(note.direction)

	# Start at right edge, travel to hit zone at x=10.
	var start_x: float = lane.size.x - 40.0
	var end_x:   float = 10.0
	visual.position = Vector2(start_x, 5.0)

	var travel_time: float = float(_lookahead_beats) * (60.0 / BeatClock.bpm)
	var tween := create_tween()
	tween.tween_property(visual, "position:x", end_x, travel_time)
	tween.tween_callback(func(): if is_instance_valid(visual): visual.queue_free())
	tween.tween_callback(func(): _visuals.erase(note))

	_visuals[note] = visual

func _on_input_scored(_direction: StringName, score: StringName, _offset: float, note_consumed: bool) -> void:
	if not note_consumed:
		return
	# Flash the first valid visual in the queue.
	for note in _visuals.keys():
		var visual = _visuals.get(note)
		if is_instance_valid(visual):
			_visuals.erase(note)
			visual.flash_result(score)
			return
	# No visual found — flash the hit zones directly.
	_flash_hit_zone(score)

func _on_note_missed(note: NoteData) -> void:
	var visual = _visuals.get(note)
	if is_instance_valid(visual):
		_visuals.erase(note)
		visual.flash_result(&"miss")
	_flash_hit_zone(&"miss")

func _flash_hit_zone(score: StringName) -> void:
	var color: Color
	match score:
		&"perfect": color = Color(0.4, 1.0, 0.5)
		&"good":    color = Color(1.0, 0.85, 0.3)
		_:          color = Color(1.0, 0.25, 0.25)
	for hz in _hit_zones.values():
		hz.color = color
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	for hz in _hit_zones.values():
		hz.color = Color(0.4, 0.35, 0.1)   # restore dim gold
