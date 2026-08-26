## BeatClock-aligned presentation for the active Combat V1 rhythm language.
class_name ResponseNoteHighway
extends Control

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")
const PhraseEvent = preload("res://combat_v1/phrase_event.gd")

const DEFAULT_LANE_ORDER: Array[StringName] = [&"left", &"down", &"up", &"right"]
const LANE_LABELS := {
	&"left": "<  LEFT",
	&"down": "v  DOWN",
	&"up": "^  UP",
	&"right": ">  RIGHT",
	&"drum_left": "L  LEFT DRUM",
	&"drum_right": "R  RIGHT DRUM",
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
const CHORD_COLOR := Color("c69cff")
const PREVIEW_COLOR := Color("8ffcff80")
const HIT_LINE_RATIO := 0.78
const APPROACH_START_RATIO := 0.16
const PREVIEW_LINE_RATIO := 0.47
const PREVIEW_DURATION_SECONDS := 0.3
const LATE_TRAVEL_BEATS := 0.5
const CLOSING_RING_START_RADIUS := 88.0
const CLOSING_RING_HIT_RADIUS := 18.0
const SUBDIVISION_MARKERS: Array[String] = ["1", "e", "&", "a"]
const SUBDIVISION_A_COLOR := Color("ff8fa3")

var _combat_v1: CombatV1 = null
var _active: bool = false
var _round_id: int = -1
var _timeline_position_beats: float = 0.0
var _visual_lead_beats: float = 2.0
var _lane_order: Array[StringName] = DEFAULT_LANE_ORDER.duplicate()
var _presentation_style: StringName = &"directional_highway"
var _targets: Array[Dictionary] = []
var _chord_groups: Array[Dictionary] = []
var _lane_feedback: Dictionary = {}
var _target_feedback: Dictionary = {}
var _preview: Dictionary = {}
var _preview_elapsed_seconds: float = 0.0

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
	if not _combat_v1.active_character_changed.is_connected(_on_active_character_changed):
		_combat_v1.active_character_changed.connect(_on_active_character_changed)
	if not _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.response_note_graded.connect(_on_response_note_graded)
	if not _combat_v1.character_performance_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.character_performance_note_graded.connect(_on_response_note_graded)
	if not _combat_v1.phrase_event_announced.is_connected(_on_phrase_event_announced):
		_combat_v1.phrase_event_announced.connect(_on_phrase_event_announced)
	set_process(true)
	_sync_from_module()

## Return the visible adapter state without exposing drawing internals.
func get_presentation_snapshot() -> Dictionary:
	var visible_targets: Array[Dictionary] = []
	for target in _targets:
		visible_targets.append({
			&"target_id": target[&"target_id"],
			&"expected_action": target[&"expected_action"],
			&"group_id": target[&"group_id"],
			&"group_size": target[&"group_size"],
			&"beat_offset": target[&"beat_offset"],
			&"due_beat": target[&"due_beat"],
			&"lane": target[&"lane"],
			&"lane_index": target[&"lane_index"],
			&"visible": target[&"visible"],
			&"progress": target[&"progress"],
			&"x": target[&"x"],
			&"y": target[&"y"],
			&"radius": target[&"radius"],
			&"subdivision_marker": target[&"subdivision_marker"],
			&"subdivision_color": target[&"subdivision_color"],
			&"grade_name": target[&"grade_name"],
		})
	return {
		&"active": _active,
		&"lane_order": _lane_order.duplicate(),
		&"presentation_style": _presentation_style,
		&"round_id": _round_id,
		&"timeline_position_beats": _timeline_position_beats,
		&"visual_lead_beats": _visual_lead_beats,
		&"targets": visible_targets,
		&"chord_groups": _chord_groups.duplicate(true),
		&"lane_feedback": _lane_feedback.duplicate(true),
		&"target_feedback": _target_feedback.duplicate(true),
		&"preview": _preview.duplicate(true),
		&"approach_start_y": size.y * APPROACH_START_RATIO,
		&"hit_line_y": size.y * HIT_LINE_RATIO,
	}

## Disconnect every signal this adapter owns and clear all round-local visuals.
## Safe to call repeatedly.
func teardown() -> void:
	if _combat_v1 != null:
		if _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
			_combat_v1.cadence_changed.disconnect(_on_cadence_changed)
		if _combat_v1.active_character_changed.is_connected(_on_active_character_changed):
			_combat_v1.active_character_changed.disconnect(_on_active_character_changed)
		if _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
			_combat_v1.response_note_graded.disconnect(_on_response_note_graded)
		if _combat_v1.character_performance_note_graded.is_connected(_on_response_note_graded):
			_combat_v1.character_performance_note_graded.disconnect(_on_response_note_graded)
		if _combat_v1.phrase_event_announced.is_connected(_on_phrase_event_announced):
			_combat_v1.phrase_event_announced.disconnect(_on_phrase_event_announced)
	_combat_v1 = null
	set_process(false)
	_clear_presentation()
	queue_redraw()

func _process(delta: float) -> void:
	_sync_from_module()
	if _preview.is_empty():
		return
	_preview_elapsed_seconds += delta
	if _preview_elapsed_seconds >= PREVIEW_DURATION_SECONDS:
		_clear_preview()
		queue_redraw()

func _on_cadence_changed(cadence: CombatV1.Cadence) -> void:
	if cadence != CombatV1.Cadence.ENEMY_PHRASE:
		_clear_preview()
	_sync_from_module()

func _on_active_character_changed(_character_state: Dictionary) -> void:
	_clear_presentation()
	_sync_identity()
	queue_redraw()

func _on_phrase_event_announced(
	event: PhraseEvent,
	expected_actions: Array[StringName]
) -> void:
	if _combat_v1 == null or _combat_v1.get_cadence() != CombatV1.Cadence.ENEMY_PHRASE:
		return
	var lanes: Array[StringName] = []
	var lane_indices: Array[int] = []
	for action in expected_actions:
		var lane_index := _lane_order.find(action)
		if lane_index < 0:
			continue
		lanes.append(action)
		lane_indices.append(lane_index)
	if lanes.is_empty():
		_clear_preview()
		return
	_preview = {
		&"prompt_id": event.prompt_id,
		&"beat_offset": event.beat_offset,
		&"actions": lanes.duplicate(),
		&"lane_indices": lane_indices,
		&"style": &"ghost",
		&"color": PREVIEW_COLOR,
	}
	_preview_elapsed_seconds = 0.0
	DebugLog.visual("[PREVIEW] prompt=%s  offset=%.2f  lanes=%s" % [
		event.prompt_id,
		event.beat_offset,
		"+".join(lanes),
	])
	queue_redraw()

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
		var target_result := {
			&"target_id": target_id,
			&"expected_action": result.get(&"expected_action", &""),
			&"actual_action": result.get(&"actual_action", &""),
			&"offset_ms": result.get(&"offset_ms", 0.0),
			&"lane": lane,
			&"group_id": result.get(&"group_id", &""),
			&"group_size": result.get(&"group_size", 1),
			&"grade_name": grade_name,
			&"visual_cue": _get_result_visual_cue(grade_name),
			&"color": _get_grade_color(grade_name),
		}
		_target_feedback[target_id] = target_result
		_lane_feedback[lane] = target_result.duplicate(true)
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
	_sync_identity()
	var presentation: Dictionary = _combat_v1.get_response_presentation()
	if not bool(presentation[&"active"]):
		presentation = _combat_v1.get_character_performance_presentation()
	if not bool(presentation[&"active"]):
		_clear_response_presentation()
		return
	var next_round_id: int = presentation[&"round_id"]
	if not _active or next_round_id != _round_id:
		_load_schedule(presentation)
	_update_positions(presentation)
	queue_redraw()

func _sync_identity() -> void:
	if _combat_v1 == null:
		return
	var state: Dictionary = _combat_v1.get_state()
	var next_lane_order: Array[StringName] = []
	for action in state.get(&"lane_order", DEFAULT_LANE_ORDER):
		next_lane_order.append(StringName(action))
	if next_lane_order.is_empty():
		next_lane_order = DEFAULT_LANE_ORDER.duplicate()
	if next_lane_order != _lane_order:
		_clear_presentation()
		_lane_order = next_lane_order
	_presentation_style = state.get(&"performance_presentation", &"directional_highway")

func _load_schedule(presentation: Dictionary) -> void:
	_clear_presentation()
	_active = true
	_round_id = presentation[&"round_id"]
	_presentation_style = presentation.get(&"presentation_style", _presentation_style)
	var presented_lane_order: Array[StringName] = []
	for action in presentation.get(&"lane_order", _lane_order):
		presented_lane_order.append(StringName(action))
	if not presented_lane_order.is_empty():
		_lane_order = presented_lane_order
	_visual_lead_beats = maxf(0.001, float(presentation[&"visual_lead_beats"]))
	for scheduled_target in presentation[&"targets"]:
		var action: StringName = scheduled_target[&"expected_action"]
		var lane_index := _lane_order.find(action)
		if lane_index < 0:
			continue
		var subdivision_marker := _get_subdivision_marker(
			float(scheduled_target[&"beat_offset"])
		)
		_targets.append({
			&"target_id": scheduled_target[&"target_id"],
			&"expected_action": action,
			&"group_id": scheduled_target[&"group_id"],
			&"group_size": scheduled_target[&"group_size"],
			&"beat_offset": scheduled_target[&"beat_offset"],
			&"due_beat": scheduled_target[&"due_beat"],
			&"lane": action,
			&"lane_index": lane_index,
			&"visible": false,
			&"spawn_logged": false,
			&"progress": 0.0,
			&"x": 0.0,
			&"y": 0.0,
			&"radius": CLOSING_RING_START_RADIUS,
			&"subdivision_marker": subdivision_marker,
			&"subdivision_color": _get_subdivision_color(subdivision_marker),
			&"grade_name": &"",
		})
	_build_chord_groups()

func _build_chord_groups() -> void:
	_chord_groups.clear()
	var groups_by_id: Dictionary = {}
	for target in _targets:
		if int(target[&"group_size"]) <= 1:
			continue
		var group_id: StringName = target[&"group_id"]
		if not groups_by_id.has(group_id):
			var target_ids: Array[StringName] = []
			var lanes: Array[StringName] = []
			groups_by_id[group_id] = {
				&"group_id": group_id,
				&"target_ids": target_ids,
				&"lanes": lanes,
				&"treatment": &"connector_pulse",
				&"color": CHORD_COLOR,
			}
		var group: Dictionary = groups_by_id[group_id]
		var group_target_ids: Array[StringName] = group[&"target_ids"]
		var group_lanes: Array[StringName] = group[&"lanes"]
		group_target_ids.append(target[&"target_id"])
		group_lanes.append(target[&"lane"])
		group[&"target_ids"] = group_target_ids
		group[&"lanes"] = group_lanes
		groups_by_id[group_id] = group
	for group_id in groups_by_id:
		_chord_groups.append(groups_by_id[group_id])

func _update_positions(presentation: Dictionary) -> void:
	_timeline_position_beats = float(presentation[&"timeline_position_beats"])
	_visual_lead_beats = maxf(0.001, float(presentation[&"visual_lead_beats"]))
	var lane_width := size.x / float(_lane_order.size())
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
		if _presentation_style == &"closing_circles":
			target[&"y"] = hit_line_y
			target[&"radius"] = lerpf(
				CLOSING_RING_START_RADIUS,
				CLOSING_RING_HIT_RADIUS,
				clampf(progress, 0.0, 1.0)
			)
		else:
			target[&"y"] = lerpf(approach_start_y, hit_line_y, progress)
			target[&"radius"] = CLOSING_RING_HIT_RADIUS
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

func _clear_response_presentation() -> void:
	var had_presentation := _active or not _targets.is_empty() \
		or not _lane_feedback.is_empty() or not _target_feedback.is_empty()
	if had_presentation:
		DebugLog.visual("[CLEAR  ] response_highway=true  round=%d" % _round_id)
	_active = false
	_round_id = -1
	_timeline_position_beats = 0.0
	_targets.clear()
	_chord_groups.clear()
	_lane_feedback.clear()
	_target_feedback.clear()
	if had_presentation:
		queue_redraw()

func _clear_preview() -> void:
	var had_preview := not _preview.is_empty()
	if had_preview:
		DebugLog.visual("[CLEAR  ] phrase_preview=true  prompt=%s" % _preview[&"prompt_id"])
	_preview.clear()
	_preview_elapsed_seconds = 0.0
	if had_preview:
		queue_redraw()

func _clear_presentation() -> void:
	_clear_response_presentation()
	_clear_preview()

func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, size)
	draw_rect(board_rect, BOARD_COLOR)
	var lane_width := size.x / float(_lane_order.size())
	for lane_index in range(_lane_order.size()):
		var lane_rect := Rect2(lane_index * lane_width, 0.0, lane_width, size.y)
		draw_rect(lane_rect, LANE_COLORS[lane_index % LANE_COLORS.size()])
		if lane_index > 0:
			draw_line(Vector2(lane_rect.position.x, 0.0), Vector2(lane_rect.position.x, size.y), GRID_COLOR, 2.0)
		var action: StringName = _lane_order[lane_index]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(lane_rect.position.x + 12.0, 28.0),
			LANE_LABELS.get(action, String(action).replace("_", " ").to_upper()),
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
	if not _preview.is_empty():
		var preview_y := size.y * PREVIEW_LINE_RATIO
		for lane_index in _preview[&"lane_indices"]:
			var preview_position := Vector2((float(lane_index) + 0.5) * lane_width, preview_y)
			draw_circle(preview_position, 21.0, PREVIEW_COLOR)
			draw_arc(preview_position, 25.0, 0.0, TAU, 32, PREVIEW_COLOR, 2.0)
	for chord_group in _chord_groups:
		var group_positions: Array[Vector2] = []
		for target in _targets:
			if target[&"group_id"] == chord_group[&"group_id"] and bool(target[&"visible"]):
				group_positions.append(Vector2(float(target[&"x"]), float(target[&"y"])))
		if group_positions.size() < 2:
			continue
		group_positions.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.x < second.x)
		var pulse_radius := 24.0 + sin(_timeline_position_beats * TAU) * 2.0
		draw_line(group_positions[0], group_positions[-1], CHORD_COLOR, 5.0)
		for group_position in group_positions:
			draw_arc(group_position, pulse_radius, 0.0, TAU, 32, CHORD_COLOR, 3.0)
	for target in _targets:
		if not bool(target[&"visible"]):
			continue
		var note_position := Vector2(float(target[&"x"]), float(target[&"y"]))
		var note_color := CHORD_COLOR if int(target[&"group_size"]) > 1 else NOTE_COLOR
		if _presentation_style == &"closing_circles":
			var ring_color: Color = target[&"subdivision_color"]
			var ring_radius: float = target[&"radius"]
			draw_circle(note_position, 10.0, Color(note_color, 0.35))
			draw_arc(note_position, ring_radius, 0.0, TAU, 48, ring_color, 5.0)
			var marker_position := note_position + Vector2(0.0, -ring_radius)
			draw_circle(marker_position, 11.0, Color(BOARD_COLOR, 0.94))
			draw_arc(marker_position, 11.0, 0.0, TAU, 24, ring_color, 2.0)
			draw_string(
				ThemeDB.fallback_font,
				marker_position + Vector2(-10.0, 6.0),
				target[&"subdivision_marker"],
				HORIZONTAL_ALIGNMENT_CENTER,
				20.0,
				16,
				ring_color
			)
		else:
			draw_circle(note_position, 18.0, note_color)
		var action: StringName = target[&"expected_action"]
		draw_string(
			ThemeDB.fallback_font,
			note_position + Vector2(-12.0, 6.0),
			String(LANE_LABELS.get(action, String(action))).left(1),
			HORIZONTAL_ALIGNMENT_CENTER,
			24.0,
			18,
			BOARD_COLOR
		)
	for lane_index in range(_lane_order.size()):
		var lane: StringName = _lane_order[lane_index]
		if not _lane_feedback.has(lane):
			continue
		var feedback: Dictionary = _lane_feedback[lane]
		var grade_name: StringName = feedback[&"grade_name"]
		_draw_result_cue(
			Vector2((float(lane_index) + 0.5) * lane_width, hit_line_y),
			feedback[&"visual_cue"],
			feedback[&"color"]
		)
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

func _get_subdivision_marker(beat_offset: float) -> String:
	var fraction := fposmod(beat_offset, 1.0)
	var subdivision_index := roundi(fraction * 4.0)
	if subdivision_index == 4:
		subdivision_index = 0
	if absf(fraction - float(subdivision_index) * 0.25) > 0.01:
		return "•"
	return SUBDIVISION_MARKERS[subdivision_index]

func _get_subdivision_color(marker: String) -> Color:
	match marker:
		"1":
			return NOTE_COLOR
		"e":
			return CHORD_COLOR
		"&":
			return HIT_LINE_COLOR
		"a":
			return SUBDIVISION_A_COLOR
		_:
			return LABEL_COLOR

func _draw_result_cue(position: Vector2, visual_cue: StringName, color: Color) -> void:
	match visual_cue:
		&"strong_burst":
			draw_circle(position, 14.0, Color(color, 0.6))
			draw_arc(position, 22.0, 0.0, TAU, 32, color, 4.0)
			draw_arc(position, 29.0, 0.0, TAU, 32, Color(color, 0.7), 2.0)
		&"shaky_double_ring":
			draw_arc(position, 18.0, 0.0, TAU, 32, color, 4.0)
			draw_arc(position, 25.0, 0.0, TAU, 32, Color(color, 0.65), 2.0)
		_:
			draw_arc(position, 19.0, 0.0, TAU, 32, color, 4.0)
			draw_line(position + Vector2(-8.0, -8.0), position + Vector2(8.0, 8.0), color, 3.0)
			draw_line(position + Vector2(-8.0, 8.0), position + Vector2(8.0, -8.0), color, 3.0)

func _get_result_visual_cue(grade_name: StringName) -> StringName:
	match grade_name:
		&"perfect", &"great", &"good":
			return &"strong_burst"
		&"near_miss":
			return &"shaky_double_ring"
		_:
			return &"miss_ring"

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
