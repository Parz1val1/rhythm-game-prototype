# Tests that Wwise-specific concepts stay behind the spike runtime bridge.
# Run: godot --headless --path . -s res://test/test_wwise_runtime_bridge.gd
extends SceneTree

class FakeWwiseEngine extends RefCounted:
	var initialized: bool = false
	var loaded_banks: Array[String] = []
	var posted_event: String = ""
	var posted_flags: int = 0
	var state_changes: Array[String] = []
	var state_group: String = ""
	var state_value: String = ""
	var stopped_playing_id: int = 0

	func init() -> void:
		initialized = true

	func is_initialized() -> bool:
		return initialized

	func load_bank(bank_name: String) -> bool:
		loaded_banks.append(bank_name)
		return true

	func post_event_callback(
		event_name: String,
		_flags: int,
		_game_object: Node,
		_callback: Callable
	) -> int:
		posted_event = event_name
		posted_flags = _flags
		return 45

	func get_playing_segment_info(_playing_id: int, _extrapolate: bool) -> Dictionary:
		return {
			"iCurrentPosition": 750,
			"fBeatDuration": 0.5,
			"iActiveDuration": 2000,
		}

	func set_state(group: String, value: String) -> bool:
		state_group = group
		state_value = value
		state_changes.append("%s=%s" % [group, value])
		return true

	func render_audio() -> void:
		pass

	func stop_event(playing_id: int, _fade_time: int, _curve: int) -> void:
		stopped_playing_id = playing_id

	func shutdown() -> void:
		initialized = false


var _has_failures: bool = false


func _init() -> void:
	await process_frame
	_run()
	quit(1 if _has_failures else 0)


func _run() -> void:
	print("=== Wwise runtime bridge tests ===")
	var bridge_script := load("res://spikes/wwise/wwise_runtime_bridge.gd")
	_check("Wwise runtime bridge is available", bridge_script != null, true)
	if bridge_script == null:
		print("=== done ===")
		return

	var engine := FakeWwiseEngine.new()
	var bridge: RefCounted = bridge_script.new()
	bridge.setup_engine(engine)
	_check("bridge initializes the Wwise engine", bridge.initialize(), true)
	_check("bridge loads only its user bank after Wwise init", engine.loaded_banks, ["Combat_Spike"])
	_check("bridge posts the authored combat event", bridge.start_music(root, func(_data): pass), 45)
	_check("bridge establishes authored starting States before playback", engine.state_changes, [
		"Combat_Layer=Disabled",
		"Combat_Section=Loop",
	])
	_check("Wwise event name stays behind the bridge", engine.posted_event, "Play_Combat_Spike")
	_check("position queries are enabled on the posted event", engine.posted_flags & 0x200000, 0x200000)
	_check("music callbacks are requested on the posted event", engine.posted_flags & 0x7f00, 0x7f00)
	_check("Wwise segment fields become generic timing data", bridge.get_music_position(45), {
		&"position_ms": 750,
		&"beat_duration_ms": 500.0,
		&"segment_duration_ms": 2000,
	})

	_check("repository layer intent maps to a Wwise State", bridge.set_layer_enabled(true), true)
	_check("Wwise layer State Group stays behind the bridge", engine.state_group, "Combat_Layer")
	_check("Wwise layer State stays behind the bridge", engine.state_value, "Enabled")
	_check("repository transition intent maps to a Wwise State", bridge.request_transition(&"alternate"), true)
	_check("Wwise section State Group stays behind the bridge", engine.state_group, "Combat_Section")
	_check("Wwise section State stays behind the bridge", engine.state_value, "Alternate")

	bridge.stop_music(45)
	_check("bridge stops only its playing event", engine.stopped_playing_id, 45)
	bridge.shutdown()
	_check("bridge shuts down its isolated engine", engine.initialized, false)
	print("=== done ===")


func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
