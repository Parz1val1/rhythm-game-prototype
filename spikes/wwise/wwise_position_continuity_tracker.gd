# Measures whether the adapter's continuous musical position advances with
# monotonic wall-clock time. This is spike evidence, not a combat dependency.
extends RefCounted

const POSITION_EPSILON_BEATS := 0.000001

var sample_count: int = 0
var discontinuity_count: int = 0
var rejected_sample_count: int = 0
var backward_sample_count: int = 0
var last_delta_error_ms: float = 0.0
var max_abs_delta_error_ms: float = 0.0

var _discontinuity_threshold_ms: float
var _last_position_beats: float = 0.0
var _last_sampled_at_ms: float = -1.0


func _init(discontinuity_threshold_ms: float = 20.0) -> void:
	_discontinuity_threshold_ms = maxf(0.0, discontinuity_threshold_ms)


func observe(
	position_beats: float,
	sampled_at_ms: float,
	beat_duration_ms: float,
	accepted: bool
) -> bool:
	if beat_duration_ms <= 0.0:
		return false

	sample_count += 1
	var is_discontinuity := false
	if not accepted:
		rejected_sample_count += 1

	if _last_sampled_at_ms >= 0.0:
		var elapsed_delta_ms := maxf(0.0, sampled_at_ms - _last_sampled_at_ms)
		var position_delta_ms := (position_beats - _last_position_beats) * beat_duration_ms
		last_delta_error_ms = position_delta_ms - elapsed_delta_ms
		max_abs_delta_error_ms = maxf(max_abs_delta_error_ms, absf(last_delta_error_ms))
		if position_beats + POSITION_EPSILON_BEATS < _last_position_beats:
			backward_sample_count += 1
		if absf(last_delta_error_ms) > _discontinuity_threshold_ms:
			is_discontinuity = true
	else:
		last_delta_error_ms = 0.0

	if is_discontinuity:
		discontinuity_count += 1
	_last_position_beats = position_beats
	_last_sampled_at_ms = sampled_at_ms
	return is_discontinuity
