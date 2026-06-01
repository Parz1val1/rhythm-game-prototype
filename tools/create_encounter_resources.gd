# tools/create_encounter_resources.gd
# One-shot generator: creates encounter .tres files in res://encounters/.
# Run: godot --headless --path . -s res://tools/create_encounter_resources.gd
#
# Array assignment rule (Godot 4):
#   e.pattern = [...]  ← FAILS: can't assign Array[Variant] to Array[NoteData] via Variant.
#   e.pattern.append(n) ← WORKS: array is a reference; append respects the existing typed array.
extends SceneTree

# preload is safe here: NoteData/EnemyData/EncounterDefinition reference no autoloads.
const EncounterDefinitionScript = preload("res://encounters/encounter_definition.gd")
const EnemyDataScript            = preload("res://characters/enemy_data.gd")
const NoteDataScript             = preload("res://rhythm_engine/note_data.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== Creating encounter resources ===")
	_save(_make_goblin_single(), "res://encounters/goblin_single.tres")
	_save(_make_orc_heavy(),     "res://encounters/orc_heavy.tres")
	_save(_make_goblin_pair(),   "res://encounters/goblin_pair.tres")
	_save(_make_string_golem(),  "res://encounters/string_golem.tres")
	print("=== Done ===")

func _save(enc, path: String) -> void:
	var err := ResourceSaver.save(enc, path)
	if err != OK:
		printerr("  FAIL  %s  (error %d)" % [path, err])
	else:
		print("  OK    %s" % path)

# --- Note helper ---

func _note(beat_offset: int, direction: String, mode: String):
	var n = NoteDataScript.new()
	n.beat_offset = beat_offset
	n.direction   = direction
	n.mode        = mode
	return n

# --- Enemy helpers ---

func _make_goblin():
	var e = EnemyDataScript.new()
	e.enemy_name   = "Goblin"
	e.max_hp       = 40;  e.hp           = 40
	e.attack_power = 8;   e.phase_length = 4
	e.pattern.append(_note(0, "up",   "targeted"))
	e.pattern.append(_note(2, "down", "targeted"))
	e.pattern.append(_note(3, "up",   "free_form"))
	return e

func _make_goblin_scout():
	var e = EnemyDataScript.new()
	e.enemy_name   = "Goblin Scout"
	e.max_hp       = 25;  e.hp           = 25
	e.attack_power = 5;   e.phase_length = 2
	e.pattern.append(_note(0, "left",  "targeted"))
	e.pattern.append(_note(1, "right", "targeted"))
	return e

func _make_orc():
	var e = EnemyDataScript.new()
	e.enemy_name   = "Orc"
	e.max_hp       = 80;  e.hp           = 80
	e.attack_power = 15;  e.phase_length = 8
	var dirs := ["up", "right", "down", "left"]
	for i in range(4):
		e.pattern.append(_note(i * 2, dirs[i], "targeted"))
	return e

func _make_string_golem_enemy():
	var e = EnemyDataScript.new()
	e.enemy_name   = "String Golem"
	e.max_hp       = 120; e.hp           = 120
	e.attack_power = 18;  e.phase_length = 8
	var dirs := ["up", "down", "up", "down", "left", "right", "left", "right"]
	for i in range(8):
		e.pattern.append(_note(i, dirs[i], "targeted"))
	return e

# --- Encounter assemblers ---

func _make_goblin_single():
	var enc = EncounterDefinitionScript.new()
	enc.encounter_id = "goblin_single"
	enc.enemies.append(_make_goblin())
	return enc

func _make_orc_heavy():
	var enc = EncounterDefinitionScript.new()
	enc.encounter_id = "orc_heavy"
	enc.enemies.append(_make_orc())
	return enc

func _make_goblin_pair():
	var enc = EncounterDefinitionScript.new()
	enc.encounter_id = "goblin_pair"
	enc.enemies.append(_make_goblin())
	enc.enemies.append(_make_goblin_scout())
	return enc

func _make_string_golem():
	var enc = EncounterDefinitionScript.new()
	enc.encounter_id = "string_golem"
	enc.enemies.append(_make_string_golem_enemy())
	return enc
