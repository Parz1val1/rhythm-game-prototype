# test/test_beat_clock_audio_loop.gd
# Regression test for whole-beat emission after a looping backing track wraps.
# Run: godot --headless --path . -s res://test/test_beat_clock_audio_loop.gd
extends SceneTree

var _emitted_beats: Array[int] = []
var _has_failures: bool = false

func _init() -> void:
	await process_frame
	await _run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== BeatClock audio-loop regression tests ===")
	var clock := root.get_node("BeatClock")
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var stream := load("res://audio/playtest_v1/stonebeat.wav").duplicate(true) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	player.stream = stream
	player.play(maxf(0.0, stream.get_length() - 0.25))
	clock.bpm = 130.0
	clock.intro_offset_ms = 0.0
	clock.beat.connect(_on_beat)
	clock.start(player)

	var previous_position := player.get_playback_position()
	var wrapped := false
	var beats_at_wrap := 0
	var wrap_time_ms := 0
	var deadline_ms := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline_ms:
		await process_frame
		var position := player.get_playback_position()
		if not wrapped and position + 0.1 < previous_position:
			wrapped = true
			beats_at_wrap = _emitted_beats.size()
			wrap_time_ms = Time.get_ticks_msec()
		if wrapped and Time.get_ticks_msec() - wrap_time_ms >= 700:
			break
		previous_position = position

	var beats_after_wrap := _emitted_beats.size() - beats_at_wrap
	_check(
		"a looping track continues emitting monotonically increasing whole beats",
		wrapped and beats_after_wrap > 0 and _is_strictly_increasing(_emitted_beats),
		true
	)

	clock.stop()
	if clock.beat.is_connected(_on_beat):
		clock.beat.disconnect(_on_beat)
	player.stop()
	player.free()
	print("=== done ===")

func _on_beat(beat_number: int) -> void:
	_emitted_beats.append(beat_number)

func _is_strictly_increasing(values: Array[int]) -> bool:
	for index in range(1, values.size()):
		if values[index] <= values[index - 1]:
			return false
	return true

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
