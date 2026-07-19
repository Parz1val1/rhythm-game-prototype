# test/test_defend_ui_clears.gd
# The DEFEND-phase hit-zone UI (NoteLane / DrumLane) must clear when the phase
# leaves DEFEND. Originally it only hid on the DEFEND->ATTACK transition; once a
# DECISION phase was inserted between DEFEND and ATTACK, the lane lingered on
# screen through DECISION. This guards that it hides on ANY non-DEFEND phase and
# drops its travelling visuals.
#
# Phase enum: ATTACK=0, DEFEND=1, DECISION=2.
# Run: godot --headless --path . -s res://test/test_defend_ui_clears.gd
extends SceneTree

var _fail_count: int = 0

func _init() -> void:
	await process_frame   # let autoloads initialize
	_run()
	quit(1 if _fail_count > 0 else 0)

func _run() -> void:
	print("=== defend UI clears on phase change ===")

	var nd_script = load("res://rhythm_engine/note_data.gd")

	_test_lane("res://combat/note_lane.tscn", "up", nd_script, "NoteLane (directional)")
	_test_lane("res://combat/beatrice_drum_lane.gd",  "drum_left", nd_script, "DrumLane (percussive)")

	print("=== done ===")

# Reveals the lane during DEFEND, then transitions to DECISION and asserts it hid.
func _test_lane(lane_path: String, direction: String, nd_script, label: String) -> void:
	var combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)

	var lane
	var res = load(lane_path)
	if res is PackedScene:
		lane = res.instantiate()
	else:
		lane = res.new()
	root.add_child(lane)
	lane.setup(combat)

	# Enter DEFEND and reveal the lane via an approaching note.
	combat.phase_changed.emit(1)   # DEFEND
	var note = nd_script.new()
	note.direction = direction
	note.beat_offset = 0.0
	combat.note_approaching.emit(note, 2)   # target_beat; BeatClock sits at 0 in tests
	_check("%s: visible during DEFEND once a note approaches" % label, lane.visible, true)

	# Leave DEFEND for DECISION — the lane must hide and drop its visuals.
	combat.phase_changed.emit(2)   # DECISION
	_check("%s: hidden during DECISION" % label, lane.visible, false)
	_check("%s: travelling visuals cleared during DECISION" % label, lane._visuals.is_empty(), true)

	lane.queue_free()
	combat.queue_free()

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
