# Roadmap

Last reviewed: 2026-08-10. This roadmap reflects current source, repository
history, the preserved project-status snapshot, and historical plans. It tracks
meaningful milestones rather than every source comment.

## Now

### N1 — Restore trustworthy automated verification

Tracking: [GitHub issue #5](https://github.com/Parz1val1/rhythm-game-prototype/issues/5)

- Repair the three stale tests identified by the strict audit:
  `test_character_input_profile.gd`, `test_defend_percussive.gd`, and
  `test_string_golem.gd`.
- Re-run all discovered test scripts and require clean raw diagnostics plus a
  completion marker from every script.
- Replace the dated audit baseline in `docs/DEVELOPMENT.md` after the suite is
  genuinely green.

This is test/interface maintenance. Current evidence does not require gameplay
changes.

### N2 — Define the next demo-ready combat integration slice

Tracking: [GitHub issue #6](https://github.com/Parz1val1/rhythm-game-prototype/issues/6)

The historical plan names a polished full fight as the publisher-demo checkpoint,
but no scoped implementation plan is currently active. Select a coherent slice
from the known remaining work before implementation:

- per-hit score/offset feedback;
- combat arena and UI layout polish;
- composed backing track and real drum/string samples; or
- input-latency calibration.

## Next

### X1 — Character-specific limit-break sequences

- Design Beatrice and Luthier's sequences together so percussion and melody remain
  mechanically distinct.
- Use the existing debug gauge-fill and limit-phase infrastructure for iteration.
- Gauge persistence between fights remains a later persistence concern.

### X2 — Demo playtest infrastructure

- Calibration flow for audio/input latency across machines and audio setups.
- Controller mappings and feel validation, especially simultaneous/chord inputs.
- Endless mode for open-ended combat playtesting.
- UI layout and placeholder-to-near-real art/audio pass.

## Later

### L1 — Vertical slice

- Beat-locked `AudioDirector` and scene transitions without music restart.
- Persistent `WorldState` and save/load.
- String-planet overworld and Resonance Cave dungeon.
- Musical puzzle system and two-phase String Warden boss.
- String-planet art/audio pass and a polished 15–20 minute playthrough.

### L2 — Expanded party play

- Multi-character turn order, targeting, party UI, and cross-party effects.
- Team-combo limit breaks for duets/trios/quartets.

The current party-shaped APIs are seams, not proof that party orchestration exists.

## Completed

- **Foundation hardening:** audio-corrected beat/sub-beat clock, `ActiveNote`, note
  lookahead/pre-injection, float beat offsets, safe signal teardown, audio buses,
  and deep-copy Resource rules.
- **Shared character system:** input profiles, chords, attack evaluators, defense
  types, solo styles, Beatrice and Luthier, character/encounter replay selection.
- **Neutral encounter patterns:** character-independent hits with deterministic
  translation into directional or percussive notes.
- **Turn flow:** `DECISION` phase and beat-snapped Attack/Defend/Item/Run actions.
- **Pre-demo fix batch (2026-06-19):** visual/score parity fix, DEFEND UI cleanup,
  enemy HP rebalance, and debug limit-gauge fill. These supersede the unchecked
  items in the preserved 2026-06-19 status snapshot.

## Design Backlog

Enemy concepts that are not scheduled implementation work remain in
[enemy-design-ideas.md](enemy-design-ideas.md).
