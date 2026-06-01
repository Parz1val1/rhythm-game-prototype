# test_scene.gd
# Prototype's main scene. Exercises the full rhythm combat stack.
# Run in Godot (F5) and press arrow keys on the beat, or F/J for Beatrice drums.
extends Node2D

const CharacterData         = preload("res://characters/character_data.gd")
const EncounterManager      = preload("res://combat/encounter_manager.gd")
const EncounterDefinition   = preload("res://encounters/encounter_definition.gd")
const CharacterInputProfile = preload("res://characters/character_input_profile.gd")
const DrumFeedbackScript    = preload("res://combat/drum_feedback.gd")
const DrumLaneScript        = preload("res://combat/drum_lane.gd")
const DrumPatternScript     = preload("res://combat/drum_pattern_display.gd")

## Set false to test ambush (enemies attack first).
@export var player_first: bool = true

## When true, loads Beatrice Styx and applies her percussive profile.
## When false, loads Luthier Frett with the default 4-direction profile.
@export var use_beatrice: bool = true

## Optional profile override. If null, auto-selects based on use_beatrice.
@export var active_profile: CharacterInputProfile = null

## Drag an encounters/*.tres file here to select the default encounter.
## The ReplayUI dropdown overrides this on replay — set it to whatever you
## want to fight on a fresh F5.
@export var encounter: EncounterDefinition

@export_group("Debug Logging")
## Master switch — all categories are silent while this is off.
@export var log_enabled:        bool = false
## Beat events, note pre-injection timing, press offsets, note expiry.
@export var log_beat_timing:    bool = false
## Phase transitions, damage dealt, HP changes, win/loss, limit break.
@export var log_combat_events:  bool = false
## Note visual spawning, hit-zone flashes.
@export var log_note_visuals:   bool = false
## Audio feedback cues (score, pitch).
@export var log_audio_events:   bool = false
@export_group("")

## Holds the encounter chosen in the ReplayUI across reload_current_scene().
## Static variables persist on the GDScript class between scene reloads.
static var pending_encounter: EncounterDefinition = null

@onready var _audio:          AudioStreamPlayer = $AudioStreamPlayer
@onready var _combat_ui:      Node              = $CombatUI
@onready var _note_lane:      Node              = $NoteLane
@onready var _audio_feedback: Node              = $AudioFeedback
@onready var _replay_ui:      Node              = $ReplayUI

var _hero:          CharacterData
var _combat:        Node
# Dynamically created nodes for Beatrice-specific UI and audio.
var _drum_feedback: Node = null
var _drum_lane:     Node = null
var _drum_pattern:  Node = null
var _profile_label: Label = null

func _ready() -> void:
	# Apply debug logging toggles from the Inspector (Debug Logging group).
	# Values are saved in test_scene.tscn so they persist between editor sessions.
	DebugLog.enabled       = log_enabled
	DebugLog.beat_timing   = log_beat_timing
	DebugLog.combat_events = log_combat_events
	DebugLog.note_visuals  = log_note_visuals
	DebugLog.audio_events  = log_audio_events

	# If a replay was requested, use the dropdown's selection instead of the
	# Inspector default. Clear immediately so a hard F5 always uses the export.
	if pending_encounter != null:
		encounter = pending_encounter
		pending_encounter = null

	# Load hero. Duplicate so runtime HP mutations don't pollute the cached asset.
	var hero_path := "res://characters/beatrice_styx.tres" if use_beatrice else "res://characters/luthier_frett.tres"
	_hero = load(hero_path) as CharacterData
	if _hero == null:
		push_error("test_scene: %s not found — using fallback hero" % hero_path)
		_hero                = CharacterData.new()
		_hero.character_name = "Hero"
		_hero.max_hp         = 100; _hero.hp = 100; _hero.attack_power = 12
	else:
		_hero = _hero.duplicate(true) as CharacterData

	# Pitch-shifted SFX for Luthier (no-op for drum directions).
	_audio_feedback.setup(_hero)

	# Beatrice: add drum audio feedback (separate from pitch-shifted SFX).
	if use_beatrice:
		_drum_feedback = DrumFeedbackScript.new()
		add_child(_drum_feedback)
		_drum_feedback.setup()

	BeatClock.bpm             = 130.0
	BeatClock.intro_offset_ms = 1200.0
	_audio.play()
	BeatClock.start(_audio)

	if encounter == null:
		push_error("test_scene: no encounter assigned — drag an encounters/*.tres file into the Encounter field in the Inspector")
		return

	var party: Array[CharacterData] = [_hero]
	_combat = EncounterManager.start_combat_from_definition(get_tree(), party, encounter, player_first)
	_combat.combat_won.connect(_on_combat_won)
	_combat.combat_lost.connect(_on_combat_lost)

	# Resolve profile: explicit override → auto by character → default (nil = Luthier).
	var profile: CharacterInputProfile = active_profile
	if profile == null and use_beatrice:
		profile = load("res://characters/beatrice_profile.tres") as CharacterInputProfile
	if profile != null:
		_combat.set_active_profile(profile)

	_combat_ui.setup(_combat, _hero)

	# Profile display label (top-left corner of the scene).
	_profile_label = Label.new()
	_profile_label.position = Vector2(8, 8)
	add_child(_profile_label)
	_update_profile_label(profile)

	# Always set up NoteLane — it shows only when it receives a note_approaching for a
	# direction it handles (up/down/left/right). This ensures directional-note enemies
	# are visible even when Beatrice's percussive profile is active.
	# For percussive profiles, also create DrumLane for drum-direction enemies.
	# Both lanes coexist; each silently ignores directions the other handles.
	var is_percussive := profile != null and profile.defense_pattern_type == &"percussive"
	_note_lane.setup(_combat)
	if is_percussive:
		_drum_lane = DrumLaneScript.new()
		add_child(_drum_lane)
		_drum_lane.position = Vector2(326, 200)
		_drum_lane.setup(_combat)

	# Drum pattern display (attack readout) — shown only for Beatrice.
	if use_beatrice:
		_drum_pattern = DrumPatternScript.new()
		add_child(_drum_pattern)
		_drum_pattern.position = Vector2(8, 580)
		_drum_pattern.setup(_combat, _combat.player_phase_length)

	# Pre-select the active encounter in the replay dropdown.
	_replay_ui.set_active_encounter(encounter)
	_replay_ui.replay_requested.connect(_on_replay_requested)

func _unhandled_input(event: InputEvent) -> void:
	if _combat == null:
		return
	if event.is_action_pressed(&"limit_break"):
		_combat.try_activate_limit_break()

func _on_combat_won() -> void:
	BeatClock.stop()
	_audio.stop()
	_replay_ui.show_outcome(true)

func _on_combat_lost() -> void:
	BeatClock.stop()
	_audio.stop()
	_replay_ui.show_outcome(false)

func _on_replay_requested(new_encounter: EncounterDefinition) -> void:
	# Store selection so _ready() can pick it up after the scene reloads.
	pending_encounter = new_encounter
	get_tree().reload_current_scene()

func _update_profile_label(profile: CharacterInputProfile) -> void:
	if _profile_label == null:
		return
	if profile == null:
		_profile_label.text = "Profile: default (Luthier — 4-direction)"
	else:
		_profile_label.text = "Profile: %s | eval=%s | def=%s" % [
			_hero.character_name if _hero else "?",
			profile.attack_evaluator,
			profile.defense_pattern_type,
		]
