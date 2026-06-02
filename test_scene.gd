# test_scene.gd
# Prototype's main scene. Exercises the full rhythm combat stack.
# Arrow keys = Luthier (pitch-scored).  F/J = Beatrice (drum/rhythm-scored).
extends Node2D

const CharacterData         = preload("res://characters/character_data.gd")
const EncounterManager      = preload("res://combat/encounter_manager.gd")
const EncounterDefinition   = preload("res://encounters/encounter_definition.gd")
const CharacterInputProfile = preload("res://characters/character_input_profile.gd")
const DrumFeedbackScript    = preload("res://combat/drum_feedback.gd")
const DrumLaneScript        = preload("res://combat/drum_lane.gd")
const DrumPatternScript     = preload("res://combat/drum_pattern_display.gd")

# Profile lookup keyed by character resource path.
# Extend this dict when adding new characters.
const _PROFILE_MAP := {
	"res://characters/luthier_frett.tres":  "res://characters/luthier_profile.tres",
	"res://characters/beatrice_styx.tres":  "res://characters/beatrice_profile.tres",
}

## Set false to test ambush (enemies attack first).
@export var player_first: bool = true

## Optional profile override. If null, auto-selects from _PROFILE_MAP.
@export var active_profile: CharacterInputProfile = null

## Drag an encounters/*.tres file here to select the default encounter.
@export var encounter: EncounterDefinition

@export_group("Debug Logging")
@export var log_enabled:        bool = false
@export var log_beat_timing:    bool = false
@export var log_combat_events:  bool = false
@export var log_note_visuals:   bool = false
@export var log_audio_events:   bool = false
@export_group("")

## Survives reload_current_scene() — set by dropdown or carried from previous session.
static var pending_encounter: EncounterDefinition = null
static var pending_hero_path: String = ""

@onready var _audio:          AudioStreamPlayer = $AudioStreamPlayer
@onready var _combat_ui:      Node              = $CombatUI
@onready var _note_lane:      Node              = $NoteLane
@onready var _audio_feedback: Node              = $AudioFeedback
@onready var _replay_ui:      Node              = $ReplayUI

var _hero:              CharacterData
var _hero_path:         String = ""
var _combat:            Node
var _drum_feedback:     Node = null
var _drum_lane:         Node = null
var _drum_pattern:      Node = null
var _profile_label:     Label = null
var _char_select:       OptionButton = null
var _char_paths:        Array = []   # parallel to _char_select items

func _ready() -> void:
	DebugLog.enabled       = log_enabled
	DebugLog.beat_timing   = log_beat_timing
	DebugLog.combat_events = log_combat_events
	DebugLog.note_visuals  = log_note_visuals
	DebugLog.audio_events  = log_audio_events

	if pending_encounter != null:
		encounter = pending_encounter
		pending_encounter = null

	# Resolve hero path: dropdown selection → Inspector default (Luthier).
	_hero_path = pending_hero_path if pending_hero_path != "" \
		else "res://characters/luthier_frett.tres"
	pending_hero_path = ""

	_hero = load(_hero_path) as CharacterData
	if _hero == null:
		push_error("test_scene: %s not found — using fallback hero" % _hero_path)
		_hero                = CharacterData.new()
		_hero.character_name = "Hero"
		_hero.max_hp         = 100; _hero.hp = 100; _hero.attack_power = 12
	else:
		_hero = _hero.duplicate(true) as CharacterData

	_audio_feedback.setup(_hero)

	BeatClock.bpm             = 130.0
	BeatClock.intro_offset_ms = 1200.0
	_audio.play()
	BeatClock.start(_audio)

	if encounter == null:
		push_error("test_scene: no encounter assigned")
		return

	var party: Array[CharacterData] = [_hero]
	_combat = EncounterManager.start_combat_from_definition(get_tree(), party, encounter, player_first)
	_combat.combat_won.connect(_on_combat_won)
	_combat.combat_lost.connect(_on_combat_lost)

	# Resolve profile.
	var profile: CharacterInputProfile = active_profile
	if profile == null and _PROFILE_MAP.has(_hero_path):
		profile = load(_PROFILE_MAP[_hero_path]) as CharacterInputProfile
	if profile != null:
		_combat.set_active_profile(profile)

	_combat_ui.setup(_combat, _hero)

	_profile_label = Label.new()
	_profile_label.position = Vector2(8, 8)
	add_child(_profile_label)
	_update_profile_label(profile)

	var is_percussive := profile != null and profile.defense_pattern_type == &"percussive"

	# Drum feedback audio — Beatrice-specific path.
	if is_percussive:
		_drum_feedback = DrumFeedbackScript.new()
		add_child(_drum_feedback)
		_drum_feedback.setup()

	# Lane routing.
	if is_percussive:
		_note_lane.visible = false
		_drum_lane = DrumLaneScript.new()
		add_child(_drum_lane)
		_drum_lane.position = Vector2(326, 200)
		_drum_lane.setup(_combat)
	else:
		_note_lane.setup(_combat)

	# Drum pattern display — percussive path only.
	if is_percussive:
		_drum_pattern = DrumPatternScript.new()
		add_child(_drum_pattern)
		_drum_pattern.position = Vector2(8, 580)
		_drum_pattern.setup(_combat, _combat.player_phase_length)

	_replay_ui.set_active_encounter(encounter)
	_replay_ui.replay_requested.connect(_on_replay_requested)

	_setup_character_selector()

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
	pending_encounter = new_encounter
	# Capture current character selection so it survives the reload.
	if _char_select != null:
		var idx := _char_select.selected
		if idx >= 0 and idx < _char_paths.size():
			pending_hero_path = _char_paths[idx]
	get_tree().reload_current_scene()

func _update_profile_label(profile: CharacterInputProfile) -> void:
	if _profile_label == null:
		return
	if profile == null:
		_profile_label.text = "Profile: default (4-direction)"
	else:
		_profile_label.text = "Profile: %s | eval=%s | def=%s" % [
			_hero.character_name if _hero else "?",
			profile.attack_evaluator,
			profile.defense_pattern_type,
		]

# ---------------------------------------------------------------------------
# Character selector dropdown
# ---------------------------------------------------------------------------

func _setup_character_selector() -> void:
	_char_select = OptionButton.new()
	_char_select.position = Vector2(8, 30)
	_char_select.custom_minimum_size = Vector2(220, 0)
	add_child(_char_select)

	_char_paths.clear()
	_char_select.clear()

	var dir := DirAccess.open("res://characters/")
	if dir == null:
		push_warning("test_scene: could not open res://characters/")
		return

	var entries: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path := "res://characters/" + fname
			var res := load(path)
			# Keep only CharacterData resources (has character_name field).
			if res != null and res.get_script() != null and res.has_method("get") \
					and res.get("character_name") != null:
				entries.append({"path": path, "name": res.character_name})
		fname = dir.get_next()
	dir.list_dir_end()

	# Alphabetical by character name for stable ordering.
	entries.sort_custom(func(a, b): return a["name"] < b["name"])

	for entry in entries:
		_char_select.add_item(entry["name"])
		_char_paths.append(entry["path"])

	# Pre-select the currently active character.
	for i in _char_paths.size():
		if _char_paths[i] == _hero_path:
			_char_select.select(i)
			break

	_char_select.item_selected.connect(_on_character_selected)

func _on_character_selected(idx: int) -> void:
	if idx < 0 or idx >= _char_paths.size():
		return
	# Store choice and reload so all systems reinitialise cleanly.
	pending_hero_path = _char_paths[idx]
	# Preserve the active encounter across the reload.
	pending_encounter = encounter
	get_tree().reload_current_scene()
