# autoloads/debug_log.gd
# Centralised debug logging for all gameplay systems.
#
# Uses class_name + static vars/methods rather than an autoload node.
# Autoload nodes aren't recognised in GDScript's parse-time scope in Godot 4.6,
# which causes "Identifier not declared" parse errors. class_name is resolved at
# parse time for regular scripts; autoload scripts (beat_clock, rhythm_input) use
# the same preload-constant workaround already used for NoteData/CharacterData:
#   const DebugLog = preload("res://autoloads/debug_log.gd")
#
# ENABLING LOGS
#   Call from test_scene.gd or any early _ready():
#     DebugLog.enable_all()          # all categories
#     DebugLog.enabled = true
#     DebugLog.combat_events = true  # single category
#
# LOG FORMAT CONVENTION
#   [TAG    ] key=value  key=value  ...
#   Tags are left-padded to 7 chars so columns stay aligned in the Output panel.
#   Each line should include the values that matter at that event boundary.
class_name DebugLog

## Master switch. All category flags are ignored while false.
static var enabled: bool = false

## Beat events, note pre-injection timing, press offsets, note expiry.
static var beat_timing:   bool = false
## Phase transitions, damage dealt, HP changes, win/loss, limit break.
static var combat_events: bool = false
## Note visual spawning, tween travel, hit-zone flashes.
static var note_visuals:  bool = false
## Audio feedback sound events (score, pitch scale).
static var audio_events:  bool = false

# ---------------------------------------------------------------------------
# Category write methods — one per category for concise call sites.
# ---------------------------------------------------------------------------

static func timing(msg: String) -> void:
    if enabled and beat_timing:
        print(msg)

static func combat(msg: String) -> void:
    if enabled and combat_events:
        print(msg)

static func visual(msg: String) -> void:
    if enabled and note_visuals:
        print(msg)

static func audio(msg: String) -> void:
    if enabled and audio_events:
        print(msg)

## Convenience: enable every category at once.
static func enable_all() -> void:
    enabled       = true
    beat_timing   = true
    combat_events = true
    note_visuals  = true
    audio_events  = true
