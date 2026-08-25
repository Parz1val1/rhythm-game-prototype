# Verifies skill-driven Character Performance through CombatV1's public seam.
extends SceneTree

class TestBeatClock extends Node:
	signal beat(beat_number: int)
	signal half_beat(beat_number: int)
	signal quarter_beat(beat_number: int, subdivision: float)
	var bpm: float = 120.0
	var beat_position: float = 0.0
	var musical_position_beats: float = 0.0
	func is_running() -> bool:
		return true
	func get_musical_position_beats() -> float:
		return musical_position_beats

var _has_failures: bool = false
var _observed_character_performance_grade: StringName = &""
var _observed_character_performance_summary: Dictionary = {}

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Character Performance tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var beat_clock: Node = root.get_node_or_null("BeatClock")
	var rhythm_input: Node = root.get_node_or_null("RhythmInput")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	var module = CombatV1Script.new()
	root.add_child(module)
	module.setup(beat_clock, rhythm_input, opponent, 1)
	module.start()

	_advance_to_tactical_vamp(module, beat_clock)
	var choices: Array = []
	if module.has_method("get_skill_choices"):
		choices = module.get_skill_choices()
	var choice_ids: Array[StringName] = []
	for choice in choices:
		choice_ids.append(choice.get(&"skill_id", &""))
	var selected := false
	if module.has_method("select_skill"):
		selected = module.select_skill(&"bright_motif")
	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	var before_boundary: Dictionary = module.get_state()
	beat_clock.beat.emit(13)
	var after_boundary: Dictionary = module.get_state()

	_check(
		"an authored skill selection enters Character Performance on a musical boundary",
		{
			&"choice_ids": choice_ids,
			&"selected": selected,
			&"count_in_cadence": before_boundary[&"cadence"],
			&"count_in_skill": before_boundary.get(&"selected_skill_id", &""),
			&"performance_cadence": after_boundary[&"cadence"],
			&"performance_skill": after_boundary.get(&"selected_skill_id", &""),
		},
		{
			&"choice_ids": [&"bright_motif", &"steadying_harmony"],
			&"selected": true,
			&"count_in_cadence": CombatV1Script.Cadence.TACTICAL_VAMP,
			&"count_in_skill": &"bright_motif",
			&"performance_cadence": CombatV1Script.Cadence.CHARACTER_PERFORMANCE,
			&"performance_skill": &"bright_motif",
		}
	)

	var presentation: Dictionary = {}
	if module.has_method("get_character_performance_presentation"):
		presentation = module.get_character_performance_presentation()
	var target_schedule: Array[Dictionary] = []
	for target in presentation.get(&"targets", []):
		target_schedule.append({
			&"action": target[&"expected_action"],
			&"due_beat": target[&"due_beat"],
			&"group_size": target[&"group_size"],
		})
	if module.has_signal("character_performance_note_graded"):
		module.character_performance_note_graded.connect(
			func(result: Dictionary) -> void:
				_observed_character_performance_grade = result[&"grade_name"]
		)
	var first_input_accepted := false
	if module.has_method("submit_character_performance_input") \
			and not presentation.get(&"targets", []).is_empty():
		var first_target: Dictionary = presentation[&"targets"][0]
		first_input_accepted = module.submit_character_performance_input(
			first_target[&"expected_action"],
			first_target[&"due_beat"]
		)
	_check(
		"Bright Motif owns a scoreable two-bar interaction",
		{
			&"skill_id": presentation.get(&"skill_id", &""),
			&"duration_beats": presentation.get(&"duration_beats", 0),
			&"targets": target_schedule,
			&"first_input_accepted": first_input_accepted,
			&"first_grade": _observed_character_performance_grade,
		},
		{
			&"skill_id": &"bright_motif",
			&"duration_beats": 8,
			&"targets": [
				{&"action": &"up", &"due_beat": 2.0, &"group_size": 1},
				{&"action": &"right", &"due_beat": 2.75, &"group_size": 1},
				{&"action": &"down", &"due_beat": 3.5, &"group_size": 1},
				{&"action": &"left", &"due_beat": 4.0, &"group_size": 1},
				{&"action": &"up", &"due_beat": 4.5, &"group_size": 1},
				{&"action": &"right", &"due_beat": 5.0, &"group_size": 1},
				{&"action": &"down", &"due_beat": 5.5, &"group_size": 1},
				{&"action": &"left", &"due_beat": 6.0, &"group_size": 1},
				{&"action": &"up", &"due_beat": 7.0, &"group_size": 2},
				{&"action": &"right", &"due_beat": 7.0, &"group_size": 2},
			],
			&"first_input_accepted": true,
			&"first_grade": &"perfect",
		}
	)

	if module.has_signal("character_performance_completed"):
		module.character_performance_completed.connect(
			func(summary: Dictionary) -> void:
				_observed_character_performance_summary = summary
		)
	for target_index in range(1, presentation.get(&"targets", []).size()):
		var target: Dictionary = presentation[&"targets"][target_index]
		module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	for beat_number in range(14, 22):
		beat_clock.beat.emit(beat_number)
	var completed_state: Dictionary = module.get_state()
	_check(
		"Bright Motif completes at its authored duration and contributes Groove",
		{
			&"cadence": completed_state[&"cadence"],
			&"groove": completed_state[&"groove"],
			&"multiplier": completed_state[&"multiplier"],
			&"summary_skill": _observed_character_performance_summary.get(
				&"skill_id",
				&""
			),
			&"summary_grade": _observed_character_performance_summary.get(
				&"grade_name",
				&""
			),
			&"summary_notes": _observed_character_performance_summary.get(
				&"total_notes",
				0
			),
		},
		{
			&"cadence": CombatV1Script.Cadence.FULL_BAND_VAMP,
			&"groove": 25.0,
			&"multiplier": 2.0,
			&"summary_skill": &"bright_motif",
			&"summary_grade": &"perfect",
			&"summary_notes": 10,
		}
	)

	module.teardown()
	module.free()

	var support_module = CombatV1Script.new()
	root.add_child(support_module)
	support_module.setup(beat_clock, rhythm_input, opponent, 1)
	support_module.start()
	_advance_to_tactical_vamp(support_module, beat_clock)
	support_module.apply_performance_result(
		CombatV1Script.Execution.MISTAKE,
		CombatV1Script.TacticalEffectiveness.EFFECTIVE
	)
	support_module.select_skill(&"steadying_harmony")
	for beat_number in range(9, 14):
		beat_clock.beat.emit(beat_number)
	var support_presentation: Dictionary = {}
	if support_module.has_method("get_character_performance_presentation"):
		support_presentation = support_module.get_character_performance_presentation()
	var chord_schedule: Array[Dictionary] = []
	var seen_groups: Array[StringName] = []
	for target in support_presentation.get(&"targets", []):
		var group_id: StringName = target[&"group_id"]
		if group_id in seen_groups:
			continue
		seen_groups.append(group_id)
		chord_schedule.append({
			&"due_beat": target[&"due_beat"],
			&"group_size": target[&"group_size"],
		})
	_observed_character_performance_summary.clear()
	if support_module.has_signal("character_performance_completed"):
		support_module.character_performance_completed.connect(
			func(summary: Dictionary) -> void:
				_observed_character_performance_summary = summary
		)
	for target in support_presentation.get(&"targets", []):
		support_module.submit_character_performance_input(
			target[&"expected_action"],
			target[&"due_beat"]
		)
	for beat_number in range(14, 26):
		beat_clock.beat.emit(beat_number)
	var support_state: Dictionary = support_module.get_state()
	_check(
		"Steadying Harmony uses a longer chord interaction to restore Composure",
		{
			&"skill_id": support_presentation.get(&"skill_id", &""),
			&"duration_beats": support_presentation.get(&"duration_beats", 0),
			&"chord_schedule": chord_schedule,
			&"cadence": support_state[&"cadence"],
			&"groove": support_state[&"groove"],
			&"composure": support_state[&"composure"],
			&"multiplier": support_state[&"multiplier"],
			&"summary_grade": _observed_character_performance_summary.get(
				&"grade_name",
				&""
			),
		},
		{
			&"skill_id": &"steadying_harmony",
			&"duration_beats": 12,
			&"chord_schedule": [
				{&"due_beat": 2.0, &"group_size": 2},
				{&"due_beat": 3.5, &"group_size": 2},
				{&"due_beat": 5.0, &"group_size": 2},
				{&"due_beat": 6.5, &"group_size": 2},
				{&"due_beat": 8.0, &"group_size": 2},
				{&"due_beat": 9.5, &"group_size": 2},
				{&"due_beat": 11.0, &"group_size": 4},
			],
			&"cadence": CombatV1Script.Cadence.FULL_BAND_VAMP,
			&"groove": 10.0,
			&"composure": 100.0,
			&"multiplier": 1.5,
			&"summary_grade": &"perfect",
		}
	)
	var repeated_phrase_offsets: Array[float] = []
	support_module.phrase_event_announced.connect(
		func(event, _expected_actions: Array[StringName]) -> void:
			repeated_phrase_offsets.append(event.beat_offset)
	)
	for beat_number in range(26, 30):
		beat_clock.beat.emit(beat_number)
	var full_band_state: Dictionary = support_module.get_state()
	var full_band_scoring_enabled: bool = rhythm_input.is_scoring_enabled()
	beat_clock.beat.emit(30)
	_check(
		"one input-free Full-Band Vamp bar returns to Enemy Phrase",
		{
			&"vamp_cadence": full_band_state[&"cadence"],
			&"vamp_scoring_enabled": full_band_scoring_enabled,
			&"next_cadence": support_module.get_cadence(),
			&"phrase_offsets": repeated_phrase_offsets,
		},
		{
			&"vamp_cadence": CombatV1Script.Cadence.FULL_BAND_VAMP,
			&"vamp_scoring_enabled": false,
			&"next_cadence": CombatV1Script.Cadence.ENEMY_PHRASE,
			&"phrase_offsets": [0.0],
		}
	)

	support_module.teardown()
	support_module.free()

	var live_clock := TestBeatClock.new()
	root.add_child(live_clock)
	var live_module = CombatV1Script.new()
	root.add_child(live_module)
	live_module.setup(live_clock, rhythm_input, opponent, 1)
	live_module.start()
	for beat_number in range(1, 9):
		live_clock.musical_position_beats = float(beat_number)
		live_clock.beat.emit(beat_number)
	for target in live_module.get_response_presentation()[&"targets"]:
		live_module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	live_module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	live_module.select_skill(&"bright_motif")
	for beat_number in range(9, 14):
		live_clock.musical_position_beats = float(beat_number)
		live_clock.beat.emit(beat_number)
	_observed_character_performance_grade = &""
	live_module.character_performance_note_graded.connect(
		func(result: Dictionary) -> void:
			_observed_character_performance_grade = result[&"grade_name"]
	)
	live_clock.musical_position_beats = 15.0
	rhythm_input.input_scored.emit(&"up", &"perfect", 0.0, false)
	var live_presentation: Dictionary = live_module.get_character_performance_presentation()
	_check(
		"the live RhythmInput adapter grades against BeatClock performance time",
		{
			&"cadence": live_module.get_cadence(),
			&"timeline_source": live_presentation.get(&"timeline_source", &""),
			&"timeline_position_beats": live_presentation.get(
				&"timeline_position_beats",
				-1.0
			),
			&"grade": _observed_character_performance_grade,
		},
		{
			&"cadence": CombatV1Script.Cadence.CHARACTER_PERFORMANCE,
			&"timeline_source": &"BeatClock",
			&"timeline_position_beats": 2.0,
			&"grade": &"perfect",
		}
	)
	live_module.teardown()
	live_module.free()
	live_clock.free()
	print("=== done ===")

func _advance_to_tactical_vamp(module: Node, beat_clock: Node) -> void:
	for beat_number in range(1, 9):
		beat_clock.beat.emit(beat_number)
	for target in module.get_response_presentation()[&"targets"]:
		module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
	module.player_intent(0)

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
