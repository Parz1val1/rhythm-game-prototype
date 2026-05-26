# test_scene.gd
# The prototype's main scene. Exercises the full rhythm combat stack:
# BeatClock → CombatScene ← RhythmInput
# Run in Godot (F5) and press arrow keys on the beat to see scoring.
extends Node2D

# Preload workarounds: class_name global scope may not be fully initialized
# when this script parses, so use preload constants for typed declarations.
const CharacterData    = preload("res://characters/character_data.gd")
const EnemyData        = preload("res://characters/enemy_data.gd")
const EncounterManager = preload("res://combat/encounter_manager.gd")

## Set to false to test ambush (enemies attack first).
@export var player_first: bool = true

## Change to &"orc_heavy" or &"goblin_pair" to test other encounters.
@export var encounter_id: StringName = &"goblin_single"

## BPM to use for this session. Set in the Inspector to match your song,
## then press Play — BeatClock picks it up before the first beat fires.
@export var bpm: float = 120.0

## Milliseconds before the first beat of your song.
## If the track has a silent or non-rhythmic intro, set this to how long
## (in ms) that intro lasts so the beat clock waits before counting.
@export var intro_offset_ms: float = 0.0

# Node references — @onready populates these after _ready() begins.
# The $ shorthand is equivalent to get_node("NodePath").
@onready var _audio:        AudioStreamPlayer = $AudioStreamPlayer
@onready var _bpm_label:    Label = $CanvasLayer/VBox/BPMLabel
@onready var _beat_label:   Label = $CanvasLayer/VBox/BeatLabel
@onready var _score_label:  Label = $CanvasLayer/VBox/ScoreLabel
@onready var _phase_label:  Label = $CanvasLayer/VBox/PhaseLabel
@onready var _enemy_label:  Label = $CanvasLayer/VBox/EnemyHPLabel
@onready var _player_label: Label = $CanvasLayer/VBox/PlayerHPLabel
@onready var _note_lane: Control = $CanvasLayer/NoteLane

var _hero:   CharacterData
var _combat: Node   # CombatScene instance

# Previous-frame HP values used to detect damage events for the red flash.
var _prev_player_hp: int = -1
var _prev_enemy_hp:  int = -1

func _ready() -> void:
	# Load Luthier Frett's stats from .tres resource.
	_hero = load("res://characters/luthier_frett.tres") as CharacterData
	if _hero == null:
		push_error("test_scene: Failed to load luthier_frett.tres — falling back to anonymous hero")
		_hero                = CharacterData.new()
		_hero.character_name = "Hero"
		_hero.max_hp         = 100
		_hero.hp             = 100
		_hero.attack_power   = 12
	else:
		_hero = _hero.duplicate() as CharacterData

	# Apply the exported BPM and intro offset before starting.
	BeatClock.bpm = bpm
	BeatClock.intro_offset_ms = intro_offset_ms

	# Start audio then anchor BeatClock to it.
	# If res://audio/placeholder_beat.ogg does not exist, audio_player.play()
	# silently fails and BeatClock falls back to wall-clock time automatically.
	_audio.play()
	BeatClock.start(_audio)

	# Build a typed array for start_combat (required by its Array[CharacterData] param).
	var party: Array[CharacterData] = [_hero]

	# Load the encounter. EncounterManager adds CombatScene as a child of this scene.
	_combat = EncounterManager.start_combat(get_tree(), party, encounter_id, player_first)
	_combat.combat_won.connect(_on_combat_won)
	_combat.combat_lost.connect(_on_combat_lost)

	# Connect beat flash and input display.
	BeatClock.beat.connect(_on_beat)
	RhythmInput.input_scored.connect(_on_input_scored)
	_note_lane.setup(_combat)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"limit_break"):
		_combat.try_activate_limit_break()

func _exit_tree() -> void:
	if BeatClock.beat.is_connected(_on_beat):
		BeatClock.beat.disconnect(_on_beat)
	if RhythmInput.input_scored.is_connected(_on_input_scored):
		RhythmInput.input_scored.disconnect(_on_input_scored)

func _process(_delta: float) -> void:
	# Keep BeatClock in sync if bpm or intro_offset_ms are tweaked live in the remote Inspector.
	BeatClock.bpm = bpm
	BeatClock.intro_offset_ms = intro_offset_ms
	_bpm_label.text  = "BPM: %.0f" % BeatClock.bpm
	_beat_label.text = "Beat: %d  (pos: %.2f)" % [BeatClock.beat_number, BeatClock.beat_position]

	# Phase label: yellow while attacking, blue while defending.
	var phase: StringName = _combat.get_phase_name()
	_phase_label.text = "Phase: %s" % phase
	_phase_label.modulate = Color.YELLOW if phase == &"ATTACK" else Color(0.4, 0.8, 1.0)

	# Player HP — flash red on damage.
	_player_label.text = "Player HP: %d / %d" % [_hero.hp, _hero.max_hp]
	if _prev_player_hp != -1 and _hero.hp < _prev_player_hp:
		_flash_red(_player_label)
	_prev_player_hp = _hero.hp

	# Enemy HP — flash red on damage.
	var target: EnemyData = _combat.get_attack_target()
	var current_enemy_hp: int = target.hp if target != null else -1
	if target != null:
		_enemy_label.text = "Enemy: %s  HP: %d / %d" % [target.enemy_name, target.hp, target.max_hp]
		if _prev_enemy_hp != -1 and current_enemy_hp < _prev_enemy_hp:
			_flash_red(_enemy_label)
	else:
		_enemy_label.text = "Enemy: none"
	_prev_enemy_hp = current_enemy_hp

func _on_beat(_beat_number: int) -> void:
	# Visual pulse: flash the beat label yellow for 0.1 seconds.
	_beat_label.modulate = Color.YELLOW
	# create_timer() is a one-shot timer that auto-frees — no Timer node needed.
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	_beat_label.modulate = Color.WHITE

func _flash_red(label: Label) -> void:
	label.modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self):
		return
	label.modulate = Color.WHITE

func _on_input_scored(direction: StringName, score: StringName, offset_ms: float, _note_consumed: bool) -> void:
	_score_label.text = "Last: %-5s  %-7s  (%+.1f ms)" % [direction, score, offset_ms]

func _on_combat_won() -> void:
	# Flush final HP values before set_process(false) freezes the labels.
	_player_label.text = "Player HP: %d / %d" % [_hero.hp, _hero.max_hp]
	_enemy_label.text  = "Enemy: none"
	_score_label.text  = "*** VICTORY! ***"
	BeatClock.stop()
	_audio.stop()
	set_process(false)

func _on_combat_lost() -> void:
	# Flush final HP values before set_process(false) freezes the labels.
	_player_label.text = "Player HP: %d / %d" % [_hero.hp, _hero.max_hp]
	var target: EnemyData = _combat.get_attack_target()
	if target != null:
		_enemy_label.text = "Enemy: %s  HP: %d / %d" % [target.enemy_name, target.hp, target.max_hp]
	_score_label.text = "*** DEFEAT! ***"
	BeatClock.stop()
	_audio.stop()
	set_process(false)
