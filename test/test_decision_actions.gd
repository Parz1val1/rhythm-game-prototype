# test/test_decision_actions.gd
# Verifies all four DECISION actions:
#   attack   → enters ATTACK phase (tested in test_decision_snap.gd; repeated here for completeness)
#   defend   → enters DEFEND with halved damage
#   item     → heals active character, then enters DEFEND
#   run      → 50% escape: combat_won OR stays in DECISION
# Run: godot --headless --path . -s res://test/test_decision_actions.gd
extends SceneTree

## Script-level fields used to observe signal emissions from connected lambdas.
## GDScript lambdas capture local variables BY VALUE, not by reference — a lambda
## that mutates a local declared in _run() will NOT be visible back in _run()'s scope.
## Promoting these to fields lets the lambda mutate them via implicit `self`.
var _won_fired: bool = false
var _decision_refired: bool = false

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== four DECISION actions tests ===")

	var combat_tscn  = load("res://combat/combat_scene.tscn")
	var CharacterData = load("res://characters/character_data.gd")
	var EnemyData     = load("res://characters/enemy_data.gd")

	# ── Attack action ──────────────────────────────────────────────────────────
	var ca = combat_tscn.instantiate(); root.add_child(ca)
	var ha = CharacterData.new(); ha.max_hp = 100; ha.hp = 100
	var ea = EnemyData.new();     ea.max_hp = 50;  ea.hp = 50
	ca.setup([ha], [ea], true)
	ca.choose_action(&"attack")
	ca.call("_on_beat", 1)
	_check("[attack] → ATTACK phase",      ca.get_phase_name() == &"ATTACK",   true)
	ca.queue_free()

	# ── Defend action ──────────────────────────────────────────────────────────
	var cd = combat_tscn.instantiate(); root.add_child(cd)
	var hd = CharacterData.new(); hd.max_hp = 100; hd.hp = 100
	var ed = EnemyData.new();     ed.max_hp = 50;  ed.hp = 50; ed.attack_power = 30
	cd.setup([hd], [ed], true)
	cd.choose_action(&"defend")
	cd.call("_on_beat", 1)
	_check("[defend] → DEFEND phase",        cd.get_phase_name() == &"DEFEND",    true)
	# Damage taken with defensive stance (30 * 0.5 = 15; hp 100 → 85).
	cd.call("_apply_damage_to_character", hd, 30)
	_check("[defend] damage halved (85 hp)", hd.hp, 85)
	cd.queue_free()

	# ── Item action ────────────────────────────────────────────────────────────
	var ci = combat_tscn.instantiate(); root.add_child(ci)
	var hi = CharacterData.new(); hi.max_hp = 100; hi.hp = 60  # damaged hero
	var ei = EnemyData.new();     ei.max_hp = 50;  ei.hp = 50
	ci.setup([hi], [ei], true)
	ci.choose_action(&"item")
	ci.call("_on_beat", 1)
	_check("[item] hp increased after item use",  hi.hp > 60,                     true)
	_check("[item] hp does not exceed max_hp",    hi.hp <= hi.max_hp,             true)
	_check("[item] → DEFEND phase after item",    ci.get_phase_name() == &"DEFEND", true)
	ci.queue_free()

	# ── Run action — successful escape (seeded RNG) ────────────────────────────
	# We set the RNG seed so _rng.randf() is predictable.
	# Find a seed where randf() < 0.5 (escape succeeds) and one where >= 0.5 (fails).
	var found_escape_seed := -1
	var found_fail_seed   := -1
	for s in range(20):
		var rng_probe := RandomNumberGenerator.new()
		rng_probe.seed = s
		var v := rng_probe.randf()
		if v < 0.5 and found_escape_seed == -1:
			found_escape_seed = s
		if v >= 0.5 and found_fail_seed == -1:
			found_fail_seed = s
		if found_escape_seed != -1 and found_fail_seed != -1:
			break

	# Run — escape succeeds.
	var cr = combat_tscn.instantiate(); root.add_child(cr)
	var hr = CharacterData.new(); hr.max_hp = 100; hr.hp = 100
	var er = EnemyData.new();     er.max_hp = 50;  er.hp = 50
	cr.setup([hr], [er], true)
	cr._rng.seed = found_escape_seed
	_won_fired = false
	cr.combat_won.connect(func(): _won_fired = true)
	cr.choose_action(&"run")
	cr.call("_on_beat", 1)
	_check("[run] escape success → combat_won fired (seed=%d)" % found_escape_seed,
		_won_fired, true)
	# Don't queue_free — combat already tore down.

	# Run — escape fails, returns to DECISION.
	var cf = combat_tscn.instantiate(); root.add_child(cf)
	var hf = CharacterData.new(); hf.max_hp = 100; hf.hp = 100
	var ef = EnemyData.new();     ef.max_hp = 50;  ef.hp = 50
	cf.setup([hf], [ef], true)
	cf._rng.seed = found_fail_seed
	cf.decision_started.connect(func(_a): _decision_refired = true)
	# Clear the initial decision_started from setup().
	_decision_refired = false
	cf.choose_action(&"run")
	cf.call("_on_beat", 1)
	_check("[run] escape fail → stays in DECISION (seed=%d)" % found_fail_seed,
		cf.get_phase_name() == &"DECISION", true)
	_check("[run] escape fail → decision_started re-emitted",
		_decision_refired, true)
	cf.queue_free()

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
