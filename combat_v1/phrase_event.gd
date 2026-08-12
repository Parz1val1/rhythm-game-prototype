## One authored musical event within an OpponentPhrase.
##
## The cue identifiers are presentation seams, not production assets: audio and
## visual consumers receive the same event and decide how to realize each cue.
class_name OpponentPhraseEvent
extends Resource

## Zero-based musical position within the phrase. Combat V1 currently supports
## the BeatClock's quarter-beat subdivisions.
@export_range(0.0, 15.75, 0.25) var beat_offset: float = 0.0

## Stable response-facing identity and human-readable presentation copy.
@export var prompt_id: StringName = &""
@export var prompt_text: String = ""

## Symbolic handoffs for production audio and visual consumers.
@export var audio_cue: StringName = &""
@export var visual_cue: StringName = &""
