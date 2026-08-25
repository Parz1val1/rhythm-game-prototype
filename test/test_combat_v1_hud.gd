# Verifies the diagnostic Combat V1 HUD through its public setup/teardown seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	# Godot releases the harness MP3 stream asynchronously after free().
	await create_timer(0.25).timeout
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 HUD tests ===")
	var hud_path := "res://combat_v1/combat_v1_hud.tscn"
	_check("diagnostic V1 HUD scene exists", FileAccess.file_exists(hud_path), true)
	if not FileAccess.file_exists(hud_path):
		print("=== done ===")
		return

	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var config = CombatV1Script.EncounterConfig.new()
	config.max_groove = 80.0
	config.jam_threshold = 70.0
	config.max_composure = 60.0
	config.min_multiplier = 0.5
	config.baseline_multiplier = 1.5
	config.max_multiplier = 3.0

	var presentation_session = CombatV1Script.SessionState.new()
	presentation_session.register_character(&"luthier_frett", "Luthier Frett")
	var module = CombatV1Script.new()
	root.add_child(module)
	module.bind_session(presentation_session, &"luthier_frett")
	module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1,
		config
	)
	module.start()

	# Deliberately connect after start() emitted its initial cadence signal.
	var hud = load(hud_path).instantiate()
	root.add_child(hud)
	hud.setup(module)
	var response_highway = hud.get_node_or_null("ResponseNoteHighway")
	_check("the diagnostic HUD includes the Response note highway", response_highway != null, true)
	if response_highway != null:
		var highway_rect: Rect2 = response_highway.get_global_rect()
		for panel_path in [
			"CadencePanel",
			"MeterPanel",
			"CuePanel",
			"FeedbackPanel",
			"InstructionPanel",
		]:
			var panel: Control = hud.get_node(panel_path)
			_check(
				"the Response board does not overlap %s" % panel_path,
				highway_rect.intersects(panel.get_global_rect()),
				false
			)
	_check("late setup reflects the current cadence", hud.get_node("CadencePanel/CadenceLabel").text, "Settle")
	_check("Settle is visibly identified as listening-only", hud.get_node("CadencePanel/ModeLabel").text, "LISTEN - NO INPUT")
	var instruction_label: Label = hud.get_node_or_null("InstructionPanel/InstructionLabel")
	_check("HUD exposes cadence-specific playtest guidance", instruction_label != null, true)
	if instruction_label != null:
		_check(
			"Settle guidance reinforces listening",
			instruction_label.text,
			"Listen. No input is scored while the band settles."
		)
	_check("late setup reflects Groove bounds", hud.get_node("MeterPanel/Meters/Groove/GrooveBar").max_value, 80.0)
	_check("late setup reflects current Groove", hud.get_node("MeterPanel/Meters/Groove/GrooveBar").value, 0.0)
	_check("late setup reflects Composure bounds", hud.get_node("MeterPanel/Meters/Composure/ComposureBar").max_value, 60.0)
	_check("late setup reflects current Composure", hud.get_node("MeterPanel/Meters/Composure/ComposureBar").value, 60.0)
	_check("late setup reflects Multiplier minimum", hud.get_node("MeterPanel/Meters/Multiplier/MultiplierBar").min_value, 0.5)
	_check("late setup reflects current Multiplier", hud.get_node("MeterPanel/Meters/Multiplier/MultiplierBar").value, 1.5)
	var inspiration_bar: ProgressBar = hud.get_node_or_null(
		"MeterPanel/Meters/Inspiration/InspirationBar"
	)
	var inspiration_value: Label = hud.get_node_or_null(
		"MeterPanel/Meters/Inspiration/InspirationValue"
	)
	_check(
		"late setup presents the active character's Inspiration and configured floor",
		{
			&"minimum": inspiration_bar.min_value if inspiration_bar != null else -1.0,
			&"maximum": inspiration_bar.max_value if inspiration_bar != null else -1.0,
			&"value": inspiration_bar.value if inspiration_bar != null else -1.0,
			&"label": inspiration_value.text if inspiration_value != null else "",
		},
		{
			&"minimum": 20.0,
			&"maximum": 100.0,
			&"value": 50.0,
			&"label": "LUTHIER INSPIRATION  50 / 100",
		}
	)
	var stronger_skill_label: Label = hud.get_node("SkillPanel/SecondSkill")
	var initially_available := "UNAVAILABLE" not in stronger_skill_label.text
	presentation_session.spend_inspiration(&"luthier_frett", 30.0)
	var unavailable_at_floor := "UNAVAILABLE" in stronger_skill_label.text
	for note_index in range(6):
		presentation_session.record_performance_grade(
			&"luthier_frett",
			&"perfect",
			&"note"
		)
	_check(
		"Skill affordability follows live Inspiration changes without owning resource rules",
		{
			&"initially_available": initially_available,
			&"unavailable_at_floor": unavailable_at_floor,
			&"available_after_play": "UNAVAILABLE" not in stronger_skill_label.text,
			&"restored_inspiration": inspiration_bar.value if inspiration_bar != null else -1.0,
		},
		{
			&"initially_available": true,
			&"unavailable_at_floor": true,
			&"available_after_play": true,
			&"restored_inspiration": 50.0,
		}
	)
	var listening_color: Color = hud.get_node("CadencePanel/ModeLabel").get_theme_color("font_color")
	for beat_number in range(1, 5):
		root.get_node("BeatClock").beat.emit(beat_number)
	_check("Enemy Phrase remains visibly listening-only", hud.get_node("CadencePanel/ModeLabel").text, "LISTEN - NO INPUT")
	for beat_number in range(5, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	_check("Response is visibly identified as active", hud.get_node("CadencePanel/ModeLabel").text, "RESPOND - INPUT ACTIVE")
	if response_highway != null:
		var highway_snapshot: Dictionary = response_highway.get_presentation_snapshot()
		_check("the integrated highway is active before the first due target", highway_snapshot[&"active"], true)
		_check("the integrated highway receives the complete Response schedule", highway_snapshot[&"targets"].size(), 6)
	var first_response_target: Dictionary = module.get_response_presentation()[&"targets"][0]
	module.submit_response_input(
		first_response_target[&"expected_action"],
		first_response_target[&"due_beat"]
	)
	_check(
		"character Inspiration signals immediately refresh the presentation meter",
		{
			&"value": inspiration_bar.value if inspiration_bar != null else -1.0,
			&"label": inspiration_value.text if inspiration_value != null else "",
		},
		{
			&"value": 55.0,
			&"label": "LUTHIER INSPIRATION  55 / 100",
		}
	)
	if instruction_label != null:
		_check(
			"Response guidance explains submission",
			instruction_label.text,
			"Use arrows, D-pad, or matching face buttons. Press Enter, Space, or Start to submit."
		)
	_check(
		"Response uses a distinct visual treatment from listening",
		hud.get_node("CadencePanel/ModeLabel").get_theme_color("font_color") != listening_color,
		true
	)
	_check(
		"an encounter result is accepted through the Combat V1 seam",
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		),
		true
	)
	_check("state signals update the Groove meter", hud.get_node("MeterPanel/Meters/Groove/GrooveBar").value, 15.0)
	_check("Groove remains named beside its value", hud.get_node("MeterPanel/Meters/Groove/GrooveValue").text, "GROOVE  15 / 80")
	_check("state signals update the shared Multiplier", hud.get_node("MeterPanel/Meters/Multiplier/MultiplierBar").value, 2.0)
	_check("Multiplier remains named beside its value", hud.get_node("MeterPanel/Meters/Multiplier/MultiplierValue").text, "MULTIPLIER  2x")
	_check("Composure remains named beside its value", hud.get_node("MeterPanel/Meters/Composure/ComposureValue").text, "COMPOSURE  60 / 60")
	var note_feedback: Label = hud.get_node_or_null("FeedbackPanel/NoteFeedbackLabel")
	_check("HUD exposes note performance feedback", note_feedback != null, true)
	if note_feedback != null:
		var grade_names: Array[StringName] = [
			&"perfect", &"great", &"good", &"near_miss", &"miss", &"major_mistake",
		]
		var displayed_grades: Array[String] = []
		var grade_colors: Array[Color] = []
		for grade_name in grade_names:
			module.response_note_graded.emit({
				&"grade_name": grade_name,
				&"offset_ms": -12.5,
			})
			displayed_grades.append(note_feedback.text)
			grade_colors.append(note_feedback.get_theme_color("font_color"))
		_check(
			"all six note grades use readable labels",
			displayed_grades,
			[
				"NOTE  PERFECT  -12.5 ms",
				"NOTE  GREAT  -12.5 ms",
				"NOTE  GOOD  -12.5 ms",
				"NOTE  NEAR MISS  -12.5 ms",
				"NOTE  MISS  -12.5 ms",
				"NOTE  MAJOR MISTAKE  -12.5 ms",
			]
		)
		_check("all six note grades have distinct colors", _unique_color_count(grade_colors), 6)
	var phrase_feedback: Label = hud.get_node_or_null("FeedbackPanel/PhraseFeedbackLabel")
	_check("HUD exposes phrase performance feedback", phrase_feedback != null, true)
	if phrase_feedback != null:
		var phrase_grade_names: Array[StringName] = [
			&"perfect", &"great", &"good", &"near_miss", &"miss", &"major_mistake",
		]
		var displayed_phrase_grades: Array[String] = []
		for grade_name in phrase_grade_names:
			module.response_phrase_graded.emit({&"grade_name": grade_name})
			displayed_phrase_grades.append(phrase_feedback.text)
		_check(
			"all six phrase grades use readable labels",
			displayed_phrase_grades,
			[
				"PHRASE  PERFECT",
				"PHRASE  GREAT",
				"PHRASE  GOOD",
				"PHRASE  NEAR MISS",
				"PHRASE  MISS",
				"PHRASE  MAJOR MISTAKE",
			]
		)
	var cue_label: Label = hud.get_node_or_null("CuePanel/CueLabel")
	_check("HUD exposes a visual phrase cue", cue_label != null, true)
	if cue_label != null:
		var cue_event = load("res://combat_v1/opponents/drum_golem.tres").phrase.events[0]
		var cue_actions: Array[StringName] = []
		cue_actions.append(&"up")
		module.phrase_event_announced.emit(cue_event, cue_actions)
		_check("listening cue identifies what the player hears", hud.get_node("CuePanel/CueModeLabel").text, "LISTENING CUE")
		_check("listening cue shows authored prompt text", cue_label.text, "HEAR  Left pulse")
		_check("placeholder audio has a readable visual equivalent", hud.get_node("CuePanel/CueDetailLabel").text, "VISUAL  PULSE LEFT  |  BEAT 0.00")
		var single_response_actions: Array[StringName] = []
		single_response_actions.append(&"up")
		module.response_target_announced.emit(cue_event, single_response_actions)
		_check("Response cue is explicitly active", hud.get_node("CuePanel/CueModeLabel").text, "RESPONSE TARGET")
		_check("Response cue shows the expected action", cue_label.text, "PLAY  UP")
		var chord_response_actions: Array[StringName] = []
		chord_response_actions.append(&"up")
		chord_response_actions.append(&"right")
		module.response_target_announced.emit(cue_event, chord_response_actions)
		_check("Response cue shows simultaneous actions together", cue_label.text, "PLAY  UP + RIGHT")
	var outcome_panel: Control = hud.get_node_or_null("OutcomePanel")
	_check("HUD exposes provisional conversation outcomes", outcome_panel != null, true)
	if outcome_panel != null:
		for result_index in range(3):
			module.apply_performance_result(
				CombatV1Script.Execution.CORRECT,
				CombatV1Script.TacticalEffectiveness.EFFECTIVE
			)
		_check("Jam outcome becomes visible", outcome_panel.visible, true)
		_check("Jam outcome uses musical language", hud.get_node("OutcomePanel/OutcomeTitle").text, "JAM REACHED")
		_check(
			"Jam outcome describes connection",
			hud.get_node("OutcomePanel/OutcomeBody").text,
			"The musical conversation found its groove."
		)

		var loss_config = CombatV1Script.EncounterConfig.new()
		loss_config.max_composure = 10.0
		loss_config.mistake_composure_loss = 10.0
		var loss_module = CombatV1Script.new()
		root.add_child(loss_module)
		loss_module.setup(
			root.get_node("BeatClock"),
			root.get_node("RhythmInput"),
			load("res://combat_v1/opponents/drum_golem.tres"),
			1,
			loss_config
		)
		loss_module.start()
		hud.setup(loss_module)
		loss_module.apply_performance_result(
			CombatV1Script.Execution.MISTAKE,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		)
		_check("loss outcome becomes visible", outcome_panel.visible, true)
		_check("loss outcome avoids violent framing", hud.get_node("OutcomePanel/OutcomeTitle").text, "MUSICAL EXCHANGE ENDED")
		_check(
			"loss outcome offers a nonviolent retry",
			hud.get_node("OutcomePanel/OutcomeBody").text,
			"The band lost the groove. Regroup when ready."
		)
		hud.teardown()
		loss_module.teardown()
		loss_module.free()
		hud.setup(module)
		_check("late setup reconstructs a missed terminal outcome", outcome_panel.visible, true)
		_check("late setup reconstructs the Jam result", hud.get_node("OutcomePanel/OutcomeTitle").text, "JAM REACHED")
		hud.teardown()

		var summary_module = CombatV1Script.new()
		root.add_child(summary_module)
		summary_module.setup(
			root.get_node("BeatClock"),
			root.get_node("RhythmInput"),
			load("res://combat_v1/opponents/drum_golem.tres"),
			1
		)
		summary_module.start()
		for beat_number in range(1, 9):
			root.get_node("BeatClock").beat.emit(beat_number)
		var summary_presentation: Dictionary = summary_module.get_response_presentation()
		for target in summary_presentation[&"targets"]:
			summary_module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
		summary_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
		hud.setup(summary_module)
		_check(
			"late setup reconstructs a missed phrase summary",
			hud.get_node("FeedbackPanel/PhraseFeedbackLabel").text,
			"PHRASE  PERFECT"
		)
		if instruction_label != null:
			_check(
				"Tactical Vamp guidance preserves no-pressure listening",
				instruction_label.text,
				"Listen without pressure. Choose a Skill with Up/Down, then confirm with Enter, Space, or A."
			)
		hud.teardown()
		summary_module.teardown()
		summary_module.free()

	hud.teardown()
	module.teardown()
	hud.free()
	module.free()

	var prototype = load("res://combat_v1/combat_v1_prototype.tscn").instantiate()
	root.add_child(prototype)
	var integrated_hud = prototype.get_node_or_null("CombatV1HUD")
	_check("standalone V1 harness includes the diagnostic HUD", integrated_hud != null, true)
	if integrated_hud != null:
		var prototype_module = prototype.get("_combat_v1")
		var hud_signals: Array[StringName] = [
			&"cadence_changed",
			&"encounter_state_changed",
			&"inspiration_changed",
			&"next_round_transition_changed",
			&"phrase_event_announced",
			&"response_target_announced",
			&"response_note_graded",
			&"character_performance_note_graded",
			&"response_phrase_graded",
			&"skill_selected",
			&"resolved",
		]
		var hud_methods: Array[StringName] = [
			&"_on_cadence_changed",
			&"_on_encounter_state_changed",
			&"_on_inspiration_changed",
			&"_on_next_round_transition_changed",
			&"_on_phrase_event_announced",
			&"_on_response_target_announced",
			&"_on_response_note_graded",
			&"_on_response_note_graded",
			&"_on_response_phrase_graded",
			&"_on_skill_selected",
			&"_on_resolved",
		]
		for connection_index in range(hud_signals.size()):
			_check(
				"integrated HUD connects %s" % hud_signals[connection_index],
				_is_connected(
					prototype_module,
					hud_signals[connection_index],
					integrated_hud,
					hud_methods[connection_index]
				),
				true
			)
		_check(
			"player-facing V1 labels avoid legacy combat framing",
			_has_no_forbidden_player_labels(integrated_hud),
			true
		)
		prototype_module.encounter_state_changed.disconnect(
			Callable(integrated_hud, &"_on_encounter_state_changed")
		)
		prototype.teardown()
		prototype.teardown()
		for connection_index in range(hud_signals.size()):
			_check(
				"integrated HUD disconnects %s with guarded teardown" % hud_signals[connection_index],
				_is_connected(
					prototype_module,
					hud_signals[connection_index],
					integrated_hud,
					hud_methods[connection_index]
				),
				false
			)
	prototype.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])

func _unique_color_count(colors: Array[Color]) -> int:
	var unique: Array[Color] = []
	for color in colors:
		if color not in unique:
			unique.append(color)
	return unique.size()

func _is_connected(source: Object, signal_name: StringName, target: Object, method_name: StringName) -> bool:
	if source == null or target == null:
		return false
	return Signal(source, signal_name).is_connected(Callable(target, method_name))

func _has_no_forbidden_player_labels(node: Node) -> bool:
	if node is Label:
		var label_text := (node as Label).text.to_lower()
		for forbidden in ["hp", "damage", "attack", "defend", "enemy defeat"]:
			if forbidden in label_text:
				return false
	for child in node.get_children():
		if not _has_no_forbidden_player_labels(child):
			return false
	return true
