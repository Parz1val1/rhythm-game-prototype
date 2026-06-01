# test/test_last_halfbeat_drop.gd
# Regression test for the off-by-one bug that silently dropped the note at
# beat_offset = phase_length - 0.5 (the last half-beat of the last beat of a
# DEFEND phase).
#
# Root cause: _on_half_beat used `next_beat_index >= phase_length` (non-strict)
# to guard BOTH the pre-inject and the current-half-beat inject.  The pre-inject
# guard was correct — beat_offset=N doesn't exist in any real pattern — but the
# return also killed the half-beat inject, whose position (N-0.5) IS valid.
# Fix: pre-inject uses `< phase_length`; current-half-beat inject always fires
# when half_pos >= 0.
#
# PRE-FIX BEHAVIOR — what would have happened before the fix:
#   The assertion "_check offset=3.5 injected" would have FAILED:
#     _has_note(ri, n_50) would return false (note never added to ri._active)
#     → FAIL  offset=3.5 injected at half_beat(4)  →  expected=true  got=false
#   Notes at 3.25 and 3.75 would have passed (quarter_beat handler unaffected).
#
# Run: godot --headless --path . -s res://test/test_last_halfbeat_drop.gd
extends SceneTree

const NoteData      = preload("res://rhythm_engine/note_data.gd")
const EnemyData     = preload("res://characters/enemy_data.gd")
const CharacterData = preload("res://characters/character_data.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== last-half-beat injection regression (phase_length=4) ===")

	var ri = null
	var bc = null
	for child in root.get_children():
		if child.name == "RhythmInput": ri = child
		if child.name == "BeatClock":   bc = child
	if ri == null or bc == null:
		printerr("FAIL: autoloads not found"); return

	# Enemy with notes at the three "last-beat" sub-positions:
	#   3.25 (quarter), 3.5 (last half-beat — previously dropped), 3.75 (three-quarter).
	var n_25 = _make_note(3.25)
	var n_50 = _make_note(3.5)    # ← the previously-dropped position
	var n_75 = _make_note(3.75)
	var enemy = EnemyData.new()
	enemy.enemy_name = "Test"; enemy.max_hp = 40; enemy.hp = 40
	enemy.attack_power = 5; enemy.phase_length = 4
	enemy.pattern.append(n_25); enemy.pattern.append(n_50); enemy.pattern.append(n_75)

	var combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	var hero = CharacterData.new()
	hero.character_name = "Hero"; hero.max_hp = 100; hero.hp = 100; hero.attack_power = 10
	combat.setup([hero], [enemy], false)   # DEFEND starts immediately

	# Advance to phase_beat_count=4 (last beat of the phase).
	combat._on_beat(1); combat._on_beat(2); combat._on_beat(3); combat._on_beat(4)

	# ── quarter-beat 0.25 of beat 4 (beat_offset=3.25) ───────────────────────
	bc.beat_position = 0.1
	ri.clear_notes()
	combat._on_quarter_beat(4)
	_check("offset=3.25 injected at quarter(4,0.25)  [always worked]",
		_has_note(ri, n_25), true)

	# ── half-beat of beat 4 (beat_offset=3.5) — the fixed position ───────────
	# Pre-fix: _on_half_beat returned early (>= guard), n_50 never reached ri._active.
	# Post-fix: current-half-beat inject fires; n_50 is in ri._active and scoreable.
	ri.clear_notes()
	combat._on_half_beat(4)
	_check("offset=3.5  injected at half_beat(4)     [previously dropped — fixed]",
		_has_note(ri, n_50), true)
	# Verify it is also scoreable: the note is in the active queue, so a player press
	# matching its direction would consume it (note_consumed=true).
	_check("offset=3.5  is present in active queue (can be scored)",
		ri._active.size() >= 1, true)
	# Exactly the half-beat note; no pre-inject fired (next_beat_index=4 >= phase_length=4).
	_check("offset=3.5  only 1 note injected (no spurious pre-inject)",
		ri._active.size() == 1, true)

	# ── quarter-beat 0.75 of beat 4 (beat_offset=3.75) ───────────────────────
	bc.beat_position = 0.8
	ri.clear_notes()
	combat._on_quarter_beat(4)
	_check("offset=3.75 injected at quarter(4,0.75)  [always worked]",
		_has_note(ri, n_75), true)

	ri.clear_notes()
	combat.queue_free()
	print("=== done ===")

func _make_note(offset: float) -> NoteData:
	var n = NoteData.new()
	n.beat_offset = offset; n.direction = &"drum_left"; n.mode = &"targeted"
	return n

func _has_note(ri: Node, note: NoteData) -> bool:
	for an in ri._active:
		if an.note == note:
			return true
	return false

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
