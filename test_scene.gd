# test_scene.gd
# Prototype's main scene. Exercises the full rhythm combat stack.
# Run in Godot (F5) and press arrow keys on the beat.
extends Node2D

const CharacterData        = preload("res://characters/character_data.gd")
const EncounterManager     = preload("res://combat/encounter_manager.gd")
const EncounterDefinition  = preload("res://encounters/encounter_definition.gd")

## Set false to test ambush (enemies attack first).
@export var player_first: bool = true

## Drag an encounters/*.tres file here to select the default encounter.
## The ReplayUI dropdown overrides this on replay — set it to whatever you
## want to fight on a fresh F5.
@export var encounter: EncounterDefinition

## Holds the encounter chosen in the ReplayUI across reload_current_scene().
## Static variables persist on the GDScript class between scene reloads.
static var pending_encounter: EncounterDefinition = null

@onready var _audio:          AudioStreamPlayer = $AudioStreamPlayer
@onready var _combat_ui:      Node              = $CombatUI
@onready var _note_lane:      Node              = $NoteLane
@onready var _audio_feedback: Node              = $AudioFeedback
@onready var _replay_ui:      Node              = $ReplayUI

var _hero:   CharacterData
var _combat: Node

func _ready() -> void:
	# If a replay was requested, use the dropdown's selection instead of the
	# Inspector default. Clear immediately so a hard F5 always uses the export.
	if pending_encounter != null:
		encounter = pending_encounter
		pending_encounter = null

	# Load hero. Duplicate so runtime HP mutations don't pollute the cached asset.
	_hero = load("res://characters/luthier_frett.tres") as CharacterData
	if _hero == null:
		push_error("test_scene: luthier_frett.tres not found — using fallback hero")
		_hero                = CharacterData.new()
		_hero.character_name = "Hero"
		_hero.max_hp         = 100
		_hero.hp             = 100
		_hero.attack_power   = 12
	else:
		_hero = _hero.duplicate() as CharacterData

	_audio_feedback.setup(_hero)   # connect pitch-shifted SFX to RhythmInput

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

	_combat_ui.setup(_combat, _hero)
	_note_lane.setup(_combat)

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
