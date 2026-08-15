# Verifies deterministic terminal outcomes across the repeatable Combat V1 cadence.
extends SceneTree

var _resolved_outcomes: Array[int] = []
var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 repeatable-resolution tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var config = CombatV1Script.EncounterConfig.new()
	config.max_groove = 10.0
	config.jam_threshold = 10.0
	config.correct_groove_gain = 5.0
	config.correct_multiplier_gain = 0.0
	var module = CombatV1Script.new()
	root.add_child(module)
	module.resolved.connect(_on_resolved)
	module.setup(beat_clock, rhythm_input, opponent, 1, config)
	module.start()

	_advance_initial_to_response(beat_clock)
	_perform_perfect_response(module)
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	_check("the first correct Response remains non-terminal", module.get_cadence(), CombatV1Script.Cadence.TACTICAL_VAMP)
	_check("the first correct Response builds partial Groove", module.get_state()[&"groove"], 5.0)

	module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	beat_clock.beat.emit(20)
	_advance_round_to_response(beat_clock)
	_perform_perfect_response(module)
	_check(
		"the second correct Response is accepted",
		module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE),
		true
	)
	_check("the repeated cadence reaches Jam", module.get_state()[&"outcome"], CombatV1Script.Outcome.JAM)
	_check("Jam enters terminal Resolution", module.get_cadence(), CombatV1Script.Cadence.RESOLUTION)
	_check("Jam is emitted exactly once", _resolved_outcomes, [CombatV1Script.Outcome.JAM])
	var terminal_state: Dictionary = module.get_state().duplicate(true)
	var response_intent_rejected: bool = not module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var continue_intent_rejected: bool = not module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	_check(
		"terminal Resolution rejects every combat intent",
		response_intent_rejected and continue_intent_rejected,
		true
	)
	_check("rejected terminal intents cannot mutate encounter state", module.get_state(), terminal_state)

	module.teardown()
	module.free()

	_resolved_outcomes.clear()
	var loss_config = CombatV1Script.EncounterConfig.new()
	loss_config.max_composure = 30.0
	loss_config.major_mistake_composure_loss = 30.0
	var loss_module = CombatV1Script.new()
	root.add_child(loss_module)
	loss_module.resolved.connect(_on_resolved)
	loss_module.setup(beat_clock, rhythm_input, opponent, 1, loss_config)
	loss_module.start()
	_advance_initial_to_response(beat_clock)
	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	_check(
		"an unplayed Response is accepted as a broken phrase",
		loss_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE),
		true
	)
	_check("a broken Response deterministically reaches loss", loss_module.get_state()[&"outcome"], CombatV1Script.Outcome.LOSS)
	_check("loss enters terminal Resolution", loss_module.get_cadence(), CombatV1Script.Cadence.RESOLUTION)
	_check("loss is emitted exactly once", _resolved_outcomes, [CombatV1Script.Outcome.LOSS])
	loss_module.teardown()
	loss_module.free()
	print("=== done ===")

func _advance_initial_to_response(beat_clock: Node) -> void:
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)

func _advance_round_to_response(beat_clock: Node) -> void:
	for beat_number in range(21, 25):
		beat_clock.beat.emit(beat_number)

func _perform_perfect_response(module: Node) -> void:
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])

func _on_resolved(outcome: int) -> void:
	_resolved_outcomes.append(outcome)

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
