# combat/replay_ui.gd
# Post-combat overlay. Shows win/loss outcome, lets the player pick any
# encounter from the encounters/ directory, and replays on button press.
extends CanvasLayer

const EncounterDefinition = preload("res://encounters/encounter_definition.gd")

## Emitted when the player presses Play Again.
## Carry the selected EncounterDefinition back to test_scene.
signal replay_requested(encounter_definition: EncounterDefinition)

@onready var _outcome_label:    Label        = $Root/Panel/VBox/OutcomeLabel
@onready var _encounter_select: OptionButton = $Root/Panel/VBox/EncounterSelect
@onready var _play_button:      Button       = $Root/Panel/VBox/PlayButton

## Parallel array — index matches OptionButton item index.
var _encounters: Array = []

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_populate_dropdown()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Show the overlay with the appropriate outcome message.
## Call from test_scene._on_combat_won / _on_combat_lost.
func show_outcome(won: bool) -> void:
	_outcome_label.text     = "Victory!" if won else "Defeat!"
	_outcome_label.modulate = Color(0.45, 1.0, 0.55) if won else Color(1.0, 0.35, 0.35)
	visible = true

## Pre-select the dropdown item matching the currently active encounter.
## Call from test_scene after setup so the dropdown starts on the right entry.
func set_active_encounter(enc: EncounterDefinition) -> void:
	if enc == null:
		return
	for i in _encounter_select.item_count:
		if _encounter_select.get_item_text(i) == enc.encounter_id:
			_encounter_select.select(i)
			return

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _populate_dropdown() -> void:
	_encounter_select.clear()
	_encounters.clear()

	var dir := DirAccess.open("res://encounters/")
	if dir == null:
		push_warning("ReplayUI: could not open res://encounters/ — dropdown will be empty")
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var def := load("res://encounters/" + fname) as EncounterDefinition
			if def != null:
				_encounters.append(def)
		fname = dir.get_next()
	dir.list_dir_end()

	# Alphabetical by encounter_id for a stable, predictable order.
	_encounters.sort_custom(func(a, b): return a.encounter_id < b.encounter_id)

	for def in _encounters:
		_encounter_select.add_item(def.encounter_id)

	# Default to the first item so selected is never -1 when items exist.
	if _encounter_select.item_count > 0:
		_encounter_select.select(0)

func _on_play_pressed() -> void:
	var idx := _encounter_select.selected
	if idx < 0 or idx >= _encounters.size():
		push_warning("ReplayUI: no encounter selected")
		return
	visible = false
	replay_requested.emit(_encounters[idx] as EncounterDefinition)
