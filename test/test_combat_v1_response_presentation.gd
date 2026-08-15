# Verifies the public, snapshot-first Response presentation seam.
extends SceneTree

var _has_failures: bool = false
var _note_results: Array[Dictionary] = []
var _announced_targets: Array[Dictionary] = []

class AtomicBeatClockStub extends Node:
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
		func(event, expected_actions: Array[StringName]) -> void:
			_announced_targets.append({
				&"expected_actions": expected_actions.duplicate(),
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
		_check("the complete phrase schedule expands the final chord", presentation[&"targets"].size(), 6)
		_check("the presentation identifies its BeatClock timeline", presentation[&"timeline_source"], &"BeatClock")
		_check("the provisional visual lead-in is two beats", presentation[&"visual_lead_beats"], 2.0)
		_check("the Response timeline begins before its first due target", presentation[&"timeline_position_beats"], 0.0)
		_check("the authored offset-zero target is due after handoff and lead-in", presentation[&"targets"][0][&"due_beat"], 6.0)
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
				&"opening_call:1:5",
			]
		)
		_check("the schedule preserves authored chord timing", offsets, [0.0, 0.75, 1.5, 2.5, 3.0, 3.0])
		_check("the final cue maps to two simultaneous lanes", actions, [&"up", &"right", &"down", &"left", &"up", &"right"])
		_check("the secondary text cue does not replace advance notation", _announced_targets.size(), 0)
		root.get_node("BeatClock").beat.emit(9)
		_check("the secondary text cue remains hidden before the first due beat", _announced_targets.size(), 0)
		for beat_number in range(10, 15):
			root.get_node("BeatClock").beat.emit(beat_number)
		_check(
			"the secondary text cue appears when the first target is scoreable",
			_announced_targets,
			[{&"expected_actions": [&"up"], &"beat_offset": 0.0}]
		)
		root.get_node("BeatClock").quarter_beat.emit(14, 0.75)
		root.get_node("BeatClock").beat.emit(15)
		root.get_node("BeatClock").half_beat.emit(15)
		root.get_node("BeatClock").beat.emit(16)
		root.get_node("BeatClock").half_beat.emit(16)
		root.get_node("BeatClock").beat.emit(17)
		_check(
			"the final cue announces one two-action chord",
			_announced_targets[-1] if _announced_targets.size() > 0 else {},
			{&"expected_actions": [&"up", &"right"], &"beat_offset": 3.0}
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
		for target_index in range(1, mini(4, presentation[&"targets"].size())):
			var target: Dictionary = presentation[&"targets"][target_index]
			module.submit_response_input(target[&"expected_action"], target[&"due_beat"])
		if presentation[&"targets"].size() >= 6:
			var first_chord_target: Dictionary = presentation[&"targets"][4]
			var second_chord_target: Dictionary = presentation[&"targets"][5]
			module.submit_response_input(second_chord_target[&"expected_action"], second_chord_target[&"due_beat"])
			module.submit_response_input(first_chord_target[&"expected_action"], first_chord_target[&"due_beat"])
			_check("chord inputs may arrive in either order", _note_results[-2][&"target_id"], second_chord_target[&"target_id"])
		var presented_facts: Array[Dictionary] = []
		var graded_by_id: Dictionary = {}
		for target in presentation[&"targets"]:
			presented_facts.append({
				&"target_id": target[&"target_id"],
				&"expected_action": target[&"expected_action"],
				&"beat_offset": target[&"beat_offset"],
				&"due_beat": target[&"due_beat"],
			})
		for result in _note_results:
			graded_by_id[result[&"target_id"]] = {
				&"target_id": result[&"target_id"],
				&"expected_action": result[&"expected_action"],
				&"beat_offset": result[&"beat_offset"],
				&"due_beat": result[&"due_beat"],
			}
		var graded_facts: Array[Dictionary] = []
		for target in presentation[&"targets"]:
			if graded_by_id.has(target[&"target_id"]):
				graded_facts.append(graded_by_id[target[&"target_id"]])
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
	_check("a tuned lead-in moves only its part of the offset-zero scoreable time", tuned_presentation[&"targets"][0][&"due_beat"], 5.25)
	tuned_module.teardown()
	tuned_module.free()

	var atomic_clock := AtomicBeatClockStub.new()
	root.add_child(atomic_clock)
	var atomic_module = CombatV1Script.new()
	root.add_child(atomic_module)
	atomic_module.setup(
		atomic_clock,
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	atomic_module.start()
	for beat_number in range(1, 9):
		atomic_clock.musical_position_beats = float(beat_number)
		atomic_clock.beat.emit(beat_number)
	atomic_clock.musical_position_beats = 8.98
	atomic_clock.beat_position = 0.98
	var before_boundary: float = atomic_module.get_response_presentation()[&"timeline_position_beats"]
	atomic_clock.musical_position_beats = 9.02
	atomic_clock.beat.emit(9)
	var after_boundary: float = atomic_module.get_response_presentation()[&"timeline_position_beats"]
	_check("the Response timeline is continuous before a whole-beat boundary", is_equal_approx(before_boundary, 0.98), true)
	_check("a whole-beat signal never combines its count with a stale fraction", is_equal_approx(after_boundary, 1.02), true)
	atomic_module.teardown()
	atomic_module.free()
	atomic_clock.free()

	var recovered_clock := AtomicBeatClockStub.new()
	root.add_child(recovered_clock)
	var recovered_module = CombatV1Script.new()
	root.add_child(recovered_module)
	recovered_module.setup(
		recovered_clock,
		root.get_node("RhythmInput"),
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	recovered_module.start()
	for beat_number in range(1, 8):
		recovered_clock.musical_position_beats = float(beat_number)
		recovered_clock.beat.emit(beat_number)
	recovered_clock.musical_position_beats = 10.2
	for recovered_beat_number in range(8, 11):
		recovered_clock.beat.emit(recovered_beat_number)
	_check(
		"late-frame boundary recovery keeps the absolute Response position",
		is_equal_approx(
			float(recovered_module.get_response_presentation()[&"timeline_position_beats"]),
			2.2
		),
		true
	)
	recovered_module.teardown()
	recovered_module.free()
	recovered_clock.free()
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
