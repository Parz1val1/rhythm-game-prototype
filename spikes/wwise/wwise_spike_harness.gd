# Isolated executable harness for GitHub issue #45.
#
# Run from the editor, a Windows export, or headlessly with:
#   godot --path . res://spikes/wwise/wwise_spike_harness.tscn -- \
#     --spike-seconds=900 --evidence-dir=user://wwise_spike
extends Node

const DebugLog = preload("res://autoloads/debug_log.gd")
const WwiseMusicAdapter = preload("res://spikes/wwise/wwise_music_adapter.gd")
const WwisePositionContinuityTracker = preload("res://spikes/wwise/wwise_position_continuity_tracker.gd")
const WwiseRuntimeBridge = preload("res://spikes/wwise/wwise_runtime_bridge.gd")

const DEFAULT_DURATION_SECONDS := 900.0
const DEFAULT_EVIDENCE_DIR := "user://wwise_spike"
const POSITION_DISCONTINUITY_THRESHOLD_MS := 20.0

var _adapter: Node
var _runtime: RefCounted
var _duration_seconds: float = DEFAULT_DURATION_SECONDS
var _evidence_dir: String = DEFAULT_EVIDENCE_DIR
var _auto_quit: bool = true
var _started_us: int = 0
var _finished: bool = false
var _evidence_file: FileAccess
var _evidence_stem: String = ""
var _position_continuity_tracker := WwisePositionContinuityTracker.new(
	POSITION_DISCONTINUITY_THRESHOLD_MS
)
@onready var _wwise_listener: Node = $WwiseListener

var _whole_boundaries: int = 0
var _missed_whole_boundaries: int = 0
var _duplicate_whole_boundaries: int = 0
var _last_whole_boundary: int = -1
var _beat_callbacks: int = 0
var _missed_beat_callbacks: int = 0
var _duplicate_beat_callbacks: int = 0
var _last_beat_callback: int = -1
var _arrangement_requests: int = 0
var _timing_errors_ms: Array[float] = []
var _clock_phase_samples_ms: Array[float] = []


func _ready() -> void:
	_parse_arguments()
	DebugLog.enabled = true
	DebugLog.beat_timing = true
	DebugLog.audio_events = true
	if not _open_evidence_file():
		_fail("Could not open Wwise spike evidence file in %s" % _evidence_dir)
		return

	_runtime = WwiseRuntimeBridge.new()
	_adapter = WwiseMusicAdapter.new()
	add_child(_adapter)
	_adapter.beat.connect(_on_beat)
	_adapter.half_beat.connect(_on_half_beat)
	_adapter.quarter_beat.connect(_on_quarter_beat)
	_adapter.arrangement_requested.connect(_on_arrangement_requested)
	_adapter.timing_observed.connect(_on_timing_observed)
	_adapter.continuous_position_sampled.connect(_on_continuous_position_sampled)
	_adapter.setup(_runtime)
	if not _adapter.start():
		_fail("Wwise failed to initialize or Play_Combat_Spike was not found")
		return
	_started_us = Time.get_ticks_usec()
	DebugLog.audio("[AUDIO  ] wwise_spike=running  duration_seconds=%.1f  evidence=%s" % [
		_duration_seconds,
		_evidence_stem,
	])


func _process(_delta: float) -> void:
	if _finished or _started_us == 0:
		return
	if _elapsed_ms() >= _duration_seconds * 1000.0:
		_finish()


func _exit_tree() -> void:
	if not _finished:
		_finish(false)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--spike-seconds="):
			_duration_seconds = maxf(1.0, float(argument.get_slice("=", 1)))
		elif argument.begins_with("--evidence-dir="):
			_evidence_dir = argument.trim_prefix("--evidence-dir=")
		elif argument == "--no-auto-quit":
			_auto_quit = false


func _open_evidence_file() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(_evidence_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return false
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	_evidence_stem = _evidence_dir.path_join("wwise-timing-%s" % timestamp)
	_evidence_file = FileAccess.open("%s.csv" % _evidence_stem, FileAccess.WRITE)
	if _evidence_file == null:
		return false
	_evidence_file.store_csv_line(PackedStringArray([
		"elapsed_ms",
		"record_type",
		"kind",
		"index",
		"position_beats",
		"callback_position_ms",
		"sampled_position_ms",
		"error_ms",
		"value",
	]))
	return true


func _on_beat(boundary: int) -> void:
	_whole_boundaries += 1
	var position_beats: float = _adapter.get_musical_position_beats()
	var beat_duration_ms: float = 60000.0 / float(_adapter.bpm)
	_clock_phase_samples_ms.append(position_beats * beat_duration_ms - _elapsed_ms())
	if _last_whole_boundary >= 0:
		if boundary <= _last_whole_boundary:
			_duplicate_whole_boundaries += 1
		elif boundary > _last_whole_boundary + 1:
			_missed_whole_boundaries += boundary - _last_whole_boundary - 1
	_last_whole_boundary = maxi(_last_whole_boundary, boundary)
	_store_evidence(&"boundary", &"beat", boundary, position_beats)

	# These repository-level intents exercise Wwise-authored, beat/bar-quantized
	# State transitions without exposing Wwise names to future combat callers.
	match boundary % 64:
		16:
			_adapter.set_layer_enabled(true)
		32:
			_adapter.request_transition(&"alternate")
		48:
			_adapter.set_layer_enabled(false)
		0:
			if boundary > 0:
				_adapter.request_transition(&"loop")


func _on_half_beat(boundary: int) -> void:
	_store_evidence(&"boundary", &"half", boundary, _adapter.get_musical_position_beats())


func _on_quarter_beat(boundary: int, subdivision: float) -> void:
	_store_evidence(
		&"boundary",
		&"quarter",
		boundary,
		_adapter.get_musical_position_beats(),
		"%.2f" % subdivision
	)


func _on_arrangement_requested(
	kind: StringName,
	value: Variant,
	requested_at_beats: float
) -> void:
	_arrangement_requests += 1
	_store_evidence(&"arrangement", kind, _arrangement_requests, requested_at_beats, str(value))


func _on_timing_observed(observation: Dictionary) -> void:
	var error_ms := float(observation.get(&"error_ms", 0.0))
	_timing_errors_ms.append(error_ms)
	var kind := StringName(observation.get(&"kind", &"unknown"))
	var callback_position_beats := float(observation.get(&"callback_position_beats", 0.0))
	var callback_index := int(round(callback_position_beats))
	if kind == &"beat":
		_beat_callbacks += 1
		if _last_beat_callback >= 0:
			if callback_index <= _last_beat_callback:
				_duplicate_beat_callbacks += 1
			elif callback_index > _last_beat_callback + 1:
				_missed_beat_callbacks += callback_index - _last_beat_callback - 1
		_last_beat_callback = maxi(_last_beat_callback, callback_index)
	_evidence_file.store_csv_line(PackedStringArray([
		"%.3f" % _elapsed_ms(),
		"callback",
		String(kind),
		str(callback_index),
		"%.6f" % float(observation.get(&"position_beats", 0.0)),
		"%.3f" % float(observation.get(&"callback_position_ms", 0.0)),
		"%.3f" % float(observation.get(&"sampled_position_ms", 0.0)),
		"%.3f" % error_ms,
		"",
	]))


func _on_continuous_position_sampled(position_beats: float, accepted: bool) -> void:
	var sampled_at_ms := _elapsed_ms()
	var beat_duration_ms: float = 60000.0 / float(_adapter.bpm)
	var is_discontinuity: bool = _position_continuity_tracker.observe(
		position_beats,
		sampled_at_ms,
		beat_duration_ms,
		accepted
	)
	if not is_discontinuity and accepted:
		return
	_store_position_anomaly(position_beats, sampled_at_ms, accepted, is_discontinuity)
	if not is_discontinuity:
		return
	DebugLog.timing(
		"[TIMING ] position_discontinuity=%d  position_beats=%.6f  delta_error_ms=%.3f  accepted=%s" % [
			_position_continuity_tracker.discontinuity_count,
			position_beats,
			_position_continuity_tracker.last_delta_error_ms,
			accepted,
		]
	)


func _store_evidence(
	record_type: StringName,
	kind: StringName,
	index: int,
	position_beats: float,
	value: String = ""
) -> void:
	if _evidence_file == null:
		return
	_evidence_file.store_csv_line(PackedStringArray([
		"%.3f" % _elapsed_ms(),
		String(record_type),
		String(kind),
		str(index),
		"%.6f" % position_beats,
		"",
		"",
		"",
		value,
	]))


func _store_position_anomaly(
	position_beats: float,
	sampled_at_ms: float,
	accepted: bool,
	is_discontinuity: bool
) -> void:
	if _evidence_file == null:
		return
	_evidence_file.store_csv_line(PackedStringArray([
		"%.3f" % sampled_at_ms,
		"position_discontinuity" if is_discontinuity else "position_regression",
		"continuous",
		str(_position_continuity_tracker.discontinuity_count),
		"%.6f" % position_beats,
		"",
		"",
		"%.3f" % _position_continuity_tracker.last_delta_error_ms,
		"accepted=%s" % accepted,
	]))


func _elapsed_ms() -> float:
	if _started_us == 0:
		return 0.0
	return float(Time.get_ticks_usec() - _started_us) / 1000.0


func _finish(allow_quit: bool = true) -> void:
	if _finished:
		return
	_finished = true
	_release_wwise_listener()
	if _adapter != null:
		_adapter.stop()
	if _evidence_file != null:
		_evidence_file.flush()
		_evidence_file = null

	var metrics := _build_metrics()
	var metrics_file := FileAccess.open("%s.json" % _evidence_stem, FileAccess.WRITE)
	if metrics_file != null:
		metrics_file.store_string(JSON.stringify(metrics, "  "))
	DebugLog.timing("[TIMING ] wwise_spike=complete  callbacks=%d  mean_error_ms=%.3f  p95_abs_error_ms=%.3f  max_abs_error_ms=%.3f" % [
		metrics[&"callback_observations"],
		metrics[&"mean_error_ms"],
		metrics[&"p95_abs_error_ms"],
		metrics[&"max_abs_error_ms"],
	])
	DebugLog.timing("[TIMING ] callback_jitter_ms=%.3f  clock_drift_ms=%.3f  clock_drift_ppm=%.3f" % [
		metrics[&"callback_jitter_ms"],
		metrics[&"clock_drift_ms"],
		metrics[&"clock_drift_ppm"],
	])
	DebugLog.timing("[TIMING ] boundaries=%d  missed=%d  duplicates=%d  beat_callbacks=%d  callback_missed=%d  callback_duplicates=%d" % [
		_whole_boundaries,
		_missed_whole_boundaries,
		_duplicate_whole_boundaries,
		_beat_callbacks,
		_missed_beat_callbacks,
		_duplicate_beat_callbacks,
	])
	DebugLog.timing("[TIMING ] position_samples=%d  position_discontinuities=%d  rejected_samples=%d  backward_samples=%d  max_delta_error_ms=%.3f" % [
		_position_continuity_tracker.sample_count,
		_position_continuity_tracker.discontinuity_count,
		_position_continuity_tracker.rejected_sample_count,
		_position_continuity_tracker.backward_sample_count,
		_position_continuity_tracker.max_abs_delta_error_ms,
	])
	print("=== done ===")
	if allow_quit and _auto_quit:
		get_tree().quit(0)


func _release_wwise_listener() -> void:
	if not is_instance_valid(_wwise_listener):
		return
	if _wwise_listener.is_inside_tree():
		remove_child(_wwise_listener)
	_wwise_listener.free()


func _build_metrics() -> Dictionary:
	var mean_error_ms := 0.0
	var callback_jitter_ms := 0.0
	var max_abs_error_ms := 0.0
	var absolute_errors: Array[float] = []
	for error_ms in _timing_errors_ms:
		mean_error_ms += error_ms
		var absolute_error := absf(error_ms)
		absolute_errors.append(absolute_error)
		max_abs_error_ms = maxf(max_abs_error_ms, absolute_error)
	if not _timing_errors_ms.is_empty():
		mean_error_ms /= _timing_errors_ms.size()
		var variance_ms := 0.0
		for error_ms in _timing_errors_ms:
			variance_ms += pow(error_ms - mean_error_ms, 2.0)
		callback_jitter_ms = sqrt(variance_ms / _timing_errors_ms.size())
	absolute_errors.sort()
	var p95_abs_error_ms := 0.0
	if not absolute_errors.is_empty():
		var percentile_index := mini(
			absolute_errors.size() - 1,
			int(ceil(absolute_errors.size() * 0.95)) - 1
		)
		p95_abs_error_ms = absolute_errors[percentile_index]
	var clock_drift_ms := 0.0
	if _clock_phase_samples_ms.size() >= 2:
		clock_drift_ms = _clock_phase_samples_ms[-1] - _clock_phase_samples_ms[0]
	var duration_ms := _elapsed_ms()
	var clock_drift_ppm := 0.0
	if duration_ms > 0.0:
		clock_drift_ppm = clock_drift_ms / duration_ms * 1000000.0
	return {
		&"godot_version": Engine.get_version_info(),
		&"wwise_version": "2025.1.9.9197",
		&"integration_tag": "wwise_v2025.1.9",
		&"duration_seconds": duration_ms / 1000.0,
		&"callback_observations": _timing_errors_ms.size(),
		&"mean_error_ms": mean_error_ms,
		&"callback_jitter_ms": callback_jitter_ms,
		&"p95_abs_error_ms": p95_abs_error_ms,
		&"max_abs_error_ms": max_abs_error_ms,
		&"clock_drift_ms": clock_drift_ms,
		&"clock_drift_ppm": clock_drift_ppm,
		&"whole_boundaries": _whole_boundaries,
		&"missed_whole_boundaries": _missed_whole_boundaries,
		&"duplicate_whole_boundaries": _duplicate_whole_boundaries,
		&"beat_callbacks": _beat_callbacks,
		&"missed_beat_callbacks": _missed_beat_callbacks,
		&"duplicate_beat_callbacks": _duplicate_beat_callbacks,
		&"arrangement_requests": _arrangement_requests,
		&"position_samples": _position_continuity_tracker.sample_count,
		&"position_discontinuities": _position_continuity_tracker.discontinuity_count,
		&"rejected_position_samples": _position_continuity_tracker.rejected_sample_count,
		&"backward_position_samples": _position_continuity_tracker.backward_sample_count,
		&"max_position_delta_error_ms": _position_continuity_tracker.max_abs_delta_error_ms,
		&"position_discontinuity_threshold_ms": POSITION_DISCONTINUITY_THRESHOLD_MS,
	}


func _fail(message: String) -> void:
	_finished = true
	if _adapter != null:
		_adapter.stop()
	if _evidence_file != null:
		_evidence_file = null
	printerr("ERROR: %s" % message)
	print("=== done ===")
	get_tree().quit(1)
