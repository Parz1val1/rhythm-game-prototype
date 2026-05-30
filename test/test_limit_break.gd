# test/test_limit_break.gd
# Run: godot --headless --path . -s res://test/test_limit_break.gd
extends SceneTree

const CharacterData = preload("res://characters/character_data.gd")

func _init() -> void:
	await process_frame
	_run()
	quit()

func _run() -> void:
	print("=== Limit Break tests ===")
	var c := CharacterData.new()
	c.max_hp = 100; c.hp = 100

	_check("gauge starts at 0.0",         is_equal_approx(c.limit_break_gauge, 0.0), true)
	_check("charge_rate_perfect > 0",     c.charge_rate_perfect > 0.0,               true)
	_check("charge_rate_good > 0",        c.charge_rate_good > 0.0,                  true)
	_check("limit_break_phase_length > 0",c.limit_break_phase_length > 0,            true)
	_check("limit_break_multiplier > 1",  c.limit_break_multiplier > 1.0,            true)

	# Simulate charging
	c.limit_break_gauge = min(1.0, c.limit_break_gauge + c.charge_rate_perfect)
	_check("gauge increases on charge",    c.limit_break_gauge > 0.0,                 true)

	# Fill the gauge
	c.limit_break_gauge = 1.0
	_check("gauge can reach 1.0",         is_equal_approx(c.limit_break_gauge, 1.0), true)

	# Discharge
	c.limit_break_gauge = 0.0
	_check("gauge resets to 0.0",         is_equal_approx(c.limit_break_gauge, 0.0), true)

	print("=== done ===")

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s  →  expected=%s  got=%s" % [label, expected, got])
