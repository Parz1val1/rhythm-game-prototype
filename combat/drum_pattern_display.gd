# combat/drum_pattern_display.gd
# Shows the drum pattern Beatrice is building during her ATTACK phase.
# Displays one icon per beat slot (L / R / B / ·) in a horizontal row.
# Clears at the start of each ATTACK phase.
# Add as a child of the test scene; call setup(combat, phase_length) after start_combat().
extends Control

const SLOT_SIZE := 36.0
const SLOT_GAP  := 6.0

var _slots: Array = []       # Array of Label nodes
var _phase_length: int = 4   # beats in the ATTACK window
var _current_beat: int = 0   # which slot to fill next

func _ready() -> void:
	custom_minimum_size = Vector2((_phase_length) * (SLOT_SIZE + SLOT_GAP), SLOT_SIZE + 24)

func setup(combat: Node, phase_length: int) -> void:
	_phase_length = phase_length
	_rebuild_slots()
	combat.phase_changed.connect(_on_phase_changed)
	RhythmInput.input_scored.connect(_on_input_scored)
	RhythmInput.input_chord.connect(_on_input_chord)
	visible = false  # shown during ATTACK only

func _exit_tree() -> void:
	if RhythmInput.input_scored.is_connected(_on_input_scored):
		RhythmInput.input_scored.disconnect(_on_input_scored)
	if RhythmInput.input_chord.is_connected(_on_input_chord):
		RhythmInput.input_chord.disconnect(_on_input_chord)

# ---------------------------------------------------------------------------

func _rebuild_slots() -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()

	# Header label
	var hdr := Label.new()
	hdr.text = "Pattern:"
	hdr.position = Vector2(0, 0)
	add_child(hdr)

	for i in range(_phase_length):
		var bg := ColorRect.new()
		bg.size     = Vector2(SLOT_SIZE, SLOT_SIZE)
		bg.position = Vector2(i * (SLOT_SIZE + SLOT_GAP), 20)
		bg.color    = Color(0.15, 0.15, 0.15)
		add_child(bg)

		var lbl := Label.new()
		lbl.text = "·"
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		bg.add_child(lbl)
		_slots.append(lbl)

func _on_phase_changed(new_phase: int) -> void:
	visible = (new_phase == 0)  # show during ATTACK (phase 0)
	if new_phase == 0:  # entering ATTACK
		_current_beat = 0
		for lbl in _slots:
			(lbl as Label).text = "·"
			(lbl.get_parent() as ColorRect).color = Color(0.15, 0.15, 0.15)

func _on_input_scored(direction: StringName, score: StringName, _off: float, _consumed: bool) -> void:
	_record_input(direction, score)

func _on_input_chord(chord_name: StringName, _score: StringName) -> void:
	# chord already recorded as the chord_name direction via input_scored;
	# override the last slot with "B" to make the chord visually distinct.
	if chord_name == &"drum_both" and _current_beat > 0:
		var slot_idx := mini(_current_beat - 1, _slots.size() - 1)
		(_slots[slot_idx] as Label).text = "B"

func _record_input(direction: StringName, score: StringName) -> void:
	if _current_beat >= _slots.size():
		return
	var icon: String
	match direction:
		&"drum_left":  icon = "L"
		&"drum_right": icon = "R"
		&"drum_both":  icon = "B"
		_:             icon = "·"
	var color: Color
	match score:
		&"perfect": color = Color(0.3, 0.9, 0.4)
		&"good":    color = Color(0.9, 0.8, 0.2)
		_:          color = Color(0.7, 0.2, 0.2)
	var lbl := _slots[_current_beat] as Label
	lbl.text = icon
	(lbl.get_parent() as ColorRect).color = color
	_current_beat += 1
