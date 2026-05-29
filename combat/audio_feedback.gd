# combat/audio_feedback.gd
# Plays instrument-appropriate SFX in response to rhythm input scoring.
# Pitch-shifts sounds based on the active character's SoloStyle scale steps.
# AudioStreamPlayers with no stream assigned play silently — add .ogg files
# to audio/sfx/ and assign them in the scene to enable audio feedback.
extends Node

const CharacterData = preload("res://characters/character_data.gd")

@onready var _perfect_player: AudioStreamPlayer = $PerfectPlayer
@onready var _good_player:    AudioStreamPlayer = $GoodPlayer
@onready var _miss_player:    AudioStreamPlayer = $MissPlayer

var _active_character: CharacterData = null

## Maps input direction to index in SoloStyle.scale_steps.
const DIRECTION_INDEX := {
	&"up": 0, &"right": 1, &"down": 2, &"left": 3,
}

## Call once after loading the player character.
func setup(character: CharacterData) -> void:
	_active_character = character
	RhythmInput.input_scored.connect(_on_input_scored)

func _exit_tree() -> void:
	if RhythmInput.input_scored.is_connected(_on_input_scored):
		RhythmInput.input_scored.disconnect(_on_input_scored)

func _on_input_scored(direction: StringName, score: StringName, _offset: float, _consumed: bool) -> void:
	var pitch: float = _get_pitch(direction)
	DebugLog.audio("[SFX    ] score=%-8s  dir=%-5s  pitch=%.2f" % [score, direction, pitch])
	match score:
		&"perfect":
			_perfect_player.pitch_scale = pitch
			_perfect_player.play()
		&"good":
			_good_player.pitch_scale = pitch
			_good_player.play()
		&"miss":
			_miss_player.pitch_scale = pitch
			_miss_player.play()

## Returns the pitch multiplier for a direction based on SoloStyle scale.
## Returns 1.0 when no SoloStyle is set (no pitch shifting).
## Formula: 2^(semitones/12) — standard equal-temperament MIDI pitch.
func _get_pitch(direction: StringName) -> float:
	if _active_character == null or _active_character.solo_style == null:
		return 1.0
	if not DIRECTION_INDEX.has(direction):
		return 1.0
	var style := _active_character.solo_style
	var idx: int = DIRECTION_INDEX[direction]
	if idx >= style.scale_steps.size():
		return 1.0
	var semitones: int = style.scale_steps[idx]
	return pow(2.0, float(semitones) / 12.0)
