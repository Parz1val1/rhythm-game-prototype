# combat/encounter_manager.gd
# Static helper — instantiate nothing, just call EncounterManager.start_combat().
# "Static" here means all methods use the `static` keyword; the class itself is
# not instantiated. In Godot 4, static methods on a non-node class are called
# as EncounterManager.method_name() after preloading or via class_name lookup.
class_name EncounterManager

# Preload workaround (parse-order safety — same rationale as CharacterData above).
const EncounterDefinition = preload("res://encounters/encounter_definition.gd")

## Start combat from an EncounterDefinition resource file.
##
## Preferred over start_combat() for new work — encounters live in .tres files
## under encounters/ and are fully editable in the Godot Inspector.
## Each enemy is deep-duplicated so runtime HP mutations don't corrupt the asset.
##
## tree:         The active SceneTree (pass get_tree() from your calling scene).
## player_party: Array of CharacterData representing the player's current party.
## definition:   An EncounterDefinition resource loaded from encounters/*.tres.
## player_first: true = players attack first (surprise); false = enemies first (ambush).
static func start_combat_from_definition(
    tree: SceneTree,
    player_party: Array[CharacterData],
    definition: EncounterDefinition,
    player_first: bool = true
) -> Node:
    var enemies: Array[EnemyData] = []
    for e in definition.enemies:
        enemies.append(e.duplicate(true) as EnemyData)
    var scene: Node = preload("res://combat/combat_scene.tscn").instantiate()
    tree.current_scene.add_child(scene)
    scene.setup(player_party, enemies, player_first)
    return scene

## Load and initialize a CombatScene from a hardcoded encounter ID.
##
## Legacy path — kept for backward compatibility and headless tests.
## Prefer start_combat_from_definition() for new work.
##
## tree:         The active SceneTree (pass get_tree() from your calling scene).
## player_party: Array of CharacterData representing the player's current party.
## encounter_id: StringName key for the enemy configuration (see _generate_enemies).
## player_first: true = players attack first (surprise); false = enemies first (ambush).
##
## Returns the instantiated CombatScene node so the caller can connect to
## combat_won / combat_lost signals before the first beat fires.
static func start_combat(
    tree: SceneTree,
    player_party: Array[CharacterData],
    encounter_id: StringName,
    player_first: bool = true
) -> Node:
    var enemy_party: Array[EnemyData] = _generate_enemies(encounter_id)
    # preload() resolves the path at script-parse time — safe for static methods.
    var scene: Node = preload("res://combat/combat_scene.tscn").instantiate()
    # Add to the current scene so it receives _process and input events.
    tree.current_scene.add_child(scene)
    scene.setup(player_party, enemy_party, player_first)
    return scene

## Build an enemy party from a hardcoded encounter id.
## Extend this match block to add more encounter types.
static func _generate_enemies(encounter_id: StringName) -> Array[EnemyData]:
    match encounter_id:
        &"goblin_single":
            return [_make_goblin()]
        &"orc_heavy":
            return [_make_orc()]
        &"goblin_pair":
            return [_make_goblin(), _make_goblin_scout()]
        &"string_golem":
            return [_make_string_golem()]
        _:
            push_warning("EncounterManager: unknown encounter_id '%s', defaulting to goblin_single" % encounter_id)
            return [_make_goblin()]

# --- Enemy constructors ---
# Each returns a fully initialized EnemyData Resource.
# Patterns use beat_offset values in range [0, phase_length - 1].

## Standard goblin: 4-beat pattern mixing targeted and free-form notes.
static func _make_goblin() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Goblin"
    e.max_hp       = 40
    e.hp           = 40
    e.attack_power = 8
    e.phase_length = 4

    # Beat 0: targeted up   — player must press Up
    var n0 := NoteData.new()
    n0.beat_offset = 0; n0.direction = &"up";   n0.mode = &"targeted"
    # Beat 2: targeted down — player must press Down
    var n1 := NoteData.new()
    n1.beat_offset = 2; n1.direction = &"down"; n1.mode = &"targeted"
    # Beat 3: free-form     — any press on the beat counts
    var n2 := NoteData.new()
    n2.beat_offset = 3; n2.direction = &"up";   n2.mode = &"free_form"

    e.pattern = [n0, n1, n2]
    return e

## Heavy orc: 8-beat pattern of four targeted notes on every other beat.
## Hits harder; tests that longer phase_length cycles correctly.
static func _make_orc() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Orc"
    e.max_hp       = 80
    e.hp           = 80
    e.attack_power = 15
    e.phase_length = 8

    var dirs: Array[StringName] = [&"up", &"right", &"down", &"left"]
    var notes: Array[NoteData] = []
    for i in range(4):
        var n := NoteData.new()
        n.beat_offset = i * 2   # beats 0, 2, 4, 6
        n.direction   = dirs[i]
        n.mode        = &"targeted"
        notes.append(n)

    e.pattern = notes
    return e

## Fast goblin scout: 2-beat pattern, low HP, tests rapid defend-phase cycling.
static func _make_goblin_scout() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Goblin Scout"
    e.max_hp       = 25
    e.hp           = 25
    e.attack_power = 5
    e.phase_length = 2

    var n0 := NoteData.new()
    n0.beat_offset = 0; n0.direction = &"left";  n0.mode = &"targeted"
    var n1 := NoteData.new()
    n1.beat_offset = 1; n1.direction = &"right"; n1.mode = &"targeted"

    e.pattern = [n0, n1]
    return e

## String Golem: 8-beat all-targeted pattern, alternating up/down then left/right pairs.
## High attack power — requires limit break or sustained perfect combo to survive.
static func _make_string_golem() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "String Golem"
    e.max_hp       = 120
    e.hp           = 120
    e.attack_power = 18
    e.phase_length = 8

    # Alternating up/down pairs, then left/right flourish — all targeted.
    var dirs: Array[StringName] = [
        &"up", &"down", &"up", &"down",
        &"left", &"right", &"left", &"right",
    ]
    var notes: Array[NoteData] = []
    for i in range(8):
        var n := NoteData.new()
        n.beat_offset = i
        n.direction   = dirs[i]
        n.mode        = &"targeted"
        notes.append(n)

    e.pattern = notes
    return e
