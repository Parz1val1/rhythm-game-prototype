# autoloads/rhythm_input.gd
# Registered as autoload "RhythmInput" in project.godot.
extends Node

const NoteData              = preload("res://rhythm_engine/note_data.gd")
const ActiveNote            = preload("res://rhythm_engine/active_note.gd")
const CharacterInputProfile = preload("res://characters/character_input_profile.gd")
# DebugLog is a class_name script, but autoloads can't rely on class_name scope
# in Godot 4.6 — use the same preload-constant workaround as NoteData above.
const DebugLog              = preload("res://autoloads/debug_log.gd")

# --- Signals ---
## Emitted on every scored directional press.
## note_consumed: true if this press consumed an active targeted/free_form note.
##                false if player pressed with no active note (ignore in DEFEND).
signal input_scored(direction: StringName, score: StringName, offset_ms: float, note_consumed: bool)

## Emitted when a targeted note expires without a matching press.
signal note_missed(note: NoteData)

## Emitted when two or more inputs within chord_window_ms are recognised as a chord.
## chord_name is the inputs joined with "+" e.g. "up+down".
signal input_chord(chord_name: StringName, score: StringName)

# --- Configurable thresholds ---
@export var perfect_ms: float = 50.0
@export var good_ms: float = 120.0

# --- Active profile ---
# Null = no filter (default: all registered rhythm actions accepted).
var _active_profile = null   # CharacterInputProfile or null

# Chord detection: keys pressed within chord_window_ms accumulate here.
# Dict of StringName → int (wall-clock ms of press). Cleared after chord check.
var _chord_buffer: Dictionary = {}

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
	if _active.size() > 0:
		DebugLog.timing("[CLEAR  ] flushed %d active note(s)" % _active.size())
	_active.clear()

# --- Profile API ---

## Set the active CharacterInputProfile. Pass null to remove the filter.
## valid_inputs = [] means "accept all" (same as no profile).
func set_active_profile(profile) -> void:
	_active_profile = profile
	_chord_buffer.clear()

## Remove the active profile, restoring default (all inputs accepted) behavior.
func clear_profile() -> void:
	_active_profile = null
	_chord_buffer.clear()

## Returns true if the given direction is allowed by the active profile.
## When no profile is set, or valid_inputs is empty, all directions are allowed.
func is_input_allowed(direction: StringName) -> bool:
	if _active_profile == null:
		return true
	var vi: Array = _active_profile.valid_inputs
	if vi.is_empty():
		return true
	return direction in vi

# --- Input handling ---

func _unhandled_input(event: InputEvent) -> void:
	var direction := _get_direction(event)
	if direction == &"":
		return

	# Profile filtering: drop inputs not in the active profile's valid_inputs.
	if not is_input_allowed(direction):
		return

	get_viewport().set_input_as_handled()

	# Chord detection: record this press timestamp and check for matches.
	if _active_profile != null and not _active_profile.chord_inputs.is_empty():
		var now_ms: int = Time.get_ticks_msec()
		_chord_buffer[direction] = now_ms
		# Remove stale entries outside the chord window.
		var window: float = _active_profile.chord_window_ms
		for key in _chord_buffer.keys():
			if float(now_ms - _chord_buffer[key]) > window:
				_chord_buffer.erase(key)
		# Check if the current buffer matches any defined chord.
		for ci in range(_active_profile.chord_inputs.size()):
			var chord_def: Array = _active_profile.chord_inputs[ci]
			var matched: bool = true
			for required in chord_def:
				if required not in _chord_buffer:
					matched = false
					break
			if matched:
				# Output name: use chord_names[ci] if defined, else auto-generate.
				var chord_name: StringName
				if ci < _active_profile.chord_names.size() and _active_profile.chord_names[ci] != &"":
					chord_name = _active_profile.chord_names[ci]
				else:
					chord_name = StringName("+".join(chord_def))
				var chord_offset: float = BeatClock.get_offset_ms()
				var chord_score: StringName = score_timing(abs(chord_offset))
				_chord_buffer.clear()
				# Try to consume a targeted note matching the chord output name.
				var note_consumed: bool = false
				for i in range(_active.size() - 1, -1, -1):
					var an = _active[i]
					if an.note.mode == &"targeted" and StringName(an.note.direction) == chord_name:
						_active.remove_at(i)
						note_consumed = true
						break
				# Emit via input_scored (defence handler) AND input_chord (evaluator/UI).
				input_scored.emit(chord_name, chord_score, chord_offset, note_consumed)
				input_chord.emit(chord_name, chord_score)
				return

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
	# Collect expired notes before emitting any signals.
	# Emitting note_missed inside the loop is unsafe: a signal handler can call
	# clear_notes() (via teardown on combat_lost), which clears _active mid-loop
	# and causes out-of-bounds access on the next iteration.
	var expired: Array = []
	for i in range(_active.size() - 1, -1, -1):
		var an = _active[i]
		if an.note.mode != &"targeted":
			continue
		var age_ms: float = float(now - an.due_time_ms)
		if age_ms > good_ms:
			expired.append(an.note)
			_active.remove_at(i)
	# Emit after the loop so signal handlers can safely modify _active.
	for note in expired:
		note_missed.emit(note)

# --- Helpers ---

func _get_direction(event: InputEvent) -> StringName:
	# When a profile is active and has valid_inputs, check only those actions.
	# This allows arbitrary input action names (e.g. drum_left) without modifying
	# the hardcoded default list below.
	if _active_profile != null and not _active_profile.valid_inputs.is_empty():
		for action in _active_profile.valid_inputs:
			if event.is_action_pressed(action):
				return action
		return &""
	# Default: standard 4-direction rhythm actions.
	if event.is_action_pressed(&"rhythm_up"):    return &"up"
	if event.is_action_pressed(&"rhythm_down"):  return &"down"
	if event.is_action_pressed(&"rhythm_left"):  return &"left"
	if event.is_action_pressed(&"rhythm_right"): return &"right"
	return &""
