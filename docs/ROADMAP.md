# Roadmap

Last reviewed: 2026-08-24. [Combat System v1](combat/COMBAT_SPEC_V1.md) is the
north star for combat prototyping. Ordering after the first slice remains
provisional and should respond to playtest evidence.

## Now

### C2 — Skills and character performances

Tracking: [Combat V1 epic #8](https://github.com/Parz1val1/rhythm-game-prototype/issues/8),
beginning with [issue #16](https://github.com/Parz1val1/rhythm-game-prototype/issues/16).

The human playtest gate in
[#15](https://github.com/Parz1val1/rhythm-game-prototype/issues/15) approved the
core conversation cadence and unblocked Phase B. Start with the smallest useful
Skill and multi-bar Character Performance model:

- Define the smallest skill model that joins a musical effect to a character's
  rhythm-game interaction.
- Test multi-bar performance duration and the pacing between Tactical Vamps and
  active play.
- Preserve distinct Luthier and Beatrice interaction languages.
- Allow the count-in presentation cleanup in
  [#42](https://github.com/Parz1val1/rhythm-game-prototype/issues/42) to land before
  or alongside early Phase B work.
- Add the small Enemy Phrase repertoire in
  [#43](https://github.com/Parz1val1/rhythm-game-prototype/issues/43) before the
  #20 playtest draws conclusions about phrase difficulty or Multiplier pressure;
  it does not block starting #16.

## Next

### C3 — Party tactics and opponent preferences

- Add multiple character performance opportunities to the cadence.
- Test the working Rhythm, Melody, and Harmony contributions against discoverable
  opponent preferences.
- Validate that support choices keep every party member useful.

### C4 — Arrangement as feedback and reward

- After the Phase B gate in #20, define #21's repository-owned arrangement intent
  and evaluate the Wwise path selected by #45 in real combat behind repository-
  owned timing and arrangement interfaces.
- Make Groove, Composure, Multiplier, contributions, and opponent synchronization
  audible in the evolving arrangement.
- Test whether the player feels they helped create the song.
- Add visual and accessibility equivalents alongside audio feedback.
- Keep native Godot audio selectable until the real-combat timing, lifecycle,
  transition, teardown, and Windows export checks pass.

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

- **Wwise musical-timeline and arrangement spike (2026-08-24):** issue #45 selected
  pinned Wwise 2025.1.9.9197 plus its community Godot integration for #21's later
  arrangement prototype behind repository-owned interfaces. A 15-minute timing
  soak, manual editor replay, authored layer/section transitions, and a Windows
  release runtime passed; native Godot audio remains the rollback path and
  shipping/platform adoption remains conditional.
- **C1 — First Combat System v1 conversation slice (2026-08-19):** delivered and
  approved the isolated Settle → Enemy Phrase → Response → Tactical Vamp loop
  through issues #9–#15, then completed playtest-driven readability and musical-agency
  revisions in #34 and #36–#38. The human replay approved the cadence, retained
  its durations as provisional tuning values, selected Stonebeat as the preferred
  playtest backing track, and explicitly unblocked Phase B.
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
