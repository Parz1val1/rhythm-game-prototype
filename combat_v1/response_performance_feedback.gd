## Replaceable one-shot audio adapter for deterministic Combat V1 Response results.
class_name CombatV1ResponsePerformanceFeedback
extends Node

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")

const LANE_ORDER: Array[StringName] = [&"left", &"down", &"up", &"right"]
const QUALITY_BANDS: Array[StringName] = [&"strong", &"shaky", &"missed"]
const LANE_PITCH_HZ := {
	&"left": 261.63,
	&"down": 293.66,
	&"up": 329.63,
	&"right": 392.00,
}
const SAMPLE_RATE := 22050
var _combat_v1: CombatV1 = null
var _players: Dictionary = {}
var _streams: Dictionary = {}
var _routed_events: Array[Dictionary] = []

func _ready() -> void:
	_ensure_players()

## Consume one CombatV1 instance's published result truth.
func setup(combat_v1: CombatV1) -> void:
	teardown()
	_ensure_players()
	_ensure_streams()
	_combat_v1 = combat_v1
	if _combat_v1 == null:
		return
	if not _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.response_note_graded.connect(_on_response_note_graded)
	if not _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
		_combat_v1.cadence_changed.connect(_on_cadence_changed)

## Return observable routing facts without exposing synthesis or player internals.
func get_feedback_snapshot() -> Dictionary:
	return {
		&"routed_events": _routed_events.duplicate(true),
	}

## Disconnect and stop every one-shot voice. Safe to call repeatedly.
func teardown() -> void:
	if _combat_v1 != null \
			and _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.response_note_graded.disconnect(_on_response_note_graded)
	if _combat_v1 != null and _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
		_combat_v1.cadence_changed.disconnect(_on_cadence_changed)
	_combat_v1 = null
	_clear_feedback()
	for player in _players.values():
		(player as AudioStreamPlayer).stream = null
	_streams.clear()

func _on_response_note_graded(result: Dictionary) -> void:
	if _combat_v1 == null or _combat_v1.get_cadence() != CombatV1.Cadence.RESPONSE:
		return
	var lane: StringName = result.get(&"lane", &"")
	if not LANE_PITCH_HZ.has(lane):
		return
	var pitch_hz: float = LANE_PITCH_HZ[lane]
	var quality_band := _get_quality_band(result.get(&"grade_name", &""))
	var timbre := _get_timbre(quality_band)
	var player := _players[lane] as AudioStreamPlayer
	player.volume_db = _get_volume_db(quality_band)
	player.stream = _get_stream(lane, pitch_hz, quality_band)
	player.play()
	var routed_event := {
		&"target_id": result.get(&"target_id", &""),
		&"expected_action": result.get(&"expected_action", &""),
		&"actual_action": result.get(&"actual_action", &""),
		&"offset_ms": result.get(&"offset_ms", 0.0),
		&"lane": lane,
		&"group_id": result.get(&"group_id", &""),
		&"group_size": result.get(&"group_size", 1),
		&"grade": result.get(&"grade", -1),
		&"grade_name": result.get(&"grade_name", &""),
		&"pitch_hz": pitch_hz,
		&"quality_band": quality_band,
		&"timbre": timbre,
	}
	_routed_events.append(routed_event)
	DebugLog.audio("[RESPONSE] target=%s  lane=%s  pitch_hz=%.2f  grade=%s" % [
		routed_event[&"target_id"],
		lane,
		pitch_hz,
		routed_event[&"grade_name"],
	])

func _on_cadence_changed(_cadence: CombatV1.Cadence) -> void:
	_clear_feedback()

func _clear_feedback() -> void:
	for player in _players.values():
		(player as AudioStreamPlayer).stop()
	_routed_events.clear()

func _ensure_players() -> void:
	if not _players.is_empty():
		return
	for lane in LANE_ORDER:
		var player := AudioStreamPlayer.new()
		player.name = "%sFeedback" % String(lane).capitalize()
		player.volume_db = -9.0
		add_child(player)
		_players[lane] = player

func _ensure_streams() -> void:
	for lane in LANE_ORDER:
		var pitch_hz: float = LANE_PITCH_HZ[lane]
		for quality_band in QUALITY_BANDS:
			_get_stream(lane, pitch_hz, quality_band)

func _get_stream(
	lane: StringName,
	lane_pitch_hz: float,
	quality_band: StringName
) -> AudioStreamWAV:
	var stream_key := StringName("%s:%s" % [lane, quality_band])
	if _streams.has(stream_key):
		return _streams[stream_key]
	var pitch_hz := lane_pitch_hz
	var duration_seconds := 0.22
	var harmonic_level := 0.22
	var amplitude := 0.42
	if quality_band == &"shaky":
		pitch_hz *= 0.985
		duration_seconds = 0.18
		harmonic_level = 0.10
		amplitude = 0.34
	elif quality_band == &"missed":
		pitch_hz *= 0.5
		duration_seconds = 0.13
		harmonic_level = 0.05
		amplitude = 0.25
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var sample_count := int(round(duration_seconds * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time_seconds := float(sample_index) / float(SAMPLE_RATE)
		var release := 1.0 - (float(sample_index) / float(sample_count))
		var attack := minf(1.0, time_seconds / 0.012)
		var envelope := attack * release * release
		var fundamental := sin(TAU * pitch_hz * time_seconds)
		var harmonic := sin(TAU * pitch_hz * 2.0 * time_seconds) * harmonic_level
		var sample_value := clampf((fundamental + harmonic) * envelope * amplitude, -1.0, 1.0)
		data.encode_s16(sample_index * 2, int(round(sample_value * 32767.0)))
	stream.data = data
	_streams[stream_key] = stream
	return stream

func _get_quality_band(grade_name: StringName) -> StringName:
	match grade_name:
		&"perfect", &"great", &"good":
			return &"strong"
		&"near_miss":
			return &"shaky"
		_:
			return &"missed"

func _get_timbre(quality_band: StringName) -> StringName:
	match quality_band:
		&"strong":
			return &"clear_pluck"
		&"shaky":
			return &"soft_pluck"
		_:
			return &"muted_pluck"

func _get_volume_db(quality_band: StringName) -> float:
	match quality_band:
		&"strong":
			return -9.0
		&"shaky":
			return -11.0
		_:
			return -13.0

func _exit_tree() -> void:
	teardown()
