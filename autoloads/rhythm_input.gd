# autoloads/rhythm_input.gd
# Registered as autoload "RhythmInput" in project.godot.
extends Node

const NoteData   = preload("res://rhythm_engine/note_data.gd")
const ActiveNote = preload("res://rhythm_engine/active_note.gd")

# --- Signals ---
## Emitted on every scored directional press.
## note_consumed: true if this press consumed an active targeted/free_form note.
##                false if player pressed with no active note (ignore in DEFEND).
signal input_scored(direction: StringName, score: StringName, offset_ms: float, note_consumed: bool)

## Emitted when a targeted note expires without a matching press.
signal note_missed(note: NoteData)

# --- Configurable thresholds ---
@export var perfect_ms: float = 50.0
@export var good_ms: float = 120.0

# --- Active note queue ---
# Array[ActiveNote] — typed as Array (untyped) due to preload workaround in autoloads.
var _active: Array = []

# --- Public API ---

func score_timing(abs_offset_ms: float) -> StringName:
    if abs_offset_ms <= perfect_ms:
        return &"perfect"
    elif abs_offset_ms <= good_ms:
        return &"good"
    else:
        return &"miss"

## Add a note to the scoring queue.
## due_time_ms: wall-clock timestamp when the note is ideally due (used for expiry).
##   Pass 0 (default) to use the current time — identical to legacy behaviour.
##   Pass a future timestamp to pre-inject the note before its beat, so early
##   presses can consume it while expiry is still anchored to the beat moment.
## Returns true if the note was newly added, false if it was already active
## (duplicate-prevention so half_beat pre-injection and beat fallback can coexist).
func add_note(note: NoteData, due_time_ms: int = 0) -> bool:
    for an in _active:
        if an.note == note:
            return false   # already queued; caller can log a fallback if needed
    var now := Time.get_ticks_msec()
    _active.append(ActiveNote.new(note, now, due_time_ms if due_time_ms > 0 else now))
    return true

func clear_notes() -> void:
    _active.clear()

# --- Input handling ---

func _unhandled_input(event: InputEvent) -> void:
    var direction := _get_direction(event)
    if direction == &"":
        return

    get_viewport().set_input_as_handled()

    var offset_ms: float = BeatClock.get_offset_ms()
    var abs_offset: float = abs(offset_ms)

    # Targeted note takes priority — search in reverse for safe removal.
    for i in range(_active.size() - 1, -1, -1):
        var an = _active[i]
        if an.note.mode == &"targeted" and an.note.direction == direction:
            var score: StringName = score_timing(abs_offset)
            _active.remove_at(i)
            input_scored.emit(direction, score, offset_ms, true)
            return

    # Free-form fallthrough — no matching targeted note active.
    var score: StringName = score_timing(abs_offset)
    input_scored.emit(direction, score, offset_ms, false)

# --- Note expiry ---

func _process(_delta: float) -> void:
    var now: int = Time.get_ticks_msec()
    for i in range(_active.size() - 1, -1, -1):
        var an = _active[i]
        if an.note.mode != &"targeted":
            continue
        # Use due_time_ms so expiry is anchored to the beat moment,
        # not to when the note was injected (which may be earlier via half_beat).
        var age_ms: float = float(now - an.due_time_ms)
        if age_ms > good_ms:
            var expired: NoteData = an.note
            _active.remove_at(i)
            note_missed.emit(expired)

# --- Helpers ---

func _get_direction(event: InputEvent) -> StringName:
    if event.is_action_pressed(&"rhythm_up"):    return &"up"
    if event.is_action_pressed(&"rhythm_down"):  return &"down"
    if event.is_action_pressed(&"rhythm_left"):  return &"left"
    if event.is_action_pressed(&"rhythm_right"): return &"right"
    return &""
