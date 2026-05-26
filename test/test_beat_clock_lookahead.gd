# test/test_beat_clock_lookahead.gd
# Verifies that CombatScene exposes note_approaching signal and lookahead_beats property.
# Run: godot --headless --path . -s res://test/test_beat_clock_lookahead.gd
extends SceneTree

const CharacterData    = preload("res://characters/character_data.gd")
const EncounterManager = preload("res://combat/encounter_manager.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== lookahead signal tests ===")

    var hero := CharacterData.new()
    hero.max_hp = 100; hero.hp = 100; hero.attack_power = 1
    var party: Array[CharacterData] = [hero]
    var combat = EncounterManager.start_combat(self, party, &"goblin_single", true)

    _check("note_approaching signal exists",
        combat.has_signal("note_approaching"), true)
    _check("phase_changed signal exists",
        combat.has_signal("phase_changed"), true)
    _check("lookahead_beats property exists",
        "lookahead_beats" in combat, true)
    _check("lookahead_beats default >= 1",
        combat.lookahead_beats >= 1, true)

    combat.queue_free()
    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
