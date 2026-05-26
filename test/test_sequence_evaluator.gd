# test/test_sequence_evaluator.gd
# Run with Godot headless — see command above.
extends SceneTree

const SequenceEvaluator = preload("res://combat/sequence_evaluator.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== SequenceEvaluator tests ===")
    var ev := SequenceEvaluator.new()

    # First perfect hit — no combo bonus yet, multiplier = 1.0
    var m := ev.record_hit(&"perfect")
    _check("first perfect multiplier == 1.0",        is_equal_approx(m, 1.0),  true)
    _check("combo_count after 1 perfect == 1",        ev.combo_count == 1,      true)

    # Four perfects in a row: combo_count=4, expect multiplier > 1.0
    ev.record_hit(&"perfect")
    ev.record_hit(&"perfect")
    m = ev.record_hit(&"perfect")   # combo_count = 4
    _check("multiplier after 4 perfects > 1.0",       m > 1.0,                  true)

    # Good hit continues combo but resets perfect streak
    ev.record_hit(&"good")
    _check("good hit keeps combo going",               ev.combo_count == 5,      true)
    _check("good hit resets perfect streak",           ev._perfect_streak == 0,  true)

    # Miss resets combo to 0, returns 0.0
    m = ev.record_hit(&"miss")
    _check("miss returns 0.0",                        is_equal_approx(m, 0.0),  true)
    _check("combo_count after miss == 0",              ev.combo_count == 0,      true)
    _check("max_combo preserved after miss",           ev.max_combo >= 5,        true)

    # reset() clears everything
    ev.reset()
    _check("reset clears combo_count",                 ev.combo_count == 0,      true)
    _check("reset clears max_combo",                   ev.max_combo == 0,        true)

    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
