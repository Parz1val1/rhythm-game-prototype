# Verifies visible Skill selection through the standalone prototype seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	await _run()
	await create_timer(0.25).timeout
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Skill presentation tests ===")
	var prototype = load("res://combat_v1/combat_v1_prototype.tscn").instantiate()
	root.add_child(prototype)
	var module = prototype.get("_combat_v1")
	var hud = prototype.get_node("CombatV1HUD")
	var beat_clock: Node = root.get_node("BeatClock")
	for beat_number in range(1, 13):
		beat_clock.beat.emit(beat_number)
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(0)
	await process_frame

	var skill_panel: Control = hud.get_node_or_null("SkillPanel")
	var first_option: Label = hud.get_node_or_null("SkillPanel/FirstSkill")
	var second_option: Label = hud.get_node_or_null("SkillPanel/SecondSkill")
	var control_hint: Label = hud.get_node_or_null("SkillPanel/Controls")
	_check(
		"Skill panel explains vertical navigation and controller A confirmation",
		control_hint.text if control_hint != null else "",
		"UP / DOWN TO CHOOSE  •  ENTER / SPACE / A TO CONFIRM"
	)
	var selection_snapshot: Dictionary = {}
	if hud.has_method("get_skill_selection_snapshot"):
		selection_snapshot = hud.get_skill_selection_snapshot()
	var move_down := InputEventJoypadButton.new()
	move_down.button_index = JOY_BUTTON_DPAD_DOWN
	move_down.pressed = true
	Input.parse_input_event(move_down)
	await process_frame
	_check(
		"vertical Tactical Vamp choices follow controller Down input",
		hud.get_skill_selection_snapshot().get(&"selected_index", -1),
		1
	)
	var start_button := InputEventJoypadButton.new()
	start_button.button_index = JOY_BUTTON_START
	start_button.pressed = true
	Input.parse_input_event(start_button)
	await process_frame
	_check(
		"controller Start does not confirm a Tactical Vamp Skill choice",
		module.get_state().get(&"selected_skill_id", &""),
		&""
	)
	var skill_count_in_updates: Array[int] = []
	module.next_round_transition_changed.connect(
		func(transition: Dictionary) -> void:
			skill_count_in_updates.append(transition[&"count_in_beat"])
	)
	var confirm_choice := InputEventJoypadButton.new()
	confirm_choice.button_index = JOY_BUTTON_A
	confirm_choice.pressed = true
	Input.parse_input_event(confirm_choice)
	await process_frame
	var selected: bool = module.get_state().get(&"selected_skill_id", &"") \
		== &"steadying_harmony"
	_check(
		"controller A confirms the highlighted Skill instead of moving Down",
		{
			&"selected_skill_id": module.get_state().get(&"selected_skill_id", &""),
			&"highlighted_index": hud.get_skill_selection_snapshot().get(&"selected_index", -1),
			&"count_in_cadence": hud.get_node("CadencePanel/CadenceLabel").text,
			&"count_in_visible": hud.get_node("InstructionPanel/CountInLabel").visible,
			&"count_in_updates": skill_count_in_updates,
		},
		{
			&"selected_skill_id": &"steadying_harmony",
			&"highlighted_index": 1,
			&"count_in_cadence": "Character Performance Count-In",
			&"count_in_visible": true,
			&"count_in_updates": [0],
		}
	)
	if not selected and prototype.has_method("select_skill_choice"):
		selected = prototype.select_skill_choice(1)
		await process_frame
	_check(
		"Tactical Vamp communicates and commits a visible Skill choice",
		{
			&"cadence_before_selection": module.get_cadence(),
			&"panel_exists": skill_panel != null,
			&"panel_visible_before_selection": selection_snapshot.get(&"visible", false),
			&"choice_ids": selection_snapshot.get(&"choice_ids", []),
			&"first_communicates_interaction": first_option != null \
				and "Rising single-note run" in first_option.text,
			&"first_communicates_effect": first_option != null \
				and "Contribute Groove" in first_option.text,
			&"second_communicates_interaction": second_option != null \
				and "Measured chord pulses" in second_option.text,
			&"second_communicates_effect": second_option != null \
				and "Restore 20 Composure" in second_option.text,
			&"selected": selected,
			&"selected_skill_id": module.get_state().get(&"selected_skill_id", &""),
			&"panel_hidden_after_selection": skill_panel != null and not skill_panel.visible,
		},
		{
			&"cadence_before_selection": 4,
			&"panel_exists": true,
			&"panel_visible_before_selection": true,
			&"choice_ids": [&"bright_motif", &"steadying_harmony"],
			&"first_communicates_interaction": true,
			&"first_communicates_effect": true,
			&"second_communicates_interaction": true,
			&"second_communicates_effect": true,
			&"selected": true,
			&"selected_skill_id": &"steadying_harmony",
			&"panel_hidden_after_selection": true,
		}
	)
	beat_clock.beat.emit(13)
	_check(
		"Skill count-in guidance prepares for Character Performance, not Enemy Phrase",
		{
			&"instruction": hud.get_node("InstructionPanel/InstructionLabel").text,
			&"count_in_updates": skill_count_in_updates,
		},
		{
			&"instruction": "Choice locked. Listen for the selected Character Performance.",
			&"count_in_updates": [0, 1],
		}
	)
	for beat_number in range(14, 18):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var highway = hud.get_node("ResponseNoteHighway")
	var performance_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check(
		"the four-lane board presents the selected Skill's authored interaction",
		{
			&"cadence": module.get_cadence(),
			&"hud_cadence": hud.get_node("CadencePanel/CadenceLabel").text,
			&"hud_mode": hud.get_node("CadencePanel/ModeLabel").text,
			&"highway_active": performance_snapshot[&"active"],
			&"target_count": performance_snapshot[&"targets"].size(),
			&"chord_group_count": performance_snapshot[&"chord_groups"].size(),
		},
		{
			&"cadence": 5,
			&"hud_cadence": "Character Performance",
			&"hud_mode": "PERFORM - INPUT ACTIVE",
			&"highway_active": true,
			&"target_count": 16,
			&"chord_group_count": 7,
		}
	)
	var first_performance_target: Dictionary = module.get_character_performance_presentation()[
		&"targets"
	][0]
	module.submit_character_performance_input(
		first_performance_target[&"expected_action"],
		float(first_performance_target[&"due_beat"]) + 0.5
	)
	var graded_highway_snapshot: Dictionary = highway.get_presentation_snapshot()
	var feedback_adapter = prototype.get_node("ResponsePerformanceFeedback")
	var audio_snapshot: Dictionary = feedback_adapter.get_feedback_snapshot()
	var routed_events: Array = audio_snapshot[&"routed_events"]
	var routed_event: Dictionary = routed_events[-1] if not routed_events.is_empty() else {}
	_check(
		"Character Performance inputs receive visual, text, and audible feedback",
		{
			&"lane_feedback": graded_highway_snapshot[&"lane_feedback"].get(
				&"left",
				{}
			).get(&"grade_name", &""),
			&"hud_feedback": hud.get_node("FeedbackPanel/NoteFeedbackLabel").text,
			&"audio_lane": routed_event.get(&"lane", &""),
			&"audio_quality": routed_event.get(&"quality_band", &""),
		},
		{
			&"lane_feedback": &"miss",
			&"hud_feedback": "NOTE  MISS  +230.8 ms",
			&"audio_lane": &"left",
			&"audio_quality": &"missed",
		}
	)

	prototype.teardown()
	prototype.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
