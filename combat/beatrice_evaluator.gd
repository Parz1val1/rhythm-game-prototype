# combat/beatrice_evaluator.gd
# AttackEvaluator for Beatrice Styx — two-button rhythm drummer.
# Scores on two independent axes:
#   Timing accuracy — combo/streak multiplier identical to PassthroughEvaluator.
#   Rhythmic coherence — rewards hits landing on beat subdivisions (whole, half,
#     quarter). Reads BeatClock.beat_position at the moment record_hit() is called,
#     which is synchronous with the input event so the value is accurate.
# Damage = attack_power × timing_multiplier × coherence_multiplier.
class_name BeatriceEvaluator
extends "res://combat/attack_evaluator.gd"

const SequenceEvaluator = preload("res://combat/sequence_evaluator.gd")

var _sequence: SequenceEvaluator = SequenceEvaluator.new()
## Coherence multiplier from the most recently recorded hit (persists for UI display).
var _last_coherence: float = 1.0
## Beat position [0.0, 1.0] pushed in by CombatScene before each record_hit() call.
## Avoids a direct BeatClock reference (RefCounted can't resolve autoload at compile time).
var _beat_position: float = 0.0

## Called by CombatScene immediately before record_hit() to supply beat position.
func set_beat_position(bp: float) -> void:
	_beat_position = bp

func record_hit(score: StringName, attack_power: int) -> int:
	var timing_mult: float = _sequence.record_hit(score)
	if score == &"miss":
		_last_coherence = 1.0
		return 0
	# Coherence: measure proximity of the press to any beat subdivision.
	_last_coherence = _compute_coherence()
	var base: float = float(attack_power) * (0.5 if score == &"good" else 1.0)
	return int(base * timing_mult * _last_coherence)

## Current timing (combo) multiplier. Same formula as SequenceEvaluator.
func get_timing_multiplier() -> float:
	return _sequence.get_multiplier()

## Coherence multiplier from the last hit. Range [1.0, 1.5].
func get_coherence_mult() -> float:
	return _last_coherence

func get_multiplier() -> float:
	return get_timing_multiplier() * _last_coherence

func get_combo_count() -> int:
	return _sequence.combo_count

func reset() -> void:
	_sequence.reset()
	_last_coherence = 1.0

# ---------------------------------------------------------------------------
# Coherence calculation
# ---------------------------------------------------------------------------

## Returns a multiplier [1.0, 1.5] based on how close the current beat_position
## is to the nearest rhythmic subdivision (whole, half, or quarter beat).
## Exactly on a subdivision = 1.5; maximally between subdivisions = 1.0.
func _compute_coherence() -> float:
	var bp: float = _beat_position
	# Distance to each subdivision as a fraction of a beat (all in [0.0, 0.5]).
	var to_beat:    float = min(bp, 1.0 - bp)         # nearest full beat
	var to_half:    float = abs(bp - 0.5)              # half beat
	var to_q1:      float = abs(bp - 0.25)             # first quarter
	var to_q3:      float = abs(bp - 0.75)             # third quarter
	var nearest:    float = min(to_beat, min(to_half, min(to_q1, to_q3)))
	# Maximum possible distance to the nearest of 4 subdivisions per beat is 0.125.
	# Normalise to [0, 1] and invert: 0 distance → 1.0, max distance → 0.0.
	var norm: float = clampf(nearest / 0.125, 0.0, 1.0)
	# Scale to [1.0, 1.5]: on-grid = 1.5, off-grid = 1.0.
	return lerp(1.5, 1.0, norm)
