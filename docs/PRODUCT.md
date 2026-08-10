# Product

## What We Are Building

**Song of the Stars** is a rhythm RPG. This repository currently contains a
combat prototype whose purpose is to validate that beat-timed attacking,
defending, and turn selection feel fun before a larger game is built around it.

The prototype combines turn-based decisions with character-specific musical
performance. A player chooses an action, performs inputs in time with continuous
music, reads enemy patterns during defense, and uses timing quality and musical
coherence to affect combat outcomes.

## Audience and Problem

The intended commercial audience, target age, release platforms, business model,
and accessibility requirements are not documented yet.

The validated design problem is narrower: determine whether a rhythm-driven RPG
combat loop can feel responsive, readable, and distinct across different musical
characters before investing in overworld, story, and production content.

## Core Experiences

- Choose `Attack`, `Defend`, `Item`, or `Run` while the backing music continues.
- Attack through a character's musical vocabulary:
  - Beatrice Styx uses two-button percussion and chords.
  - Luthier Frett uses four-direction melodic input.
- Defend against visible, beat-aligned enemy patterns translated into the active
  character's input vocabulary.
- Build timing/combo multipliers and charge a limit gauge.
- Replay encounters with a different character or enemy group without carrying
  mutated Resource state between fights.

## Product Principles

- **Audio feel first.** Scoring follows perceived audio time, not accumulated frame
  time, and future transitions are intended to respect the beat.
- **Characters should play differently.** Input profiles, evaluators, defense
  styles, visuals, and instrument routing create distinct musical identities.
- **Enemies should remain character-neutral.** Encounter patterns describe timing
  and lane count; the defending character determines the concrete inputs.
- **Prototype before expanding.** Prove and polish combat before building the
  planned world, dungeon, boss, and save systems.
- **Deterministic patterns.** A given enemy pattern and character resolve the same
  way each time so behavior can be tested and replayed.

## Scope

### Current prototype

- One local Godot combat scene with no network or backend.
- Two playable characters and multiple Resource-authored encounters.
- `DECISION`, `ATTACK`, and `DEFEND` phases.
- Character-specific attack evaluation and directional/percussive defense.
- Combo, limit gauge, combat UI, note lanes, replay selection, and debug logging.
- Placeholder backing audio and incomplete instrument feedback assets.

### Planned, but not implemented

- A polished, demo-ready combat integration pass.
- Character-specific limit-break sequences, calibration, controller support,
  stronger visual/audio feedback, and real instrument samples.
- A vertical slice with beat-locked music stems, overworld exploration, a dungeon,
  musical puzzles, a boss encounter, world state, and save/load.

### Explicitly outside the current prototype

- A complete overworld, story campaign, production art/audio pass, or shipping UI.
- Multi-character party orchestration and team-combo gameplay. The combat data
  model has a party seam, but current play uses one active character.
- Online play, accounts, authentication, telemetry, or cloud persistence.

See [ROADMAP.md](ROADMAP.md) for ordering and [ARCHITECTURE.md](ARCHITECTURE.md)
for the implemented system.
