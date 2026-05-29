# autoloads/debug_log.gd
# Centralised debug logging for all gameplay systems.
# Registered as autoload "DebugLog" in project.godot (loaded before BeatClock/RhythmInput).
#
# USAGE
#   DebugLog.timing("...")   — beat events, note injection, press offsets
#   DebugLog.combat("...")   — phase transitions, damage, HP changes, win/loss
#   DebugLog.visual("...")   — note visual spawning, hit-zone flashes
#   DebugLog.audio("...")    — audio feedback cues
#
# TO ENABLE AT RUNTIME
#   1. Run the scene, open Remote tab in Godot's Scene panel.
#   2. Click the DebugLog node → toggle flags in the Inspector.
#   OR call in code before combat starts:
#      DebugLog.enabled = true
#      DebugLog.combat_events = true
#
# LOG FORMAT CONVENTION
#   [TAG   ] key=value  key=value  ...
#   Tags are left-padded to 7 chars so columns stay aligned in the Output panel.
#   Each log line should include the values that matter at that event boundary
#   (direction, beat number, HP before/after, offset ms, etc.).
extends Node

## Master switch. All category flags are ignored while this is false.
@export var enabled: bool = false

@export_group("Categories")
## Beat events, note pre-injection timing, press offsets, note expiry.
@export var beat_timing:   bool = false
## Phase transitions, damage dealt, HP changes, win/loss, limit break.
@export var combat_events: bool = false
## Note visual spawning, tween travel, hit-zone flashes.
@export var note_visuals:  bool = false
## Audio feedback sound events (score, pitch scale).
@export var audio_events:  bool = false

# ---------------------------------------------------------------------------
# Category write methods — one per category for concise call sites.
# ---------------------------------------------------------------------------

func timing(msg: String) -> void:
    if enabled and beat_timing:
        print(msg)

func combat(msg: String) -> void:
    if enabled and combat_events:
        print(msg)

func visual(msg: String) -> void:
    if enabled and note_visuals:
        print(msg)

func audio(msg: String) -> void:
    if enabled and audio_events:
        print(msg)

## Convenience: enable every category at once.
## Call DebugLog.enable_all() before starting a combat to get a full trace.
func enable_all() -> void:
    enabled       = true
    beat_timing   = true
    combat_events = true
    note_visuals  = true
    audio_events  = true
