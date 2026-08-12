# combat_v1/encounter_state.gd
# Deterministic encounter-wide Groove, Composure, Multiplier, and outcome state.
class_name CombatV1EncounterState
extends RefCounted

const DebugLog = preload("res://autoloads/debug_log.gd")

enum Outcome {
	NONE,
	JAM,
	LOSS,
}

## Execution and tactical effectiveness are independent inputs. Correct execution
## changes momentum without implying that the musical choice was effective.
enum Execution {
	CORRECT,
	NEAR_MISS,
	MISTAKE,
	MAJOR_MISTAKE,
}

enum TacticalEffectiveness {
	EFFECTIVE,
	INEFFECTIVE,
}

const _EXECUTION_NAMES: Array[StringName] = [
	&"correct",
	&"near_miss",
	&"mistake",
	&"major_mistake",
]

const _EFFECTIVENESS_NAMES: Array[StringName] = [
	&"effective",
	&"ineffective",
]

const _OUTCOME_NAMES: Array[StringName] = [
	&"none",
	&"jam",
	&"loss",
]

## Emitted after every accepted atomic application with its resulting snapshot.
signal state_changed(state: Dictionary)
## Emitted exactly once when an atomic application makes the encounter terminal.
signal resolved(outcome: Outcome)

class Config extends RefCounted:
	var max_groove: float = 100.0
	var max_composure: float = 100.0
	var min_multiplier: float = 1.0
	var baseline_multiplier: float = 1.0
	var max_multiplier: float = 4.0
	var jam_threshold: float = 100.0
	var correct_groove_gain: float = 10.0
	var ineffective_groove_scale: float = 0.0
	var correct_multiplier_gain: float = 0.5
	var near_miss_groove_gain: float = 2.0
	var near_miss_composure_loss: float = 5.0
	var mistake_composure_loss: float = 15.0
	var major_mistake_composure_loss: float = 30.0
	var mistake_multiplier_loss: float = 0.5

var _max_groove: float = 100.0
var _max_composure: float = 100.0
var _min_multiplier: float = 1.0
var _baseline_multiplier: float = 1.0
var _max_multiplier: float = 4.0
var _jam_threshold: float = 100.0
var _correct_groove_gain: float = 10.0
var _ineffective_groove_scale: float = 0.0
var _correct_multiplier_gain: float = 0.5
var _near_miss_groove_gain: float = 2.0
var _near_miss_composure_loss: float = 5.0
var _mistake_composure_loss: float = 15.0
var _major_mistake_composure_loss: float = 30.0
var _mistake_multiplier_loss: float = 0.5

var _groove: float = 0.0
var _composure: float = 100.0
var _multiplier: float = 1.0
var _outcome: Outcome = Outcome.NONE

## Configure and initialize one encounter. Configuration is copied into scalar
## bounds so later caller mutation cannot change a live encounter.
func setup(config: Config = null) -> void:
	var source: Config = config if config != null else Config.new()
	_max_groove = maxf(source.max_groove, 0.001)
	_max_composure = maxf(source.max_composure, 0.001)
	_min_multiplier = maxf(source.min_multiplier, 0.0)
	_max_multiplier = maxf(source.max_multiplier, _min_multiplier)
	_baseline_multiplier = clampf(source.baseline_multiplier, _min_multiplier, _max_multiplier)
	_jam_threshold = clampf(source.jam_threshold, 0.001, _max_groove)
	_correct_groove_gain = maxf(source.correct_groove_gain, 0.0)
	_ineffective_groove_scale = clampf(source.ineffective_groove_scale, 0.0, 1.0)
	_correct_multiplier_gain = maxf(source.correct_multiplier_gain, 0.0)
	_near_miss_groove_gain = maxf(source.near_miss_groove_gain, 0.0)
	_near_miss_composure_loss = maxf(source.near_miss_composure_loss, 0.0)
	_mistake_composure_loss = maxf(source.mistake_composure_loss, 0.0)
	_major_mistake_composure_loss = maxf(source.major_mistake_composure_loss, 0.0)
	_mistake_multiplier_loss = maxf(source.mistake_multiplier_loss, 0.0)

	reset()

## Return the configured encounter to its initial non-terminal state.
func reset() -> void:
	_groove = 0.0
	_composure = _max_composure
	_multiplier = _baseline_multiplier
	_outcome = Outcome.NONE

## Apply one atomic performance result. Groove uses the Multiplier that existed
## when the result arrived; any momentum change affects later results.
func apply_performance_result(
	execution: Execution,
	effectiveness: TacticalEffectiveness
) -> bool:
	if _outcome != Outcome.NONE:
		return false
	if execution < Execution.CORRECT or execution > Execution.MAJOR_MISTAKE:
		return false
	if effectiveness < TacticalEffectiveness.EFFECTIVE \
			or effectiveness > TacticalEffectiveness.INEFFECTIVE:
		return false

	var old_groove := _groove
	var old_composure := _composure
	var old_multiplier := _multiplier
	var effectiveness_scale := 1.0
	if effectiveness == TacticalEffectiveness.INEFFECTIVE:
		effectiveness_scale = _ineffective_groove_scale
	var groove_gain := 0.0
	var composure_loss := 0.0
	var multiplier_change := 0.0
	var reset_multiplier := false
	match execution:
		Execution.CORRECT:
			groove_gain = _correct_groove_gain
			multiplier_change = _correct_multiplier_gain
		Execution.NEAR_MISS:
			groove_gain = _near_miss_groove_gain
			composure_loss = _near_miss_composure_loss
		Execution.MISTAKE:
			composure_loss = _mistake_composure_loss
			multiplier_change = -_mistake_multiplier_loss
		Execution.MAJOR_MISTAKE:
			composure_loss = _major_mistake_composure_loss
			reset_multiplier = true
	_groove = clampf(
		_groove + (groove_gain * effectiveness_scale * _multiplier),
		0.0,
		_max_groove
	)
	_composure = clampf(_composure - composure_loss, 0.0, _max_composure)
	if reset_multiplier:
		# A reset removes momentum above baseline but never rewards an encounter
		# already below baseline.
		_multiplier = minf(_multiplier, _baseline_multiplier)
	else:
		_multiplier = clampf(
			_multiplier + multiplier_change,
			_min_multiplier,
			_max_multiplier
		)

	var terminal_outcome := _resolve_terminal_outcome()
	DebugLog.combat(
		"[STATE  ] execution=%s  tactical=%s  groove=%.1f->%.1f  composure=%.1f->%.1f  multiplier=%.2f->%.2f" % [
			_EXECUTION_NAMES[execution],
			_EFFECTIVENESS_NAMES[effectiveness],
			old_groove,
			_groove,
			old_composure,
			_composure,
			old_multiplier,
			_multiplier,
		]
	)
	state_changed.emit(get_state())
	if terminal_outcome != Outcome.NONE:
		DebugLog.combat(
			"[RESULT ] outcome=%s  groove=%.1f  composure=%.1f" % [
				_OUTCOME_NAMES[terminal_outcome],
				_groove,
				_composure,
			]
		)
		resolved.emit(terminal_outcome)
	return true

func _resolve_terminal_outcome() -> Outcome:
	var jam_reached := _groove >= _jam_threshold
	var loss_reached := _composure <= 0.0
	# Provisional Issue #10 policy confirmed by the product owner: an atomic tie
	# resolves as a Jam. Keep this explicit rather than relying on incidental order.
	if jam_reached:
		_outcome = Outcome.JAM
	elif loss_reached:
		_outcome = Outcome.LOSS
	return _outcome

## Return an immutable-by-convention snapshot for callers and tests.
func get_state() -> Dictionary:
	return {
		&"groove": _groove,
		&"max_groove": _max_groove,
		&"composure": _composure,
		&"max_composure": _max_composure,
		&"multiplier": _multiplier,
		&"min_multiplier": _min_multiplier,
		&"baseline_multiplier": _baseline_multiplier,
		&"max_multiplier": _max_multiplier,
		&"jam_threshold": _jam_threshold,
		&"outcome": _outcome,
		&"outcome_name": _OUTCOME_NAMES[_outcome],
		&"terminal": _outcome != Outcome.NONE,
	}
