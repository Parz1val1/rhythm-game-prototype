# Product

The canonical target for combat behavior is
[Combat System v1](combat/COMBAT_SPEC_V1.md). This document provides product-level
scope; it does not restate the combat specification.

## What We Are Building

**Song of the Stars** is a rhythm RPG about resolving encounters through musical
conversation. The party listens to other performers, responds to demonstrate
understanding, makes tactical musical choices, and performs through distinct
character-specific interaction languages. A successful encounter should evolve
from challenge into a shared jam.

This repository exists to validate that combat vision before a larger game is
built around it. The current HP-based Attack/Defend prototype is an implementation
foundation and migration source, not the target product model.

## Audience and Problem

The intended commercial audience, target age, release platforms, business model,
and accessibility requirements are not documented yet.

The design problem is narrower: determine whether listening, tactics, physical
performance, and an evolving arrangement can form a satisfying RPG encounter
before investing in overworld, story, and production content.

## Core Experiences

- Listen to an opponent's phrase and answer it as musical communication.
- Make unpressured tactical choices while the arrangement continues to vamp.
- Perform multi-bar skills through character-specific rhythm languages.
- Build Groove toward a Jam while protecting the band's Composure.
- Hear the arrangement develop in response to execution and tactical choices.
- Discover opponent preferences and create useful interactions across the party.

## Product Principles

- **Musical conversation.** Combat expresses listening, understanding, and shared
  creation rather than conventional violence with a musical skin.
- **Audio feel first.** Perceived audio time governs performance, and significant
  combat state should become audible without sacrificing visual accessibility.
- **Characters should play differently.** Each rhythm language should ask the
  player's hands to think differently.
- **Listening is play.** Tactical Vamps can continue indefinitely; stopping to hear
  the created arrangement carries no punishment.
- **Execution enables tactics.** Progression and preferences amplify successful
  performance rather than replacing it.
- **Prototype before expanding.** Test the relationships and questions in Combat
  System v1 before balancing formulas or building content breadth.

## Scope

### Current prototype

- One local Godot combat scene with no network or backend.
- Two playable characters and multiple Resource-authored encounters.
- A legacy `DECISION`, `ATTACK`, and `DEFEND` phase model.
- Character-specific attack evaluation and directional/percussive defense.
- HP/damage resolution, combo, limit gauge, combat UI, note lanes, replay
  selection, and debug logging.
- Temporary procedural playtest loops and incomplete instrument feedback assets;
  no production soundtrack or dynamic arrangement exists yet.
- Initial standardized controller bindings: Luthier supports D-pad and positional
  face-button directions, while Beatrice supports left/right triggers. Remapping,
  glyph adaptation, and calibration are not implemented.

See the [V1 reconciliation ledger](combat/reconciliation-v1.md) for the exact
current/target gap and reusable foundations.

### Planned, but not implemented

- The Combat System v1 cadence, Groove, Composure, shared Multiplier,
  character-specific Inspiration, skills, and musical preferences.
- Multi-character party performances, evolving arrangement feedback, input/audio
  calibration, controller remapping and glyph adaptation, and real instrument
  samples.
- A vertical slice with beat-locked music stems, overworld exploration, a dungeon,
  musical puzzles, a boss encounter, world state, and save/load.

### Explicitly outside the current prototype

- A complete overworld, story campaign, production art/audio pass, or shipping UI.
- Multi-character party orchestration in the current implementation. Combat
  System v1 requires it eventually, but current play uses one active character.
- Online play, accounts, authentication, telemetry, or cloud persistence.

See [ROADMAP.md](ROADMAP.md) for ordering and [ARCHITECTURE.md](ARCHITECTURE.md)
for the implemented system.
