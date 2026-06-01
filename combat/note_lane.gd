# combat/note_lane.gd
# Visualizes incoming notes during the DEFEND phase.
# Each direction has a hit zone placed in a cross pattern at the center of the
# screen; notes approach from the matching viewport edge so direction is
# spatially obvious (up notes fall from the top, left notes slide from the left, etc.)
# Call setup(combat) once after EncounterManager.start_combat*() returns.
extends Control

const NoteVisualScene = preload("res://combat/note_visual.tscn")
const NoteData        = preload("res://rhythm_engine/note_data.gd")

# Distance from viewport center to each hit zone's center (px).
const HIT_ZONE_OFFSET: float = 80.0
# Hit zone square size (px).
const HIT_ZONE_SIZE: float = 44.0
# NoteVisual is 34×34; half-size used for centering.
const NOTE_HALF: float = 17.0

# Hit zone dim/flash colors.
const HZ_DIM     := Color(0.25, 0.20, 0.05)
const HZ_PERFECT := Color(0.40, 1.00, 0.50)
const HZ_GOOD    := Color(1.00, 0.85, 0.30)
const HZ_MISS    := Color(1.00, 0.25, 0.25)

@onready var _phase_info: Label = $PhaseInfo

# Populated in _ready(). Keys are String ("up"/"down"/"left"/"right").
var _hit_zones:     Dictionary = {}   # String → ColorRect (the zone background)
var _hz_centers:    Dictionary = {}   # String → Vector2  (screen-space center)
var _spawn_centers: Dictionary = {}   # String → Vector2  (off-screen spawn point)

# Maps NoteData → NoteVisual currently travelling.
var _visuals: Dictionary = {}

var _lookahead_beats: int = 2

# Arrow glyphs used on hit zone labels.
const ARROW := { "up": "↑", "down": "↓", "left": "←", "right": "→" }

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_hit_zones()

## Wire this lane to a CombatScene after start_combat*() returns.
func setup(combat: Node) -> void:
	_lookahead_beats = combat.lookahead_beats
	combat.note_approaching.connect(_on_note_approaching)
	combat.phase_changed.connect(_on_phase_changed)
	RhythmInput.input_scored.connect(_on_input_scored)
	RhythmInput.note_missed.connect(_on_note_missed)
	visible = false   # hidden until first DEFEND phase

func _exit_tree() -> void:
	if RhythmInput.input_scored.is_connected(_on_input_scored):
		RhythmInput.input_scored.disconnect(_on_input_scored)
	if RhythmInput.note_missed.is_connected(_on_note_missed):
		RhythmInput.note_missed.disconnect(_on_note_missed)

# ---------------------------------------------------------------------------
# Hit zone construction
# ---------------------------------------------------------------------------

func _build_hit_zones() -> void:
	# Headless / first-frame guard: viewport may not be sized yet.
	var vp := get_viewport_rect().size
	if vp.x < 10.0 or vp.y < 10.0:
		vp = Vector2(1152.0, 648.0)

	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var off := HIT_ZONE_OFFSET
	var half_hz := HIT_ZONE_SIZE * 0.5

	_hz_centers = {
		"up":    Vector2(cx,        cy - off),
		"down":  Vector2(cx,        cy + off),
		"left":  Vector2(cx - off,  cy),
		"right": Vector2(cx + off,  cy),
	}
	# Spawn points are off-screen in the matching direction.
	_spawn_centers = {
		"up":    Vector2(cx,        -NOTE_HALF),
		"down":  Vector2(cx,        vp.y + NOTE_HALF),
		"left":  Vector2(-NOTE_HALF, cy),
		"right": Vector2(vp.x + NOTE_HALF, cy),
	}

	for dir in ["up", "down", "left", "right"]:
		var hz := ColorRect.new()
		hz.name     = "HitZone_" + dir
		hz.size     = Vector2(HIT_ZONE_SIZE, HIT_ZONE_SIZE)
		hz.position = (_hz_centers[dir] as Vector2) - Vector2(half_hz, half_hz)
		hz.color    = HZ_DIM
		add_child(hz)

		var lbl := Label.new()
		lbl.text                = ARROW[dir]
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		hz.add_child(lbl)

		_hit_zones[dir] = hz

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == 0:
		# Entering ATTACK: hide and clear travelling visuals.
		visible = false
		DebugLog.visual("[LANE   ] visible=false (ATTACK)")
		for visual in _visuals.values():
			if is_instance_valid(visual):
				visual.queue_free()
		_visuals.clear()
	# Do NOT auto-show on DEFEND entry. Show lazily in _on_note_approaching only
	# when a direction this lane handles actually arrives. This prevents empty
	# up/down/left/right hit zones appearing during a percussive-enemy DEFEND phase.

func _on_note_approaching(note: NoteData, target_beat: int) -> void:
	var dir := String(note.direction)
	if not _spawn_centers.has(dir):
		return
	# Reveal on first note this lane handles, so hit zones only appear when needed.
	if not visible:
		visible = true
		DebugLog.visual("[LANE   ] visible=true (first note_approaching for dir=%s)" % dir)

	var spawn_edge := _spawn_centers[dir] as Vector2
	var hit_zone   := _hz_centers[dir]    as Vector2

	# Use actual beats remaining so late-announced notes (e.g. beat_offset=0
	# emitted from the ATTACK→DEFEND transition) still arrive on time.
	var beats_remaining: float = max(1.0, float(target_beat - BeatClock.beat_number))
	var travel_time := beats_remaining * (60.0 / BeatClock.bpm)

	# Spawn at a position proportional to beats_remaining so every note travels
	# at the same apparent speed. Normal notes (beats_remaining == lookahead_beats)
	# spawn at the screen edge. Early-announced notes spawn proportionally closer
	# to the hit zone, making them visually distinct from same-direction notes that
	# spawn at the edge at the same moment.
	var spawn_fraction := minf(beats_remaining / float(_lookahead_beats), 1.0)
	var spawn_pos := hit_zone.lerp(spawn_edge, spawn_fraction)

	DebugLog.visual("[SPAWN  ] dir=%-5s  travel=%.0f ms  (%.1f beat(s))  spawn=%.0f%%" % [
		dir, travel_time * 1000.0, beats_remaining, spawn_fraction * 100.0])

	var visual: Control = NoteVisualScene.instantiate()
	add_child(visual)
	visual.init(note.direction)
	visual.position = spawn_pos - Vector2(NOTE_HALF, NOTE_HALF)

	var tween := create_tween()
	tween.tween_property(visual, "position",
		hit_zone - Vector2(NOTE_HALF, NOTE_HALF),
		travel_time)
	# Only queue_free the visual when the tween finishes — do NOT erase from
	# _visuals here. _on_input_scored and _on_note_missed are the sole owners of
	# cleanup. If we erased here, a press arriving slightly after the tween ends
	# would find no entry for this note, skip to the NEXT same-direction note,
	# and wrongly consume its visual.
	tween.tween_callback(func(): if is_instance_valid(visual): visual.queue_free())

	_visuals[note] = visual

func _on_input_scored(direction: StringName, score: StringName, _offset: float, note_consumed: bool) -> void:
	if not note_consumed:
		return
	var dir := String(direction)
	# Find the first entry for this direction and consume it.
	# The entry may be stale (visual already freed by the tween when the note
	# arrived at the hit zone) — in that case, erase the stale entry and flash
	# the hit zone. This prevents a late press from wrongly consuming a later
	# same-direction visual that is still travelling.
	for n in _visuals.keys():
		if String(n.direction) != dir:
			continue
		var v = _visuals.get(n)
		_visuals.erase(n)  # always consume the entry, travelling or arrived
		if is_instance_valid(v):
			v.flash_result(score)
			DebugLog.visual("[FLASH  ] dir=%-5s  score=%s  (note visual consumed)" % [dir, score])
		else:
			# Visual already arrived at the hit zone — just flash the zone.
			_flash_hit_zone(dir, score)
			DebugLog.visual("[FLASH  ] dir=%-5s  score=%s  (visual arrived, zone flash)" % [dir, score])
		return
	# No entry at all — note may have been consumed before visual spawned.
	DebugLog.visual("[FLASH  ] dir=%-5s  score=%s  (hit zone only — no visual entry)" % [dir, score])
	_flash_hit_zone(dir, score)

func _on_note_missed(note: NoteData) -> void:
	DebugLog.visual("[MISS   ] dir=%-5s  note expired — miss flash" % String(note.direction))
	if _visuals.has(note):
		var visual = _visuals.get(note)
		_visuals.erase(note)  # erase even if stale, to prevent build-up
		if is_instance_valid(visual):
			visual.flash_result(&"miss")
	_flash_hit_zone(String(note.direction), &"miss")

# ---------------------------------------------------------------------------
# Hit zone flash
# ---------------------------------------------------------------------------

func _flash_hit_zone(dir: String, score: StringName) -> void:
	var hz = _hit_zones.get(dir) as ColorRect
	if hz == null:
		return
	var color: Color
	match score:
		&"perfect": color = HZ_PERFECT
		&"good":    color = HZ_GOOD
		_:          color = HZ_MISS
	hz.color = color
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(hz):
		hz.color = HZ_DIM
