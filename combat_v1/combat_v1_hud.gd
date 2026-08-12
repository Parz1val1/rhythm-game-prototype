## Diagnostic presentation for the public CombatV1 observable interface.
class_name CombatV1HUD
extends Control

const CombatV1 = preload("res://combat_v1/combat_v1.gd")
const PhraseEvent = preload("res://combat_v1/phrase_event.gd")

@onready var _cadence_label: Label = $CadencePanel/CadenceLabel
@onready var _mode_label: Label = $CadencePanel/ModeLabel
@onready var _groove_bar: ProgressBar = $MeterPanel/Meters/Groove/GrooveBar
@onready var _groove_value: Label = $MeterPanel/Meters/Groove/GrooveValue
@onready var _composure_bar: ProgressBar = $MeterPanel/Meters/Composure/ComposureBar
@onready var _composure_value: Label = $MeterPanel/Meters/Composure/ComposureValue
@onready var _multiplier_bar: ProgressBar = $MeterPanel/Meters/Multiplier/MultiplierBar
@onready var _multiplier_value: Label = $MeterPanel/Meters/Multiplier/MultiplierValue
@onready var _note_feedback_label: Label = $FeedbackPanel/NoteFeedbackLabel
@onready var _phrase_feedback_label: Label = $FeedbackPanel/PhraseFeedbackLabel
@onready var _cue_mode_label: Label = $CuePanel/CueModeLabel
@onready var _cue_label: Label = $CuePanel/CueLabel
@onready var _cue_detail_label: Label = $CuePanel/CueDetailLabel
@onready var _outcome_panel: Panel = $OutcomePanel
@onready var _outcome_title: Label = $OutcomePanel/OutcomeTitle
@onready var _outcome_body: Label = $OutcomePanel/OutcomeBody
@onready var _instruction_label: Label = $InstructionPanel/InstructionLabel

var _combat_v1: CombatV1 = null

## Observe one CombatV1 instance and immediately reflect its current snapshot.
## This does not depend on setup-time signals still being available.
func setup(combat_v1: CombatV1) -> void:
	teardown()
	_combat_v1 = combat_v1
	if _combat_v1 == null:
		return
	if not _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
		_combat_v1.cadence_changed.connect(_on_cadence_changed)
	if not _combat_v1.encounter_state_changed.is_connected(_on_encounter_state_changed):
		_combat_v1.encounter_state_changed.connect(_on_encounter_state_changed)
	if not _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.response_note_graded.connect(_on_response_note_graded)
	if not _combat_v1.response_phrase_graded.is_connected(_on_response_phrase_graded):
		_combat_v1.response_phrase_graded.connect(_on_response_phrase_graded)
	if not _combat_v1.phrase_event_announced.is_connected(_on_phrase_event_announced):
		_combat_v1.phrase_event_announced.connect(_on_phrase_event_announced)
	if not _combat_v1.response_target_announced.is_connected(_on_response_target_announced):
		_combat_v1.response_target_announced.connect(_on_response_target_announced)
	if not _combat_v1.resolved.is_connected(_on_resolved):
		_combat_v1.resolved.connect(_on_resolved)
	_outcome_panel.visible = false
	_note_feedback_label.text = "NOTE  WAITING"
	_phrase_feedback_label.text = "PHRASE  WAITING"
	_cue_mode_label.text = "PHRASE CUE"
	_cue_label.text = "WAITING FOR PHRASE"
	_cue_detail_label.text = "VISUAL CUES MIRROR THE PLACEHOLDER AUDIO"
	_sync_from_module()

func _on_cadence_changed(_cadence: CombatV1.Cadence) -> void:
	_sync_from_module()

func _on_encounter_state_changed(_state: Dictionary) -> void:
	_sync_from_module()

func _on_response_note_graded(result: Dictionary) -> void:
	var grade_name: StringName = result[&"grade_name"]
	_note_feedback_label.text = "NOTE  %s  %+.1f ms" % [
		_get_grade_display_name(grade_name),
		float(result[&"offset_ms"]),
	]
	_note_feedback_label.add_theme_color_override("font_color", _get_grade_color(grade_name))

func _on_response_phrase_graded(summary: Dictionary) -> void:
	var grade_name: StringName = summary[&"grade_name"]
	_phrase_feedback_label.text = "PHRASE  %s" % _get_grade_display_name(grade_name)
	_phrase_feedback_label.add_theme_color_override("font_color", _get_grade_color(grade_name))

func _on_phrase_event_announced(event: PhraseEvent) -> void:
	_cue_mode_label.text = "LISTENING CUE"
	_cue_mode_label.add_theme_color_override("font_color", _get_mode_color(CombatV1.Cadence.ENEMY_PHRASE))
	_cue_label.text = "HEAR  %s" % event.prompt_text
	_cue_detail_label.text = "VISUAL  %s  |  BEAT %.2f" % [
		String(event.visual_cue).replace("_", " ").to_upper(),
		event.beat_offset,
	]

func _on_response_target_announced(event: PhraseEvent, expected_action: StringName) -> void:
	_cue_mode_label.text = "RESPONSE TARGET"
	_cue_mode_label.add_theme_color_override("font_color", _get_mode_color(CombatV1.Cadence.RESPONSE))
	_cue_label.text = "PLAY  %s" % String(expected_action).replace("_", " ").to_upper()
	_cue_detail_label.text = "SOURCE  %s  |  BEAT %.2f" % [event.prompt_text, event.beat_offset]

func _on_resolved(outcome: CombatV1.Outcome) -> void:
	_show_outcome(outcome)

func _show_outcome(outcome: CombatV1.Outcome) -> void:
	_outcome_panel.visible = true
	match outcome:
		CombatV1.Outcome.JAM:
			_outcome_title.text = "JAM REACHED"
			_outcome_body.text = "The musical conversation found its groove."
		CombatV1.Outcome.LOSS:
			_outcome_title.text = "MUSICAL EXCHANGE ENDED"
			_outcome_body.text = "The band lost the groove. Regroup when ready."
		_:
			_outcome_panel.visible = false

func _sync_from_module() -> void:
	if _combat_v1 == null:
		return
	var state: Dictionary = _combat_v1.get_state()
	_cadence_label.text = String(state[&"cadence_name"])
	_mode_label.text = _get_mode_text(state[&"cadence"])
	_mode_label.add_theme_color_override("font_color", _get_mode_color(state[&"cadence"]))
	_instruction_label.text = _get_instruction_text(state[&"cadence"])
	if bool(state[&"terminal"]):
		var outcome: CombatV1.Outcome = state[&"outcome"]
		_show_outcome(outcome)
	var response_summary: Dictionary = state[&"response_summary"]
	if not response_summary.is_empty():
		_on_response_phrase_graded(response_summary)

	_groove_bar.min_value = 0.0
	_groove_bar.max_value = float(state[&"max_groove"])
	_groove_bar.value = float(state[&"groove"])
	_groove_value.text = "GROOVE  %s / %s" % [_format_number(state[&"groove"]), _format_number(state[&"max_groove"])]

	_composure_bar.min_value = 0.0
	_composure_bar.max_value = float(state[&"max_composure"])
	_composure_bar.value = float(state[&"composure"])
	_composure_value.text = "COMPOSURE  %s / %s" % [_format_number(state[&"composure"]), _format_number(state[&"max_composure"])]

	_multiplier_bar.min_value = float(state[&"min_multiplier"])
	_multiplier_bar.max_value = float(state[&"max_multiplier"])
	_multiplier_bar.value = float(state[&"multiplier"])
	_multiplier_value.text = "MULTIPLIER  %sx" % _format_number(state[&"multiplier"])

func _get_mode_text(cadence: CombatV1.Cadence) -> String:
	match cadence:
		CombatV1.Cadence.SETTLE, CombatV1.Cadence.ENEMY_PHRASE:
			return "LISTEN - NO INPUT"
		CombatV1.Cadence.RESPONSE:
			return "RESPOND - INPUT ACTIVE"
		CombatV1.Cadence.TACTICAL_VAMP:
			return "TACTICAL VAMP - NO TIME PRESSURE"
		CombatV1.Cadence.RESOLUTION:
			return "CONVERSATION COMPLETE"
		_:
			return "WAITING"

func _get_mode_color(cadence: CombatV1.Cadence) -> Color:
	match cadence:
		CombatV1.Cadence.SETTLE, CombatV1.Cadence.ENEMY_PHRASE:
			return Color("40d1ff")
		CombatV1.Cadence.RESPONSE:
			return Color("72f28e")
		CombatV1.Cadence.TACTICAL_VAMP:
			return Color("f4b85c")
		CombatV1.Cadence.RESOLUTION:
			return Color("c69cff")
		_:
			return Color("8daecf")

func _get_instruction_text(cadence: CombatV1.Cadence) -> String:
	match cadence:
		CombatV1.Cadence.SETTLE:
			return "Listen. No input is scored while the band settles."
		CombatV1.Cadence.ENEMY_PHRASE:
			return "Listen to the phrase and watch each visual cue."
		CombatV1.Cadence.RESPONSE:
			return "Play the shown directions, then press Enter or Space to submit the phrase."
		CombatV1.Cadence.TACTICAL_VAMP:
			return "Listen without pressure. Press Enter or Space when you are ready for the next round."
		CombatV1.Cadence.RESOLUTION:
			return "Conversation complete. Reload the harness to play again."
		_:
			return "Waiting for the conversation to begin."

func _get_grade_display_name(grade_name: StringName) -> String:
	match grade_name:
		&"perfect":
			return "PERFECT"
		&"great":
			return "GREAT"
		&"good":
			return "GOOD"
		&"near_miss":
			return "NEAR MISS"
		&"miss":
			return "MISS"
		&"major_mistake":
			return "MAJOR MISTAKE"
		_:
			return "UNRATED"

func _get_grade_color(grade_name: StringName) -> Color:
	match grade_name:
		&"perfect":
			return Color("8ffcff")
		&"great":
			return Color("72f28e")
		&"good":
			return Color("d6ef78")
		&"near_miss":
			return Color("ffd166")
		&"miss":
			return Color("ff8c61")
		&"major_mistake":
			return Color("ff5c8a")
		_:
			return Color("8daecf")

func _format_number(value: Variant) -> String:
	var number := float(value)
	if is_equal_approx(number, roundf(number)):
		return "%d" % int(roundf(number))
	return "%.1f" % number

## Disconnect every signal this HUD owns. Safe to call repeatedly.
func teardown() -> void:
	if _combat_v1 == null:
		return
	if _combat_v1.cadence_changed.is_connected(_on_cadence_changed):
		_combat_v1.cadence_changed.disconnect(_on_cadence_changed)
	if _combat_v1.encounter_state_changed.is_connected(_on_encounter_state_changed):
		_combat_v1.encounter_state_changed.disconnect(_on_encounter_state_changed)
	if _combat_v1.response_note_graded.is_connected(_on_response_note_graded):
		_combat_v1.response_note_graded.disconnect(_on_response_note_graded)
	if _combat_v1.response_phrase_graded.is_connected(_on_response_phrase_graded):
		_combat_v1.response_phrase_graded.disconnect(_on_response_phrase_graded)
	if _combat_v1.phrase_event_announced.is_connected(_on_phrase_event_announced):
		_combat_v1.phrase_event_announced.disconnect(_on_phrase_event_announced)
	if _combat_v1.response_target_announced.is_connected(_on_response_target_announced):
		_combat_v1.response_target_announced.disconnect(_on_response_target_announced)
	if _combat_v1.resolved.is_connected(_on_resolved):
		_combat_v1.resolved.disconnect(_on_resolved)
	_combat_v1 = null

func _exit_tree() -> void:
	teardown()
