# test/test_injection_characterization.gd
# Characterization test: documents which notes get injected at which beat positions.
# Uses a synthetic enemy with one note per subdivision type (whole, quarter, half,
# three-quarter) so the test exercises every injection path.
#
# This test MUST pass both before and after the injection-consolidation refactor.
# It is the safety net for that change.
#
# Run: godot --headless --path . -s res://test/test_injection_characterization.gd
extends SceneTree

const NoteData    = preload("res://rhythm_engine/note_data.gd")
const EnemyData   = preload("res://characters/enemy_data.gd")
const CharacterData = preload("res://characters/character_data.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== injection characterization tests ===")

	var ri = null
	var bc = null
	for child in root.get_children():
		if child.name == "RhythmInput": ri = child
		if child.name == "BeatClock":   bc = child
	if ri == null:
		printerr("FAIL: RhythmInput not found"); return
	if bc == null:
		printerr("FAIL: BeatClock not found"); return

	# Build a test-only enemy with one note per subdivision in a 2-beat phase.
	# Offsets covered: 0.0 (whole), 0.25 (quarter), 0.5 (half), 0.75 (3/4), 1.0 (next whole).
	# Note: beat_offset=1.5 (last half-beat of a 2-beat phase) is NOT tested here —
	# the current _on_half_beat guard (next_beat_index >= phase_length) skips it,
	# and the refactor must preserve that behavior.
	var offsets: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
	var notes: Array[NoteData] = []
	for off in offsets:
		var n = NoteData.new()
		n.beat_offset = off
		n.direction   = &"drum_left"
		n.mode        = &"targeted"
		notes.append(n)

	var enemy = EnemyData.new()
	enemy.enemy_name = "Test"; enemy.max_hp = 40; enemy.hp = 40
	enemy.attack_power = 5;  enemy.phase_length = 2
	enemy.pattern = notes

	var combat = load("res://combat/combat_scene.tscn").instantiate()
	root.add_child(combat)

	var hero = CharacterData.new()
	hero.character_name = "Hero"; hero.max_hp = 100; hero.hp = 100; hero.attack_power = 10
	# player_first=false → DEFEND phase starts immediately (phase_beat_count=0)
	combat.setup([hero], [enemy], false)

	# ── half_beat(0) — fires before first full beat of DEFEND ─────────────────
	# phase_beat_count=0, next_beat_index=0 → pre-inject beat_offset=0.0.
	# half_index = float(0-1)+0.5 = -0.5 → no pattern match.
	ri.clear_notes()
	combat._on_half_beat(0)
	_check("half_beat[0]: injects offset=0.0",  _has_offset(ri, 0.0),          true)
	_check("half_beat[0]: exactly 1 note",       ri._active.size() == 1,        true)

	# ── beat(1) — first full beat, increments phase_beat_count to 1 ───────────
	# _on_beat does not inject; only emits note_approaching.
	ri.clear_notes()
	combat._on_beat(1)
	_check("beat[1]: no direct injection",       ri._active.size() == 0,        true)

	# ── quarter_beat at 0.25 — phase_beat_count=1, beat_idx=0 ────────────────
	# BeatClock.beat_position < 0.5 → is_three_quarter=false → injects offset=0.25.
	bc.beat_position = 0.1
	ri.clear_notes()
	combat._on_quarter_beat(1)
	_check("quarter_beat[0.25]: injects 0.25",   _has_offset(ri, 0.25),         true)
	_check("quarter_beat[0.25]: exactly 1 note", ri._active.size() == 1,        true)

	# ── half_beat(1) — phase_beat_count=1 ────────────────────────────────────
	# next_beat_index=1 < phase_length=2 → no early return.
	# Injects: offset=1.0 (pre-inject, future due_ms) AND offset=0.5 (current half-beat).
	ri.clear_notes()
	combat._on_half_beat(1)
	_check("half_beat[1]: injects offset=0.5",   _has_offset(ri, 0.5),          true)
	_check("half_beat[1]: injects offset=1.0",   _has_offset(ri, 1.0),          true)
	_check("half_beat[1]: exactly 2 notes",      ri._active.size() == 2,        true)

	# ── quarter_beat at 0.75 — phase_beat_count=1, beat_idx=0 ────────────────
	# BeatClock.beat_position >= 0.5 → is_three_quarter=true → injects offset=0.75.
	bc.beat_position = 0.8
	ri.clear_notes()
	combat._on_quarter_beat(1)
	_check("quarter_beat[0.75]: injects 0.75",   _has_offset(ri, 0.75),         true)
	_check("quarter_beat[0.75]: exactly 1 note", ri._active.size() == 1,        true)

	# ── beat(2) — second beat, increments phase_beat_count to 2 ───────────────
	ri.clear_notes()
	combat._on_beat(2)
	_check("beat[2]: no direct injection",       ri._active.size() == 0,        true)

	# ── half_beat(2) — phase_beat_count=2 = phase_length → guard fires ────────
	# next_beat_index=2 >= phase_length=2 → returns early → NO injection.
	ri.clear_notes()
	combat._on_half_beat(2)
	_check("half_beat[2]: guard early-return → 0 notes", ri._active.size() == 0, true)

	ri.clear_notes()
	combat.queue_free()
	print("=== done ===")

# ---------------------------------------------------------------------------

func _has_offset(ri: Node, offset: float) -> bool:
	for an in ri._active:
		if is_equal_approx(an.note.beat_offset, offset):
			return true
	return false

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
