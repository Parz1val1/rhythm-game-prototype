# test/test_neutral_pattern_translator.gd
# Verifies NeutralPatternTranslator resolves NeutralHit → NoteData for each
# defense_pattern_type, lane_count, and sequence_index combination.
#
# Percussive resolution rule:
#   lane_count 1 → alternates drum_right / drum_left by sequence_index % 2
#                  (right-first: index 0 → drum_right, index 1 → drum_left, …)
#   lane_count 2 → drum_both, always.
#
# Directional resolution rule:
#   lane_count 1 → cycle [up, right, down, left] by int(beat_offset) % 4
#   lane_count 2 → that arrow + its opposite (index+2)%4.
#
# Run: godot --headless --path . -s res://test/test_neutral_pattern_translator.gd
extends SceneTree

const NeutralHit               = preload("res://rhythm_engine/neutral_hit.gd")
const NeutralPatternTranslator = preload("res://combat/neutral_pattern_translator.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== neutral pattern translator tests ===")

	# ── Percussive: lane_count 1 alternates drum_right / drum_left by sequence_index ──
	var notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"percussive", 0)
	_check("percussive lane=1 returns 1 note",              notes.size() == 1,                  true)
	_check("percussive seq_idx=0 → drum_right",            notes[0].direction == &"drum_right", true)
	_check("percussive seq_idx=0 note is targeted",        notes[0].mode == &"targeted",        true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(0.5, 1), &"percussive", 1)
	_check("percussive seq_idx=1 → drum_left",             notes[0].direction == &"drum_left",  true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(1.0, 1), &"percussive", 2)
	_check("percussive seq_idx=2 → drum_right",            notes[0].direction == &"drum_right", true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(1.5, 1), &"percussive", 3)
	_check("percussive seq_idx=3 → drum_left",             notes[0].direction == &"drum_left",  true)

	# beat_offset doesn't affect single-hit hand assignment (sequence_index drives it)
	notes = NeutralPatternTranslator.resolve_notes(_hit(7.0, 1), &"percussive", 0)
	_check("percussive beat=7 seq_idx=0 → drum_right",     notes[0].direction == &"drum_right", true)
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"percussive", 1)
	_check("percussive beat=0 seq_idx=1 → drum_left",      notes[0].direction == &"drum_left",  true)

	# ── Percussive: lane_count 2 → drum_both ────────────────────────────────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(1.5, 2), &"percussive", 0)
	_check("percussive lane=2 returns 1 note",             notes.size() == 1,                  true)
	_check("percussive lane=2 → drum_both",                notes[0].direction == &"drum_both",  true)
	_check("percussive lane=2 note is targeted",           notes[0].mode == &"targeted",        true)

	# lane=2 ignores sequence_index
	notes = NeutralPatternTranslator.resolve_notes(_hit(3.0, 2), &"percussive", 7)
	_check("percussive lane=2 seq_idx=7 still drum_both",  notes[0].direction == &"drum_both",  true)

	# ── Directional: lane_count 1 cycles up/right/down/left by beat_offset ──────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"directional", 0)
	_check("directional lane=1 returns 1 note",            notes.size() == 1,                  true)
	_check("directional beat=0 → up",                     notes[0].direction == &"up",         true)
	_check("directional note is targeted",                 notes[0].mode == &"targeted",        true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(1.0, 1), &"directional", 1)
	_check("directional beat=1 → right",                  notes[0].direction == &"right",      true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(2.0, 1), &"directional", 2)
	_check("directional beat=2 → down",                   notes[0].direction == &"down",       true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(3.0, 1), &"directional", 3)
	_check("directional beat=3 → left",                   notes[0].direction == &"left",       true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(4.0, 1), &"directional", 4)
	_check("directional beat=4 cycles → up",              notes[0].direction == &"up",         true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(7.0, 1), &"directional", 7)
	_check("directional beat=7 → left",                   notes[0].direction == &"left",       true)

	# ── Directional: lane_count 2 → two distinct opposite arrows ────────────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 2), &"directional", 0)
	_check("directional lane=2 returns 2 notes",           notes.size() == 2,                  true)
	_check("directional lane=2 directions are distinct",   notes[0].direction != notes[1].direction, true)
	_check("directional lane=2 notes are targeted",
		notes[0].mode == &"targeted" and notes[1].mode == &"targeted", true)
	_check("directional lane=2 beat=0: up+down",
		(notes[0].direction == &"up" and notes[1].direction == &"down") or
		(notes[0].direction == &"down" and notes[1].direction == &"up"), true)

	# ── Unknown defense type falls back to directional ───────────────────────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"unknown_type", 0)
	_check("unknown type falls back to directional",       notes[0].direction == &"up",         true)

	# ── String-Golem-like: 8 whole-beat single hits → strict R/L alternation ────────
	var dirs: Array[String] = []
	for i in range(8):
		var n = NeutralPatternTranslator.resolve_notes(_hit(float(i), 1), &"percussive", i)
		dirs.append(n[0].direction)
	_check("8-hit percussive: starts on drum_right",       dirs[0] == &"drum_right",            true)
	_check("8-hit percussive: beat 1 is drum_left",        dirs[1] == &"drum_left",             true)
	_check("8-hit percussive: alternates all 8",
		dirs == ["drum_right","drum_left","drum_right","drum_left",
		         "drum_right","drum_left","drum_right","drum_left"], true)

	# ── Determinism: same args → identical result every call ─────────────────────────
	var ha := _hit(2.5, 1)
	var r1 = NeutralPatternTranslator.resolve_notes(ha, &"percussive", 4)
	var r2 = NeutralPatternTranslator.resolve_notes(ha, &"percussive", 4)
	_check("percussive resolution is deterministic",        r1[0].direction == r2[0].direction,  true)

	var hb := _hit(3.0, 1)
	var r3 = NeutralPatternTranslator.resolve_notes(hb, &"directional", 3)
	var r4 = NeutralPatternTranslator.resolve_notes(hb, &"directional", 3)
	_check("directional resolution is deterministic",       r3[0].direction == r4[0].direction,  true)

	# 5 identical calls must agree
	var hc := _hit(5.0, 1)
	var runs: Array[String] = []
	for _i in 5:
		var n = NeutralPatternTranslator.resolve_notes(hc, &"directional", 5)
		runs.append(n[0].direction)
	_check("5 calls with same args all identical",          runs.count(runs[0]) == 5,            true)

	print("=== done ===")

func _hit(beat_offset: float, lane_count: int) -> Resource:
	var h := NeutralHit.new()
	h.beat_offset = beat_offset
	h.lane_count  = lane_count
	return h

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
