# Verifies next-round count-in presentation through the public CombatV1/HUD seam.
extends SceneTree

var _has_failures: bool = false
var _count_in_updates: Array[int] = []
var _raw_scored_inputs: int = 0
var _phrase_hud_snapshots: Array[Dictionary] = []

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 count-in presentation tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)
	var beat_clock: Node = root.get_node("BeatClock")
	var rhythm_input: Node = root.get_node("RhythmInput")
	module.setup(
		beat_clock,
		rhythm_input,
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.start()

	var hud = load("res://combat_v1/combat_v1_hud.tscn").instantiate()
	root.add_child(hud)
	hud.setup(module)
	module.next_round_transition_changed.connect(_on_next_round_transition_changed)
	rhythm_input.input_scored.connect(_on_raw_input_scored)
	module.phrase_event_announced.connect(
		func(_event, _expected_actions: Array[StringName]) -> void:
			_phrase_hud_snapshots.append({
				&"cadence": hud.get_node("CadencePanel/CadenceLabel").text,
				&"mode": hud.get_node("CadencePanel/ModeLabel").text,
				&"instruction": hud.get_node("InstructionPanel/InstructionLabel").text,
				&"count_in_visible": hud.get_node("InstructionPanel/CountInLabel").visible,
			})
	)
	_advance_to_tactical_vamp(module, beat_clock, CombatV1Script)
	_check(
		"Tactical Vamp stays pressure-free until the player commits",
		[
			hud.get_node("CadencePanel/ModeLabel").text,
			hud.get_node("InstructionPanel/InstructionLabel").text,
		],
		[
			"TACTICAL VAMP - NO TIME PRESSURE",
			"Listen without pressure. Press Enter, Space, or Start when you are ready.",
		]
	)

	_check(
		"Continue is accepted through the Combat V1 intent seam",
		module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND),
		true
	)
	var transition_state: Dictionary = module.get_state()
	var count_in_label: Label = hud.get_node_or_null("InstructionPanel/CountInLabel")
	_check(
		"accepting Continue immediately presents the committed listening transition",
		{
			&"cadence": transition_state[&"cadence"],
			&"pending": transition_state.get(&"next_round_pending", false),
			&"count_in_beat": transition_state.get(&"next_round_count_in_beat", -1),
			&"count_in_beats": transition_state.get(&"next_round_count_in_beats", -1),
			&"cadence_label": hud.get_node("CadencePanel/CadenceLabel").text,
			&"mode": hud.get_node("CadencePanel/ModeLabel").text,
			&"instruction": hud.get_node("InstructionPanel/InstructionLabel").text,
			&"count_in_visible": count_in_label != null and count_in_label.visible,
			&"count_in_text": count_in_label.text if count_in_label != null else "",
		},
		{
			&"cadence": CombatV1Script.Cadence.TACTICAL_VAMP,
			&"pending": true,
			&"count_in_beat": 0,
			&"count_in_beats": 4,
			&"cadence_label": "Next Round Count-In",
			&"mode": "COUNT-IN - LISTEN",
			&"instruction": "Choice locked. Listen for the next Enemy Phrase.",
			&"count_in_visible": true,
			&"count_in_text": "COUNT-IN  ○  ○  ○  ○",
		}
	)
	_check(
		"duplicate Continue is rejected while the listening transition is pending",
		module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND),
		false
	)
	rhythm_input._unhandled_input(_action(&"rhythm_up"))
	_check(
		"rhythm input remains unscoreable during the count-in",
		[_raw_scored_inputs, rhythm_input.is_scoring_enabled()],
		[0, false]
	)
	_phrase_hud_snapshots.clear()

	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	_check(
		"each authoritative count-in beat is presented exactly once",
		{
			&"updates": _count_in_updates,
			&"state_beat": module.get_state()[&"next_round_count_in_beat"],
			&"hud_text": count_in_label.text if count_in_label != null else "",
			&"cadence": module.get_cadence(),
		},
		{
			&"updates": [0, 1, 2, 3, 4],
			&"state_beat": 4,
			&"hud_text": "COUNT-IN  ●  ●  ●  ●",
			&"cadence": CombatV1Script.Cadence.TACTICAL_VAMP,
		}
	)
	beat_clock.beat.emit(13)
	_check(
		"Enemy Phrase is visibly active before its first preview is presented",
		{
			&"preview_snapshots": _phrase_hud_snapshots,
			&"transition_pending": module.get_state()[&"next_round_pending"],
			&"count_in_beat": module.get_state()[&"next_round_count_in_beat"],
		},
		{
			&"preview_snapshots": [{
				&"cadence": "Enemy Phrase",
				&"mode": "LISTEN - NO INPUT",
				&"instruction": "Listen to the phrase and watch each visual cue.",
				&"count_in_visible": false,
			}],
			&"transition_pending": false,
			&"count_in_beat": 0,
		}
	)

	for beat_number in range(14, 18):
		beat_clock.beat.emit(beat_number)
	_advance_response_to_tactical_vamp(module, CombatV1Script)
	_check(
		"leaving the prior round clears its count-in presentation",
		[
			module.get_state()[&"next_round_pending"],
			count_in_label.visible if count_in_label != null else true,
		],
		[false, false]
	)
	_count_in_updates.clear()
	module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	_check(
		"a repeated round starts one fresh count-in presentation",
		[
			_count_in_updates,
			module.get_state()[&"next_round_count_in_beat"],
			count_in_label.text if count_in_label != null else "",
		],
		[[0], 0, "COUNT-IN  ○  ○  ○  ○"]
	)
	for result_index in range(8):
		if module.get_state()[&"terminal"]:
			break
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		)
	_check(
		"encounter resolution clears a pending count-in presentation",
		{
			&"cadence": module.get_cadence(),
			&"pending": module.get_state()[&"next_round_pending"],
			&"count_in_beat": module.get_state()[&"next_round_count_in_beat"],
			&"mode": hud.get_node("CadencePanel/ModeLabel").text,
			&"count_in_visible": count_in_label.visible if count_in_label != null else true,
		},
		{
			&"cadence": CombatV1Script.Cadence.RESOLUTION,
			&"pending": false,
			&"count_in_beat": 0,
			&"mode": "CONVERSATION COMPLETE",
			&"count_in_visible": false,
		}
	)

	rhythm_input.input_scored.disconnect(_on_raw_input_scored)
	module.next_round_transition_changed.disconnect(_on_next_round_transition_changed)
	hud.teardown()
	module.teardown()
	hud.free()
	module.free()

	var teardown_module = CombatV1Script.new()
	root.add_child(teardown_module)
	teardown_module.setup(
		beat_clock,
		rhythm_input,
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	teardown_module.start()
	var teardown_hud = load("res://combat_v1/combat_v1_hud.tscn").instantiate()
	root.add_child(teardown_hud)
	teardown_hud.setup(teardown_module)
	_advance_to_tactical_vamp(teardown_module, beat_clock, CombatV1Script)
	teardown_module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	teardown_module.teardown()
	_check(
		"teardown clears a pending count-in presentation",
		{
			&"running": teardown_module.get_state()[&"running"],
			&"pending": teardown_module.get_state()[&"next_round_pending"],
			&"count_in_beat": teardown_module.get_state()[&"next_round_count_in_beat"],
			&"mode": teardown_hud.get_node("CadencePanel/ModeLabel").text,
			&"count_in_visible": teardown_hud.get_node("InstructionPanel/CountInLabel").visible,
		},
		{
			&"running": false,
			&"pending": false,
			&"count_in_beat": 0,
			&"mode": "WAITING",
			&"count_in_visible": false,
		}
	)
	teardown_hud.teardown()
	teardown_hud.free()
	teardown_module.free()
	print("=== done ===")

func _advance_to_tactical_vamp(module: Node, beat_clock: Node, CombatV1Script) -> void:
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	_advance_response_to_tactical_vamp(module, CombatV1Script)

func _advance_response_to_tactical_vamp(module: Node, CombatV1Script) -> void:
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)

func _on_next_round_transition_changed(transition: Dictionary) -> void:
	_count_in_updates.append(transition[&"count_in_beat"])

func _on_raw_input_scored(
	_direction: StringName,
	_score: StringName,
	_offset_ms: float,
	_note_consumed: bool
) -> void:
	_raw_scored_inputs += 1

func _action(action_name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
