# combat/drum_lane.gd
# Percussive DEFEND visualizer for Beatrice Styx.
# Shows two hit zones (L / R). A drum_both note spawns visuals in BOTH lanes
# simultaneously — the player reads it as "press both at once".
# Builds its entire UI in code — no .tscn required.
extends Control

const NoteData = preload("res://rhythm_engine/note_data.gd")

const ZONE_SIZE  := 50.0
const ZONE_Y     := 200.0
const LANE_W     := 500.0
const LANE_H     := 260.0
const SPAWN_Y    := 0.0

const HZ_DIM     := Color(0.25, 0.10, 0.10)
const HZ_PERFECT := Color(0.40, 1.00, 0.50)
const HZ_GOOD    := Color(1.00, 0.85, 0.30)
const HZ_MISS    := Color(1.00, 0.25, 0.25)

const ZONE_LABELS := { &"drum_left": "L", &"drum_right": "R" }
const ZONE_COLORS := {
	&"drum_left":  Color(0.6, 0.2, 0.2),
	&"drum_right": Color(0.2, 0.2, 0.6),
}
# drum_both uses both zone colors; a brighter tint signals "hit both"
const COLOR_BOTH := Color(0.8, 0.5, 0.1)

var _zone_x: Dictionary = {}
var _hit_zones: Dictionary = {}
# Maps NoteData → Control (single) or Array[Control] (drum_both dual visual)
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
	# Two zones only — L at 1/3, R at 2/3.
	var positions := { &"drum_left": LANE_W * 0.33, &"drum_right": LANE_W * 0.67 }
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
		for entry in _visuals.values():
			_free_entry(entry)
		_visuals.clear()
	# Lazy show — reveal on first note_approaching.

func _on_note_approaching(note: NoteData, target_beat: int) -> void:
	var dir := StringName(note.direction)
	if dir == &"drum_both":
		# Spawn a visual in each of the two lanes — player reads it as "press both".
		if not visible: visible = true
		var v_l := _spawn_visual(&"drum_left",  target_beat, COLOR_BOTH)
		var v_r := _spawn_visual(&"drum_right", target_beat, COLOR_BOTH)
		_visuals[note] = [v_l, v_r]
		return
	if not _zone_x.has(dir):
		return
	if not visible: visible = true
	_visuals[note] = _spawn_visual(dir, target_beat, ZONE_COLORS.get(dir, Color.WHITE))

func _spawn_visual(dir: StringName, target_beat: int, color: Color) -> ColorRect:
	var x: float = _zone_x[dir]
	var beats_rem: float = max(0.5, float(target_beat - BeatClock.beat_number))
	var travel := beats_rem * (60.0 / BeatClock.bpm)
	var v := ColorRect.new()
	v.size     = Vector2(ZONE_SIZE - 6.0, 14.0)
	v.color    = color
	v.position = Vector2(x - (ZONE_SIZE - 6.0) * 0.5, SPAWN_Y)
	add_child(v)
	var tween := create_tween()
	tween.tween_property(v, "position:y", ZONE_Y - 7.0, travel)
	tween.tween_callback(func(): if is_instance_valid(v): v.queue_free())
	return v

func _on_input_scored(direction: StringName, score: StringName, _off: float, note_consumed: bool) -> void:
	if not note_consumed:
		return
	# Find and free the visual(s) for this direction, then flash zone(s).
	for note in _visuals.keys():
		var note_dir := StringName(note.direction)
		if note_dir != direction:
			continue
		_free_entry(_visuals[note])
		_visuals.erase(note)
		break
	if direction == &"drum_both":
		_flash_zone(&"drum_left", score)
		_flash_zone(&"drum_right", score)
	else:
		_flash_zone(direction, score)

func _on_note_missed(note: NoteData) -> void:
	if _visuals.has(note):
		_free_entry(_visuals[note])
		_visuals.erase(note)
	var dir := StringName(note.direction)
	if dir == &"drum_both":
		_flash_zone(&"drum_left", &"miss")
		_flash_zone(&"drum_right", &"miss")
	else:
		_flash_zone(dir, &"miss")

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

func _free_entry(entry) -> void:
	if entry is Array:
		for v in entry:
			if is_instance_valid(v): v.queue_free()
	elif is_instance_valid(entry):
		entry.queue_free()
