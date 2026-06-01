# test/test_solo_style.gd
# Verifies SoloStyle resource fields and that luthier .tres files load correctly.
# Run: godot --headless --path . -s res://test/test_solo_style.gd
extends SceneTree

const SoloStyle     = preload("res://characters/solo_style.gd")
const CharacterData = preload("res://characters/character_data.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== SoloStyle tests ===")

    # --- SoloStyle default field values ---
    var style := SoloStyle.new()
    _check("instrument_name default is string",   style.instrument_name is String,                  true)
    _check("audio_bus default is string",         style.audio_bus is String,                        true)
    _check("scale_steps default has 4 entries",   style.scale_steps.size() == 4,                    true)
    _check("root_note default is int",            style.root_note is int,                           true)
    _check("accent_color default is Color",       style.accent_color is Color,                      true)
    _check("phase_intro_text default is string",  style.phase_intro_text is String,                 true)

    # --- CharacterData has solo_style field ---
    var c := CharacterData.new()
    _check("CharacterData.solo_style exists",     "solo_style" in c,                                true)
    _check("solo_style default is null",          c.solo_style == null,                             true)

    # --- Assign a SoloStyle to CharacterData ---
    c.solo_style = SoloStyle.new()
    c.solo_style.instrument_name = "Lute"
    c.solo_style.scale_steps = [0, 2, 7, 9]
    _check("solo_style assignable",               c.solo_style != null,                             true)
    _check("instrument_name roundtrip",           c.solo_style.instrument_name == "Lute",           true)
    _check("scale_steps roundtrip",               c.solo_style.scale_steps[2] == 7,                 true)

    # --- Load luthier_solo_style.tres ---
    var lss = load("res://characters/luthier_solo_style.tres")
    _check("luthier_solo_style.tres loads",       lss != null,                                      true)
    if lss != null:
        _check("lss.instrument_name is Lute",     lss.instrument_name == "Lute",                    true)
        _check("lss.scale_steps[0] == 0",         lss.scale_steps[0] == 0,                          true)
        _check("lss.scale_steps[1] == 2",         lss.scale_steps[1] == 2,                          true)
        _check("lss.scale_steps[2] == 7",         lss.scale_steps[2] == 7,                          true)
        _check("lss.scale_steps[3] == 9",         lss.scale_steps[3] == 9,                          true)
        _check("lss.root_note == 57",             lss.root_note == 57,                              true)
        _check("lss.phase_intro_text non-empty",  lss.phase_intro_text.length() > 0,               true)

    # --- Load luthier_frett.tres ---
    var lf = load("res://characters/luthier_frett.tres")
    _check("luthier_frett.tres loads",            lf != null,                                       true)
    if lf != null:
        _check("lf.character_name is Luthier Frett", lf.character_name == "Luthier Frett",         true)
        _check("lf.max_hp == 120",                lf.max_hp == 120,                                 true)
        _check("lf.attack_power == 14",           lf.attack_power == 14,                            true)
        _check("lf.solo_style is SoloStyle",      lf.solo_style != null,                            true)
        # Limit break fields: ResourceSaver may omit default-valued fields from the .tres text,
        # but they still resolve correctly at runtime via class defaults. Checking here confirms
        # the values are correct regardless of whether they appear literally in the file.
        _check("lf.limit_break_gauge == 0.0",     lf.limit_break_gauge == 0.0,                      true)
        _check("lf.charge_rate_perfect == 0.08",  lf.charge_rate_perfect == 0.08,                   true)
        _check("lf.charge_rate_good == 0.03",     lf.charge_rate_good == 0.03,                      true)
        _check("lf.limit_break_phase_length == 8", lf.limit_break_phase_length == 8,                true)
        _check("lf.limit_break_multiplier == 2.5", lf.limit_break_multiplier == 2.5,                true)
        if lf.solo_style != null:
            _check("lf.solo_style.instrument_name",  lf.solo_style.instrument_name == "Lute",      true)

    print("=== done ===")

func _check(label: String, got, expected) -> void:
    if got == expected:
        print("  PASS  %s" % label)
    else:
        printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
