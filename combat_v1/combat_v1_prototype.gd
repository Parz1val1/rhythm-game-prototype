# combat_v1/combat_v1_prototype.gd
# Standalone presentation harness for the isolated CombatV1 module.
extends Node2D

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const DebugLog = preload("res://autoloads/debug_log.gd")
const OpponentData = preload("res://combat_v1/opponent_data.gd")
const PhraseEvent = preload("res://combat_v1/phrase_event.gd")
const CombatV1HUD = preload("res://combat_v1/combat_v1_hud.gd")

const PLAYTEST_TRACK_NAMES: Array[String] = [
	"Campfire Strings",
	"Stonebeat",
	"Starcurrent",
]
const PLAYTEST_TRACKS: Array[AudioStream] = [
	preload("res://audio/playtest_v1/campfire_strings.wav"),
	preload("res://audio/playtest_v1/stonebeat.wav"),
	preload("res://audio/playtest_v1/starcurrent.wav"),
]

@export_range(1, 8, 1) var settle_bars: int = 2
@export_range(0.25, 8.0, 0.25) var response_visual_lead_beats: float = 2.0
@export var opponent: OpponentData = preload("res://combat_v1/opponents/drum_golem.tres")
@export_range(0, 2, 1) var default_playtest_track: int = 0

@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var _hud: CombatV1HUD = $CombatV1HUD

var _combat_v1: CombatV1
var _resources_started: bool = false
var _selected_playtest_track_index: int = -1

## Player-facing backing-track choices available in the comparison harness.
func get_playtest_track_options() -> Array[String]:
	return PLAYTEST_TRACK_NAMES.duplicate()

func get_selected_playtest_track_name() -> String:
	if _selected_playtest_track_index < 0:
		return ""
	return PLAYTEST_TRACK_NAMES[_selected_playtest_track_index]

## Change backing tracks without restarting CombatV1 or its BeatClock timeline.
func select_playtest_track(index: int) -> bool:
	if index < 0 or index >= PLAYTEST_TRACKS.size():
		return false
	var was_playing := _audio.playing
	var playback_position := _audio.get_playback_position() if was_playing else 0.0
	_audio.stream = PLAYTEST_TRACKS[index]
	_configure_loop(_audio.stream)
	_selected_playtest_track_index = index
	if was_playing:
		var loop_length := _audio.stream.get_length()
		_audio.play(fmod(playback_position, loop_length) if loop_length > 0.0 else 0.0)
	_hud.show_playtest_track(index, get_selected_playtest_track_name(), PLAYTEST_TRACKS.size())
	DebugLog.audio("[AUDIO  ] playtest_track=%d  name=%s  position_s=%.3f" % [
		index + 1,
		get_selected_playtest_track_name(),
		playback_position,
	])
	return true

func _ready() -> void:
	BeatClock.bpm = 130.0
	BeatClock.intro_offset_ms = 1200.0
	select_playtest_track(default_playtest_track)
	_audio.play()
	DebugLog.audio("[AUDIO  ] v1=started  track=%s" % get_selected_playtest_track_name())
	BeatClock.start(_audio)
	DebugLog.timing("[TIMING ] v1_clock=started  bpm=%.1f  intro_offset_ms=%.1f" % [
		BeatClock.bpm, BeatClock.intro_offset_ms])
	_resources_started = true

	_combat_v1 = CombatV1.new()
	add_child(_combat_v1)
	_combat_v1.response_visual_lead_beats = response_visual_lead_beats
	_combat_v1.setup(BeatClock, RhythmInput, opponent, settle_bars)
	_combat_v1.phrase_event_announced.connect(_on_phrase_event_announced)
	_combat_v1.response_phrase_graded.connect(_on_response_phrase_graded)
	_combat_v1.start()
	# Bind after start() so the harness continuously exercises snapshot-first setup.
	_hud.setup(_combat_v1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_1:
				select_playtest_track(0)
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				select_playtest_track(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3:
				select_playtest_track(2)
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
		return

	if event.is_action_pressed(&"playtest_audio_previous"):
		select_playtest_track(wrapi(
			_selected_playtest_track_index - 1,
			0,
			PLAYTEST_TRACKS.size()
		))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"playtest_audio_next"):
		select_playtest_track(wrapi(
			_selected_playtest_track_index + 1,
			0,
			PLAYTEST_TRACKS.size()
		))
		get_viewport().set_input_as_handled()
		return
	if _combat_v1 == null:
		return
	var should_advance := event.is_action_pressed(&"playtest_advance")
	if event is InputEventKey:
		var key_event := event as InputEventKey
		should_advance = should_advance \
			or key_event.keycode == KEY_ENTER \
			or key_event.keycode == KEY_SPACE
	if not should_advance:
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

func _configure_loop(stream: AudioStream) -> void:
	if not stream is AudioStreamWAV:
		return
	var wave := stream as AudioStreamWAV
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_begin = 0
	wave.loop_end = int(round(wave.get_length() * wave.mix_rate))

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
