# Verifies active party identity through the standalone Combat V1 presentation seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	await _run()
	await process_frame
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Party Presentation tests ===")
	var prototype = load("res://combat_v1/combat_v1_prototype.tscn").instantiate()
	root.add_child(prototype)
	await process_frame
	var module = prototype.get("_combat_v1")
	var hud = prototype.get_node("CombatV1HUD")
	var highway = hud.get_node("ResponseNoteHighway")
	var beat_clock: Node = root.get_node("BeatClock")
	var beat_number := 1

	while module.get_cadence() != module.Cadence.RESPONSE and beat_number < 32:
		beat_clock.beat.emit(beat_number)
		beat_number += 1
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(module.Intent.SUBMIT_RESPONSE)
	prototype.select_skill_choice(0)
	while module.get_cadence() != module.Cadence.CHARACTER_PERFORMANCE \
			and beat_number < 48:
		beat_clock.beat.emit(beat_number)
		beat_number += 1
	for target in module.get_character_performance_presentation()[&"targets"]:
		module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	while module.get_cadence() == module.Cadence.CHARACTER_PERFORMANCE \
			and beat_number < 64:
		beat_clock.beat.emit(beat_number)
		beat_number += 1
	if module.get_cadence() == module.Cadence.TACTICAL_VAMP \
			and module.get_state()[&"active_character_id"] == &"beatrice_styx":
		prototype.select_skill_choice(0)
	while module.get_cadence() != module.Cadence.CHARACTER_PERFORMANCE \
			and beat_number < 80:
		beat_clock.beat.emit(beat_number)
		beat_number += 1
	await process_frame

	var character_label: Label = hud.get_node_or_null("CadencePanel/CharacterLabel")
	var highway_snapshot: Dictionary = highway.get_presentation_snapshot()
	var state: Dictionary = module.get_state()
	var presented_actions: Array[StringName] = []
	for target in highway_snapshot[&"targets"]:
		var action: StringName = target[&"expected_action"]
		if action not in presented_actions:
			presented_actions.append(action)
	_check(
		"switching to Beatrice refreshes identity, choices, controls, and lane presentation",
		{
			&"party_size": state.get(&"party_order", []).size(),
			&"active_character_id": state[&"active_character_id"],
			&"character_label": character_label.text if character_label != null else "",
			&"skill_ids": hud.get_skill_selection_snapshot()[&"choice_ids"],
			&"lane_order": highway_snapshot[&"lane_order"],
			&"presentation_style": highway_snapshot.get(&"presentation_style", &""),
			&"presented_actions": presented_actions,
			&"target_count": highway_snapshot[&"targets"].size(),
			&"stale_feedback": highway_snapshot[&"lane_feedback"].size(),
			&"note_feedback": hud.get_node("FeedbackPanel/NoteFeedbackLabel").text,
			&"instruction": hud.get_node("InstructionPanel/InstructionLabel").text,
		},
		{
			&"party_size": 2,
			&"active_character_id": &"beatrice_styx",
			&"character_label": "BEATRICE STYX  •  DRUMS",
			&"skill_ids": [&"driving_backbeat", &"syncopated_fill"],
			&"lane_order": [&"drum_left", &"drum_right"],
			&"presentation_style": &"closing_circles",
			&"presented_actions": [&"drum_left", &"drum_right"],
			&"target_count": 11,
			&"stale_feedback": 0,
			&"note_feedback": "NOTE  WAITING",
			&"instruction": "Use F/J or the left/right triggers for Beatrice's two-hand drum language.",
		}
	)

	var first_drum_target: Dictionary = module.get_character_performance_presentation()[
		&"targets"
	][0]
	module.submit_character_performance_input(
		first_drum_target[&"expected_action"],
		first_drum_target[&"due_beat"]
	)
	await process_frame
	var feedback_adapter = prototype.get_node("ResponsePerformanceFeedback")
	var routed_events: Array = feedback_adapter.get_feedback_snapshot()[&"routed_events"]
	var routed_event: Dictionary = routed_events[-1] if not routed_events.is_empty() else {}
	_check(
		"Beatrice's accepted input uses her drum voice and instrument bus",
		{
			&"lane": routed_event.get(&"lane", &""),
			&"instrument_name": routed_event.get(&"instrument_name", ""),
			&"audio_bus": routed_event.get(&"audio_bus", &""),
			&"timbre": routed_event.get(&"timbre", &""),
			&"quality": routed_event.get(&"quality_band", &""),
		},
		{
			&"lane": &"drum_left",
			&"instrument_name": "Drums",
			&"audio_bus": &"Drums",
			&"timbre": &"drum_hit",
			&"quality": &"strong",
		}
	)

	prototype.teardown()
	prototype.free()
	prototype = null
	module = null
	hud = null
	highway = null
	feedback_adapter = null
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
