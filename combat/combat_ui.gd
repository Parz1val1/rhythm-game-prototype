# combat/combat_ui.gd
# Displays all combat state: HP bars, phase, combo, limit break gauge, beat pulse.
# Call setup(combat, player_character) once after the combat scene is ready.
# Extends CanvasLayer so it always renders on top of 2D world content.
extends CanvasLayer

const CharacterData = preload("res://characters/character_data.gd")

@onready var _phase_label:    Label     = $BGPanel/HBoxTop/PhaseLabel
@onready var _beat_pulse:     ColorRect = $BGPanel/HBoxTop/BeatPulse
@onready var _combo_label:    Label     = $BGPanel/HBoxTop/ComboLabel
@onready var _player_name:    Label     = $PlayerBar/PlayerName
@onready var _player_fill:    ColorRect = $PlayerBar/HPBarBG/HPBarFill
@onready var _player_numbers: Label     = $PlayerBar/HPNumbers
@onready var _enemy_name:     Label     = $EnemyBar/PlayerName
@onready var _enemy_fill:     ColorRect = $EnemyBar/HPBarBG/HPBarFill
@onready var _enemy_numbers:  Label     = $EnemyBar/HPNumbers
@onready var _limit_fill:     ColorRect = $LimitBar/LimitBarBG/LimitBarFill
@onready var _limit_ready:    Label     = $LimitBar/LimitReady

var _combat = null
var _hero: CharacterData = null
## Maximum pixel width of the HP / limit break bars. Matches HPBarBG width in the scene.
var _bar_max_width: float = 200.0

## Call once after EncounterManager.start_combat() returns.
func setup(combat: Node, hero: CharacterData) -> void:
	_combat = combat
	_hero   = hero
	_player_name.text = hero.character_name

	# Tint phase label with character's accent color when SoloStyle is set.
	if hero.solo_style != null:
		_phase_label.add_theme_color_override("font_color", hero.solo_style.accent_color)

	combat.phase_changed.connect(_on_phase_changed)
	combat.combo_updated.connect(_on_combo_updated)
	combat.limit_break_ready.connect(_on_limit_break_ready)
	combat.limit_break_ended.connect(_on_limit_break_ended)
	BeatClock.beat.connect(_on_beat)

func _exit_tree() -> void:
	if BeatClock.beat.is_connected(_on_beat):
		BeatClock.beat.disconnect(_on_beat)
	if is_instance_valid(_combat):
		if _combat.phase_changed.is_connected(_on_phase_changed):
			_combat.phase_changed.disconnect(_on_phase_changed)
		if _combat.combo_updated.is_connected(_on_combo_updated):
			_combat.combo_updated.disconnect(_on_combo_updated)
		if _combat.limit_break_ready.is_connected(_on_limit_break_ready):
			_combat.limit_break_ready.disconnect(_on_limit_break_ready)
		if _combat.limit_break_ended.is_connected(_on_limit_break_ended):
			_combat.limit_break_ended.disconnect(_on_limit_break_ended)

func _process(_delta: float) -> void:
	if not is_instance_valid(_hero) or not is_instance_valid(_combat):
		return

	# --- Player HP bar ---
	var hp_ratio: float = float(_hero.hp) / float(_hero.max_hp)
	_player_fill.size.x = _bar_max_width * clampf(hp_ratio, 0.0, 1.0)
	_player_numbers.text = "%d / %d" % [_hero.hp, _hero.max_hp]
	_player_fill.color   = _hp_color(hp_ratio)

	# --- Enemy HP bar --- show the current attack target.
	var enemy = _combat.get_attack_target()
	if enemy != null:
		_enemy_name.text = enemy.enemy_name
		var e_ratio: float = float(enemy.hp) / float(enemy.max_hp)
		_enemy_fill.size.x = _bar_max_width * clampf(e_ratio, 0.0, 1.0)
		_enemy_numbers.text = "%d / %d" % [enemy.hp, enemy.max_hp]
		_enemy_fill.color   = _hp_color(e_ratio)
	else:
		_enemy_name.text   = "—"
		_enemy_fill.size.x = 0.0
		_enemy_numbers.text = ""

	# --- Limit break bar ---
	var lb_ratio: float = clampf(_hero.limit_break_gauge, 0.0, 1.0)
	_limit_fill.size.x = _bar_max_width * lb_ratio
	_limit_fill.color  = Color(0.9, 0.7, 0.1) if lb_ratio < 1.0 else Color(1.0, 0.95, 0.2)

func _on_phase_changed(new_phase: int) -> void:
	_phase_label.text = "ATTACK" if new_phase == 0 else "DEFEND"
	# Brief flash on phase transition.
	var tween := create_tween()
	tween.tween_property(_phase_label, "modulate", Color(1.5, 1.5, 0.5), 0.0)
	tween.tween_property(_phase_label, "modulate", Color.WHITE, 0.3)

func _on_combo_updated(combo: int, multiplier: float) -> void:
	if combo <= 0:
		_combo_label.text = ""
		return
	_combo_label.text = "Combo: %d  ×%.1f" % [combo, multiplier]

func _on_limit_break_ready(_char: CharacterData) -> void:
	_limit_ready.visible = true
	_limit_ready.text = "SPACE → LIMIT BREAK!"

func _on_limit_break_ended() -> void:
	_limit_ready.visible = false

func _on_beat(_beat_number: int) -> void:
	_beat_pulse.color = Color(1.0, 1.0, 0.3)
	var tween := create_tween()
	tween.tween_property(_beat_pulse, "color", Color(0.2, 0.2, 0.2), 0.08)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.2, 0.85, 0.3)   # green
	elif ratio > 0.25:
		return Color(0.95, 0.75, 0.1)  # yellow
	else:
		return Color(0.9, 0.2, 0.2)    # red
