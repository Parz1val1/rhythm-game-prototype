# characters/character_input_profile.gd
# Describes how a character maps physical inputs to game actions.
# Compose with CharacterData.solo_style: this is behavior; solo_style is identity.
# One profile per character type — Luthier and Beatrice share nothing except the seam.
class_name CharacterInputProfile
extends Resource

## Which input actions this character's inputs are filtered to.
## An empty array means "accept all registered rhythm actions" (default / Luthier path).
## Example for a 4-direction player: [&"up", &"down", &"left", &"right"]
@export var valid_inputs: Array[StringName] = []

## Chord definitions: each entry is an Array of StringName actions that,
## when pressed within chord_window_ms of each other, register as one combined action.
## The combined action name is the entries joined with "+" e.g. "up+down".
## Example: [[&"up", &"down"], [&"left", &"right"]]
@export var chord_inputs: Array[Array] = []

## How close together (ms) two simultaneous inputs must be to count as a chord.
@export var chord_window_ms: float = 30.0

## How this character's ATTACK phase is scored.
## &"rhythm"  — directional timing (the Luthier / default path).
## &"pitch"   — pitch/note matching (Beatrice's path, not yet implemented).
@export var scoring_mode: StringName = &"rhythm"

## Which AttackEvaluator class to use for ATTACK phase damage.
## Matched by name in CombatScene._create_evaluator().
## &"passthrough" preserves the current SequenceEvaluator-based behavior.
@export var attack_evaluator: StringName = &"passthrough"

## How the DEFEND phase interprets incoming notes.
## &"directional" — arrow-matching (current default).
## &"percussive"  — timing-only (Beatrice's path, not yet implemented).
@export var defense_pattern_type: StringName = &"directional"
