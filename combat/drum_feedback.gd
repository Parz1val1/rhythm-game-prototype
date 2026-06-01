# combat/drum_feedback.gd
# Audio feedback for Beatrice's two-button drum kit.
# Connects to RhythmInput.input_scored (drum_left / drum_right) and
# RhythmInput.input_chord (drum_both) to play the appropriate drum sound.
# Routes all sounds through the "Drums" AudioBus.
#
# Drum sound files (not included — add royalty-free samples to audio/sfx/):
#   audio/sfx/drum_left.ogg   — e.g. snare hit
#   audio/sfx/drum_right.ogg  — e.g. kick hit
#   audio/sfx/drum_both.ogg   — e.g. combined crash/accent hit
#
# AudioStreamPlayers with no stream assigned play silently until files are added.
extends Node

const DebugLog = preload("res://autoloads/debug_log.gd")

# One player per drum voice so simultaneous hits don't cut each other off.
var _left_player:  AudioStreamPlayer
var _right_player: AudioStreamPlayer
var _both_player:  AudioStreamPlayer

func _ready() -> void:
	_left_player  = _make_player("LeftPlayer",  "res://audio/sfx/drum_left.ogg")
	_right_player = _make_player("RightPlayer", "res://audio/sfx/drum_right.ogg")
	_both_player  = _make_player("BothPlayer",  "res://audio/sfx/drum_both.ogg")

## Wire to RhythmInput signals. Call once after the node enters the tree.
func setup() -> void:
	RhythmInput.input_scored.connect(_on_input_scored)
	RhythmInput.input_chord.connect(_on_input_chord)

func _exit_tree() -> void:
	if RhythmInput.input_scored.is_connected(_on_input_scored):
		RhythmInput.input_scored.disconnect(_on_input_scored)
	if RhythmInput.input_chord.is_connected(_on_input_chord):
		RhythmInput.input_chord.disconnect(_on_input_chord)

func _on_input_scored(direction: StringName, score: StringName, _offset: float, _consumed: bool) -> void:
	DebugLog.audio("[DRUM   ] dir=%-12s  score=%s" % [direction, score])
	match direction:
		&"drum_left":  _left_player.play()
		&"drum_right": _right_player.play()
		# drum_both is handled via input_chord; skip here to avoid double-play.

func _on_input_chord(chord_name: StringName, _score: StringName) -> void:
	if chord_name == &"drum_both":
		DebugLog.audio("[DRUM   ] chord=drum_both")
		_both_player.play()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_player(node_name: String, stream_path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus  = "Drums"
	# Load stream if the file exists; gracefully silent if not.
	if ResourceLoader.exists(stream_path):
		p.stream = load(stream_path)
	add_child(p)
	return p
