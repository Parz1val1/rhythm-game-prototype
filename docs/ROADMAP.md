# Roadmap

Last reviewed: 2026-08-11. [Combat System v1](combat/COMBAT_SPEC_V1.md) is the
north star for combat prototyping. Ordering after the first slice remains
provisional and should respond to playtest evidence.

## Now

### C1 — Approve the first Combat System v1 conversation slice

Tracking: [Combat V1 epic #8](https://github.com/Parz1val1/rhythm-game-prototype/issues/8).

The first conversation slice is specified as issues
[#9](https://github.com/Parz1val1/rhythm-game-prototype/issues/9) through
[#15](https://github.com/Parz1val1/rhythm-game-prototype/issues/15), beginning with
the isolated V1 harness and ending at the human playtest gate:

- a short Settle;
- one authored Enemy Phrase with no required input;
- a distinct Response using an existing character rhythm language;
- minimal Groove, Composure, and shared Multiplier state;
- an indefinite Tactical Vamp with continuous music; and
- provisional Jam/loss endpoints for testing, without settling final formulas.

The previous demo-polish direction in
[issue #6](https://github.com/Parz1val1/rhythm-game-prototype/issues/6) is closed as
superseded.

## Next

### C2 — Skills and character performances

- Define the smallest skill model that joins a musical effect to a character's
  rhythm-game interaction.
- Test multi-bar performance duration and the pacing between Tactical Vamps and
  active play.
- Preserve distinct Luthier and Beatrice interaction languages.

### C3 — Party tactics and opponent preferences

- Add multiple character performance opportunities to the cadence.
- Test the working Rhythm, Melody, and Harmony contributions against discoverable
  opponent preferences.
- Validate that support choices keep every party member useful.

### C4 — Arrangement as feedback and reward

- Make Groove, Composure, Multiplier, contributions, and opponent synchronization
  audible in the evolving arrangement.
- Test whether the player feels they helped create the song.
- Add visual and accessibility equivalents alongside audio feedback.

## Later

### L1 — Progression and expressive breadth

- Inspiration persistence, floors, generation, and skill costs.
- Skill loadouts and acquisition through progression, story, and exploration.
- Guided, character-specific improvisation.
- Duets, Ensembles, and Finale/Limit Performances after their open design questions
  are resolved.

### L2 — Vertical slice

- Overworld-to-combat musical transitions and beat-locked stems.
- Wild musical creature discovery, a dungeon, musical puzzles, and a boss that
  bends the established combat language.
- Persistent world state and save/load.
- A polished 15–20 minute playthrough.

## Completed

- **Combat System v1 intake (2026-08-11):** established the new normative combat
  design, canonical vocabulary, authority routing, and current/target
  reconciliation without changing runtime behavior.
- **N1 — Trustworthy automated verification (2026-08-11):** updated three stale
  tests to the current typed-array, input-map, and autoload-loading contracts. The
  strict suite is green across 35 scripts and 422 visible `PASS` results. Tracking:
  [GitHub issue #5](https://github.com/Parz1val1/rhythm-game-prototype/issues/5).
- **Foundation hardening:** audio-corrected beat/sub-beat clock, `ActiveNote`, note
  lookahead/pre-injection, float beat offsets, safe signal teardown, audio buses,
  and deep-copy Resource rules.
- **Shared character foundation:** input profiles, chords, attack evaluators,
  defense types, solo styles, Beatrice and Luthier, and replay selection.
- **Legacy neutral encounter patterns:** character-independent hits with
  deterministic translation into directional or percussive notes.
- **Legacy turn flow:** `DECISION`, `ATTACK`, and `DEFEND` phases with beat-snapped
  actions.
- **Pre-demo fix batch (2026-06-19):** visual/score parity, DEFEND UI cleanup,
  encounter HP rebalance, and debug limit-gauge fill for the legacy loop.

## Design Backlog

Enemy concepts that are not scheduled implementation work remain in
[enemy-design-ideas.md](enemy-design-ideas.md).
