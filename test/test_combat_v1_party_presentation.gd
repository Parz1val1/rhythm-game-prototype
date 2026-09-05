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
	var feedback_adapter = prototype.get_node("ResponsePerformanceFeedback")
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
	var luthier_targets: Array = module.get_character_performance_presentation()[&"targets"]
	var first_luthier_target: Dictionary = luthier_targets[0]
	module.submit_character_performance_input(
		first_luthier_target[&"expected_action"],
		first_luthier_target[&"due_beat"]
	)
	await process_frame
	var luthier_events: Array = feedback_adapter.get_feedback_snapshot()[&"routed_events"]
	var luthier_audio_event: Dictionary = luthier_events[-1] \
		if not luthier_events.is_empty() else {}
	for target_index in range(1, luthier_targets.size()):
		var target: Dictionary = luthier_targets[target_index]
		module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	while module.get_cadence() == module.Cadence.CHARACTER_PERFORMANCE \
			and beat_number < 64:
		beat_clock.beat.emit(beat_number)
		beat_number += 1
	var beatrice_selection_facts: Dictionary = {}
	if module.get_cadence() == module.Cadence.TACTICAL_VAMP \
			and module.get_state()[&"active_character_id"] == &"beatrice_styx":
		var playtest_session = prototype.get("_session_state")
		playtest_session.spend_inspiration(&"beatrice_styx", 11.0)
		var beatrice_choices: Array = module.get_skill_choices()
		beatrice_selection_facts = {
			&"inspiration": module.get_state()[&"inspiration"],
			&"cost": beatrice_choices[1][&"inspiration_cost"],
			&"affordable": beatrice_choices[1][&"affordable"],
			&"selected": prototype.select_skill_choice(1),
			&"remaining": module.get_state()[&"inspiration"],
		}
	while module.get_cadence() != module.Cadence.CHARACTER_PERFORMANCE \
			and beat_number < 80:
		beat_clock.beat.emit(beat_number)
		beat_number += 1
	await process_frame
	_check(
		"39 visible Inspiration can commit the 20-cost Syncopated Fill",
		beatrice_selection_facts,
		{
			&"inspiration": 39.0,
			&"cost": 20.0,
			&"affordable": true,
			&"selected": true,
			&"remaining": 19.0,
		}
	)

	var character_label: Label = hud.get_node_or_null("CadencePanel/CharacterLabel")
	var highway_snapshot: Dictionary = highway.get_presentation_snapshot()
	var state: Dictionary = module.get_state()
	var presented_actions: Array[StringName] = []
	for target in highway_snapshot[&"targets"]:
		var action: StringName = target[&"expected_action"]
		if action not in presented_actions:
			presented_actions.append(action)
	var first_ring: Dictionary = highway_snapshot[&"targets"][0] \
		if not highway_snapshot[&"targets"].is_empty() else {}
	var beat_strip: Dictionary = highway_snapshot.get(&"beat_strip", {})
	var cue_role_counts := {
		&"active": 0,
		&"preview": 0,
		&"hidden": 0,
	}
	for target in highway_snapshot[&"targets"]:
		var cue_role: StringName = target.get(&"cue_role", &"hidden")
		cue_role_counts[cue_role] = int(cue_role_counts.get(cue_role, 0)) + 1
	_check(
		"Beatrice exposes one clear drum cue, one preview, and a compact four-beat pulse",
		{
			&"active": beat_strip.get(&"active", false),
			&"cell_count": beat_strip.get(&"cells", []).size(),
			&"downbeat_cell": beat_strip.get(&"downbeat_cell", -1),
			&"current_cell": beat_strip.get(&"current_cell", -1),
			&"beat_fraction": beat_strip.get(&"beat_fraction", -1.0),
			&"current_action": beat_strip.get(&"current_action", &""),
			&"next_action": beat_strip.get(&"next_action", &""),
			&"subdivision_visible": beat_strip.get(&"subdivision", {}).get(
				&"visible",
				false
			),
			&"cue_role_counts": cue_role_counts,
			&"wheel_removed": not highway_snapshot.has(&"measure_wheel"),
		},
		{
			&"active": true,
			&"cell_count": 4,
			&"downbeat_cell": 0,
			&"current_cell": 0,
			&"beat_fraction": 0.0,
			&"current_action": &"drum_left",
			&"next_action": &"drum_right",
			&"subdivision_visible": false,
			&"cue_role_counts": {
				&"active": 1,
				&"preview": 1,
				&"hidden": 11,
			},
			&"wheel_removed": true,
		}
	)
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
			&"starting_ring_radius": first_ring.get(&"radius", 0.0),
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
			&"presentation_style": &"percussion_pulse",
			&"presented_actions": [&"drum_left", &"drum_right"],
			&"target_count": 13,
			&"starting_ring_radius": 88.0,
			&"stale_feedback": 0,
			&"note_feedback": "NOTE  WAITING",
			&"instruction": "Use F/J or the left/right triggers for Beatrice's two-hand drum language.",
		}
	)

	var initial_clock_snapshot: Dictionary = highway.get_presentation_snapshot()
	beat_clock.stop()
	beat_clock.beat_position = 0.5
	await process_frame
	var half_beat_clock_snapshot: Dictionary = highway.get_presentation_snapshot()
	beat_clock.beat_position = 0.0
	beat_clock.beat.emit(beat_number)
	beat_number += 1
	await process_frame
	var one_beat_clock_snapshot: Dictionary = highway.get_presentation_snapshot()
	_check(
		"the four-beat pulse advances while one active halo contracts",
		{
			&"initial_cell": initial_clock_snapshot[&"beat_strip"][&"current_cell"],
			&"initial_fraction": initial_clock_snapshot[&"beat_strip"][&"beat_fraction"],
			&"initial_halo_visible": initial_clock_snapshot[&"targets"][0][&"visible"],
			&"initial_halo_radius": initial_clock_snapshot[&"targets"][0][&"radius"],
			&"half_beat_cell": half_beat_clock_snapshot[&"beat_strip"][&"current_cell"],
			&"half_beat_fraction": half_beat_clock_snapshot[&"beat_strip"][&"beat_fraction"],
			&"half_beat_halo_radius": half_beat_clock_snapshot[&"targets"][0][&"radius"],
			&"one_beat_cell": one_beat_clock_snapshot[&"beat_strip"][&"current_cell"],
			&"one_beat_fraction": one_beat_clock_snapshot[&"beat_strip"][&"beat_fraction"],
			&"one_beat_halo_radius": one_beat_clock_snapshot[&"targets"][0][&"radius"],
		},
		{
			&"initial_cell": 0,
			&"initial_fraction": 0.0,
			&"initial_halo_visible": true,
			&"initial_halo_radius": 88.0,
			&"half_beat_cell": 0,
			&"half_beat_fraction": 0.5,
			&"half_beat_halo_radius": 70.5,
			&"one_beat_cell": 1,
			&"one_beat_fraction": 0.0,
			&"one_beat_halo_radius": 53.0,
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
	var subdivided_cue_snapshot: Dictionary = highway.get_presentation_snapshot()
	var subdivision: Dictionary = subdivided_cue_snapshot[&"beat_strip"][&"subdivision"]
	var routed_events: Array = feedback_adapter.get_feedback_snapshot()[&"routed_events"]
	var beatrice_audio_event: Dictionary = routed_events[-1] \
		if not routed_events.is_empty() else {}
	_check(
		"each party member's accepted Skill input starts their instrument voice",
		{
			&"luthier": _get_skill_audio_facts(luthier_audio_event),
			&"beatrice": _get_skill_audio_facts(beatrice_audio_event),
		},
		{
			&"luthier": {
				&"source": &"character_performance",
				&"skill_id": &"bright_motif",
				&"instrument_name": "Lute",
				&"audio_bus": &"Strings",
				&"timbre": &"clear_pluck",
				&"quality": &"strong",
				&"volume_db": -3.0,
				&"voice_started": true,
			},
			&"beatrice": {
				&"source": &"character_performance",
				&"skill_id": &"syncopated_fill",
				&"instrument_name": "Drums",
				&"audio_bus": &"Drums",
				&"timbre": &"drum_hit",
				&"quality": &"strong",
				&"volume_db": -3.0,
				&"voice_started": true,
			},
		}
	)
	_check(
		"subdivision timing appears only when the current drum cue needs it",
		{
			&"current_action": subdivided_cue_snapshot[&"beat_strip"][&"current_action"],
			&"visible": subdivision[&"visible"],
			&"cell_index": subdivision.get(&"cell_index", -1),
			&"fraction": subdivision.get(&"fraction", -1.0),
		},
		{
			&"current_action": &"drum_right",
			&"visible": true,
			&"cell_index": 2,
			&"fraction": 0.75,
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

func _get_skill_audio_facts(event: Dictionary) -> Dictionary:
	return {
		&"source": event.get(&"source", &""),
		&"skill_id": event.get(&"skill_id", &""),
		&"instrument_name": event.get(&"instrument_name", ""),
		&"audio_bus": event.get(&"audio_bus", &""),
		&"timbre": event.get(&"timbre", &""),
		&"quality": event.get(&"quality_band", &""),
		&"volume_db": event.get(&"volume_db", -INF),
		&"voice_started": event.get(&"voice_started", false),
	}

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
