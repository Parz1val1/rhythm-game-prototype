# autoloads/beat_clock.gd
# Registered as autoload "BeatClock" in project.godot.
# This node is added to the scene tree automatically before any other scene loads.
# Access it from any script as: BeatClock.bpm, BeatClock.beat, etc.
extends Node

# --- Signals ---
# In Godot, signals are the idiomatic way to notify other systems of events
# without creating hard dependencies. Connect to these from CombatScene or UI.

## Fires once per beat. beat_number increments from 0 at start().
signal beat(beat_number: int)
## Fires at the midpoint of each beat (beat_position == 0.5).
signal half_beat(beat_number: int)
## Fires at beat_position 0.25 and 0.75.
signal quarter_beat(beat_number: int)

# --- Public state ---

## Beats per minute. Change at runtime to affect tempo immediately.
@export var bpm: float = 120.0

## Current beat index since start() was called. Increments on each beat signal.
var beat_number: int = 0

## Fractional position within the current beat: 0.0 (on the beat) → 1.0 (next beat).
var beat_position: float = 0.0

# --- Private state ---

var _stream_player: AudioStreamPlayer = null
var _running: bool = false
var _prev_beat_position: float = 0.0
var _seconds_per_beat: float = 60.0 / bpm  # kept in sync with bpm in _process()
var _start_ticks_ms: int = 0          # fallback origin when no audio stream

# --- Public API ---

## Anchor BeatClock to an AudioStreamPlayer and begin emitting beat signals.
## Call this after audio_player.play() in your scene's _ready().
## stream_player may have no stream set; BeatClock will fall back to wall-clock time
## (less accurate but still functional for prototyping without audio files).
func start(stream_player: AudioStreamPlayer) -> void:
    _stream_player = stream_player
    _seconds_per_beat = 60.0 / bpm
    _running = true
    beat_number = 0
    beat_position = 0.0
    _prev_beat_position = 0.0
    _start_ticks_ms = Time.get_ticks_msec()

## Stop emitting beat signals. Call on combat end or scene transition.
func stop() -> void:
    _running = false
    _stream_player = null

## Returns how far (in milliseconds) the current moment is from the nearest beat.
## Negative  = player pressed early (before the beat).
## Positive  = player pressed late (after the beat).
## Zero      = perfect timing.
## Used by RhythmInput on every keypress to produce a timing score.
func get_offset_ms() -> float:
    if not _running:
        return 0.0
    # beat_position <= 0.5: we're closer to the current beat (positive = late)
    # beat_position >  0.5: we're closer to the next beat (negative = early)
    if beat_position <= 0.5:
        return beat_position * _seconds_per_beat * 1000.0
    else:
        return (beat_position - 1.0) * _seconds_per_beat * 1000.0

# --- Internal ---

func _process(_delta: float) -> void:
    if not _running:
        return

    # --- Why AudioServer timing? ---
    # Godot's audio subsystem runs on its own thread with a hardware output buffer.
    # The player hears audio 50–120ms AFTER the engine schedules it.
    # AudioServer.get_time_since_last_mix() gives the time since the audio thread
    # last mixed a buffer. AudioServer.get_output_latency() gives the hardware delay.
    # Together with get_playback_position() they yield the stream's true perceived
    # position — what the player actually hears right now — not what the engine
    # computed some frames ago. Without this correction, beat_position would be
    # systematically ahead of the audio, making "on the beat" presses score as early.

    var audio_time: float
    if _stream_player != null and _stream_player.playing:
        # Audio-corrected perceived playback position:
        audio_time = (
            _stream_player.get_playback_position()
            + AudioServer.get_time_since_last_mix()
            - AudioServer.get_output_latency()
        )
    else:
        # Fallback: wall-clock time since start() (no audio sync, but functional).
        audio_time = float(Time.get_ticks_msec() - _start_ticks_ms) / 1000.0

    # Guard: on the first frames get_output_latency() can exceed get_playback_position()
    # + get_time_since_last_mix(), producing a negative value. Clamp so that
    # total_beats and beat_position stay in their expected non-negative ranges.
    audio_time = max(0.0, audio_time)

    _seconds_per_beat = 60.0 / bpm  # support live BPM changes
    var total_beats: float = audio_time / _seconds_per_beat
    var new_beat_number: int = int(total_beats)
    var new_beat_position: float = fmod(total_beats, 1.0)

    # Beat/sub-beat detection.
    # The two branches are mutually exclusive to prevent double-emission:
    # on boundary frames the guard block fires for the old beat's tail, then
    # beat_number advances — the regular crossing checks are skipped entirely.
    # On non-boundary frames only the regular crossing checks run.
    var boundary_crossed: bool = new_beat_number > beat_number

    if boundary_crossed:
        # Before beat_position wraps to near 0.0, emit any sub-beat thresholds
        # that were in the tail of the previous beat and would otherwise be skipped.
        # The 0.25 threshold cannot be missed on a wrap frame: if
        # _prev_beat_position < 0.25 we never crossed 0.25 in the old beat, and
        # the new beat's 0.25 will be detected normally in a future frame.
        if _prev_beat_position < 0.5:
            half_beat.emit(beat_number)      # beat_number is still the OLD value here
        if _prev_beat_position < 0.75:
            quarter_beat.emit(beat_number)
        # Advance beat_number for each missed boundary (handles lag-spike multi-beat skips).
        while beat_number < new_beat_number:
            beat_number += 1
            beat.emit(beat_number)
    else:
        # No beat boundary this frame — check sub-beat thresholds normally.
        # Half-beat crossing (position crosses 0.5 within the same beat).
        if _prev_beat_position < 0.5 and new_beat_position >= 0.5:
            half_beat.emit(beat_number)
        # Quarter-beat crossings (0.25 and 0.75).
        if _prev_beat_position < 0.25 and new_beat_position >= 0.25:
            quarter_beat.emit(beat_number)
        if _prev_beat_position < 0.75 and new_beat_position >= 0.75:
            quarter_beat.emit(beat_number)

    _prev_beat_position = new_beat_position
    beat_position = new_beat_position
