## BeatClock-aligned four-lane presentation for the active Combat V1 Response.
class_name ResponseNoteHighway
extends Control

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")

const LANE_ORDER: Array[StringName] = [&"left", &"down", &"up", &"right"]
const LANE_LABELS := {
	&"left": "<  LEFT",
	&"down": "v  DOWN",
	&"up": "^  UP",
	&"right": ">  RIGHT",
}
const BOARD_COLOR := Color("091126")
const LANE_COLORS: Array[Color] = [
	Color("152747"),
	Color("10213d"),
	Color("152747"),
	Color("10213d"),
]
const GRID_COLOR := Color("385b84")
const HIT_LINE_COLOR := Color("8ffcff")
const LABEL_COLOR := Color("dcecff")
const NOTE_COLOR := Color("f6c85f")
const HIT_LINE_RATIO := 0.78
const APPROACH_START_RATIO := 0.16
const LATE_TRAVEL_BEATS := 0.5

var _combat_v1: CombatV1 = null
var _active: bool = false
var _round_id: int = -1
var _timeline_position_beats: float = 0.0
var _visual_lead_beats: float = 2.0
var _targets: Array[Dictionary] = []
var _lane_feedback: Dictionary = {}

func _ready() -> void:
	set_process(false)
	queue_redraw()

func setup(combat_v1: CombatV1) -> void:
	teardown()
	_combat_v1 = combat_v1
	if _combat_v1 == null:
		return
	if not _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
		_combat_v1.cadence_changed.connect(_on_cadence_changed)
	if not _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.response_note_graded.connect(_on_response_note_graded)
	set_process(true)
	_sync_from_module()

## Return the visible adapter state without exposing drawing internals.
func get_presentation_snapshot() -> Dictionary:
	var visible_targets: Array[Dictionary] = []
	for target in _targets:
		visible_targets.append({
			&"target_id": target[&"target_id"],
			&"expected_action": target[&"expected_action"],
			&"beat_offset": target[&"beat_offset"],
			&"due_beat": target[&"due_beat"],
			&"lane": target[&"lane"],
			&"lane_index": target[&"lane_index"],
			&"visible": target[&"visible"],
			&"progress": target[&"progress"],
			&"x": target[&"x"],
			&"y": target[&"y"],
			&"grade_name": target[&"grade_name"],
		})
	return {
		&"active": _active,
		&"lane_order": LANE_ORDER.duplicate(),
		&"round_id": _round_id,
		&"timeline_position_beats": _timeline_position_beats,
		&"visual_lead_beats": _visual_lead_beats,
		&"targets": visible_targets,
		&"lane_feedback": _lane_feedback.duplicate(true),
		&"approach_start_y": size.y * APPROACH_START_RATIO,
		&"hit_line_y": size.y * HIT_LINE_RATIO,
	}

## Disconnect every signal this adapter owns and clear all round-local visuals.
## Safe to call repeatedly.
func teardown() -> void:
	if _combat_v1 != null:
		if _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
			_combat_v1.cadence_changed.disconnect(_on_cadence_changed)
		if _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
			_combat_v1.response_note_graded.disconnect(_on_response_note_graded)
	_combat_v1 = null
	set_process(false)
	_clear_presentation()
	queue_redraw()

func _process(_delta: float) -> void:
	_sync_from_module()

func _on_cadence_changed(_cadence: CombatV1.Cadence) -> void:
	_sync_from_module()

func _on_response_note_graded(result: Dictionary) -> void:
	var target_id: StringName = result.get(&"target_id", &"")
	for target_index in range(_targets.size()):
		var target: Dictionary = _targets[target_index]
		if target[&"target_id"] != target_id:
			continue
		var grade_name: StringName = result[&"grade_name"]
		target[&"grade_name"] = grade_name
		target[&"visible"] = false
		_targets[target_index] = target
		var lane: StringName = target[&"lane"]
		_lane_feedback[lane] = {
			&"target_id": target_id,
			&"grade_name": grade_name,
		}
		DebugLog.visual("[RESULT ] target=%s  lane=%s  grade=%s" % [
			target_id,
			lane,
			grade_name,
		])
		queue_redraw()
		return

func _sync_from_module() -> void:
	if _combat_v1 == null:
		return
	var presentation: Dictionary = _combat_v1.get_response_presentation()
	if not bool(presentation[&"active"]):
		_clear_presentation()
		return
	var next_round_id: int = presentation[&"round_id"]
	if not _active or next_round_id != _round_id:
		_load_schedule(presentation)
	_update_positions(presentation)
	queue_redraw()

func _load_schedule(presentation: Dictionary) -> void:
	_clear_presentation()
	_active = true
	_round_id = presentation[&"round_id"]
	_visual_lead_beats = maxf(0.001, float(presentation[&"visual_lead_beats"]))
	for scheduled_target in presentation[&"targets"]:
		var action: StringName = scheduled_target[&"expected_action"]
		var lane_index := LANE_ORDER.find(action)
		if lane_index < 0:
			continue
		_targets.append({
			&"target_id": scheduled_target[&"target_id"],
			&"expected_action": action,
			&"beat_offset": scheduled_target[&"beat_offset"],
			&"due_beat": scheduled_target[&"due_beat"],
			&"lane": action,
			&"lane_index": lane_index,
			&"visible": false,
			&"spawn_logged": false,
			&"progress": 0.0,
			&"x": 0.0,
			&"y": 0.0,
			&"grade_name": &"",
		})

func _update_positions(presentation: Dictionary) -> void:
	_timeline_position_beats = float(presentation[&"timeline_position_beats"])
	_visual_lead_beats = maxf(0.001, float(presentation[&"visual_lead_beats"]))
	var lane_width := size.x / float(LANE_ORDER.size())
	var approach_start_y := size.y * APPROACH_START_RATIO
	var hit_line_y := size.y * HIT_LINE_RATIO
	for target_index in range(_targets.size()):
		var target: Dictionary = _targets[target_index]
		var due_beat := float(target[&"due_beat"])
		var beats_until_due := due_beat - _timeline_position_beats
		var progress := 1.0 - (beats_until_due / _visual_lead_beats)
		var lane_index: int = target[&"lane_index"]
		target[&"progress"] = progress
		target[&"x"] = (float(lane_index) + 0.5) * lane_width
		target[&"y"] = lerpf(approach_start_y, hit_line_y, progress)
		var was_visible: bool = target[&"visible"]
		target[&"visible"] = target[&"grade_name"] == &"" \
			and beats_until_due <= _visual_lead_beats \
			and beats_until_due >= -LATE_TRAVEL_BEATS
		if bool(target[&"visible"]) and not was_visible and not bool(target[&"spawn_logged"]):
			target[&"spawn_logged"] = true
			DebugLog.visual("[SPAWN  ] target=%s  lane=%s  due=%.2f  lead=%.2f beats" % [
				target[&"target_id"],
				target[&"lane"],
				due_beat,
				_visual_lead_beats,
			])
		_targets[target_index] = target

func _clear_presentation() -> void:
	if _active or not _targets.is_empty() or not _lane_feedback.is_empty():
		DebugLog.visual("[CLEAR  ] response_highway=true  round=%d" % _round_id)
	_active = false
	_round_id = -1
	_timeline_position_beats = 0.0
	_targets.clear()
	_lane_feedback.clear()

func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, size)
	draw_rect(board_rect, BOARD_COLOR)
	var lane_width := size.x / float(LANE_ORDER.size())
	for lane_index in range(LANE_ORDER.size()):
		var lane_rect := Rect2(lane_index * lane_width, 0.0, lane_width, size.y)
		draw_rect(lane_rect, LANE_COLORS[lane_index])
		if lane_index > 0:
			draw_line(Vector2(lane_rect.position.x, 0.0), Vector2(lane_rect.position.x, size.y), GRID_COLOR, 2.0)
		var action: StringName = LANE_ORDER[lane_index]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(lane_rect.position.x + 12.0, 28.0),
			LANE_LABELS[action],
			HORIZONTAL_ALIGNMENT_LEFT,
			lane_width - 24.0,
			16,
			LABEL_COLOR
		)
	var hit_line_y := size.y * HIT_LINE_RATIO
	draw_line(Vector2(0.0, hit_line_y), Vector2(size.x, hit_line_y), HIT_LINE_COLOR, 4.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(12.0, hit_line_y - 10.0),
		"HIT LINE",
		HORIZONTAL_ALIGNMENT_LEFT,
		100.0,
		14,
		HIT_LINE_COLOR
	)
	for target in _targets:
		if not bool(target[&"visible"]):
			continue
		var note_position := Vector2(float(target[&"x"]), float(target[&"y"]))
		draw_circle(note_position, 18.0, NOTE_COLOR)
		var action: StringName = target[&"expected_action"]
		draw_string(
			ThemeDB.fallback_font,
			note_position + Vector2(-12.0, 6.0),
			String(LANE_LABELS[action]).left(1),
			HORIZONTAL_ALIGNMENT_CENTER,
			24.0,
			18,
			BOARD_COLOR
		)
	for lane_index in range(LANE_ORDER.size()):
		var lane: StringName = LANE_ORDER[lane_index]
		if not _lane_feedback.has(lane):
			continue
		var feedback: Dictionary = _lane_feedback[lane]
		var grade_name: StringName = feedback[&"grade_name"]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(float(lane_index) * lane_width + 8.0, hit_line_y + 30.0),
			String(grade_name).replace("_", " ").to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			lane_width - 16.0,
			15,
			_get_grade_color(grade_name)
		)
	draw_rect(board_rect, GRID_COLOR, false, 2.0)

func _get_grade_color(grade_name: StringName) -> Color:
	match grade_name:
		&"perfect":
			return Color("8ffcff")
		&"great":
			return Color("72f28e")
		&"good":
			return Color("d6ef78")
		&"near_miss":
			return Color("ffd166")
		&"miss":
			return Color("ff8c61")
		_:
			return Color("ff5c8a")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _exit_tree() -> void:
	teardown()
