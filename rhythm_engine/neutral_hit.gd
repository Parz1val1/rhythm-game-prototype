## Abstract beat in an enemy's attack pattern — character-vocabulary-independent.
## beat_offset: timing position within the repeating phase (matches NoteData.beat_offset).
## lane_count:  1 = single input required; 2 = simultaneous pair (chord for percussive,
##              two arrows for directional). Resolved to character vocabulary at injection.
class_name NeutralHit
extends Resource

@export var beat_offset: float = 0.0
@export var lane_count: int = 1
