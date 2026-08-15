# test/test_combat_v1_phrase_playback.gd
# Verifies authored phrase playback through the public CombatV1 interface.
extends SceneTree

const PhraseEvent = preload("res://combat_v1/phrase_event.gd")

var _announced_offsets: Array[float] = []
var _audio_event_sequence: Array[String] = []
var _visual_event_sequence: Array[String] = []
var _observed_inputs: int = 0
var _raw_scored_inputs: int = 0
var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 phrase-playback tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var module = CombatV1Script.new()
	root.add_child(module)
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	_check("phrase event signal exists", module.has_signal(&"phrase_event_announced"), true)
	if beat_clock == null or rhythm_input == null or opponent == null:
		_check("playback dependencies load", false, true)
		module.queue_free()
		print("=== done ===")
		return

	if module.has_signal(&"phrase_event_announced"):
		Signal(module, &"phrase_event_announced").connect(_on_phrase_event_announced)
		Signal(module, &"phrase_event_announced").connect(_on_audio_phrase_event)
		Signal(module, &"phrase_event_announced").connect(_on_visual_phrase_event)
	module.rhythm_input_observed.connect(_on_rhythm_input_observed)
	rhythm_input.input_scored.connect(_on_raw_input_scored)
	module.setup(beat_clock, rhythm_input, opponent, 2)
	_check("start enters configured Settle", module.start(), true)
	_check("state reports two Settle bars", module.get_state()[&"settle_bars"], 2)
	_check("state reports the authored phrase", module.get_state()[&"phrase_id"], &"opening_call")

	for beat_number in range(1, 8):
		beat_clock.beat.emit(beat_number)
	_check("Settle remains input-free for seven beats", module.get_cadence(), CombatV1Script.Cadence.SETTLE)
	_check("Settle announces no phrase events", _announced_offsets, [])
	rhythm_input._unhandled_input(_action(&"rhythm_up"))
	_check("Settle input is not scored by RhythmInput", _raw_scored_inputs, 0)

	beat_clock.beat.emit(8)
	_check("eighth beat enters Enemy Phrase", module.get_cadence(), CombatV1Script.Cadence.ENEMY_PHRASE)
	_check("phrase announces its downbeat event", _announced_offsets, [0.0])
	var listening_state: Dictionary = module.get_state().duplicate(true)
	rhythm_input._unhandled_input(_action(&"rhythm_up"))
	_check("Enemy Phrase input does not change encounter or cadence state", module.get_state(), listening_state)
	_check("Enemy Phrase input is not scored by RhythmInput", _raw_scored_inputs, 0)
	_check("Enemy Phrase input is not exposed as scored V1 input", _observed_inputs, 0)

	# The explicit subdivision must win even while the public clock property still
	# reflects its pre-emission value, matching BeatClock's real callback ordering.
	beat_clock.beat_position = 0.0
	beat_clock.quarter_beat.emit(8, 0.75)
	beat_clock.beat.emit(9)
	beat_clock.beat_position = 0.5
	beat_clock.half_beat.emit(9)
	beat_clock.beat.emit(10)
	beat_clock.beat_position = 0.5
	beat_clock.half_beat.emit(10)
	beat_clock.beat.emit(11)
	_check(
		"headless beat simulation reproduces every authored offset",
		_announced_offsets,
		[0.0, 0.75, 1.5, 2.5, 3.0]
	)
	_check("one handoff keeps audio and visual event sequences in parity", _audio_event_sequence, _visual_event_sequence)
	_check("every event reaches both presentation consumers", _audio_event_sequence.size(), 5)
	_check("phrase remains active through its last authored beat", module.get_cadence(), CombatV1Script.Cadence.ENEMY_PHRASE)

	beat_clock.beat.emit(12)
	_check("authored one-bar phrase transitions to Response", module.get_cadence(), CombatV1Script.Cadence.RESPONSE)
	_check("Response handoff remains input-free", rhythm_input.is_scoring_enabled(), false)
	beat_clock.beat_position = 0.0
	for beat_number in range(13, 17):
		beat_clock.beat.emit(beat_number)
	_check("Response restores the prior scoring state after its handoff", rhythm_input.is_scoring_enabled(), true)
	module.teardown()
	if rhythm_input.input_scored.is_connected(_on_raw_input_scored):
		rhythm_input.input_scored.disconnect(_on_raw_input_scored)
	module.queue_free()
	print("=== done ===")

func _on_phrase_event_announced(event: PhraseEvent) -> void:
	_announced_offsets.append(event.beat_offset)

func _on_audio_phrase_event(event: PhraseEvent) -> void:
	_audio_event_sequence.append("%s@%.2f" % [event.prompt_id, event.beat_offset])

func _on_visual_phrase_event(event: PhraseEvent) -> void:
	_visual_event_sequence.append("%s@%.2f" % [event.prompt_id, event.beat_offset])

func _on_rhythm_input_observed(_direction: StringName, _score: StringName, _offset_ms: float) -> void:
	_observed_inputs += 1

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
