# Verifies Enemy Phrase lane previews through the public CombatV1/highway seam.
extends SceneTree

const PhraseEvent = preload("res://combat_v1/phrase_event.gd")

var _has_failures: bool = false
var _announced_previews: Array[String] = []
var _raw_scored_inputs: int = 0

func _init() -> void:
	await process_frame
	await _run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 phrase-preview tests ===")
	var CombatV1Script = load("res://combat_v1/combat_v1.gd")
	var module = CombatV1Script.new()
	root.add_child(module)
	var beat_clock: Node = root.get_node("BeatClock")
	var rhythm_input: Node = root.get_node("RhythmInput")
	module.setup(
		beat_clock,
		rhythm_input,
		load("res://combat_v1/opponents/drum_golem.tres"),
		1
	)
	module.phrase_event_announced.connect(_on_phrase_event_announced)
	rhythm_input.input_scored.connect(_on_raw_input_scored)
	module.start()

	var highway = load("res://combat_v1/response_note_highway.tscn").instantiate()
	root.add_child(highway)
	highway.set_anchors_preset(Control.PRESET_TOP_LEFT)
	highway.size = Vector2(640.0, 300.0)
	highway.setup(module)

	for beat_number in range(1, 5):
		beat_clock.beat.emit(beat_number)
	await process_frame
	var preview: Dictionary = highway.get_presentation_snapshot().get(&"preview", {})
	_check(
		"the first authored phrase event previews its mapped highway lane",
		preview.get(&"actions", []),
		[&"up"]
	)
	_check(
		"the four-lane board remains visible throughout Enemy Phrase",
		[highway.visible, highway.get_presentation_snapshot()[&"lane_order"]],
		[true, [&"left", &"down", &"up", &"right"]]
	)
	rhythm_input._unhandled_input(_action(&"rhythm_up"))
	await create_timer(0.4).timeout
	_check(
		"the listening preview clears after its brief visual flash",
		highway.get_presentation_snapshot().get(&"preview", {}),
		{}
	)

	beat_clock.quarter_beat.emit(4, 0.75)
	beat_clock.quarter_beat.emit(4, 0.75)
	await process_frame
	_check(
		"a recovered subdivision announces one preview at its exact mapped offset",
		_announced_previews,
		["0.00:up", "0.75:right"]
	)
	highway.teardown()
	highway.teardown()
	_check(
		"guarded teardown clears an active listening preview",
		highway.get_presentation_snapshot().get(&"preview", {}),
		{}
	)
	highway.setup(module)

	beat_clock.beat.emit(5)
	beat_clock.half_beat.emit(5)
	beat_clock.beat.emit(6)
	beat_clock.half_beat.emit(6)
	beat_clock.beat.emit(7)
	await process_frame
	var final_preview: Dictionary = highway.get_presentation_snapshot()[&"preview"]
	_check(
		"every authored phrase event reaches the correct mapped preview lane group",
		_announced_previews,
		["0.00:up", "0.75:right", "1.50:down", "2.50:left", "3.00:up+right"]
	)

	beat_clock.beat.emit(8)
	await process_frame
	var response_presentation: Dictionary = module.get_response_presentation()
	var final_response_actions: Array[StringName] = []
	var preview_color: Color = final_preview[&"color"]
	for target in response_presentation[&"targets"]:
		if is_equal_approx(float(target[&"beat_offset"]), 3.0):
			final_response_actions.append(target[&"expected_action"])
	_check(
		"Together is one ghost chord with the same actions later scheduled in Response",
		{
			&"preview_actions": final_preview[&"actions"],
			&"preview_style": final_preview[&"style"],
			&"preview_translucent": preview_color.a < 1.0,
			&"response_actions": final_response_actions,
		},
		{
			&"preview_actions": [&"up", &"right"],
			&"preview_style": &"ghost",
			&"preview_translucent": true,
			&"response_actions": [&"up", &"right"],
		}
	)
	_check(
		"the Response cadence clears the listening preview",
		highway.get_presentation_snapshot()[&"preview"],
		{}
	)
	var first_target: Dictionary = response_presentation[&"targets"][0]
	var first_target_available: bool = module.submit_response_input(
		first_target[&"expected_action"],
		first_target[&"due_beat"]
	)
	_check(
		"listening input is not scored and does not consume a Response target",
		[_raw_scored_inputs, first_target_available],
		[0, true]
	)

	module.player_intent(CombatV1Script.Intent.SUBMIT_RESPONSE)
	module.player_intent(CombatV1Script.Intent.CONTINUE_ROUND)
	for beat_number in range(9, 13):
		beat_clock.beat.emit(beat_number)
	beat_clock.beat.emit(13)
	await process_frame
	_check(
		"a repeated round begins with one fresh downbeat preview",
		highway.get_presentation_snapshot()[&"preview"].get(&"actions", []),
		[&"up"]
	)
	for result_index in range(8):
		if module.get_state()[&"terminal"]:
			break
		module.apply_performance_result(
			CombatV1Script.Execution.CORRECT,
			CombatV1Script.TacticalEffectiveness.EFFECTIVE
		)
	_check(
		"encounter resolution clears the listening preview",
		highway.get_presentation_snapshot()[&"preview"],
		{}
	)

	highway.teardown()
	module.teardown()
	if rhythm_input.input_scored.is_connected(_on_raw_input_scored):
		rhythm_input.input_scored.disconnect(_on_raw_input_scored)
	highway.free()
	module.free()
	print("=== done ===")

func _on_phrase_event_announced(
	event: PhraseEvent,
	expected_actions: Array[StringName]
) -> void:
	_announced_previews.append("%.2f:%s" % [event.beat_offset, "+".join(expected_actions)])

func _on_raw_input_scored(
	_direction: StringName,
	_score: StringName,
	_offset_ms: float,
	_note_consumed: bool
) -> void:
	_raw_scored_inputs += 1

func _action(action_name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
