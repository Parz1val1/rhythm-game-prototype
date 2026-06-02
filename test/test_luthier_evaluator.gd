# test/test_luthier_evaluator.gd
# Verifies LuthierEvaluator: timing axis, melodic-coherence axis, damage formula,
# and registration in CombatScene under &"luthier_pitch".
# Run: godot --headless --path . -s res://test/test_luthier_evaluator.gd
extends SceneTree

const LuthierEvaluator = preload("res://combat/luthier_evaluator.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== LuthierEvaluator tests ===")

	var ev = LuthierEvaluator.new()

	# --- AttackEvaluator interface ---
	_check("has record_hit",            ev.has_method("record_hit"),             true)
	_check("has reset",                 ev.has_method("reset"),                  true)
	_check("has get_multiplier",        ev.has_method("get_multiplier"),         true)
	_check("has get_combo_count",       ev.has_method("get_combo_count"),        true)

	# --- Two-axis interface (mirrors BeatriceEvaluator) ---
	_check("has get_timing_multiplier", ev.has_method("get_timing_multiplier"),  true)
	_check("has get_coherence_mult",    ev.has_method("get_coherence_mult"),     true)
	_check("has set_last_direction",    ev.has_method("set_last_direction"),     true)

	# --- miss → 0 damage, combo reset ---
	var dmg := ev.record_hit(&"miss", 10)
	_check("miss returns 0",            dmg == 0,                                true)
	_check("combo 0 after miss",        ev.get_combo_count() == 0,               true)

	# --- perfect → damage > 0 ---
	ev.reset()
	ev.set_last_direction(&"up")
	dmg = ev.record_hit(&"perfect", 10)
	_check("perfect damage > 0",        dmg > 0,                                 true)
	_check("combo 1 after perfect",     ev.get_combo_count() == 1,               true)

	# --- good < perfect ---
	ev.reset()
	ev.set_last_direction(&"up")
	var dmg_good    := ev.record_hit(&"good", 10)
	ev.reset()
	ev.set_last_direction(&"up")
	var dmg_perfect := ev.record_hit(&"perfect", 10)
	_check("good damage < perfect",     dmg_good < dmg_perfect,                  true)

	# --- coherence multiplier bounds [1.0, 1.5] ---
	var coh := ev.get_coherence_mult()
	_check("coherence >= 1.0",          coh >= 1.0,                              true)
	_check("coherence <= 1.5",          coh <= 1.5,                              true)

	# --- stepwise motion > same-note repetition ---
	ev.reset()
	ev.set_last_direction(&"up")        # idx 0 — first note, no prev
	ev.record_hit(&"perfect", 10)
	ev.set_last_direction(&"right")     # idx 1, step from 0 → 1
	ev.record_hit(&"perfect", 10)
	var coh_step   := ev.get_coherence_mult()
	ev.set_last_direction(&"right")     # idx 1, same note 1 → 1
	ev.record_hit(&"perfect", 10)
	var coh_repeat := ev.get_coherence_mult()
	_check("stepwise > repeat",         coh_step > coh_repeat,                   true)

	# --- timing multiplier starts at 1.0 ---
	ev.reset()
	_check("timing mult starts 1.0",    is_equal_approx(ev.get_timing_multiplier(), 1.0), true)

	# --- 4 perfects raises timing multiplier ---
	ev.set_last_direction(&"up");    ev.record_hit(&"perfect", 10)
	ev.set_last_direction(&"right"); ev.record_hit(&"perfect", 10)
	ev.set_last_direction(&"down");  ev.record_hit(&"perfect", 10)
	ev.set_last_direction(&"left");  ev.record_hit(&"perfect", 10)
	_check("timing mult > 1 after 4",   ev.get_timing_multiplier() > 1.0,        true)

	# --- get_multiplier == timing × coherence ---
	ev.reset()
	ev.set_last_direction(&"up")
	ev.record_hit(&"perfect", 20)
	var product := ev.get_timing_multiplier() * ev.get_coherence_mult()
	_check("get_multiplier = t×c",      is_equal_approx(ev.get_multiplier(), product), true)

	# --- damage formula: attack_power × timing × coherence (±1 int rounding) ---
	ev.reset()
	ev.set_last_direction(&"up")
	var bd       := ev.record_hit(&"perfect", 20)
	var expected := int(float(20) * ev.get_timing_multiplier() * ev.get_coherence_mult())
	_check("damage formula ±1",         abs(bd - expected) <= 1,                 true)

	# --- reset clears all state ---
	ev.reset()
	_check("reset clears combo",        ev.get_combo_count() == 0,               true)
	_check("reset clears timing mult",  is_equal_approx(ev.get_timing_multiplier(), 1.0), true)

	# --- CombatScene recognises &"luthier_pitch" without crashing ---
	var combat_tscn = load("res://combat/combat_scene.tscn")
	var combat = combat_tscn.instantiate()
	root.add_child(combat)
	var CharacterInputProfile = load("res://characters/character_input_profile.gd")
	var prof = CharacterInputProfile.new()
	prof.attack_evaluator = &"luthier_pitch"
	combat.set_active_profile(prof)
	_check("CombatScene survives luthier_pitch", true, true)
	combat.queue_free()

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
