# Verifies musical contributions and opponent preferences through CombatV1's public seam.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	await process_frame
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 musical-preference tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var beatrice = _load_isolated_party_template(
		"res://combat_v1/party/beatrice_styx.tres"
	)
	var session = CombatV1Script.SessionState.new()
	var module = CombatV1Script.new()
	root.add_child(module)

	module.bind_party(session, [beatrice])
	module.setup(beat_clock, rhythm_input, opponent, 1)
	var hud = load("res://combat_v1/combat_v1_hud.tscn").instantiate()
	root.add_child(hud)
	hud.setup(module)
	var initial_preference_label: Label = hud.get_node_or_null(
		"PreferencePanel/KnowledgeLabel"
	)
	_check(
		"the HUD presents all opponent preferences as unknown before experimentation",
		initial_preference_label.text if initial_preference_label != null else "",
		"RHYTHM  UNKNOWN\nMELODY  UNKNOWN\nHARMONY  UNKNOWN"
	)
	_check(
		"opponent preferences begin unknown before the player experiments",
		module.get_state().get(&"opponent_preference_knowledge", {}),
		{
			&"Rhythm": &"unknown",
			&"Melody": &"unknown",
			&"Harmony": &"unknown",
		}
	)
	module.start()
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	module.select_skill(&"driving_backbeat")
	for beat_number in range(9, 14):
		beat_clock.beat.emit(beat_number)
	for target in module.get_character_performance_presentation()[&"targets"]:
		module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	for beat_number in range(14, 22):
		beat_clock.beat.emit(beat_number)

	var state: Dictionary = module.get_state()
	_check(
		"perfect execution of weak Rhythm earns reduced Groove without losing Composure",
		{
			&"groove": state[&"groove"],
			&"composure": state[&"composure"],
		},
		{
			# The perfect Response earns 10 Groove and raises Multiplier to 1.5.
			# Weak Rhythm then earns 10 * 0.5 * 1.5 = 7.5 Groove.
			&"groove": 17.5,
			&"composure": 100.0,
		}
	)
	_check(
		"trying Rhythm reveals weak preference separately from the perfect execution grade",
		{
			&"knowledge": state.get(&"opponent_preference_knowledge", {}),
			&"grade": state[&"character_performance_summary"].get(&"grade_name", &""),
			&"preference": state[&"character_performance_summary"].get(
				&"preference_label",
				&""
			),
		},
		{
			&"knowledge": {
				&"Rhythm": &"weak",
				&"Melody": &"unknown",
				&"Harmony": &"unknown",
			},
			&"grade": &"perfect",
			&"preference": &"weak",
		}
	)
	var revealed_preference_label: Label = hud.get_node_or_null(
		"PreferencePanel/KnowledgeLabel"
	)
	var opponent_response_label: Label = hud.get_node_or_null(
		"PreferencePanel/LastResponseLabel"
	)
	_check(
		"the HUD keeps execution and discovered opponent response visibly separate",
		{
			&"execution": hud.get_node("FeedbackPanel/PhraseFeedbackLabel").text,
			&"knowledge": revealed_preference_label.text \
				if revealed_preference_label != null else "",
			&"opponent_response": opponent_response_label.text \
				if opponent_response_label != null else "",
		},
		{
			&"execution": "PHRASE  PERFECT",
			&"knowledge": "RHYTHM  WEAK\nMELODY  UNKNOWN\nHARMONY  UNKNOWN",
			&"opponent_response": "LAST SKILL RESPONSE  WEAK",
		}
	)

	hud.teardown()
	hud.free()
	module.teardown()
	module.free()

	beatrice = _load_isolated_party_template(
		"res://combat_v1/party/beatrice_styx.tres"
	)
	session = CombatV1Script.SessionState.new()
	module = CombatV1Script.new()
	root.add_child(module)
	module.bind_party(session, [beatrice])
	module.setup(beat_clock, rhythm_input, opponent, 1)
	var hybrid_hud = load("res://combat_v1/combat_v1_hud.tscn").instantiate()
	root.add_child(hybrid_hud)
	hybrid_hud.setup(module)
	var syncopated_choice: Dictionary = module.get_skill_choices()[1]
	_check(
		"a Skill can expose multiple authored musical contributions",
		syncopated_choice.get(&"musical_contributions", []),
		[&"Rhythm", &"Harmony"]
	)
	_check(
		"the Tactical Vamp menu names every contribution on a hybrid Skill",
		"RHYTHM + HARMONY" in hybrid_hud.get_node("SkillPanel/SecondSkill").text,
		true
	)
	module.start()
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	module.apply_performance_result(
		CombatV1Script.Execution.MISTAKE,
		CombatV1Script.TacticalEffectiveness.EFFECTIVE
	)
	module.select_skill(&"syncopated_fill")
	for beat_number in range(9, 14):
		beat_clock.beat.emit(beat_number)
	for target in module.get_character_performance_presentation()[&"targets"]:
		module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	for beat_number in range(14, 26):
		beat_clock.beat.emit(beat_number)
	state = module.get_state()
	_check(
		"a hybrid contribution averages its opponent preference weights",
		state[&"groove"],
		17.5
	)
	_check(
		"Beatrice's hybrid support choice restores Composure despite weak Rhythm preference",
		state[&"composure"],
		100.0
	)
	_check(
		"trying a hybrid Skill reveals each of its contribution preferences",
		state.get(&"opponent_preference_knowledge", {}),
		{
			&"Rhythm": &"weak",
			&"Melody": &"unknown",
			&"Harmony": &"neutral",
		}
	)

	hybrid_hud.teardown()
	hybrid_hud.free()
	module.teardown()
	module.free()

	var luthier = _load_isolated_party_template(
		"res://combat_v1/party/luthier_frett.tres"
	)
	session = CombatV1Script.SessionState.new()
	module = CombatV1Script.new()
	root.add_child(module)
	module.bind_party(session, [luthier])
	module.setup(beat_clock, rhythm_input, opponent, 1)
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
	state = module.get_state()
	_check(
		"a strong Melody preference increases Groove and becomes known through play",
		{
			&"groove": state[&"groove"],
			&"melody_preference": state[&"opponent_preference_knowledge"][&"Melody"],
			&"preference_feedback": state[&"character_performance_summary"][
				&"preference_label"
			],
		},
		{
			# The perfect Response earns 10 and raises Multiplier to 1.5.
			# Strong Melody then earns 10 * 1.5 * 1.5 = 22.5 Groove.
			&"groove": 32.5,
			&"melody_preference": &"strong",
			&"preference_feedback": &"strong",
		}
	)
	module.teardown()
	module.free()
	luthier = null
	module = null
	session = null
	beatrice = null
	opponent = null
	CombatV1Script = null
	print("=== done ===")

func _load_isolated_party_template(path: String) -> Resource:
	var isolated: Resource = load(path).duplicate(false)
	isolated.set("input_profile", isolated.get("input_profile").duplicate(true))
	isolated.set("presentation_style", isolated.get("presentation_style").duplicate(true))
	var isolated_skills: Array = isolated.get("skills").duplicate()
	for skill_index in range(isolated_skills.size()):
		isolated_skills[skill_index] = isolated_skills[skill_index].duplicate(true)
	isolated.set("skills", isolated_skills)
	return isolated

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
