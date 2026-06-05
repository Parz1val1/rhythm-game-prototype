# test/test_neutral_hit.gd
# Verifies the NeutralHit resource: abstract enemy pattern format with
# beat_offset (timing) and lane_count (1=single, 2=simultaneous pair).
# Run: godot --headless --path . -s res://test/test_neutral_hit.gd
extends SceneTree

const NeutralHit = preload("res://rhythm_engine/neutral_hit.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== neutral hit format tests ===")

	var hit := NeutralHit.new()
	_check("default beat_offset is 0.0",  hit.beat_offset == 0.0, true)
	_check("default lane_count is 1",     hit.lane_count == 1,    true)

	hit.beat_offset = 1.5
	hit.lane_count = 2
	_check("can set beat_offset to 1.5",  hit.beat_offset == 1.5, true)
	_check("can set lane_count to 2",     hit.lane_count == 2,    true)

	# Array of NeutralHit for use as enemy neutral_pattern
	var pattern: Array[NeutralHit] = []
	var h0 := NeutralHit.new(); h0.beat_offset = 0.0; h0.lane_count = 1
	var h1 := NeutralHit.new(); h1.beat_offset = 0.5; h1.lane_count = 1
	var h2 := NeutralHit.new(); h2.beat_offset = 1.5; h2.lane_count = 2
	pattern.append(h0)
	pattern.append(h1)
	pattern.append(h2)
	_check("pattern array holds 3 hits",         pattern.size() == 3,        true)
	_check("first hit beat_offset is 0.0",        pattern[0].beat_offset == 0.0, true)
	_check("second hit beat_offset is 0.5",       pattern[1].beat_offset == 0.5, true)
	_check("third hit lane_count is 2 (chord)",   pattern[2].lane_count == 2,    true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
