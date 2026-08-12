# test/test_combat_v1_encounter_state.gd
# Verifies encounter resources and outcomes through the public state interface.
extends SceneTree

var _has_failures: bool = false
var _resolved_outcomes: Array[int] = []
var _state_change_count: int = 0

func _init() -> void:
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 encounter-state tests ===")
	var StateScript = load("res://combat_v1/encounter_state.gd")
	_check("encounter state module loads", StateScript != null, true)
	if StateScript == null:
		print("=== done ===")
		return

	var config = StateScript.Config.new()
	config.max_groove = 80.0
	config.max_composure = 60.0
	config.min_multiplier = 0.5
	config.baseline_multiplier = 1.5
	config.max_multiplier = 3.0
	config.jam_threshold = 70.0
	config.correct_groove_gain = 10.0
	config.ineffective_groove_scale = 0.0
	config.correct_multiplier_gain = 0.5
	config.near_miss_groove_gain = 2.0
	config.near_miss_composure_loss = 5.0
	config.mistake_composure_loss = 15.0
	config.major_mistake_composure_loss = 30.0
	config.mistake_multiplier_loss = 1.0

	var state = StateScript.new()
	state.setup(config)
	var snapshot: Dictionary = state.get_state()
	_check("Groove begins empty", snapshot[&"groove"], 0.0)
	_check("shared Composure begins at its configured maximum", snapshot[&"composure"], 60.0)
	_check("shared Multiplier begins at its configured baseline", snapshot[&"multiplier"], 1.5)
	_check("Jam threshold is observable", snapshot[&"jam_threshold"], 70.0)
	_check("encounter begins non-terminal", snapshot[&"outcome"], StateScript.Outcome.NONE)

	_check(
		"effective correct play is accepted",
		state.apply_performance_result(
			StateScript.Execution.CORRECT,
			StateScript.TacticalEffectiveness.EFFECTIVE
		),
		true
	)
	snapshot = state.get_state()
	_check("current Multiplier modifies Groove", snapshot[&"groove"], 15.0)
	_check("correct execution preserves Composure", snapshot[&"composure"], 60.0)
	_check("correct execution increases band-wide Multiplier", snapshot[&"multiplier"], 2.0)

	_check(
		"correct but ineffective play is accepted",
		state.apply_performance_result(
			StateScript.Execution.CORRECT,
			StateScript.TacticalEffectiveness.INEFFECTIVE
		),
		true
	)
	snapshot = state.get_state()
	_check("ineffective tactics can produce no Groove", snapshot[&"groove"], 15.0)
	_check("ineffective tactics do not reduce Composure", snapshot[&"composure"], 60.0)
	_check("correct execution still builds Multiplier", snapshot[&"multiplier"], 2.5)

	_check(
		"Near Miss result is accepted",
		state.apply_performance_result(
			StateScript.Execution.NEAR_MISS,
			StateScript.TacticalEffectiveness.EFFECTIVE
		),
		true
	)
	snapshot = state.get_state()
	_check("Near Miss can add small Groove through Multiplier", snapshot[&"groove"], 20.0)
	_check("Near Miss can also reduce Composure", snapshot[&"composure"], 55.0)
	_check("Near Miss maintains Multiplier", snapshot[&"multiplier"], 2.5)

	_check(
		"execution mistake is accepted",
		state.apply_performance_result(
			StateScript.Execution.MISTAKE,
			StateScript.TacticalEffectiveness.EFFECTIVE
		),
		true
	)
	snapshot = state.get_state()
	_check("execution mistake does not add Groove", snapshot[&"groove"], 20.0)
	_check("execution mistake reduces Composure", snapshot[&"composure"], 40.0)
	_check("execution mistake reduces Multiplier", snapshot[&"multiplier"], 1.5)

	state.apply_performance_result(
		StateScript.Execution.MISTAKE,
		StateScript.TacticalEffectiveness.INEFFECTIVE
	)
	snapshot = state.get_state()
	_check("Multiplier clamps at its configured minimum", snapshot[&"multiplier"], 0.5)

	state.setup(config)
	state.apply_performance_result(
		StateScript.Execution.CORRECT,
		StateScript.TacticalEffectiveness.EFFECTIVE
	)
	state.apply_performance_result(
		StateScript.Execution.MAJOR_MISTAKE,
		StateScript.TacticalEffectiveness.INEFFECTIVE
	)
	snapshot = state.get_state()
	_check("major mistake reduces Composure", snapshot[&"composure"], 30.0)
	_check("major mistake resets raised Multiplier to baseline", snapshot[&"multiplier"], 1.5)

	var bounds_config = StateScript.Config.new()
	bounds_config.max_groove = 100.0
	bounds_config.max_composure = 100.0
	bounds_config.min_multiplier = 0.5
	bounds_config.baseline_multiplier = 1.5
	bounds_config.max_multiplier = 2.0
	bounds_config.jam_threshold = 100.0
	bounds_config.correct_groove_gain = 0.0
	bounds_config.correct_multiplier_gain = 4.0
	state.setup(bounds_config)
	state.apply_performance_result(
		StateScript.Execution.CORRECT,
		StateScript.TacticalEffectiveness.INEFFECTIVE
	)
	_check("Multiplier clamps at its configured maximum", state.get_state()[&"multiplier"], 2.0)

	var near_config = StateScript.Config.new()
	near_config.max_groove = 100.0
	near_config.max_composure = 100.0
	near_config.jam_threshold = 90.0
	near_config.correct_groove_gain = 85.0
	near_config.correct_multiplier_gain = 0.0
	near_config.near_miss_groove_gain = 0.0
	near_config.near_miss_composure_loss = 95.0
	state.setup(near_config)
	state.apply_performance_result(
		StateScript.Execution.CORRECT,
		StateScript.TacticalEffectiveness.EFFECTIVE
	)
	state.apply_performance_result(
		StateScript.Execution.NEAR_MISS,
		StateScript.TacticalEffectiveness.EFFECTIVE
	)
	snapshot = state.get_state()
	_check("near-win Groove remains non-terminal", snapshot[&"groove"], 85.0)
	_check("near-loss Composure remains non-terminal", snapshot[&"composure"], 5.0)
	_check("simultaneous near-win and near-loss remains unresolved", snapshot[&"outcome"], StateScript.Outcome.NONE)

	var tie_config = StateScript.Config.new()
	tie_config.max_groove = 10.0
	tie_config.max_composure = 5.0
	tie_config.jam_threshold = 10.0
	tie_config.near_miss_groove_gain = 10.0
	tie_config.near_miss_composure_loss = 5.0
	state.setup(tie_config)
	_resolved_outcomes.clear()
	_state_change_count = 0
	state.resolved.connect(_on_state_resolved)
	state.state_changed.connect(_on_state_changed)
	_check(
		"atomic competing terminal result is accepted",
		state.apply_performance_result(
			StateScript.Execution.NEAR_MISS,
			StateScript.TacticalEffectiveness.EFFECTIVE
		),
		true
	)
	snapshot = state.get_state()
	_check("Groove clamps at its configured maximum", snapshot[&"groove"], 10.0)
	_check("Composure clamps at zero", snapshot[&"composure"], 0.0)
	_check("Jam wins simultaneous terminal conditions", snapshot[&"outcome"], StateScript.Outcome.JAM)
	_check("terminal state is observable", snapshot[&"terminal"], true)
	_check("Jam resolves exactly once", _resolved_outcomes, [StateScript.Outcome.JAM])
	_check("atomic application emits one state change", _state_change_count, 1)
	var jam_snapshot: Dictionary = snapshot.duplicate(true)
	_check(
		"post-Jam application is rejected",
		state.apply_performance_result(
			StateScript.Execution.CORRECT,
			StateScript.TacticalEffectiveness.EFFECTIVE
		),
		false
	)
	_check("post-Jam state is unchanged", state.get_state(), jam_snapshot)
	_check("post-Jam application emits no second outcome", _resolved_outcomes.size(), 1)
	_check("post-Jam application emits no state change", _state_change_count, 1)

	var loss_config = StateScript.Config.new()
	loss_config.max_composure = 10.0
	loss_config.mistake_composure_loss = 50.0
	state = StateScript.new()
	state.setup(loss_config)
	_resolved_outcomes.clear()
	_state_change_count = 0
	state.resolved.connect(_on_state_resolved)
	state.state_changed.connect(_on_state_changed)
	_check(
		"Composure-breaking mistake is accepted",
		state.apply_performance_result(
			StateScript.Execution.MISTAKE,
			StateScript.TacticalEffectiveness.INEFFECTIVE
		),
		true
	)
	snapshot = state.get_state()
	_check("zero Composure resolves a loss", snapshot[&"outcome"], StateScript.Outcome.LOSS)
	_check("loss resolves exactly once", _resolved_outcomes, [StateScript.Outcome.LOSS])
	var loss_snapshot: Dictionary = snapshot.duplicate(true)
	_check(
		"post-loss application is rejected",
		state.apply_performance_result(
			StateScript.Execution.MISTAKE,
			StateScript.TacticalEffectiveness.EFFECTIVE
		),
		false
	)
	_check("post-loss state is unchanged", state.get_state(), loss_snapshot)
	_check("post-loss application emits no second outcome", _resolved_outcomes.size(), 1)
	print("=== done ===")

func _on_state_resolved(outcome: int) -> void:
	_resolved_outcomes.append(outcome)

func _on_state_changed(_snapshot: Dictionary) -> void:
	_state_change_count += 1

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
