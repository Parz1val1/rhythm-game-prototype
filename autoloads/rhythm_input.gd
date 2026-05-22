# autoloads/rhythm_input.gd
# Registered as autoload "RhythmInput" in project.godot.
# Receives input events before any scene node because autoloads sit at the top
# of the scene tree. _unhandled_input fires only for events not consumed by UI.
extends Node

# Type alias for NoteData to resolve parse-time type resolution issues
# In Godot 4.6, class_name declarations create global scope but autoloads
# load before global scope is fully initialized. This is a known pattern.
const NoteData = preload("res://rhythm_engine/note_data.gd")

# --- Signals ---

## Emitted on every scored directional press.
## direction: &"up" / &"down" / &"left" / &"right"
## score:     &"perfect" / &"good" / &"miss"
## offset_ms: signed ms from nearest beat (negative=early, positive=late)
signal input_scored(direction: StringName, score: StringName, offset_ms: float)

## Emitted when a targeted note expires without a matching press.
## CombatScene listens to this to apply full defend-phase damage.
signal note_missed(note: NoteData)

# --- Configurable thresholds ---

## Absolute offset ≤ perfect_ms scores as "perfect".
@export var perfect_ms: float = 50.0

## Absolute offset ≤ good_ms scores as "good". Beyond this = "miss".
@export var good_ms: float = 120.0

# --- Active note queue ---

## Targeted notes currently in the scoring window.
## Populated by CombatScene via add_note(). Expired notes emit note_missed.
var active_notes: Array[NoteData] = []

## Parallel array: the Time.get_ticks_msec() value when each note was injected.
## Used to detect expiry without modifying NoteData.
var _note_inject_times: Array[int] = []

# --- Public API ---

## Score an absolute timing offset against the configured thresholds.
## abs_offset_ms must be >= 0 (pass abs(BeatClock.get_offset_ms())).
## Returns &"perfect", &"good", or &"miss".
## Public (no underscore) so test/test_scoring.gd can call it directly.
func score_timing(abs_offset_ms: float) -> StringName:
	if abs_offset_ms <= perfect_ms:
		return &"perfect"
	elif abs_offset_ms <= good_ms:
		return &"good"
	else:
		return &"miss"

## Inject a note into the active window. Called by CombatScene on each beat signal.
## Records the injection timestamp for expiry checking — NoteData is not mutated.
func add_note(note: NoteData) -> void:
	active_notes.append(note)
	_note_inject_times.append(Time.get_ticks_msec())

## Flush all active notes without scoring. Call at phase transitions.
func clear_notes() -> void:
	active_notes.clear()
	_note_inject_times.clear()

# --- Input handling ---

## Called by Godot for every InputEvent not consumed by a UI control.
## Scores the press against active targeted notes first (hybrid model), then
## falls back to free-form beat scoring if no targeted note matches.
func _unhandled_input(event: InputEvent) -> void:
	var direction := _get_direction(event)
	if direction == &"":
		return

	# Mark as handled so no other node processes this rhythm input.
	get_viewport().set_input_as_handled()

	var offset_ms: float = BeatClock.get_offset_ms()
	var abs_offset: float = abs(offset_ms)

	# --- Hybrid scoring: targeted note takes priority over free-form ---
	# Search active_notes in reverse so removal by index is safe.
	for i in range(active_notes.size() - 1, -1, -1):
		var note: NoteData = active_notes[i]
		if note.mode == &"targeted" and note.direction == direction:
			# Found a matching targeted note — score it and remove from queue.
			var score: StringName = score_timing(abs_offset)
			active_notes.remove_at(i)
			_note_inject_times.remove_at(i)
			input_scored.emit(direction, score, offset_ms)
			return

	# No matching targeted note — treat as free-form beat press.
	var score: StringName = score_timing(abs_offset)
	input_scored.emit(direction, score, offset_ms)

# --- Note expiry ---

## Each frame, check whether any targeted note's timing window has closed.
## A note expires when more than good_ms has elapsed since it was injected.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	# Iterate in reverse so removal by index doesn't skip entries.
	for i in range(active_notes.size() - 1, -1, -1):
		if active_notes[i].mode != &"targeted":
			continue
		var age_ms: float = float(now - _note_inject_times[i])
		if age_ms > good_ms:
			var expired: NoteData = active_notes[i]
			active_notes.remove_at(i)
			_note_inject_times.remove_at(i)
			note_missed.emit(expired)

# --- Helpers ---

func _get_direction(event: InputEvent) -> StringName:
	# is_action_pressed() returns true only on the initial press, not hold.
	if event.is_action_pressed(&"rhythm_up"):    return &"up"
	if event.is_action_pressed(&"rhythm_down"):  return &"down"
	if event.is_action_pressed(&"rhythm_left"):  return &"left"
	if event.is_action_pressed(&"rhythm_right"): return &"right"
	return &""
