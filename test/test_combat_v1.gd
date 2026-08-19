# test/test_combat_v1.gd
# Verifies the isolated Combat V1 interface without touching the legacy CombatScene.
extends SceneTree

var _cadences: Array[int] = []
var _observed_inputs: int = 0
var _rejected_intents: int = 0
var _resolved_outcome: int = -1
var _encounter_state_changes: int = 0
var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	# Godot releases MP3 playback asynchronously after the prototype is freed.
	await create_timer(0.25).timeout
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 harness tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)

	_check("module exposes setup", module.has_method("setup"), true)
	_check("module exposes start", module.has_method("start"), true)
	_check("module exposes player_intent", module.has_method("player_intent"), true)
	_check("module exposes apply_performance_result", module.has_method("apply_performance_result"), true)
	_check("module exposes get_state", module.has_method("get_state"), true)
	_check("module exposes Response presentation", module.has_method("get_response_presentation"), true)
	_check("module exposes teardown", module.has_method("teardown"), true)
	_check("cadence_changed signal exists", module.has_signal("cadence_changed"), true)
	_check("intent_rejected signal exists", module.has_signal("intent_rejected"), true)
	_check("encounter_state_changed signal exists", module.has_signal("encounter_state_changed"), true)
	_check("response_target_announced signal exists", module.has_signal("response_target_announced"), true)
	_check("resolved signal exists", module.has_signal("resolved"), true)
	_check("module contains no legacy combat semantics", _has_no_legacy_semantics(), true)
	var prototype_scene = load("res://combat_v1/combat_v1_prototype.tscn")
	_check("independent prototype scene loads", prototype_scene != null, true)

	var beat_clock: Node = _find_autoload("BeatClock")
	var rhythm_input: Node = _find_autoload("RhythmInput")
	_check("BeatClock autoload available", beat_clock != null, true)
	_check("RhythmInput autoload available", rhythm_input != null, true)
	if beat_clock == null or rhythm_input == null:
		module.queue_free()
		print("=== done ===")
		return

	var encounter_config = CombatV1Script.EncounterConfig.new()
	encounter_config.max_groove = 10.0
	encounter_config.max_composure = 20.0
	encounter_config.jam_threshold = 10.0
	encounter_config.correct_groove_gain = 5.0
	encounter_config.correct_multiplier_gain = 0.0
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	module.setup(beat_clock, rhythm_input, opponent, 1, encounter_config)
	module.cadence_changed.connect(_on_cadence_changed)
	module.rhythm_input_observed.connect(_on_rhythm_input_observed)
	module.intent_rejected.connect(_on_intent_rejected)
	module.encounter_state_changed.connect(_on_encounter_state_changed)
	module.resolved.connect(_on_resolved)

	_check("start enters Settle", module.start(), true)
	_check("initial cadence is typed", module.get_cadence() == CombatV1Script.Cadence.SETTLE, true)
	_check("initial state exposes typed cadence", module.get_state()[&"cadence"] == CombatV1Script.Cadence.SETTLE, true)
	_check("initial state exposes display name separately", module.get_state()[&"cadence_name"] == &"Settle", true)
	_check("CombatV1 exposes empty Groove", module.get_state()[&"groove"], 0.0)
	_check("CombatV1 exposes full shared Composure", module.get_state()[&"composure"], 20.0)
	_check("CombatV1 exposes baseline shared Multiplier", module.get_state()[&"multiplier"], 1.0)
	_check("CombatV1 exposes non-terminal outcome", module.get_state()[&"outcome"], CombatV1Script.Outcome.NONE)
	_check("BeatClock listener connected once", _connection_count(beat_clock, &"beat", module), 1)
	_check("half-beat phrase listener connected once", _connection_count(beat_clock, &"half_beat", module), 1)
	_check("quarter-beat phrase listener connected once", _connection_count(beat_clock, &"quarter_beat", module), 1)
	_check("RhythmInput listener connected once", _connection_count(rhythm_input, &"input_scored", module), 1)
	_check("repeated start is ignored", module.start(), false)
	_check("repeated start keeps one BeatClock listener", _connection_count(beat_clock, &"beat", module), 1)

	beat_clock.beat.emit(1)
	_check("Settle waits for configured bar", module.get_cadence() == CombatV1Script.Cadence.SETTLE, true)
	for beat_number in range(2, 5):
		beat_clock.beat.emit(beat_number)
	_check("Settle transitions to Enemy Phrase", module.get_cadence() == CombatV1Script.Cadence.ENEMY_PHRASE, true)
	for beat_number in range(5, 9):
		beat_clock.beat.emit(beat_number)
	_check("Enemy Phrase transitions to Response", module.get_cadence() == CombatV1Script.Cadence.RESPONSE, true)
	_check("cadence signal carries enum values", _cadences.size() >= 3 and _cadences[0] == CombatV1Script.Cadence.SETTLE, true)

	var response_targets: Array = module.get_response_presentation()[&"targets"]
	beat_clock.beat.emit(9)
	beat_clock.beat.emit(10)
	beat_clock.beat_position = 0.0
	var first_response_action: StringName = response_targets[0][&"expected_action"]
	rhythm_input.input_scored.emit(first_response_action, &"perfect", -4.0, false)
	_check("shared input is observed through its signal", _observed_inputs, 1)
	_check("Response rejects a command for another cadence", module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND), false)
	_check("known invalid command is reported", _rejected_intents, 1)
	_check("unknown command is rejected predictably", module.player_intent(99), false)
	_check("unknown command is reported", _rejected_intents, 2)
	_check("Response remains until typed intent", module.get_cadence() == CombatV1Script.Cadence.RESPONSE, true)
	for target_index in range(1, response_targets.size()):
		var target: Dictionary = response_targets[target_index]
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	_check("typed response intent advances cadence", module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE), true)
	_check("Response transitions to Tactical Vamp", module.get_cadence() == CombatV1Script.Cadence.TACTICAL_VAMP, true)
	_check("typed next-round intent is accepted", module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND), true)
	_check("next-round intent waits in Tactical Vamp", module.get_cadence() == CombatV1Script.Cadence.TACTICAL_VAMP, true)
	for beat_number in range(11, 15):
		beat_clock.beat.emit(beat_number)
	beat_clock.beat.emit(15)
	_check("the following downbeat starts another Enemy Phrase", module.get_cadence() == CombatV1Script.Cadence.ENEMY_PHRASE, true)
	_check(
		"performance result applies through CombatV1",
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		),
		true
	)
	_check("resolution cadence is observable", module.get_cadence() == CombatV1Script.Cadence.RESOLUTION, true)
	_check("resolution signal carries typed Jam outcome", _resolved_outcome, CombatV1Script.Outcome.JAM)
	_check("terminal outcome is present in CombatV1 state", module.get_state()[&"outcome"], CombatV1Script.Outcome.JAM)
	_check("Groove is present in CombatV1 state", module.get_state()[&"groove"], 10.0)
	_check("state changes are observable through CombatV1", _encounter_state_changes, 2)
	_check(
		"post-terminal result is rejected through CombatV1",
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		),
		false
	)
	_check("CombatV1 emits one terminal outcome", _resolved_outcome, CombatV1Script.Outcome.JAM)

	module.teardown()
	module.teardown()
	_check("teardown removes BeatClock listener", _connection_count(beat_clock, &"beat", module), 0)
	_check("teardown removes half-beat listener", _connection_count(beat_clock, &"half_beat", module), 0)
	_check("teardown removes quarter-beat listener", _connection_count(beat_clock, &"quarter_beat", module), 0)
	_check("teardown removes RhythmInput listener", _connection_count(rhythm_input, &"input_scored", module), 0)
	_check("teardown is idempotent", module.get_state()[&"running"], false)
	_check("module can start again without duplicate listeners", module.start(), true)
	_check("restart has one BeatClock listener", _connection_count(beat_clock, &"beat", module), 1)
	_check("restart clears the previous Response summary", module.get_state()[&"response_summary"].is_empty(), true)
	module.teardown()
	_check("teardown restores RhythmInput scoring state", rhythm_input.is_scoring_enabled(), true)
	module.queue_free()

	if prototype_scene != null:
		var prototype = prototype_scene.instantiate()
		root.add_child(prototype)
		var prototype_module = prototype.get("_combat_v1")
		var prototype_hud = prototype.get_node("CombatV1HUD")
		var prototype_highway = prototype_hud.get_node("ResponseNoteHighway")
		_check("HUD connects cadence signal", _is_connected(prototype_module, &"cadence_changed", prototype_hud, "_on_cadence_changed"), true)
		_check("HUD connects encounter state signal", _is_connected(prototype_module, &"encounter_state_changed", prototype_hud, "_on_encounter_state_changed"), true)
		_check("prototype connects phrase event signal", _is_connected(prototype_module, &"phrase_event_announced", prototype, "_on_phrase_event_announced"), true)
		_check("HUD connects phrase event signal", _is_connected(prototype_module, &"phrase_event_announced", prototype_hud, "_on_phrase_event_announced"), true)
		_check("HUD connects Response target signal", _is_connected(prototype_module, &"response_target_announced", prototype_hud, "_on_response_target_announced"), true)
		_check("HUD connects Response note signal", _is_connected(prototype_module, &"response_note_graded", prototype_hud, "_on_response_note_graded"), true)
		_check("highway connects cadence signal", _is_connected(prototype_module, &"cadence_changed", prototype_highway, "_on_cadence_changed"), true)
		_check("highway connects phrase event signal", _is_connected(prototype_module, &"phrase_event_announced", prototype_highway, "_on_phrase_event_announced"), true)
		_check("highway connects Response note signal", _is_connected(prototype_module, &"response_note_graded", prototype_highway, "_on_response_note_graded"), true)
		_check("prototype connects Response summary signal", _is_connected(prototype_module, &"response_phrase_graded", prototype, "_on_response_phrase_graded"), true)
		_check("HUD connects Response summary signal", _is_connected(prototype_module, &"response_phrase_graded", prototype_hud, "_on_response_phrase_graded"), true)
		_check("HUD connects resolution signal", _is_connected(prototype_module, &"resolved", prototype_hud, "_on_resolved"), true)
		prototype.teardown()
		prototype.teardown()
		_check("HUD teardown disconnects cadence signal", _is_connected(prototype_module, &"cadence_changed", prototype_hud, "_on_cadence_changed"), false)
		_check("HUD teardown disconnects encounter state signal", _is_connected(prototype_module, &"encounter_state_changed", prototype_hud, "_on_encounter_state_changed"), false)
		_check("prototype teardown disconnects phrase event signal", _is_connected(prototype_module, &"phrase_event_announced", prototype, "_on_phrase_event_announced"), false)
		_check("HUD teardown disconnects phrase event signal", _is_connected(prototype_module, &"phrase_event_announced", prototype_hud, "_on_phrase_event_announced"), false)
		_check("HUD teardown disconnects Response target signal", _is_connected(prototype_module, &"response_target_announced", prototype_hud, "_on_response_target_announced"), false)
		_check("HUD teardown disconnects Response note signal", _is_connected(prototype_module, &"response_note_graded", prototype_hud, "_on_response_note_graded"), false)
		_check("highway teardown disconnects cadence signal", _is_connected(prototype_module, &"cadence_changed", prototype_highway, "_on_cadence_changed"), false)
		_check("highway teardown disconnects phrase event signal", _is_connected(prototype_module, &"phrase_event_announced", prototype_highway, "_on_phrase_event_announced"), false)
		_check("highway teardown disconnects Response note signal", _is_connected(prototype_module, &"response_note_graded", prototype_highway, "_on_response_note_graded"), false)
		_check("prototype teardown disconnects Response summary signal", _is_connected(prototype_module, &"response_phrase_graded", prototype, "_on_response_phrase_graded"), false)
		_check("HUD teardown disconnects Response summary signal", _is_connected(prototype_module, &"response_phrase_graded", prototype_hud, "_on_response_phrase_graded"), false)
		_check("HUD teardown disconnects resolution signal", _is_connected(prototype_module, &"resolved", prototype_hud, "_on_resolved"), false)
		prototype.free()

	_check("cadence transitions are externally observable", _cadences.size() >= 8, true)
	print("=== done ===")

func _find_autoload(node_name: StringName) -> Node:
	return root.get_node_or_null(NodePath(String(node_name)))

func _connection_count(source: Node, signal_name: StringName, target: Object) -> int:
	var count := 0
	for connection in Signal(source, signal_name).get_connections():
		if connection["callable"].get_object() == target:
			count += 1
	return count

func _is_connected(source: Object, signal_name: StringName, target: Object, method_name: StringName) -> bool:
	if source == null:
		return false
	return Signal(source, signal_name).is_connected(Callable(target, method_name))

func _has_no_legacy_semantics() -> bool:
	var source: String = FileAccess.get_file_as_string("res://combat_v1/combat_v1.gd").to_lower()
	for forbidden in ["hp", "damage", "attack", "defend", "limit gauge", "limit_gauge"]:
		if forbidden in source:
			return false
	return true

func _on_cadence_changed(cadence: int) -> void:
	_cadences.append(cadence)

func _on_rhythm_input_observed(_direction: StringName, _score: StringName, _offset_ms: float) -> void:
	_observed_inputs += 1

func _on_intent_rejected(_intent: int) -> void:
	_rejected_intents += 1

func _on_encounter_state_changed(_state: Dictionary) -> void:
	_encounter_state_changes += 1

func _on_resolved(outcome: int) -> void:
	_resolved_outcome = outcome

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
