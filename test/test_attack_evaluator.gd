# test/test_attack_evaluator.gd
# Verifies the AttackEvaluator interface and PassthroughEvaluator behavior.
# The passthrough must produce identical output to the raw SequenceEvaluator path
# so existing combat tests stay green when CombatScene switches to using it.
# Run: godot --headless --path . -s res://test/test_attack_evaluator.gd
extends SceneTree

const AttackEvaluator      = preload("res://combat/attack_evaluator.gd")
const PassthroughEvaluator = preload("res://combat/passthrough_evaluator.gd")
const SequenceEvaluator    = preload("res://combat/sequence_evaluator.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== AttackEvaluator tests ===")

	# Base evaluator interface exists
	var base = AttackEvaluator.new()
	_check("base has record_hit method",   base.has_method("record_hit"),  true)
	_check("base has reset method",        base.has_method("reset"),       true)
	_check("base has get_multiplier",      base.has_method("get_multiplier"), true)
	_check("base record_hit returns 0",    base.record_hit(&"perfect", 10) == 0, true)

	# PassthroughEvaluator inherits the interface
	var ev = PassthroughEvaluator.new()
	_check("passthrough has record_hit",   ev.has_method("record_hit"),    true)
	_check("passthrough has reset",        ev.has_method("reset"),         true)

	# Passthrough produces same damage as the current manual formula:
	# perfect → attack_power * 1.0 (no combo yet)
	var dmg = ev.record_hit(&"perfect", 10)
	_check("perfect hit damage == 10",     dmg == 10,                      true)

	# good → attack_power * 0.5 * multiplier
	ev.reset()
	dmg = ev.record_hit(&"good", 10)
	_check("good hit damage == 5",         dmg == 5,                       true)

	# miss → 0 damage
	ev.reset()
	dmg = ev.record_hit(&"miss", 10)
	_check("miss damage == 0",             dmg == 0,                       true)

	# Combo + streak multiplier: 4 perfects → combo_bonus=0.1, streak_bonus=0.2 → 1.3x
	ev.reset()
	ev.record_hit(&"perfect", 10)
	ev.record_hit(&"perfect", 10)
	ev.record_hit(&"perfect", 10)
	dmg = ev.record_hit(&"perfect", 10)   # combo_count=4, _perfect_streak=4 → mult=1.3
	_check("4 perfects → multiplier 1.3 → dmg 13", dmg == 13,             true)

	# reset() clears combo state
	ev.reset()
	_check("after reset multiplier == 1.0",
		is_equal_approx(ev.get_multiplier(), 1.0), true)

	# CombatScene exposes set_active_profile
	var combat_tscn = load("res://combat/combat_scene.tscn")
	var combat = combat_tscn.instantiate()
	root.add_child(combat)
	_check("CombatScene has set_active_profile",
		combat.has_method("set_active_profile"), true)
	combat.queue_free()

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
