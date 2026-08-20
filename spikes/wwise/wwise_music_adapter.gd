# Repository-owned musical-time seam for the Wwise feasibility spike.
#
# The injected runtime owns every Wwise-specific type, event, callback, state,
# and position query. Combat and presentation callers observe only the existing
# BeatClock-compatible surface below.
extends Node

const DebugLog = preload("res://autoloads/debug_log.gd")

signal beat(beat_number: int)
signal half_beat(beat_number: int)
signal quarter_beat(beat_number: int, subdivision: float)
signal arrangement_requested(kind: StringName, value: Variant, requested_at_beats: float)
signal timing_observed(observation: Dictionary)
signal continuous_position_sampled(position_beats: float, accepted: bool)

const CALLBACK_KINDS := {
	0x0100: &"beat",
	0x0200: &"bar",
	0x0400: &"entry",
	0x0800: &"exit",
	0x1000: &"grid",
	0x2000: &"user_cue",
	0x4000: &"sync_point",
}

var bpm: float = 120.0
var beat_number: int = 0
var beat_position: float = 0.0
var musical_position_beats: float = 0.0

var _runtime: Object
var _playing_id: int = 0
var _running: bool = false
var _position_ready: bool = false
var _last_boundary_step: int = 0
var _seconds_per_beat: float = 0.5
var _completed_source_ms: float = 0.0
var _last_source_position_ms: float = -1.0
var _last_segment_duration_ms: float = 0.0
var _pending_callbacks: Array[Dictionary] = []


func setup(runtime: Object) -> void:
	_runtime = runtime


func start() -> bool:
	if _runtime == null \
			or not _runtime.has_method(&"initialize") \
			or not _runtime.has_method(&"start_music") \
			or not _runtime.has_method(&"get_music_position"):
		return false
	if not bool(_runtime.call(&"initialize")):
		return false
	_playing_id = int(_runtime.call(&"start_music", self, _on_music_callback))
	if _playing_id <= 0:
		return false
	beat_number = 0
	beat_position = 0.0
	musical_position_beats = 0.0
	_last_boundary_step = 0
	_completed_source_ms = 0.0
	_last_source_position_ms = -1.0
	_last_segment_duration_ms = 0.0
	_pending_callbacks.clear()
	_position_ready = false
	_running = true
	DebugLog.audio("[AUDIO  ] wwise_spike=started  playing_id=%d" % _playing_id)
	return true


func stop() -> void:
	if _runtime != null and _playing_id > 0 and _runtime.has_method(&"stop_music"):
		_runtime.call(&"stop_music", _playing_id)
	if _runtime != null and _runtime.has_method(&"shutdown"):
		_runtime.call(&"shutdown")
	_running = false
	_playing_id = 0
	DebugLog.audio("[AUDIO  ] wwise_spike=stopped")


func is_running() -> bool:
	return _running


func get_musical_position_beats() -> float:
	return musical_position_beats


func get_offset_ms() -> float:
	if not _running:
		return 0.0
	if beat_position <= 0.5:
		return beat_position * _seconds_per_beat * 1000.0
	return (beat_position - 1.0) * _seconds_per_beat * 1000.0


func set_layer_enabled(enabled: bool) -> bool:
	if _runtime == null or not _runtime.has_method(&"set_layer_enabled"):
		return false
	var accepted := bool(_runtime.call(&"set_layer_enabled", enabled))
	if accepted:
		arrangement_requested.emit(&"layer", enabled, musical_position_beats)
		DebugLog.audio("[AUDIO  ] arrangement=layer  enabled=%s  requested_at=%.3f" % [
			enabled,
			musical_position_beats,
		])
	return accepted


func request_transition(section: StringName) -> bool:
	if section.is_empty() \
			or _runtime == null \
			or not _runtime.has_method(&"request_transition"):
		return false
	var accepted := bool(_runtime.call(&"request_transition", section))
	if accepted:
		arrangement_requested.emit(&"transition", section, musical_position_beats)
		DebugLog.audio("[AUDIO  ] arrangement=transition  section=%s  requested_at=%.3f" % [
			section,
			musical_position_beats,
		])
	return accepted


func _process(_delta: float) -> void:
	if not _running or not _position_ready:
		return
	var sample: Variant = _runtime.call(&"get_music_position", _playing_id)
	if not sample is Dictionary:
		return
	_publish_position(sample as Dictionary)
	_publish_pending_callbacks(sample as Dictionary)


func _publish_position(sample: Dictionary) -> void:
	var source_position_ms := float(sample.get(&"position_ms", -1.0))
	var beat_duration_ms := float(sample.get(&"beat_duration_ms", 0.0))
	var segment_duration_ms := float(sample.get(&"segment_duration_ms", 0.0))
	if source_position_ms < 0.0 or beat_duration_ms <= 0.0:
		return

	var comparison_duration_ms := _last_segment_duration_ms \
		if _last_segment_duration_ms > 0.0 else segment_duration_ms
	var source_wrapped := _last_source_position_ms >= 0.0 \
		and comparison_duration_ms > 0.0 \
		and _last_source_position_ms > comparison_duration_ms * 0.5 \
		and source_position_ms < comparison_duration_ms * 0.5
	if source_wrapped:
		_completed_source_ms += comparison_duration_ms
		DebugLog.timing("[TIMING ] wwise_segment=wrapped  segment_ms=%.3f  elapsed_ms=%.3f" % [
			comparison_duration_ms,
			_completed_source_ms,
		])
	_last_source_position_ms = source_position_ms
	if segment_duration_ms > 0.0:
		_last_segment_duration_ms = segment_duration_ms

	_seconds_per_beat = beat_duration_ms / 1000.0
	bpm = 60000.0 / beat_duration_ms
	var sampled_position_beats := (_completed_source_ms + source_position_ms) / beat_duration_ms
	var accepted := sampled_position_beats + 0.000001 >= musical_position_beats
	continuous_position_sampled.emit(sampled_position_beats, accepted)
	if not accepted:
		return

	# Publish the atomic position before any boundary signal, matching BeatClock.
	musical_position_beats = sampled_position_beats
	beat_number = int(floor(sampled_position_beats))
	beat_position = fmod(sampled_position_beats, 1.0)

	var current_boundary_step := int(floor(sampled_position_beats * 4.0 + 0.000001))
	for boundary_step in range(_last_boundary_step + 1, current_boundary_step + 1):
		_publish_boundary(boundary_step)
	_last_boundary_step = current_boundary_step


func _publish_boundary(boundary_step: int) -> void:
	var boundary_beat := boundary_step / 4
	match boundary_step % 4:
		0:
			beat.emit(boundary_beat)
		1:
			quarter_beat.emit(boundary_beat, 0.25)
		2:
			half_beat.emit(boundary_beat)
		3:
			quarter_beat.emit(boundary_beat, 0.75)


func _on_music_callback(data: Dictionary) -> void:
	# Wwise music callbacks are comparative evidence during the spike. Boundary
	# publication remains derived from continuous position so late frames can
	# recover missed callbacks without duplicate gameplay signals.
	var callback_type := int(data.get("callback_type", 0))
	var segment_info: Variant = data.get("segmentInfo", {})
	if not segment_info is Dictionary or not CALLBACK_KINDS.has(callback_type):
		return
	var callback_position_ms := float((segment_info as Dictionary).get("iCurrentPosition", -1.0))
	if callback_position_ms < 0.0:
		return
	_position_ready = true
	_pending_callbacks.append({
		&"kind": CALLBACK_KINDS[callback_type],
		&"callback_position_ms": callback_position_ms,
		&"delivered_us": Time.get_ticks_usec(),
	})


func _publish_pending_callbacks(sample: Dictionary) -> void:
	if _pending_callbacks.is_empty():
		return
	var sampled_position_ms := float(sample.get(&"position_ms", -1.0))
	var beat_duration_ms := float(sample.get(&"beat_duration_ms", 0.0))
	if sampled_position_ms < 0.0 or beat_duration_ms <= 0.0:
		return
	var segment_duration_ms := float(sample.get(&"segment_duration_ms", 0.0))
	for callback in _pending_callbacks:
		var callback_position_ms := float(callback[&"callback_position_ms"])
		var error_ms := sampled_position_ms - callback_position_ms
		if segment_duration_ms > 0.0:
			if error_ms < -segment_duration_ms * 0.5:
				error_ms += segment_duration_ms
			elif error_ms > segment_duration_ms * 0.5:
				error_ms -= segment_duration_ms
		var observation := {
			&"kind": callback[&"kind"],
			&"callback_position_ms": callback_position_ms,
			&"sampled_position_ms": sampled_position_ms,
			&"error_ms": error_ms,
			&"position_beats": musical_position_beats,
			&"callback_position_beats": musical_position_beats - error_ms / beat_duration_ms,
			&"beat_duration_ms": beat_duration_ms,
			&"delivered_us": callback[&"delivered_us"],
		}
		timing_observed.emit(observation)
		DebugLog.timing("[TIMING ] wwise_callback=%s  position_beats=%.3f  error_ms=%.3f" % [
			observation[&"kind"],
			observation[&"position_beats"],
			observation[&"error_ms"],
		])
	_pending_callbacks.clear()
