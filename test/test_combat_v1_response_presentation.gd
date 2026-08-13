# Verifies the public, snapshot-first Response presentation seam.
extends SceneTree

var _has_failures: bool = false
var _note_results: Array[Dictionary] = []
var _announced_targets: Array[Dictionary] = []

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Response presentation tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)
	module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.response_target_announced.connect(
		func(event, expected_action: StringName) -> void:
			_announced_targets.append({
				&"expected_action": expected_action,
				&"beat_offset": event.beat_offset,
			})
	)
	module.response_note_graded.connect(func(result: Dictionary) -> void: _note_results.append(result))
	module.start()
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)

	_check(
		"CombatV1 exposes one snapshot-first Response presentation seam",
		module.has_method(&"get_response_presentation"),
		true
	)
	if module.has_method(&"get_response_presentation"):
		var presentation: Dictionary = module.call(&"get_response_presentation")
		_check("the complete phrase schedule is observable when Response begins", presentation[&"targets"].size(), 5)
		_check("the presentation identifies its BeatClock timeline", presentation[&"timeline_source"], &"BeatClock")
		_check("the provisional visual lead-in is two beats", presentation[&"visual_lead_beats"], 2.0)
		_check("the Response timeline begins before its first due target", presentation[&"timeline_position_beats"], 0.0)
		_check("the authored offset-zero target is due after the lead-in", presentation[&"targets"][0][&"due_beat"], 2.0)
		var target_ids: Array[StringName] = []
		var actions: Array[StringName] = []
		var offsets: Array[float] = []
		for target in presentation[&"targets"]:
			target_ids.append(target[&"target_id"])
			actions.append(target[&"expected_action"])
			offsets.append(target[&"beat_offset"])
		_check(
			"the complete schedule has stable round-scoped target identities",
			target_ids,
			[
				&"opening_call:1:0",
				&"opening_call:1:1",
				&"opening_call:1:2",
				&"opening_call:1:3",
				&"opening_call:1:4",
			]
		)
		_check("the schedule preserves authored beat offsets", offsets, [0.0, 0.75, 1.5, 2.5, 3.0])
		_check("the schedule maps every target into Luthier's four actions", actions, [&"up", &"right", &"down", &"left", &"up"])
		_check("the secondary text cue does not replace advance notation", _announced_targets.size(), 0)
		root.get_node("BeatClock").beat.emit(9)
		_check("the secondary text cue remains hidden before the first due beat", _announced_targets.size(), 0)
		root.get_node("BeatClock").beat.emit(10)
		_check(
			"the secondary text cue appears when the first target is scoreable",
			_announced_targets,
			[{&"expected_action": &"up", &"beat_offset": 0.0}]
		)

		var first_target: Dictionary = presentation[&"targets"][0]
		_check(
			"grading accepts the scoreable due time from the presentation",
			module.submit_response_input(first_target[&"expected_action"], first_target[&"due_beat"]),
			true
		)
		var first_result: Dictionary = _note_results[0]
		_check("the graded target keeps presentation identity", first_result[&"target_id"], first_target[&"target_id"])
		_check("the graded target keeps presentation action", first_result[&"expected_action"], first_target[&"expected_action"])
		_check("the graded target keeps authored offset", first_result[&"beat_offset"], first_target[&"beat_offset"])
		_check("the graded target keeps its scoreable due time", first_result[&"due_beat"], first_target[&"due_beat"])
		_check("the presented due time grades perfectly", first_result[&"grade_name"], &"perfect")
		for target_index in range(1, presentation[&"targets"].size()):
			var target: Dictionary = presentation[&"targets"][target_index]
			module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
		var presented_facts: Array[Dictionary] = []
		var graded_facts: Array[Dictionary] = []
		for target in presentation[&"targets"]:
			presented_facts.append({
				&"target_id": target[&"target_id"],
				&"expected_action": target[&"expected_action"],
				&"beat_offset": target[&"beat_offset"],
				&"due_beat": target[&"due_beat"],
			})
		for result in _note_results:
			graded_facts.append({
				&"target_id": result[&"target_id"],
				&"expected_action": result[&"expected_action"],
				&"beat_offset": result[&"beat_offset"],
				&"due_beat": result[&"due_beat"],
			})
		_check("visual and graded targets have exact identity/action/timing parity", graded_facts, presented_facts)

	module.teardown()
	module.free()

	var tuned_module = CombatV1Script.new()
	root.add_child(tuned_module)
	tuned_module.response_visual_lead_beats = 1.25
	tuned_module.setup(
		root.get_node("BeatClock"),
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	tuned_module.start()
	for beat_number in range(1, 9):
		root.get_node("BeatClock").beat.emit(beat_number)
	var tuned_presentation: Dictionary = tuned_module.get_response_presentation()
	_check("the visual lead-in remains configurable", tuned_presentation[&"visual_lead_beats"], 1.25)
	_check("a tuned lead-in moves the offset-zero scoreable time", tuned_presentation[&"targets"][0][&"due_beat"], 1.25)
	tuned_module.teardown()
	tuned_module.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
