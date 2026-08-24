# Wwise-specific implementation hidden behind WwiseMusicAdapter's runtime seam.
# No combat or presentation caller should load this script directly.
extends RefCounted

const EVENT_NAME := "Play_Combat_Spike"
# Wwise.init() loads Init internally; the spike owns only its user bank.
const BANK_NAMES := ["Combat_Spike"]
const LAYER_STATE_GROUP := "Combat_Layer"
const LAYER_DISABLED_STATE := "Disabled"
const LAYER_ENABLED_STATE := "Enabled"
const SECTION_STATE_GROUP := "Combat_Section"
const SECTION_STATES := {
	"loop": "Loop",
	"alternate": "Alternate",
}

# AkUtils.AkCallbackType values from integration tag wwise_v2025.1.9.
const AK_END_OF_EVENT := 0x0001
const AK_MUSIC_SYNC_ALL := 0x7f00
const AK_ENABLE_GET_MUSIC_PLAY_POSITION := 0x200000
const CALLBACK_FLAGS := (
	AK_END_OF_EVENT
	| AK_MUSIC_SYNC_ALL
	| AK_ENABLE_GET_MUSIC_PLAY_POSITION
)
const AK_CURVE_LINEAR := 4

var _engine: Object


func setup_engine(engine: Object) -> void:
	_engine = engine


func initialize() -> bool:
	if _engine == null:
		if not Engine.has_singleton(&"Wwise"):
			return false
		_engine = Engine.get_singleton(&"Wwise")
	if not _engine.has_method(&"init") or not _engine.has_method(&"is_initialized"):
		return false
	if not bool(_engine.call(&"is_initialized")):
		_engine.call(&"init")
	if not bool(_engine.call(&"is_initialized")) or not _engine.has_method(&"load_bank"):
		return false
	for bank_name in BANK_NAMES:
		if not bool(_engine.call(&"load_bank", bank_name)):
			return false
	return true


func start_music(owner: Node, callback: Callable) -> int:
	if _engine == null \
			or not _engine.has_method(&"post_event_callback") \
			or not _engine.has_method(&"set_state"):
		return 0
	if not bool(_engine.call(&"set_state", LAYER_STATE_GROUP, LAYER_DISABLED_STATE)):
		return 0
	if not bool(_engine.call(&"set_state", SECTION_STATE_GROUP, SECTION_STATES["loop"])):
		return 0
	return int(_engine.call(
		&"post_event_callback",
		EVENT_NAME,
		CALLBACK_FLAGS,
		owner,
		callback
	))


func get_music_position(playing_id: int) -> Dictionary:
	if _engine == null or not _engine.has_method(&"get_playing_segment_info"):
		return {}
	var raw: Variant = _engine.call(&"get_playing_segment_info", playing_id, true)
	if not raw is Dictionary:
		return {}
	var segment := raw as Dictionary
	var beat_duration_seconds := float(segment.get("fBeatDuration", 0.0))
	if beat_duration_seconds <= 0.0:
		return {}
	return {
		&"position_ms": int(segment.get("iCurrentPosition", -1)),
		&"beat_duration_ms": beat_duration_seconds * 1000.0,
		&"segment_duration_ms": int(segment.get("iActiveDuration", 0)),
	}


func set_layer_enabled(enabled: bool) -> bool:
	if _engine == null or not _engine.has_method(&"set_state"):
		return false
	var state := LAYER_ENABLED_STATE if enabled else LAYER_DISABLED_STATE
	return bool(_engine.call(&"set_state", LAYER_STATE_GROUP, state))


func request_transition(section: StringName) -> bool:
	if _engine == null or not _engine.has_method(&"set_state"):
		return false
	var section_key := String(section)
	if not SECTION_STATES.has(section_key):
		return false
	return bool(_engine.call(
		&"set_state",
		SECTION_STATE_GROUP,
		SECTION_STATES[section_key]
	))


func stop_music(playing_id: int) -> void:
	if _engine != null and _engine.has_method(&"stop_event"):
		_engine.call(&"stop_event", playing_id, 0, AK_CURVE_LINEAR)


func shutdown() -> void:
	if _engine != null \
			and _engine.has_method(&"is_initialized") \
			and bool(_engine.call(&"is_initialized")) \
			and _engine.has_method(&"shutdown"):
		_engine.call(&"shutdown")
