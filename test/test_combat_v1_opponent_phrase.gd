# test/test_combat_v1_opponent_phrase.gd
# Verifies authored opponent phrase content through its Resource interface.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 opponent-phrase tests ===")
	var opponent = load("res://combat_v1/opponents/drum_golem.tres")
	_check("authored V1 opponent loads", opponent != null, true)
	if opponent == null:
		print("=== done ===")
		return

	_check("opponent has a stable domain identifier", opponent.opponent_id, &"drum_golem")
	_check("opponent has a presentation name", opponent.display_name, "Drum Golem")
	_check("opponent owns an authored phrase", opponent.phrase != null, true)
	if opponent.phrase != null:
		var phrase = opponent.phrase
		_check("prototype phrase is one bar", phrase.bar_count, 1)
		_check("one bar has four beats", phrase.get_duration_beats(), 4)
		_check("prototype phrase authors five prompt events", phrase.events.size(), 5)
		var offsets: Array[float] = []
		var all_events_are_presentable := true
		for event in phrase.events:
			offsets.append(event.beat_offset)
			all_events_are_presentable = all_events_are_presentable \
				and event.prompt_id != &"" \
				and not event.prompt_text.is_empty() \
				and event.audio_cue != &"" \
				and event.visual_cue != &""
		_check("phrase keeps reproducible musical offsets", offsets, [0.0, 0.75, 1.5, 2.5, 3.0])
		_check("each event carries prompt, audio, and visual data", all_events_are_presentable, true)

	_check("V1 opponent does not expose HP", _has_property(opponent, &"hp"), false)
	_check("V1 opponent does not expose attack power", _has_property(opponent, &"attack_power"), false)
	print("=== done ===")

func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property[&"name"] == property_name:
			return true
	return false

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
