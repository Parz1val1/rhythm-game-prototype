# test/test_neutral_pattern_translator.gd
# Verifies NeutralPatternTranslator resolves NeutralHit → NoteData for each
# defense_pattern_type and lane_count, including determinism guarantee.
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

	# ── Percussive: lane_count 1 alternates drum_left / drum_right ──────────
	var notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"percussive")
	_check("percussive lane=1 returns 1 note",           notes.size() == 1,                      true)
	_check("percussive beat 0.0 → drum_left",            notes[0].direction == &"drum_left",      true)
	_check("percussive beat 0.0 note is targeted",       notes[0].mode == &"targeted",            true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(0.5, 1), &"percussive")
	_check("percussive beat 0.5 → drum_right",           notes[0].direction == &"drum_right",     true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(1.0, 1), &"percussive")
	_check("percussive beat 1.0 → drum_left",            notes[0].direction == &"drum_left",      true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(1.5, 1), &"percussive")
	_check("percussive beat 1.5 → drum_right",           notes[0].direction == &"drum_right",     true)

	# ── Percussive: lane_count 2 → drum_both (1 note) ───────────────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(1.5, 2), &"percussive")
	_check("percussive lane=2 returns 1 note",           notes.size() == 1,                      true)
	_check("percussive lane=2 → drum_both",              notes[0].direction == &"drum_both",      true)
	_check("percussive lane=2 note is targeted",         notes[0].mode == &"targeted",            true)

	# ── Directional: lane_count 1 cycles up/right/down/left ─────────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"directional")
	_check("directional lane=1 returns 1 note",          notes.size() == 1,                      true)
	_check("directional beat 0 → up",                   notes[0].direction == &"up",             true)
	_check("directional beat 0 note is targeted",        notes[0].mode == &"targeted",            true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(1.0, 1), &"directional")
	_check("directional beat 1 → right",                notes[0].direction == &"right",          true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(2.0, 1), &"directional")
	_check("directional beat 2 → down",                 notes[0].direction == &"down",           true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(3.0, 1), &"directional")
	_check("directional beat 3 → left",                 notes[0].direction == &"left",           true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(4.0, 1), &"directional")
	_check("directional beat 4 cycles → up",            notes[0].direction == &"up",             true)

	notes = NeutralPatternTranslator.resolve_notes(_hit(7.0, 1), &"directional")
	_check("directional beat 7 → left",                 notes[0].direction == &"left",           true)

	# ── Directional: lane_count 2 → two distinct opposite arrows ────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 2), &"directional")
	_check("directional lane=2 returns 2 notes",         notes.size() == 2,                      true)
	_check("directional lane=2 directions are distinct", notes[0].direction != notes[1].direction, true)
	_check("directional lane=2 notes are targeted",
		notes[0].mode == &"targeted" and notes[1].mode == &"targeted", true)

	# beat 0 → up; opposite (idx+2)%4 → down
	_check("directional lane=2 beat 0: up+down",
		(notes[0].direction == &"up" and notes[1].direction == &"down") or
		(notes[0].direction == &"down" and notes[1].direction == &"up"), true)

	# ── Unknown defense type falls back to directional ───────────────────────
	notes = NeutralPatternTranslator.resolve_notes(_hit(0.0, 1), &"unknown_type")
	_check("unknown type falls back to directional",     notes[0].direction == &"up",             true)

	# ── Determinism: same hit + same type → identical direction every call ──
	var ha := _hit(2.5, 1)
	var r1 = NeutralPatternTranslator.resolve_notes(ha, &"percussive")
	var r2 = NeutralPatternTranslator.resolve_notes(ha, &"percussive")
	_check("percussive resolution is deterministic",     r1[0].direction == r2[0].direction,      true)

	var hb := _hit(3.0, 1)
	var r3 = NeutralPatternTranslator.resolve_notes(hb, &"directional")
	var r4 = NeutralPatternTranslator.resolve_notes(hb, &"directional")
	_check("directional resolution is deterministic",    r3[0].direction == r4[0].direction,      true)

	# Same enemy beat + same character always yields same resolved sequence
	var hc := _hit(5.0, 1)
	var runs: Array[String] = []
	for _i in 5:
		var n = NeutralPatternTranslator.resolve_notes(hc, &"directional")
		runs.append(n[0].direction)
	_check("5 calls on beat 5 directional all identical", runs.count(runs[0]) == 5,              true)

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
