# combat/replay_ui.gd
# Post-combat overlay. Shows win/loss outcome, lets the player pick any
# character + encounter combination, and replays on button press.
# The overlay is hidden during gameplay and only shown via show_outcome().
extends CanvasLayer

const EncounterDefinition = preload("res://encounters/encounter_definition.gd")
const CharacterData       = preload("res://characters/character_data.gd")

## Emitted when the player presses Play Again.
## hero_path: res:// path to the selected CharacterData .tres file.
signal replay_requested(encounter_definition: EncounterDefinition, hero_path: String)

@onready var _outcome_label:    Label        = $Root/Panel/VBox/OutcomeLabel
@onready var _encounter_select: OptionButton = $Root/Panel/VBox/EncounterSelect
@onready var _play_button:      Button       = $Root/Panel/VBox/PlayButton

## Parallel arrays — indices match OptionButton item indices.
var _encounters:      Array = []
var _character_paths: Array = []

# Dynamically created — inserted into VBox above the encounter dropdown.
var _character_select: OptionButton = null

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_inject_character_dropdown()
	_populate_characters()
	_populate_encounters()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Show the overlay with the appropriate outcome message.
## Call from test_scene._on_combat_won / _on_combat_lost.
func show_outcome(won: bool) -> void:
	_outcome_label.text     = "Victory!" if won else "Defeat!"
	_outcome_label.modulate = Color(0.45, 1.0, 0.55) if won else Color(1.0, 0.35, 0.35)
	visible = true

## Pre-select the encounter dropdown item matching the currently active encounter.
func set_active_encounter(enc: EncounterDefinition) -> void:
	if enc == null:
		return
	for i in _encounter_select.item_count:
		if _encounter_select.get_item_text(i) == enc.encounter_id:
			_encounter_select.select(i)
			return

## Pre-select the character dropdown item matching the currently active hero path.
func set_active_character(hero_path: String) -> void:
	if hero_path == "":
		return
	for i in _character_paths.size():
		if _character_paths[i] == hero_path:
			_character_select.select(i)
			return

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Create the character OptionButton and insert it into the VBox above the
## encounter dropdown so the panel reads: Outcome → Character → Encounter → Play.
func _inject_character_dropdown() -> void:
	var vbox := _encounter_select.get_parent()
	_character_select = OptionButton.new()
	# Insert before EncounterSelect (index 1 in the VBox, after OutcomeLabel).
	vbox.add_child(_character_select)
	vbox.move_child(_character_select, _encounter_select.get_index())

func _populate_characters() -> void:
	_character_select.clear()
	_character_paths.clear()

	var dir := DirAccess.open("res://characters/")
	if dir == null:
		push_warning("ReplayUI: could not open res://characters/")
		return

	var entries: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path := "res://characters/" + fname
			var res := load(path)
			if res != null and res.get_script() != null \
					and res.get("character_name") != null:
				entries.append({"path": path, "name": res.character_name})
		fname = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(func(a, b): return a["name"] < b["name"])
	for entry in entries:
		_character_select.add_item(entry["name"])
		_character_paths.append(entry["path"])

	if _character_select.item_count > 0:
		_character_select.select(0)

func _populate_encounters() -> void:
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

	_encounters.sort_custom(func(a, b): return a.encounter_id < b.encounter_id)
	for def in _encounters:
		_encounter_select.add_item(def.encounter_id)

	if _encounter_select.item_count > 0:
		_encounter_select.select(0)

func _on_play_pressed() -> void:
	var enc_idx  := _encounter_select.selected
	var char_idx := _character_select.selected
	if enc_idx < 0 or enc_idx >= _encounters.size():
		push_warning("ReplayUI: no encounter selected")
		return
	var hero_path := _character_paths[char_idx] if char_idx >= 0 \
		and char_idx < _character_paths.size() else ""
	visible = false
	replay_requested.emit(_encounters[enc_idx] as EncounterDefinition, hero_path)
