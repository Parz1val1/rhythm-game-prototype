# Verifies ordered party Character Performances through CombatV1's public seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	await process_frame
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Party Performance tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var luthier = _load_isolated_party_template(
		"res://combat_v1/party/luthier_frett.tres"
	)
	var beatrice = _load_isolated_party_template(
		"res://combat_v1/party/beatrice_styx.tres"
	)
	var session = CombatV1Script.SessionState.new()
	var module = CombatV1Script.new()
	root.add_child(module)

	var bound := false
	if module.has_method(&"bind_party") and luthier != null and beatrice != null:
		bound = module.bind_party(session, [luthier, beatrice])
	luthier.display_name = "Mutated Caller Template"
	luthier.input_profile.input_map.clear()
	luthier.presentation_style.instrument_name = "Mutated Instrument"
	luthier.skills[0].skill_id = &"mutated_luthier_skill"
	beatrice.input_profile.input_map.clear()
	beatrice.presentation_style.instrument_name = "Mutated Drums"
	beatrice.skills[0].skill_id = &"mutated_beatrice_skill"
	module.setup(beat_clock, rhythm_input, opponent, 1)
	var state: Dictionary = module.get_state()
	var choice_ids: Array[StringName] = []
	for choice in module.get_skill_choices():
		choice_ids.append(choice[&"skill_id"])
	var party_order: Array[StringName] = []
	for member in state.get(&"party_order", []):
		party_order.append(member.get(&"character_id", &""))

	_check(
		"binding an authored party activates the first member's complete performance identity",
		{
			&"bound": bound,
			&"party_order": party_order,
			&"active_character_id": state.get(&"active_character_id", &""),
			&"active_character_name": state.get(&"active_character_name", ""),
			&"rhythm_language": state.get(&"rhythm_language", &""),
			&"instrument_name": state.get(&"instrument_name", ""),
			&"evaluator_id": state.get(&"evaluator_id", &""),
			&"scoring_mode": state.get(&"scoring_mode", &""),
			&"skill_ids": choice_ids,
			&"party_inspiration_count": state.get(&"party_inspiration", []).size(),
			&"luthier_input_allowed": rhythm_input.is_input_allowed(&"up"),
			&"beatrice_input_blocked": not rhythm_input.is_input_allowed(&"drum_left"),
		},
		{
			&"bound": true,
			&"party_order": [&"luthier_frett", &"beatrice_styx"],
			&"active_character_id": &"luthier_frett",
			&"active_character_name": "Luthier Frett",
			&"rhythm_language": &"melodic_strings",
			&"instrument_name": "Lute",
			&"evaluator_id": &"luthier_pitch",
			&"scoring_mode": &"pitch",
			&"skill_ids": [&"bright_motif", &"steadying_harmony"],
			&"party_inspiration_count": 2,
			&"luthier_input_allowed": true,
			&"beatrice_input_blocked": true,
		}
	)

	module.start()
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	module.select_skill(&"bright_motif")
	for beat_number in range(9, 14):
		beat_clock.beat.emit(beat_number)
	for target in module.get_character_performance_presentation()[&"targets"]:
		module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	for beat_number in range(14, 22):
		beat_clock.beat.emit(beat_number)

	var switched_state: Dictionary = module.get_state()
	var beatrice_choice_ids: Array[StringName] = []
	for choice in module.get_skill_choices():
		beatrice_choice_ids.append(choice[&"skill_id"])
	_check(
		"completing Luthier's performance switches every active seam to Beatrice",
		{
			&"cadence": switched_state[&"cadence"],
			&"active_character_id": switched_state[&"active_character_id"],
			&"active_party_index": switched_state.get(&"active_party_index", -1),
			&"rhythm_language": switched_state.get(&"rhythm_language", &""),
			&"instrument_name": switched_state.get(&"instrument_name", ""),
			&"evaluator_id": switched_state.get(&"evaluator_id", &""),
			&"scoring_mode": switched_state.get(&"scoring_mode", &""),
			&"inspiration": switched_state[&"inspiration"],
			&"skill_ids": beatrice_choice_ids,
			&"luthier_input_blocked": not rhythm_input.is_input_allowed(&"up"),
			&"beatrice_input_allowed": rhythm_input.is_input_allowed(&"drum_left"),
			&"stale_performance_targets": module.get_character_performance_presentation()[
				&"targets"
			].size(),
		},
		{
			&"cadence": CombatV1Script.Cadence.TACTICAL_VAMP,
			&"active_character_id": &"beatrice_styx",
			&"active_party_index": 1,
			&"rhythm_language": &"percussive_drums",
			&"instrument_name": "Drums",
			&"evaluator_id": &"beatrice_rhythm",
			&"scoring_mode": &"rhythm",
			&"inspiration": 50.0,
			&"skill_ids": [&"driving_backbeat", &"syncopated_fill"],
			&"luthier_input_blocked": true,
			&"beatrice_input_allowed": true,
			&"stale_performance_targets": 0,
		}
	)

	module.select_skill(&"driving_backbeat")
	for beat_number in range(22, 27):
		beat_clock.beat.emit(beat_number)
	var beatrice_presentation: Dictionary = module.get_character_performance_presentation()
	var beatrice_actions: Array[StringName] = []
	for target in beatrice_presentation[&"targets"]:
		var expected_action: StringName = target[&"expected_action"]
		if expected_action not in beatrice_actions:
			beatrice_actions.append(expected_action)
		module.submit_character_performance_input(
			expected_action,
			target[&"due_beat"]
		)
	for beat_number in range(27, 35):
		beat_clock.beat.emit(beat_number)
	var after_beatrice: Dictionary = module.get_state()
	for beat_number in range(35, 39):
		beat_clock.beat.emit(beat_number)
	var full_band_state: Dictionary = module.get_state()
	beat_clock.beat.emit(39)
	var next_phrase_state: Dictionary = module.get_state()

	_check(
		"Beatrice performs a two-hand rhythm before one Full-Band Vamp returns to Luthier",
		{
			&"performance_actions": beatrice_actions,
			&"performance_target_count": beatrice_presentation[&"targets"].size(),
			&"after_performance_cadence": after_beatrice[&"cadence"],
			&"after_performance_character": after_beatrice[&"active_character_id"],
			&"full_band_cadence": full_band_state[&"cadence"],
			&"next_cadence": next_phrase_state[&"cadence"],
			&"next_character": next_phrase_state[&"active_character_id"],
			&"next_party_index": next_phrase_state.get(&"active_party_index", -1),
			&"luthier_input_restored": rhythm_input.is_input_allowed(&"up"),
			&"beatrice_input_cleared": not rhythm_input.is_input_allowed(&"drum_left"),
			&"beat_listener_count": _connection_count(beat_clock, &"beat", module),
			&"still_running": module.is_running(),
		},
		{
			&"performance_actions": [&"drum_left", &"drum_right"],
			&"performance_target_count": 11,
			&"after_performance_cadence": CombatV1Script.Cadence.FULL_BAND_VAMP,
			&"after_performance_character": &"beatrice_styx",
			&"full_band_cadence": CombatV1Script.Cadence.FULL_BAND_VAMP,
			&"next_cadence": CombatV1Script.Cadence.ENEMY_PHRASE,
			&"next_character": &"luthier_frett",
			&"next_party_index": 0,
			&"luthier_input_restored": true,
			&"beatrice_input_cleared": true,
			&"beat_listener_count": 1,
			&"still_running": true,
		}
	)

	module.teardown()
	module.free()
	module = null
	session = null
	luthier = null
	beatrice = null
	opponent = null
	CombatV1Script = null
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])

func _connection_count(source: Node, signal_name: StringName, target: Object) -> int:
	var count := 0
	for connection in Signal(source, signal_name).get_connections():
		if connection["callable"].get_object() == target:
			count += 1
	return count

func _load_isolated_party_template(path: String) -> Resource:
	var isolated: Resource = load(path).duplicate(false)
	isolated.set("input_profile", isolated.get("input_profile").duplicate(true))
	isolated.set("presentation_style", isolated.get("presentation_style").duplicate(true))
	var isolated_skills: Array = isolated.get("skills").duplicate()
	for skill_index in range(isolated_skills.size()):
		isolated_skills[skill_index] = isolated_skills[skill_index].duplicate(true)
	isolated.set("skills", isolated_skills)
	return isolated
