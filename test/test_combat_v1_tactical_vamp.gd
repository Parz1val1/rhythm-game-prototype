# Verifies the repeatable Tactical Vamp cadence through CombatV1's public seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Tactical Vamp tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var module = CombatV1Script.new()
	root.add_child(module)
	var repeated_phrase_offsets: Array[float] = []
	module.phrase_event_announced.connect(
		func(event, _expected_actions: Array[StringName]) -> void:
			repeated_phrase_offsets.append(event.beat_offset)
	)
	module.setup(beat_clock, rhythm_input, opponent, 1)
	module.start()

	_advance_to_response(beat_clock)
	_perform_perfect_response(module)
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	_check("completed Response enters Tactical Vamp", module.get_cadence(), CombatV1Script.Cadence.TACTICAL_VAMP)
	var waiting_state: Dictionary = module.get_state().duplicate(true)
	for beat_number in range(32):
		beat_clock.beat.emit(beat_number)
	_check("waiting indefinitely in Tactical Vamp preserves encounter state", module.get_state(), waiting_state)
	_check(
		"Tactical Vamp rejects out-of-scope performance intents",
		module.player_intent(2),
		false
	)
	_check(
		"continue-round intent is accepted during Tactical Vamp",
		module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND),
		true
	)
	_check("continue-round intent waits in Tactical Vamp", module.get_cadence(), CombatV1Script.Cadence.TACTICAL_VAMP)
	_check(
		"a queued next round rejects duplicate continue intents",
		module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND),
		false
	)
	repeated_phrase_offsets.clear()
	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	_check(
		"one full count-in bar passes before the opponent melody returns",
		{
			&"cadence": module.get_cadence(),
			&"phrase_offsets": repeated_phrase_offsets,
		},
		{
			&"cadence": CombatV1Script.Cadence.TACTICAL_VAMP,
			&"phrase_offsets": [],
		}
	)
	beat_clock.beat.emit(13)
	_check("the following downbeat starts the next Enemy Phrase", module.get_cadence(), CombatV1Script.Cadence.ENEMY_PHRASE)
	_check("the opponent melody starts on that downbeat", repeated_phrase_offsets, [0.0])

	_advance_round_to_response(beat_clock)
	_check("the repeated round reaches Response without another Settle", module.get_cadence(), CombatV1Script.Cadence.RESPONSE)
	var repeated_inputs_accepted := true
	for target in module.get_response_presentation()[&"targets"]:
		repeated_inputs_accepted = module.submit_response_input(
			target[&"expected_action"],
			target[&"due_beat"]
		) and repeated_inputs_accepted
	_check("the repeated Response accepts every refreshed target", repeated_inputs_accepted, true)
	_check(
		"the repeated Response returns to Tactical Vamp",
		module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE),
		true
	)
	_check("the second round preserves and advances Groove", module.get_state()[&"groove"], 25.0)
	_check("the second round preserves Composure", module.get_state()[&"composure"], 100.0)
	_check("the second round preserves and advances Multiplier", module.get_state()[&"multiplier"], 2.0)
	_check("repeated rounds keep one BeatClock listener", _connection_count(beat_clock, &"beat", module), 1)
	_check("repeated rounds keep one half-beat listener", _connection_count(beat_clock, &"half_beat", module), 1)
	_check("repeated rounds keep one quarter-beat listener", _connection_count(beat_clock, &"quarter_beat", module), 1)
	_check("repeated rounds keep one RhythmInput listener", _connection_count(rhythm_input, &"input_scored", module), 1)

	module.teardown()
	module.free()
	print("=== done ===")

func _advance_to_response(beat_clock: Node) -> void:
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)

func _perform_perfect_response(module: Node) -> void:
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])

func _advance_round_to_response(beat_clock: Node) -> void:
	for beat_number in range(14, 18):
		beat_clock.beat.emit(beat_number)

func _connection_count(source: Node, signal_name: StringName, target: Object) -> int:
	var count := 0
	for connection in Signal(source, signal_name).get_connections():
		if connection["callable"].get_object() == target:
			count += 1
	return count

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
