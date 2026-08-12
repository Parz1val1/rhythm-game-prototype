# combat_v1/combat_v1_prototype.gd
# Standalone presentation harness for the isolated CombatV1 module.
extends Node2D

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")
const OpponentData = preload("res://combat_v1/opponent_data.gd")
const PhraseEvent = preload("res://combat_v1/phrase_event.gd")

@export_range(1, 8, 1) var settle_bars: int = 2
@export var opponent: OpponentData = preload("res://combat_v1/opponents/drum_golem.tres")

@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var _cadence_label: Label = $CadenceLabel
@onready var _detail_label: Label = $DetailLabel
@onready var _hint_label: Label = $HintLabel

var _combat_v1: CombatV1
var _resources_started: bool = false

func _ready() -> void:
	BeatClock.bpm = 130.0
	BeatClock.intro_offset_ms = 1200.0
	_audio.play()
	DebugLog.audio("[AUDIO  ] v1=started")
	BeatClock.start(_audio)
	DebugLog.timing("[TIMING ] v1_clock=started  bpm=%.1f  intro_offset_ms=%.1f" % [
		BeatClock.bpm, BeatClock.intro_offset_ms])
	_resources_started = true

	_combat_v1 = CombatV1.new()
	add_child(_combat_v1)
	_combat_v1.setup(BeatClock, RhythmInput, opponent, settle_bars)
	_combat_v1.cadence_changed.connect(_on_cadence_changed)
	_combat_v1.phrase_event_announced.connect(_on_phrase_event_announced)
	_combat_v1.response_target_announced.connect(_on_response_target_announced)
	_combat_v1.response_note_graded.connect(_on_response_note_graded)
	_combat_v1.response_phrase_graded.connect(_on_response_phrase_graded)
	_combat_v1.rhythm_input_observed.connect(_on_rhythm_input_observed)
	_combat_v1.resolved.connect(_on_resolved)
	_combat_v1.start()
	_update_view(_combat_v1.get_state())

func _unhandled_input(event: InputEvent) -> void:
	if _combat_v1 == null or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ENTER and key_event.keycode != KEY_SPACE:
		return

	match _combat_v1.get_cadence():
		CombatV1.Cadence.RESPONSE:
			_combat_v1.player_intent(CombatV1.Intent.SUBMIT_RESPONSE)
		CombatV1.Cadence.TACTICAL_VAMP:
			_combat_v1.player_intent(CombatV1.Intent.CONTINUE_ROUND)
		_:
			pass

func _on_cadence_changed(_cadence: int) -> void:
	_update_view(_combat_v1.get_state())

func _on_phrase_event_announced(event: PhraseEvent) -> void:
	_detail_label.text = "%s at beat %.2f" % [event.prompt_text, event.beat_offset]
	DebugLog.visual("[PROMPT ] cue=%s  prompt=%s  offset=%.2f" % [
		event.visual_cue, event.prompt_id, event.beat_offset])
	DebugLog.audio("[PHRASE ] cue=%s  prompt=%s  offset=%.2f" % [
		event.audio_cue, event.prompt_id, event.beat_offset])

func _on_response_target_announced(event: PhraseEvent, expected_action: StringName) -> void:
	_detail_label.text = "Respond with %s at beat %.2f" % [expected_action, event.beat_offset]
	DebugLog.visual("[TARGET ] action=%s  offset=%.2f  source=%s" % [
		expected_action, event.beat_offset, event.prompt_id])

func _on_response_note_graded(result: Dictionary) -> void:
	_detail_label.text = "Response note: %s (%+.1f ms)" % [
		result[&"grade_name"], result[&"offset_ms"]]

func _on_response_phrase_graded(summary: Dictionary) -> void:
	_detail_label.text = "Response phrase: %s" % summary[&"grade_name"]
	DebugLog.combat("[SUMMARY] grade=%s  average=%.2f  broken=%s" % [
		summary[&"grade_name"], summary[&"average_score"], summary[&"broken"]])

func _on_rhythm_input_observed(direction: StringName, score: StringName, offset_ms: float) -> void:
	if _combat_v1.get_cadence() == CombatV1.Cadence.RESPONSE:
		return
	_detail_label.text = "Last rhythm input: %s / %s (%+.1f ms)" % [direction, score, offset_ms]

func _on_resolved(_outcome: CombatV1.Outcome) -> void:
	_detail_label.text = "Conversation resolved: %s" % _combat_v1.get_state()[&"outcome_name"]
	_hint_label.text = "V1 harness complete — reload the scene to run it again."

func _update_view(state: Dictionary) -> void:
	_cadence_label.text = "Cadence: %s" % state[&"cadence_name"]
	_detail_label.text = "Beat count: %d" % state[&"beat_count"]
	if state[&"cadence"] == CombatV1.Cadence.RESOLUTION:
		_hint_label.text = "Conversation resolved."
	elif state[&"cadence"] == CombatV1.Cadence.RESPONSE:
		_hint_label.text = "Play the four-direction targets, then press Enter or Space to submit."
	elif state[&"cadence"] == CombatV1.Cadence.TACTICAL_VAMP:
		_hint_label.text = "Tactical Vamp: listen freely, then press Enter or Space to continue on the next beat."
	else:
		_hint_label.text = "Listen — the next cadence advances on the BeatClock."

## Stop the harness and disconnect every local module signal. Safe to repeat.
func teardown() -> void:
	if _combat_v1 != null:
		if _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
			_combat_v1.cadence_changed.disconnect(_on_cadence_changed)
		if _combat_v1.phrase_event_announced.is_connected(_on_phrase_event_announced):
			_combat_v1.phrase_event_announced.disconnect(_on_phrase_event_announced)
		if _combat_v1.response_target_announced.is_connected(_on_response_target_announced):
			_combat_v1.response_target_announced.disconnect(_on_response_target_announced)
		if _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
			_combat_v1.response_note_graded.disconnect(_on_response_note_graded)
		if _combat_v1.response_phrase_graded.is_connected(_on_response_phrase_graded):
			_combat_v1.response_phrase_graded.disconnect(_on_response_phrase_graded)
		if _combat_v1.rhythm_input_observed.is_connected(_on_rhythm_input_observed):
			_combat_v1.rhythm_input_observed.disconnect(_on_rhythm_input_observed)
		if _combat_v1.resolved.is_connected(_on_resolved):
			_combat_v1.resolved.disconnect(_on_resolved)
		_combat_v1.teardown()
	if not _resources_started:
		return
	_resources_started = false
	BeatClock.stop()
	DebugLog.timing("[TIMING ] v1_clock=stopped")
	_audio.stop()
	DebugLog.audio("[AUDIO  ] v1=stopped")

func _exit_tree() -> void:
	teardown()
