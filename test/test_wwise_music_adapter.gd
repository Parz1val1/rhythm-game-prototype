# Behavioral tests for the repository-owned Wwise spike seam.
# Run: godot --headless --path . -s res://test/test_wwise_music_adapter.gd
extends SceneTree

class FakeWwiseRuntime extends RefCounted:
	var position_ms: int = 0
	var beat_duration_ms: float = 500.0
	var segment_duration_ms: int = 2000
	var render_count: int = 0
	var position_query_count: int = 0
	var started: bool = false
	var layer_enabled: bool = false
	var transition_name: StringName = &""
	var music_callback: Callable

	func initialize() -> bool:
		return true

	func start_music(_owner: Node, callback: Callable) -> int:
		started = true
		music_callback = callback
		return 45

	func emit_music_callback(callback_type: int, callback_position_ms: int) -> void:
		music_callback.call({
			"callback_type": callback_type,
			"segmentInfo": {
				"iCurrentPosition": callback_position_ms,
				"fBeatDuration": beat_duration_ms / 1000.0,
				"iActiveDuration": segment_duration_ms,
			},
		})

	func get_music_position(_playing_id: int) -> Dictionary:
		position_query_count += 1
		return {
			&"position_ms": position_ms,
			&"beat_duration_ms": beat_duration_ms,
			&"segment_duration_ms": segment_duration_ms,
		}

	func render_audio() -> void:
		render_count += 1

	func stop_music(_playing_id: int) -> void:
		started = false

	func set_layer_enabled(enabled: bool) -> bool:
		layer_enabled = enabled
		return true

	func request_transition(section: StringName) -> bool:
		transition_name = section
		return true

	func shutdown() -> void:
		pass


var _whole_beats: Array[int] = []
var _half_beats: Array[int] = []
var _quarter_beats: Array[Vector2] = []
var _timing_observations: Array[Dictionary] = []
var _has_failures: bool = false


func _init() -> void:
	await process_frame
	await _run()
	quit(1 if _has_failures else 0)


func _run() -> void:
	print("=== Wwise music adapter tests ===")
	var adapter_script := load("res://spikes/wwise/wwise_music_adapter.gd")
	_check("Wwise music adapter is available", adapter_script != null, true)
	if adapter_script == null:
		print("=== done ===")
		return

	var runtime := FakeWwiseRuntime.new()
	var adapter: Node = adapter_script.new()
	root.add_child(adapter)
	adapter.beat.connect(_on_beat)
	adapter.half_beat.connect(_on_half_beat)
	adapter.quarter_beat.connect(_on_quarter_beat)
	adapter.timing_observed.connect(_on_timing_observed)
	adapter.setup(runtime)
	_check("adapter starts through the repository-owned runtime seam", adapter.start(), true)
	await process_frame
	_check("position polling waits for the first valid music callback", runtime.position_query_count, 0)

	# One late main-thread frame advances across seven musical boundaries. The
	# adapter must recover every boundary from authoritative continuous position.
	runtime.position_ms = 875
	runtime.emit_music_callback(0x0100, 850)
	await process_frame

	_check("every crossed whole beat is published once", _whole_beats, [1])
	_check("every crossed half beat is published once", _half_beats, [0, 1])
	_check("every crossed quarter beat is published once", _quarter_beats, [
		Vector2(0, 0.25),
		Vector2(0, 0.75),
		Vector2(1, 0.25),
		Vector2(1, 0.75),
	])
	_check("continuous musical position is atomic", adapter.get_musical_position_beats(), 1.75)
	_check("the integration autoload remains the sole RenderAudio owner", runtime.render_count, 0)
	_check("signed offset remains negative before the next beat", adapter.get_offset_ms(), -125.0)
	_check("callback comparison is published without Wwise types", _timing_observations.size(), 1)
	if not _timing_observations.is_empty():
		var observation := _timing_observations[0]
		_check("callback type is normalized", observation.get(&"kind"), &"beat")
		_check("same-frame position exposes callback delivery error", observation.get(&"error_ms"), 25.0)
		_check("observation records continuous musical time", observation.get(&"position_beats"), 1.75)
		_check("callback position is continuous and generic", observation.get(&"callback_position_beats"), 1.7)

	adapter.stop()
	adapter.free()

	_whole_beats.clear()
	_half_beats.clear()
	_quarter_beats.clear()
	var looping_runtime := FakeWwiseRuntime.new()
	looping_runtime.position_ms = 1875
	var looping_adapter: Node = adapter_script.new()
	root.add_child(looping_adapter)
	looping_adapter.beat.connect(_on_beat)
	looping_adapter.half_beat.connect(_on_half_beat)
	looping_adapter.quarter_beat.connect(_on_quarter_beat)
	looping_adapter.setup(looping_runtime)
	_check("looping adapter starts", looping_adapter.start(), true)
	looping_runtime.emit_music_callback(0x0400, 1875)
	await process_frame

	_whole_beats.clear()
	_half_beats.clear()
	_quarter_beats.clear()
	looping_runtime.position_ms = 125
	await process_frame

	_check("a segment wrap preserves continuous musical position", looping_adapter.get_musical_position_beats(), 4.25)
	_check("a segment wrap publishes only the newly crossed beat", _whole_beats, [4])
	_check("a segment wrap publishes only the newly crossed subdivision", _quarter_beats, [Vector2(4, 0.25)])
	_check("a segment wrap does not invent a half beat", _half_beats, [])

	var has_arrangement_seam := looping_adapter.has_method(&"set_layer_enabled") \
		and looping_adapter.has_method(&"request_transition")
	_check("adapter exposes repository-owned arrangement intent", has_arrangement_seam, true)
	if has_arrangement_seam:
		var position_before_arrangement: float = looping_adapter.get_musical_position_beats()
		_check("layer intent reaches the runtime seam", looping_adapter.set_layer_enabled(true), true)
		_check("layer intent contains no Wwise state name", looping_runtime.layer_enabled, true)
		_check("transition intent reaches the runtime seam", looping_adapter.request_transition(&"alternate"), true)
		_check("transition intent contains a repository section name", looping_runtime.transition_name, &"alternate")
		_check(
			"arrangement intent does not restart musical time",
			looping_adapter.get_musical_position_beats(),
			position_before_arrangement
		)

	looping_adapter.stop()
	looping_adapter.free()
	print("=== done ===")


func _on_beat(beat_number: int) -> void:
	_whole_beats.append(beat_number)


func _on_half_beat(beat_number: int) -> void:
	_half_beats.append(beat_number)


func _on_quarter_beat(beat_number: int, subdivision: float) -> void:
	_quarter_beats.append(Vector2(beat_number, subdivision))


func _on_timing_observed(observation: Dictionary) -> void:
	_timing_observations.append(observation)


func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
