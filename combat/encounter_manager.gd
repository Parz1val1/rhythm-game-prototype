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
        &"drum_golem":
            return [_make_drum_golem()]
        _:
            push_warning("EncounterManager: unknown encounter_id '%s', defaulting to goblin_single" % encounter_id)
            return [_make_goblin()]

# --- Enemy constructors ---
# Each returns a fully initialized EnemyData Resource.
# Patterns use neutral hits: beat_offset in range [0, phase_length-1], lane_count 1 or 2.
# Directions are resolved at injection time by NeutralPatternTranslator using the
# defending character's defense_pattern_type.

## Standard goblin: 4-beat pattern, 3 single hits.
static func _make_goblin() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Goblin"
    e.max_hp       = 40
    e.hp           = 40
    e.attack_power = 8
    e.phase_length = 4
    e.neutral_pattern.append(_hit(0.0, 1))
    e.neutral_pattern.append(_hit(2.0, 1))
    e.neutral_pattern.append(_hit(3.0, 1))
    return e

## Heavy orc: 8-beat pattern, 4 single hits on every other beat.
static func _make_orc() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Orc"
    e.max_hp       = 80
    e.hp           = 80
    e.attack_power = 15
    e.phase_length = 8
    for i in range(4):
        e.neutral_pattern.append(_hit(float(i * 2), 1))
    return e

## Fast goblin scout: 2-beat pattern, 2 single hits.
static func _make_goblin_scout() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Goblin Scout"
    e.max_hp       = 25
    e.hp           = 25
    e.attack_power = 5
    e.phase_length = 2
    e.neutral_pattern.append(_hit(0.0, 1))
    e.neutral_pattern.append(_hit(1.0, 1))
    return e

## String Golem: 8-beat all-single neutral pattern.
static func _make_string_golem() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "String Golem"
    e.max_hp       = 120
    e.hp           = 120
    e.attack_power = 18
    e.phase_length = 8
    for i in range(8):
        e.neutral_pattern.append(_hit(float(i), 1))
    return e

## Drum Golem: 4-beat half-beat pattern, single hits + two chords (lane_count 2).
## Resolved to percussive vocabulary for Beatrice: L,R,L,both,L,R,both.
## Resolved to directional vocabulary for any other character.
static func _make_drum_golem() -> EnemyData:
    var e := EnemyData.new()
    e.enemy_name   = "Drum Golem"
    e.max_hp       = 60
    e.hp           = 60
    e.attack_power = 14
    e.phase_length = 4
    # beat 0.0, 0.5, 1.0 = single; 1.5 = chord; 2.0, 2.5 = single; 3.0 = chord
    var offsets: Array[float]  = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    var lanes:   Array[int]    = [1,   1,   1,   2,   1,   1,   2  ]
    for i in range(offsets.size()):
        e.neutral_pattern.append(_hit(offsets[i], lanes[i]))
    return e

static func _hit(beat_offset: float, lane_count: int) -> NeutralHit:
    var h := NeutralHit.new()
    h.beat_offset = beat_offset
    h.lane_count  = lane_count
    return h
