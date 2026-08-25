# Verifies character-owned Inspiration through the public Combat V1 seams.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Inspiration tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)
	module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.start()
	var state: Dictionary = module.get_state()
	_check(
		"Inspiration belongs to the active character while Multiplier stays shared",
		{
			&"character_id": state.get(&"active_character_id", &""),
			&"character_name": state.get(&"active_character_name", ""),
			&"inspiration": state.get(&"inspiration", -1.0),
			&"min_inspiration": state.get(&"min_inspiration", -1.0),
			&"max_inspiration": state.get(&"max_inspiration", -1.0),
			&"multiplier": state[&"multiplier"],
		},
		{
			&"character_id": &"luthier_frett",
			&"character_name": "Luthier Frett",
			&"inspiration": 50.0,
			&"min_inspiration": 20.0,
			&"max_inspiration": 100.0,
			&"multiplier": 1.0,
		}
	)
	var party_session = CombatV1Script.SessionState.new()
	var luthier_config = CombatV1Script.InspirationConfig.new()
	luthier_config.max_inspiration = 30.0
	luthier_config.min_inspiration = 10.0
	luthier_config.initial_inspiration = 15.0
	var beatrice_config = CombatV1Script.InspirationConfig.new()
	beatrice_config.max_inspiration = 50.0
	beatrice_config.min_inspiration = 5.0
	beatrice_config.initial_inspiration = 12.0
	party_session.register_character(&"luthier_frett", "Luthier Frett", luthier_config)
	party_session.register_character(&"beatrice_styx", "Beatrice Styx", beatrice_config)
	var good_note_inspiration := -1.0
	var perfect_note_inspiration := -1.0
	if party_session.has_method("record_performance_grade"):
		party_session.record_performance_grade(&"luthier_frett", &"good", &"note")
		good_note_inspiration = party_session.get_character_state(
			&"luthier_frett"
		)[&"inspiration"]
		party_session.record_performance_grade(&"luthier_frett", &"perfect", &"note")
		perfect_note_inspiration = party_session.get_character_state(
			&"luthier_frett"
		)[&"inspiration"]
		party_session.record_performance_grade(&"luthier_frett", &"good", &"phrase")
	_check(
		"ordinary and Perfect performances generate bounded, character-specific Inspiration",
		{
			&"good_note": good_note_inspiration,
			&"perfect_note": perfect_note_inspiration,
			&"luthier": party_session.get_character_state(&"luthier_frett"),
			&"beatrice": party_session.get_character_state(&"beatrice_styx"),
		},
		{
			&"good_note": 18.0,
			&"perfect_note": 23.0,
			&"luthier": {
				&"character_id": &"luthier_frett",
				&"character_name": "Luthier Frett",
				&"inspiration": 30.0,
				&"min_inspiration": 10.0,
				&"max_inspiration": 30.0,
			},
			&"beatrice": {
				&"character_id": &"beatrice_styx",
				&"character_name": "Beatrice Styx",
				&"inspiration": 12.0,
				&"min_inspiration": 5.0,
				&"max_inspiration": 50.0,
			},
		}
	)
	var affordable_spend := false
	var inspiration_after_spend := -1.0
	var below_floor_spend := true
	var negative_spend := true
	if party_session.has_method("spend_inspiration"):
		affordable_spend = party_session.spend_inspiration(&"luthier_frett", 15.0)
		inspiration_after_spend = party_session.get_character_state(
			&"luthier_frett"
		)[&"inspiration"]
		below_floor_spend = party_session.spend_inspiration(&"luthier_frett", 6.0)
		negative_spend = party_session.spend_inspiration(&"luthier_frett", -1.0)
	_check(
		"spending is atomic, honors the configured floor, and never changes another character",
		{
			&"accepted": affordable_spend,
			&"after_spend": inspiration_after_spend,
			&"below_floor_accepted": below_floor_spend,
			&"negative_accepted": negative_spend,
			&"after_rejection": party_session.get_character_state(
				&"luthier_frett"
			)[&"inspiration"],
			&"other_character": party_session.get_character_state(
				&"beatrice_styx"
			)[&"inspiration"],
		},
		{
			&"accepted": true,
			&"after_spend": 15.0,
			&"below_floor_accepted": false,
			&"negative_accepted": false,
			&"after_rejection": 15.0,
			&"other_character": 12.0,
		}
	)
	var inspiration_updates: Array[float] = []
	if module.has_signal("inspiration_changed"):
		Signal(module, &"inspiration_changed").connect(
			func(updated_state: Dictionary) -> void:
				inspiration_updates.append(float(updated_state[&"inspiration"]))
		)
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	var response_targets: Array = module.get_response_presentation()[&"targets"]
	for target_index in range(response_targets.size()):
		var target: Dictionary = response_targets[target_index]
		var offset_beats := 0.2 if target_index == 1 else 0.0
		module.submit_response_input(
			target[&"expected_action"],
			float(target[&"due_beat"]) + offset_beats
		)
	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	_check(
		"live Response notes and strong phrase grades publish circulating Inspiration",
		{
			&"inspiration": module.get_state()[&"inspiration"],
			&"grade": module.get_state()[&"response_summary"].get(&"grade_name", &""),
			&"updates": inspiration_updates,
		},
		{
			&"inspiration": 94.0,
			&"grade": &"great",
			&"updates": [55.0, 58.0, 63.0, 68.0, 73.0, 78.0, 94.0],
		}
	)
	var skill_choices: Array = module.get_skill_choices()
	var chosen_skill: bool = module.select_skill(&"steadying_harmony")
	_check(
		"authored stronger Skills expose their cost and spend once at commitment",
		{
			&"basic_cost": skill_choices[0].get(&"inspiration_cost", -1.0),
			&"basic_affordable": skill_choices[0].get(&"affordable", false),
			&"stronger_cost": skill_choices[1].get(&"inspiration_cost", -1.0),
			&"stronger_affordable": skill_choices[1].get(&"affordable", false),
			&"selected": chosen_skill,
			&"selected_skill": module.get_state()[&"selected_skill_id"],
			&"after_spend": module.get_state()[&"inspiration"],
			&"published_after_spend": inspiration_updates.back(),
			&"duplicate_accepted": module.select_skill(&"steadying_harmony"),
			&"after_duplicate": module.get_state()[&"inspiration"],
		},
		{
			&"basic_cost": 0.0,
			&"basic_affordable": true,
			&"stronger_cost": 30.0,
			&"stronger_affordable": true,
			&"selected": true,
			&"selected_skill": &"steadying_harmony",
			&"after_spend": 64.0,
			&"published_after_spend": 64.0,
			&"duplicate_accepted": false,
			&"after_duplicate": 64.0,
		}
	)
	module.teardown()
	module.free()
	var unaffordable_module = CombatV1Script.new()
	root.add_child(unaffordable_module)
	if unaffordable_module.has_method("bind_session"):
		unaffordable_module.bind_session(party_session, &"luthier_frett")
	unaffordable_module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	unaffordable_module.start()
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	for target in unaffordable_module.get_response_presentation()[&"targets"]:
		unaffordable_module.submit_response_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	unaffordable_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var unavailable_choices: Array = unaffordable_module.get_skill_choices()
	var unavailable_selected: bool = unaffordable_module.select_skill(&"steadying_harmony")
	_check(
		"an unaffordable Skill never commits, spends, or leaves Tactical Vamp",
		{
			&"inspiration": unaffordable_module.get_state()[&"inspiration"],
			&"stronger_affordable": unavailable_choices[1].get(&"affordable", true),
			&"selected": unavailable_selected,
			&"selected_skill": unaffordable_module.get_state()[&"selected_skill_id"],
			&"count_in_pending": unaffordable_module.get_state()[&"next_round_pending"],
			&"cadence": unaffordable_module.get_cadence(),
			&"other_character": party_session.get_character_state(
				&"beatrice_styx"
			)[&"inspiration"],
		},
		{
			&"inspiration": 30.0,
			&"stronger_affordable": false,
			&"selected": false,
			&"selected_skill": &"",
			&"count_in_pending": false,
			&"cadence": CombatV1Script.Cadence.TACTICAL_VAMP,
			&"other_character": 12.0,
		}
	)
	unaffordable_module.teardown()
	unaffordable_module.free()
	var next_encounter = CombatV1Script.new()
	root.add_child(next_encounter)
	next_encounter.bind_session(party_session, &"luthier_frett")
	next_encounter.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	next_encounter.start()
	var next_state: Dictionary = next_encounter.get_state()
	var visible_party: Dictionary = {}
	for character_state in next_state.get(&"party_inspiration", []):
		visible_party[character_state[&"character_id"]] = character_state[&"inspiration"]
	var legacy_character = load("res://characters/luthier_frett.tres")
	_check(
		"fresh encounters preserve party Inspiration while resetting fight-local state",
		{
			&"inspiration": next_state[&"inspiration"],
			&"party": visible_party,
			&"groove": next_state[&"groove"],
			&"composure": next_state[&"composure"],
			&"multiplier": next_state[&"multiplier"],
			&"legacy_hp": legacy_character.hp,
			&"legacy_limit": legacy_character.limit_break_gauge,
		},
		{
			&"inspiration": 30.0,
			&"party": {&"luthier_frett": 30.0, &"beatrice_styx": 12.0},
			&"groove": 0.0,
			&"composure": 100.0,
			&"multiplier": 1.0,
			&"legacy_hp": 120,
			&"legacy_limit": 0.0,
		}
	)
	next_encounter.teardown()
	var restarted_session_updates: Array[Dictionary] = []
	next_encounter.inspiration_changed.connect(
		func(character_state: Dictionary) -> void:
			restarted_session_updates.append(character_state)
	)
	var restarted_encounter: bool = next_encounter.start()
	party_session.record_performance_grade(&"beatrice_styx", &"good", &"note")
	next_encounter.teardown()
	party_session.record_performance_grade(&"beatrice_styx", &"good", &"note")
	_check(
		"restarted encounters observe party changes and guarded teardown disconnects them",
		{
			&"restarted": restarted_encounter,
			&"updates": restarted_session_updates,
			&"luthier": party_session.get_character_state(
				&"luthier_frett"
			)[&"inspiration"],
			&"beatrice": party_session.get_character_state(
				&"beatrice_styx"
			)[&"inspiration"],
		},
		{
			&"restarted": true,
			&"updates": [{
				&"character_id": &"beatrice_styx",
				&"character_name": "Beatrice Styx",
				&"inspiration": 15.0,
				&"min_inspiration": 5.0,
				&"max_inspiration": 50.0,
			}],
			&"luthier": 30.0,
			&"beatrice": 18.0,
		}
	)
	next_encounter.free()
	var performance_session = CombatV1Script.SessionState.new()
	var performance_config = CombatV1Script.InspirationConfig.new()
	performance_config.max_inspiration = 90.0
	performance_config.min_inspiration = 10.0
	performance_config.initial_inspiration = 30.0
	performance_config.successful_note_gain = 1.0
	performance_config.perfect_note_bonus = 1.0
	performance_config.successful_phrase_gain = 4.0
	performance_config.perfect_phrase_bonus = 2.0
	performance_session.register_character(
		&"luthier_frett",
		"Luthier Frett",
		performance_config
	)
	var performance_module = CombatV1Script.new()
	root.add_child(performance_module)
	performance_module.bind_session(performance_session, &"luthier_frett")
	performance_module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	performance_module.start()
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	for target in performance_module.get_response_presentation()[&"targets"]:
		performance_module.submit_response_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	performance_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var before_skill: float = performance_module.get_state()[&"inspiration"]
	performance_module.select_skill(&"steadying_harmony")
	var after_skill: float = performance_module.get_state()[&"inspiration"]
	for beat_number in range(9, 14):
		root.get_node("BeatClock").beat.emit(beat_number)
	for target in performance_module.get_character_performance_presentation()[&"targets"]:
		performance_module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	var after_notes: float = performance_module.get_state()[&"inspiration"]
	for beat_number in range(14, 26):
		root.get_node("BeatClock").beat.emit(beat_number)
	_check(
		"configured Character Performance gains restore Inspiration after spending",
		{
			&"response_generation": before_skill,
			&"after_cost": after_skill,
			&"after_notes": after_notes,
			&"after_phrase": performance_module.get_state()[&"inspiration"],
			&"grade": performance_module.get_state()[&"character_performance_summary"].get(
				&"grade_name",
				&""
			),
		},
		{
			&"response_generation": 48.0,
			&"after_cost": 18.0,
			&"after_notes": 50.0,
			&"after_phrase": 56.0,
			&"grade": &"perfect",
		}
	)
	performance_module.teardown()
	performance_module.free()
	var ordinary_session = CombatV1Script.SessionState.new()
	var ordinary_config = CombatV1Script.InspirationConfig.new()
	ordinary_config.initial_inspiration = ordinary_config.min_inspiration
	ordinary_session.register_character(&"luthier_frett", "Luthier Frett", ordinary_config)
	var ordinary_module = CombatV1Script.new()
	root.add_child(ordinary_module)
	ordinary_module.bind_session(ordinary_session, &"luthier_frett")
	ordinary_module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	ordinary_module.start()
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	for target in ordinary_module.get_response_presentation()[&"targets"]:
		ordinary_module.submit_response_input(
			target[&"expected_action"],
			float(target[&"due_beat"]) + 0.2
		)
	ordinary_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	var ordinary_generated: float = ordinary_module.get_state()[&"inspiration"]
	var ordinary_affordable: bool = ordinary_module.get_skill_choices()[1][&"affordable"]
	var ordinary_selected: bool = ordinary_module.select_skill(&"steadying_harmony")
	_check(
		"one ordinary all-Good Response circulates from the floor through a stronger Skill",
		{
			&"grade": ordinary_module.get_state()[&"response_summary"][&"grade_name"],
			&"generated": ordinary_generated,
			&"affordable": ordinary_affordable,
			&"selected": ordinary_selected,
			&"after_spend": ordinary_module.get_state()[&"inspiration"],
		},
		{
			&"grade": &"good",
			&"generated": 50.0,
			&"affordable": true,
			&"selected": true,
			&"after_spend": 20.0,
		}
	)
	ordinary_module.teardown()
	ordinary_module.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
