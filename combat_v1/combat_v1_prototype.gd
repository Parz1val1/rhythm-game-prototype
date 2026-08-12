# combat_v1/combat_v1_prototype.gd
# Standalone presentation harness for the isolated CombatV1 module.
extends Node2D

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")

@export var settle_beats: int = 2
@export var enemy_phrase_beats: int = 4

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
	_combat_v1.setup(BeatClock, RhythmInput, settle_beats, enemy_phrase_beats)
	_combat_v1.cadence_changed.connect(_on_cadence_changed)
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
			_combat_v1.player_intent(CombatV1.Intent.SELECT_PERFORMANCE)
		CombatV1.Cadence.CHARACTER_PERFORMANCE:
			_combat_v1.player_intent(CombatV1.Intent.COMPLETE_PERFORMANCE)
		CombatV1.Cadence.FULL_BAND_VAMP:
			_combat_v1.resolve(&"complete")
		_:
			pass

func _on_cadence_changed(_cadence: int) -> void:
	_update_view(_combat_v1.get_state())

func _on_rhythm_input_observed(direction: StringName, score: StringName, offset_ms: float) -> void:
	_detail_label.text = "Last rhythm input: %s / %s (%+.1f ms)" % [direction, score, offset_ms]

func _on_resolved(outcome: StringName) -> void:
	_detail_label.text = "Conversation resolved: %s" % outcome
	_hint_label.text = "V1 harness complete — reload the scene to run it again."

func _update_view(state: Dictionary) -> void:
	_cadence_label.text = "Cadence: %s" % state[&"cadence_name"]
	_detail_label.text = "Beat count: %d" % state[&"beat_count"]
	if state[&"cadence"] == CombatV1.Cadence.RESOLUTION:
		_hint_label.text = "Conversation resolved."
	elif state[&"cadence"] == CombatV1.Cadence.RESPONSE:
		_hint_label.text = "Press Enter or Space to submit the response."
	elif state[&"cadence"] == CombatV1.Cadence.TACTICAL_VAMP:
		_hint_label.text = "Tactical Vamp: press Enter or Space to choose a performance."
	elif state[&"cadence"] == CombatV1.Cadence.CHARACTER_PERFORMANCE:
		_hint_label.text = "Placeholder performance: press Enter or Space when complete."
	elif state[&"cadence"] == CombatV1.Cadence.FULL_BAND_VAMP:
		_hint_label.text = "Full-Band Vamp: press Enter or Space to resolve."
	else:
		_hint_label.text = "Listen — the next cadence advances on the BeatClock."

## Stop the harness and disconnect every local module signal. Safe to repeat.
func teardown() -> void:
	if _combat_v1 != null:
		if _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
			_combat_v1.cadence_changed.disconnect(_on_cadence_changed)
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
