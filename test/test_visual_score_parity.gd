# test/test_visual_score_parity.gd
# Regression guard for the "phantom note" bug: during DEFEND, every note that gets
# INJECTED for scoring (RhythmInput.add_note) must also be ANNOUNCED for a visual
# (CombatScene.note_approaching), and vice-versa. If the two disagree, the player
# either takes damage from an invisible note (injected, never drawn) or sees a hit
# zone flash for a note that was never scored (drawn, never injected).
#
# The old defense-matrix tests verified that resolve_notes() produced the right
# DIRECTIONS, but never checked that the live injection path and the live visual
# path COVER THE SAME SET of hits. That blind spot let two gaps through:
#   * sub-beat hits at beat_offset >= lookahead_beats (e.g. Drum Golem's 2.5)
#   * the 2nd+ enemy in a multi-enemy encounter (e.g. Goblin Pair's scout)
#
# This test drives a full DEFEND phase tick-by-tick (mirroring BeatClock's
# beat / half_beat / quarter_beat order) and compares the two sets per enemy.
#
# Run: godot --headless --path . -s res://test/test_visual_score_parity.gd
extends SceneTree

# NOTE: scripts that transitively reference combat_scene.gd are load()ed at runtime
# (after process_frame), NOT preloaded at parse time. Preloading them forces
# combat_scene.gd to compile before the BeatClock/RhythmInput autoload globals are
# registered, which fails with "Identifier not found: BeatClock". Same rationale as
# test_beat_clock_lookahead.gd.
var _EncounterManager
var _CharacterData

var _fail_count: int = 0

func _init() -> void:
	await process_frame   # let autoloads (BeatClock, RhythmInput) initialize
	_run()
	quit(1 if _fail_count > 0 else 0)

func _run() -> void:
	print("=== visual/score parity tests ===")
	_EncounterManager = load("res://combat/encounter_manager.gd")
	_CharacterData    = load("res://characters/character_data.gd")

	var bc: Node = null
	var ri: Node = null
	for child in root.get_children():
		if child.name == "BeatClock":   bc = child
		if child.name == "RhythmInput": ri = child
	if bc == null or ri == null:
		printerr("FAIL: BeatClock/RhythmInput autoloads not found"); return

	# Directional defender (default profile) vs the two encounters that exposed the bug.
	_check_parity(bc, ri, "drum_golem", null,
		"Drum Golem (directional, sub-beat 2.5)")
	_check_parity(bc, ri, "goblin_pair", null,
		"Goblin Pair (directional, multi-enemy)")

	# Percussive defender (Beatrice) — proves the gap is not directional-specific.
	var perc = load("res://characters/beatrice_profile.tres")
	_check_parity(bc, ri, "drum_golem", perc,
		"Drum Golem (percussive / Beatrice)")

	print("=== done ===")

# Drives a full DEFEND phase for the given encounter and asserts that the set of
# injected notes equals the set of announced notes, keyed by (enemy, offset, dir).
func _check_parity(bc: Node, ri: Node, encounter_id: String, profile, label: String) -> void:
	var enemies = _EncounterManager._generate_enemies(StringName(encounter_id))

	var combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)

	var hero = _CharacterData.new()
	hero.character_name = "Hero"
	hero.max_hp = 100000; hero.hp = 100000; hero.attack_power = 10
	if profile != null:
		combat.set_active_profile(profile)
	combat.setup([hero], enemies, false)   # false → no DECISION; we drive DEFEND directly

	ri.clear_notes()

	# Announced set: every note emitted via note_approaching, tagged with the enemy
	# that is defending at emit time.  count > 1 ⇒ the same note got a double visual.
	var announced: Dictionary = {}
	var on_approach := func(note, _target_beat):
		var e = combat._get_defending_enemy_internal()
		var en: String = e.enemy_name if e != null else "?"
		var key := "%s | %.2f | %s" % [en, note.beat_offset, String(note.direction)]
		announced[key] = int(announced.get(key, 0)) + 1
	combat.note_approaching.connect(on_approach)

	# Injected set: snapshot RhythmInput's active queue after every injecting tick,
	# tagged with the current defender, deduped by key.
	var injected: Dictionary = {}
	var snapshot := func():
		var e = combat._get_defending_enemy_internal()
		if e == null:
			return
		for an in ri._active:
			var key := "%s | %.2f | %s" % [e.enemy_name, an.note.beat_offset, String(an.note.direction)]
			injected[key] = true

	# --- Drive the phase ---------------------------------------------------------
	var base: int = 100
	bc.beat_number = base
	bc.beat_position = 0.0
	combat._enter_defend_phase()        # first enemy: fires the early-announce
	snapshot.call()

	# Pre-first-beat sub-beats (phase_beat_count == 0): pre-injects beat_offset 0.0.
	bc.beat_position = 0.5;  combat._on_half_beat(base);    snapshot.call()
	bc.beat_position = 0.75; combat._on_quarter_beat(base); snapshot.call()

	var n: int = base + 1
	var guard: int = 0
	while combat.get_phase_name() == &"DEFEND" and guard < 64:
		bc.beat_number = n
		bc.beat_position = 0.0;  combat._on_beat(n);          snapshot.call()
		if combat.get_phase_name() != &"DEFEND":
			break
		bc.beat_position = 0.25; combat._on_quarter_beat(n);  snapshot.call()
		bc.beat_position = 0.5;  combat._on_half_beat(n);     snapshot.call()
		bc.beat_position = 0.75; combat._on_quarter_beat(n);  snapshot.call()
		n += 1
		guard += 1

	combat.note_approaching.disconnect(on_approach)

	# --- Compare -----------------------------------------------------------------
	var missing_visuals: Array = []    # injected but never announced → phantom damage
	for key in injected.keys():
		if not announced.has(key):
			missing_visuals.append(key)

	var phantom_visuals: Array = []    # announced but never injected → flash w/ no note
	for key in announced.keys():
		if not injected.has(key):
			phantom_visuals.append(key)

	var double_visuals: Array = []     # announced more than once in a single pass
	for key in announced.keys():
		if int(announced[key]) > 1:
			double_visuals.append("%s (x%d)" % [key, announced[key]])

	_check("%s: no injected-but-invisible notes" % label,
		missing_visuals, [])
	_check("%s: no announced-but-unscored notes" % label,
		phantom_visuals, [])
	_check("%s: no note announced twice" % label,
		double_visuals, [])
	# Sanity: the phase actually produced notes (guards against a no-op false pass).
	_check("%s: produced at least one note" % label,
		injected.size() > 0, true)

	combat.queue_free()

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
