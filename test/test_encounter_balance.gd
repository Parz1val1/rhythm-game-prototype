# test/test_encounter_balance.gd
# Balance guardrail for the .tres encounter data (what real gameplay loads via
# EncounterManager.start_combat_from_definition). Luthier does ~40-80 damage per
# 4-beat ATTACK phase, so to make fights last ~2-3 attack phases:
#   * no single enemy should be so frail it dies in one phase (ENEMY_MIN), and
#   * an encounter's total HP should sit in a band that spans ~2-3 phases.
# This documents the tuning intent and guards against regressing to one-shot foes.
#
# Run: godot --headless --path . -s res://test/test_encounter_balance.gd
extends SceneTree

const ENCOUNTERS := [
	"res://encounters/goblin_single.tres",
	"res://encounters/goblin_pair.tres",
	"res://encounters/drum_golem.tres",
	"res://encounters/arrow_archer.tres",
	"res://encounters/string_golem.tres",
	"res://encounters/orc_heavy.tres",
]

# Per-enemy floor so nothing dies in a single attack phase (a frail enemy in a
# multi-enemy pack may sit near the floor; solo enemies should be higher).
const ENEMY_MIN: int = 40
const ENEMY_MAX: int = 150
# Per-encounter total HP band ≈ 2-3 attack phases of damage.
const TOTAL_MIN: int = 90
const TOTAL_MAX: int = 170

var _fail_count: int = 0

func _init() -> void:
	await process_frame
	_run()
	quit(1 if _fail_count > 0 else 0)

func _run() -> void:
	print("=== encounter balance guardrails ===")
	for path in ENCOUNTERS:
		var enc = load(path)
		if enc == null:
			_check("loads %s" % path, false, true)
			continue
		var total: int = 0
		var per_ok: bool = true
		for e in enc.enemies:
			total += e.max_hp
			if e.max_hp < ENEMY_MIN or e.max_hp > ENEMY_MAX:
				per_ok = false
			_check("%s: %s starts at full hp" % [enc.encounter_id, e.enemy_name],
				e.hp == e.max_hp, true)
		_check("%s: each enemy max_hp in [%d, %d]" % [enc.encounter_id, ENEMY_MIN, ENEMY_MAX],
			per_ok, true)
		_check("%s: total hp %d in [%d, %d]" % [enc.encounter_id, total, TOTAL_MIN, TOTAL_MAX],
			total >= TOTAL_MIN and total <= TOTAL_MAX, true)
	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
