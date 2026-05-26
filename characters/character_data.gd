## Player character stats and progression state.
class_name CharacterData
extends Resource

@export var character_name: String = ""
@export var max_hp: int = 100
@export var hp: int = 100

## Base damage dealt on a perfect hit during ATTACK phase.
@export var attack_power: int = 10

## Current limit break charge. Range [0.0, 1.0].
## At 1.0 the limit break is available; call CombatScene.try_activate_limit_break().
@export var limit_break_gauge: float = 0.0

## Gauge fill per perfect hit (0.0–1.0).
@export var charge_rate_perfect: float = 0.08

## Gauge fill per good hit (0.0–1.0).
@export var charge_rate_good: float = 0.03

## How many beats the limit break ATTACK phase lasts (longer than normal phase).
@export var limit_break_phase_length: int = 8

## Damage multiplier applied to all hits during the limit break phase.
@export var limit_break_multiplier: float = 2.5
