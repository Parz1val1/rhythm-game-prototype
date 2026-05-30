# tools/create_luthier_resources.gd
# One-shot resource generator. Run once with:
#   godot --headless --path . -s res://tools/create_luthier_resources.gd
# Generates:
#   characters/luthier_solo_style.tres
#   characters/luthier_frett.tres
extends SceneTree

const SoloStyle     = preload("res://characters/solo_style.gd")
const CharacterData = preload("res://characters/character_data.gd")

func _init() -> void:
    await process_frame
    _run()
    quit()

func _run() -> void:
    print("=== Creating Luthier resources ===")

    # --- SoloStyle ---
    var style := SoloStyle.new()
    style.instrument_name = "Lute"
    style.audio_bus       = "Master"   # "Strings" bus doesn't exist yet; use Master
    style.scale_steps     = [0, 2, 7, 9]
    style.root_note       = 57
    style.accent_color    = Color(0.85, 0.65, 0.25, 1.0)
    style.phase_intro_text = "Luthier takes the stage!"

    var err := ResourceSaver.save(style, "res://characters/luthier_solo_style.tres")
    if err != OK:
        printerr("FAIL: could not save luthier_solo_style.tres  (error %d)" % err)
        return
    print("  saved: characters/luthier_solo_style.tres")

    # Reload to confirm round-trip before embedding in CharacterData
    var loaded_style = load("res://characters/luthier_solo_style.tres")
    if loaded_style == null:
        printerr("FAIL: reload of luthier_solo_style.tres returned null")
        return

    # --- CharacterData ---
    var luthier := CharacterData.new()
    luthier.character_name          = "Luthier Frett"
    luthier.max_hp                  = 120
    luthier.hp                      = 120
    luthier.attack_power            = 14
    luthier.limit_break_gauge       = 0.0
    luthier.charge_rate_perfect     = 0.08
    luthier.charge_rate_good        = 0.03
    luthier.limit_break_phase_length = 8
    luthier.limit_break_multiplier  = 2.5
    luthier.solo_style              = loaded_style   # embed the saved style

    err = ResourceSaver.save(luthier, "res://characters/luthier_frett.tres")
    if err != OK:
        printerr("FAIL: could not save luthier_frett.tres  (error %d)" % err)
        return
    print("  saved: characters/luthier_frett.tres")

    # Final confirmation
    var lf = load("res://characters/luthier_frett.tres")
    if lf == null:
        printerr("FAIL: reload of luthier_frett.tres returned null")
    elif lf.solo_style == null:
        printerr("FAIL: luthier_frett.solo_style is null after reload")
    else:
        print("  confirmed: luthier_frett.solo_style.instrument_name = %s" % lf.solo_style.instrument_name)

    print("=== done ===")
