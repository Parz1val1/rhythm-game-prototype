# combat/drum_lane.gd
# Percussive DEFEND visualizer for Beatrice Styx.
# Shows three hit zones (L / B / R) horizontally at the bottom of the screen.
# Notes fall from the top of the panel toward the hit zones.
# Builds its entire UI in code — no .tscn required.
extends Control

const NoteData = preload("res://rhythm_engine/note_data.gd")

const ZONE_SIZE  := 50.0
const ZONE_Y     := 200.0   # hit zone Y position within the panel
const LANE_W     := 500.0
const LANE_H     := 260.0
const SPAWN_Y    := 0.0

const HZ_DIM     := Color(0.25, 0.10, 0.10)
const HZ_PERFECT := Color(0.40, 1.00, 0.50)
const HZ_GOOD    := Color(1.00, 0.85, 0.30)
const HZ_MISS    := Color(1.00, 0.25, 0.25)

const ZONE_LABELS := { &"drum_left": "L", &"drum_both": "B", &"drum_right": "R" }
const ZONE_COLORS := {
	&"drum_left":  Color(0.6, 0.2, 0.2),
	&"drum_both":  Color(0.6, 0.4, 0.1),
	&"drum_right": Color(0.2, 0.2, 0.6),
}
# X-center of each hit zone within the panel.
var _zone_x: Dictionary = {}
var _hit_zones: Dictionary = {}
var _visuals: Dictionary = {}
var _lookahead_beats: int = 2

func _ready() -> void:
	custom_minimum_size = Vector2(LANE_W, LANE_H)
	_build_zones()

func setup(combat: Node) -> void:
	_lookahead_beats = combat.lookahead_beats
	combat.note_approaching.connect(_on_note_approaching)
	combat.phase_changed.connect(_on_phase_changed)
	RhythmInput.input_scored.connect(_on_input_scored)
	RhythmInput.note_missed.connect(_on_note_missed)
	visible = false

func _exit_tree() -> void:
	if RhythmInput.input_scored.is_connected(_on_input_scored):
		RhythmInput.input_scored.disconnect(_on_input_scored)
	if RhythmInput.note_missed.is_connected(_on_note_missed):
		RhythmInput.note_missed.disconnect(_on_note_missed)

func _build_zones() -> void:
	var positions := { &"drum_left": LANE_W * 0.25, &"drum_both": LANE_W * 0.5, &"drum_right": LANE_W * 0.75 }
	for dir in positions:
		var x: float = positions[dir]
		_zone_x[dir] = x
		var hz := ColorRect.new()
		hz.size     = Vector2(ZONE_SIZE, ZONE_SIZE)
		hz.position = Vector2(x - ZONE_SIZE * 0.5, ZONE_Y - ZONE_SIZE * 0.5)
		hz.color    = HZ_DIM
		add_child(hz)
		var lbl := Label.new()
		lbl.text = ZONE_LABELS.get(dir, "?")
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		hz.add_child(lbl)
		_hit_zones[dir] = hz

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == 0:
		visible = false
		for v in _visuals.values():
			if is_instance_valid(v): v.queue_free()
		_visuals.clear()
	# Do NOT auto-show on DEFEND entry — show lazily from _on_note_approaching.

func _on_note_approaching(note: NoteData, target_beat: int) -> void:
	var dir := note.direction
	if not _zone_x.has(dir):
		return
	if not visible:
		visible = true
	var x: float  = _zone_x[dir]
	var beats_rem: float = max(0.5, float(target_beat - BeatClock.beat_number))
	var travel    := beats_rem * (60.0 / BeatClock.bpm)
	var visual    := ColorRect.new()
	visual.size   = Vector2(ZONE_SIZE - 6.0, 14.0)
	visual.color  = ZONE_COLORS.get(dir, Color.WHITE)
	visual.position = Vector2(x - (ZONE_SIZE - 6.0) * 0.5, SPAWN_Y)
	add_child(visual)
	var tween := create_tween()
	tween.tween_property(visual, "position:y", ZONE_Y - 7.0, travel)
	tween.tween_callback(func(): if is_instance_valid(visual): visual.queue_free())
	_visuals[note] = visual

func _on_input_scored(direction: StringName, score: StringName, _off: float, note_consumed: bool) -> void:
	if not note_consumed:
		return
	_flash_and_consume(direction, score)

func _on_note_missed(note: NoteData) -> void:
	if _visuals.has(note):
		var v = _visuals[note]
		_visuals.erase(note)
		if is_instance_valid(v): v.queue_free()
	_flash_zone(StringName(note.direction), &"miss")

func _flash_and_consume(direction: StringName, score: StringName) -> void:
	for note in _visuals.keys():
		if note.direction == String(direction):
			var v = _visuals[note]
			_visuals.erase(note)
			if is_instance_valid(v): v.queue_free()
			break
	_flash_zone(direction, score)

func _flash_zone(dir: StringName, score: StringName) -> void:
	var hz = _hit_zones.get(dir) as ColorRect
	if hz == null:
		return
	var color: Color
	match score:
		&"perfect": color = HZ_PERFECT
		&"good":    color = HZ_GOOD
		_:          color = HZ_MISS
	hz.color = color
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(hz):
		hz.color = HZ_DIM
