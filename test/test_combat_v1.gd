# test/test_combat_v1.gd
# Verifies the isolated Combat V1 interface without touching the legacy CombatScene.
extends SceneTree

var _cadences: Array[int] = []
var _observed_inputs: int = 0
var _rejected_intents: int = 0
var _resolved_outcome: StringName = &""
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
	_check("module exposes get_state", module.has_method("get_state"), true)
	_check("module exposes resolve", module.has_method("resolve"), true)
	_check("module exposes teardown", module.has_method("teardown"), true)
	_check("cadence_changed signal exists", module.has_signal("cadence_changed"), true)
	_check("intent_rejected signal exists", module.has_signal("intent_rejected"), true)
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

	module.setup(beat_clock, rhythm_input, 2, 4)
	module.cadence_changed.connect(_on_cadence_changed)
	module.rhythm_input_observed.connect(_on_rhythm_input_observed)
	module.intent_rejected.connect(_on_intent_rejected)
	module.resolved.connect(_on_resolved)

	_check("start enters Settle", module.start(), true)
	_check("initial cadence is typed", module.get_cadence() == CombatV1Script.Cadence.SETTLE, true)
	_check("initial state exposes typed cadence", module.get_state()[&"cadence"] == CombatV1Script.Cadence.SETTLE, true)
	_check("initial state exposes display name separately", module.get_state()[&"cadence_name"] == &"Settle", true)
	_check("BeatClock listener connected once", _connection_count(beat_clock, &"beat", module), 1)
	_check("RhythmInput listener connected once", _connection_count(rhythm_input, &"input_scored", module), 1)
	_check("repeated start is ignored", module.start(), false)
	_check("repeated start keeps one BeatClock listener", _connection_count(beat_clock, &"beat", module), 1)

	beat_clock.beat.emit(1)
	_check("Settle waits for configured beats", module.get_cadence() == CombatV1Script.Cadence.SETTLE, true)
	beat_clock.beat.emit(2)
	_check("Settle transitions to Enemy Phrase", module.get_cadence() == CombatV1Script.Cadence.ENEMY_PHRASE, true)
	for beat_number in range(3, 7):
		beat_clock.beat.emit(beat_number)
	_check("Enemy Phrase transitions to Response", module.get_cadence() == CombatV1Script.Cadence.RESPONSE, true)
	_check("cadence signal carries enum values", _cadences.size() >= 3 and _cadences[0] == CombatV1Script.Cadence.SETTLE, true)

	rhythm_input.input_scored.emit(&"up", &"perfect", -4.0, false)
	_check("shared input is observed through its signal", _observed_inputs, 1)
	_check("Response rejects a command for another cadence", module.player_intent(CombatV1Script.Intent.SELECT_PERFORMANCE), false)
	_check("known invalid command is reported", _rejected_intents, 1)
	_check("unknown command is rejected predictably", module.player_intent(99), false)
	_check("unknown command is reported", _rejected_intents, 2)
	_check("Response remains until typed intent", module.get_cadence() == CombatV1Script.Cadence.RESPONSE, true)
	_check("typed response intent advances cadence", module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE), true)
	_check("Response transitions to Tactical Vamp", module.get_cadence() == CombatV1Script.Cadence.TACTICAL_VAMP, true)
	_check("typed performance selection advances cadence", module.player_intent(CombatV1Script.Intent.SELECT_PERFORMANCE), true)
	_check("Tactical Vamp transitions to Character Performance", module.get_cadence() == CombatV1Script.Cadence.CHARACTER_PERFORMANCE, true)
	_check("performance completion returns to Tactical Vamp", module.player_intent(CombatV1Script.Intent.COMPLETE_PERFORMANCE), true)
	_check("Character Performance does not skip Tactical Vamp", module.get_cadence() == CombatV1Script.Cadence.TACTICAL_VAMP, true)
	_check("performance loop can begin another character performance", module.player_intent(CombatV1Script.Intent.SELECT_PERFORMANCE), true)
	_check("second performance returns to Tactical Vamp", module.player_intent(CombatV1Script.Intent.COMPLETE_PERFORMANCE), true)
	_check("full-band boundary is explicit placeholder", module.player_intent(CombatV1Script.Intent.COMPLETE_PERFORMANCE_SEQUENCE), true)
	_check("placeholder reaches Full-Band Vamp", module.get_cadence() == CombatV1Script.Cadence.FULL_BAND_VAMP, true)
	_check("resolution is observable", module.resolve(&"complete"), true)
	_check("resolution cadence is observable", module.get_cadence() == CombatV1Script.Cadence.RESOLUTION, true)
	_check("resolution signal carries outcome", _resolved_outcome, &"complete")
	_check("resolution is present in state", module.get_state()[&"resolution"], &"complete")

	module.teardown()
	module.teardown()
	_check("teardown removes BeatClock listener", _connection_count(beat_clock, &"beat", module), 0)
	_check("teardown removes RhythmInput listener", _connection_count(rhythm_input, &"input_scored", module), 0)
	_check("teardown is idempotent", module.get_state()[&"running"], false)
	_check("module can start again without duplicate listeners", module.start(), true)
	_check("restart has one BeatClock listener", _connection_count(beat_clock, &"beat", module), 1)
	module.teardown()
	module.queue_free()

	if prototype_scene != null:
		var prototype = prototype_scene.instantiate()
		root.add_child(prototype)
		var prototype_module = prototype.get("_combat_v1")
		_check("prototype connects cadence signal", _is_connected(prototype_module, &"cadence_changed", prototype, "_on_cadence_changed"), true)
		_check("prototype connects input signal", _is_connected(prototype_module, &"rhythm_input_observed", prototype, "_on_rhythm_input_observed"), true)
		_check("prototype connects resolution signal", _is_connected(prototype_module, &"resolved", prototype, "_on_resolved"), true)
		prototype.teardown()
		prototype.teardown()
		_check("prototype teardown disconnects cadence signal", _is_connected(prototype_module, &"cadence_changed", prototype, "_on_cadence_changed"), false)
		_check("prototype teardown disconnects input signal", _is_connected(prototype_module, &"rhythm_input_observed", prototype, "_on_rhythm_input_observed"), false)
		_check("prototype teardown disconnects resolution signal", _is_connected(prototype_module, &"resolved", prototype, "_on_resolved"), false)
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

func _on_resolved(outcome: StringName) -> void:
	_resolved_outcome = outcome

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
