# characters/character_input_profile.gd
# Describes how a character maps physical inputs to game actions.
# Compose with CharacterData.solo_style: this is behavior; solo_style is identity.
# One profile per character type — Luthier and Beatrice share nothing except the seam.
class_name CharacterInputProfile
extends Resource

## Maps InputMap action names to the direction alias they produce.
## The alias is what flows through RhythmInput, notes, evaluators, and audio.
##
## Examples:
##   Luthier (translated):  {&"rhythm_up": &"up", &"rhythm_down": &"down", ...}
##   Beatrice (identity):   {&"drum_left": &"drum_left", &"drum_right": &"drum_right"}
##
## An empty dictionary means "use the built-in default directional map" — the same
## fallback used when no profile is set at all (rhythm_up/down/left/right → up/down/left/right).
@export var input_map: Dictionary = {}

## Chord definitions: each entry is an Array of direction aliases (the VALUES of
## input_map, not raw action names) that, when all appear in the chord buffer within
## chord_window_ms of each other, fire as a single combined action.
## Example: [[&"drum_left", &"drum_right"]]
@export var chord_inputs: Array[Array] = []

## Output action name for each chord in chord_inputs (parallel array).
## When empty or shorter than chord_inputs, the output name auto-generates as "a+b".
## Example: [&"drum_both"] makes drum_left+drum_right register as &"drum_both".
@export var chord_names: Array[StringName] = []

## How close together (ms) two simultaneous inputs must be to count as a chord.
@export var chord_window_ms: float = 30.0

## How this character's ATTACK phase is scored.
## &"rhythm"  — directional timing (the Luthier / default path).
## &"pitch"   — pitch/note matching (Beatrice's path, not yet implemented).
@export var scoring_mode: StringName = &"rhythm"

## Which AttackEvaluator class to use for ATTACK phase damage.
## Matched by name in CombatScene._create_evaluator().
@export var attack_evaluator: StringName = &"passthrough"

## How the DEFEND phase interprets incoming notes.
## &"directional" — arrow-matching (current default).
## &"percussive"  — timing-only (Beatrice's path).
@export var defense_pattern_type: StringName = &"directional"
