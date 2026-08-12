# combat_v1/combat_v1_prototype.gd
# Standalone presentation harness for the isolated CombatV1 module.
extends Node2D

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")
const OpponentData = preload("res://combat_v1/opponent_data.gd")
const PhraseEvent = preload("res://combat_v1/phrase_event.gd")
const CombatV1HUD = preload("res://combat_v1/combat_v1_hud.gd")

@export_range(1, 8, 1) var settle_bars: int = 2
@export var opponent: OpponentData = preload("res://combat_v1/opponents/drum_golem.tres")

@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var _hud: CombatV1HUD = $CombatV1HUD

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
	_combat_v1.phrase_event_announced.connect(_on_phrase_event_announced)
	_combat_v1.response_phrase_graded.connect(_on_response_phrase_graded)
	_combat_v1.start()
	# Bind after start() so the harness continuously exercises snapshot-first setup.
	_hud.setup(_combat_v1)

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

func _on_phrase_event_announced(event: PhraseEvent) -> void:
	DebugLog.visual("[PROMPT ] cue=%s  prompt=%s  offset=%.2f" % [
		event.visual_cue, event.prompt_id, event.beat_offset])
	DebugLog.audio("[PHRASE ] cue=%s  prompt=%s  offset=%.2f" % [
		event.audio_cue, event.prompt_id, event.beat_offset])

func _on_response_phrase_graded(summary: Dictionary) -> void:
	DebugLog.combat("[SUMMARY] grade=%s  average=%.2f  broken=%s" % [
		summary[&"grade_name"], summary[&"average_score"], summary[&"broken"]])

## Stop the harness and disconnect every local module signal. Safe to repeat.
func teardown() -> void:
	_hud.teardown()
	if _combat_v1 != null:
		if _combat_v1.phrase_event_announced.is_connected(_on_phrase_event_announced):
			_combat_v1.phrase_event_announced.disconnect(_on_phrase_event_announced)
		if _combat_v1.response_phrase_graded.is_connected(_on_response_phrase_graded):
			_combat_v1.response_phrase_graded.disconnect(_on_response_phrase_graded)
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
