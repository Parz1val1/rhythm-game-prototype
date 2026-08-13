# Combat System v1 Reconciliation

Last reviewed: 2026-08-11.

This ledger tracks the gap between the approved
[Combat System v1](COMBAT_SPEC_V1.md) target and the current prototype. It is a
migration aid, not an alternative specification. A legacy behavior remains valid
evidence and may contain reusable machinery even when its product model is being
replaced.

## Classification

- **Aligned seam** — current machinery supports the target without defining it.
- **Partial** — some behavior exists, but the V1 relationship is not implemented.
- **Missing** — the target behavior has no meaningful implementation yet.
- **Contradiction** — the current product model directly expresses a different
  rule.
- **Open** — V1 intentionally withholds the decision; do not resolve it incidentally.

## Core Model

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| Encounters are musical conversations culminating in a Jam | `CombatV1EncounterState` produces a typed one-shot `JAM` when configurable Groove reaches its provisional threshold, and the diagnostic HUD presents that outcome as finding a shared groove; the separately configured legacy flow still resolves victory through enemy HP | **Partial** | Route later V1 performance slices through the new state seam, then retire damage framing only as those slices replace the legacy flow. The final maximum-Groove interaction remains open. |
| Groove begins empty and measures synchronization | `CombatV1EncounterState` initializes Groove at zero, clamps it to configured bounds, and applies Multiplier-adjusted gains through one typed performance-result interface. Response phrase grades feed that seam, and the diagnostic HUD displays the public value and maximum without HP framing. | **Partial** | Keep the formula and six-grade mapping provisional; later performance and opponent-effectiveness slices must reuse the state owner rather than moving Multiplier math into callers. |
| Shared Composure begins full and reaches zero on execution failure | `CombatV1EncounterState` initializes one shared Composure value at its configured maximum and resolves a typed one-shot `LOSS` at zero. Response Near Miss, Miss, and broken-phrase summaries produce the matching execution inputs; the diagnostic HUD presents the shared meter and a nonviolent lost-groove outcome, while legacy characters still own individual HP outside V1. | **Partial** | Preserve the V1 state independently from legacy HP and route later Character Performance grading through the same typed state seam. |
| Multiplier is shared, band-wide momentum that modifies Groove | `CombatV1EncounterState` owns one configurable baseline/minimum/maximum Multiplier, applies it to Groove, raises it for correct execution, reduces it for mistakes, and resets excess momentum on a major mistake. The diagnostic HUD displays that shared value directly from `CombatV1.get_state()`. | **Partial** | Tune the provisional changes through playtesting; do not duplicate Multiplier math in performance callers or reuse evaluator-local damage multipliers. |
| Each character owns persistent Inspiration used by skills | `CharacterData` owns a limit gauge charged during ATTACK; durable persistence does not exist | **Contradiction** | Design Inspiration as a new resource. Limit-style resources remain open and must not be equated with Inspiration. |
| Correct execution can be tactically ineffective without harming Composure | The Issue #10 interface accepts separate `Execution` and `TacticalEffectiveness` enums. Correct-but-ineffective play defaults to zero Groove while preserving Composure and still building shared Multiplier | **Partial** | Later opponent-preference and skill slices should produce tactical effectiveness values without coupling those rules to execution or the state model. |

### Issue #10 provisional state seam

`CombatV1` owns `CombatV1EncounterState` and exposes
`apply_performance_result(execution, effectiveness)`, the merged `get_state()`
snapshot, `encounter_state_changed`, and typed `resolved` outcomes. The state
module is deterministic and has no input, UI, audio, timing-window, evaluator, or
legacy Character/Enemy dependency. It applies one result atomically, uses the
pre-result Multiplier for Groove, clamps all resources, and becomes immutable once
terminal.

The default gains, losses, bounds, threshold, and ineffective Groove scale are
configuration, not final balance. Response maps its six configurable grades onto
the coarse execution values (`CORRECT`, `NEAR_MISS`, `MISTAKE`,
`MAJOR_MISTAKE`); the encounter state still does not define timing windows or
replace those six execution truths.

An implementation-time product-owner decision settled the provisional competing
terminal rule for Issue #10: if one atomic result reaches both the Jam threshold
and zero Composure, `JAM` wins. The final maximum-Groove interaction remains open.

## Cadence and Interaction

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| `Approach -> Settle -> Enemy Phrase -> Response -> Tactical Vamp <-> Character Performance -> Full-Band Vamp -> Resolution` | `CombatV1` now runs the provisional Settle-free core loop `Settle -> Enemy Phrase -> Response -> Tactical Vamp -> Enemy Phrase -> ... -> Resolution`. Response results preserve encounter-wide state across rounds, and typed Jam/loss outcomes end the cadence. Character Performance, party ordering, and Full-Band Vamp behavior remain unimplemented. | **Partial** | Keep `CombatV1` as the migration seam. Replace the provisional direct next-round command when skills and party performances provide the missing middle cadence; leave the legacy `CombatScene` phase graph unchanged until a replacement is implemented. |
| Enemy Phrase is primarily a listening phase followed by a distinct Response | `CombatV1` deep-copies a V1 opponent resource, spends configurable four-beat bars in Settle, then reproduces the opponent's one-to-four-bar phrase from audio-corrected whole/half/quarter beat signals. Listening phases suppress `RhythmInput` scoring. Response begins only after the phrase duration, restores scoring, replays the heard offsets as active-profile actions, and emits note and phrase results. The diagnostic HUD gives listening and active Response distinct text/color treatments and visualizes the matching cue seam. Repeated rounds refresh the targets without repeating Settle. | **Aligned seam** | Preserve input-free listening and the separate phrase/Response presentation signals when party/performance cadence is added. |
| Tactical Vamps continue indefinitely with no time pressure | `CombatV1` leaves Tactical Vamp unchanged for any number of BeatClock cycles while its backing harness audio, clock, and timing/input subscriptions continue. One provisional `CONTINUE_ROUND` intent queues exactly one Enemy Phrase transition on the next whole beat; no skill or action is auto-selected. | **Aligned seam** | Preserve indefinite waiting and beat-aligned re-entry when the provisional command is replaced by selected skills and party rules. |
| Party members select skills and perform separate multi-bar interactions | The prototype uses one active character and four generic actions: Attack, Defend, Item, Run | **Contradiction** | Introduce a skill/performance seam and party cadence before content breadth. Item existence remains open. |
| Character rhythm languages should make the player's hands think differently | Luthier has four-direction melodic input on arrows, D-pad, or positionally matching face buttons; Beatrice has two-hand percussion on F/J or left/right triggers, plus chords, alternation, and separate visuals/evaluators. V1 Response accepts an active `CharacterInputProfile` and uses Luthier's four aliases for the first reproduction exercise. Fixed controller mappings exist, but remapping, glyph adaptation, calibration, and V1 party switching do not. | **Partial** | Retain the profile seam; Issue #18 owns party switching and broader language validation rather than expanding it inside Response. |
| Performance grading includes six working levels and phrase-level recovery | `CombatV1ResponseGrader` produces configurable Perfect, Great, Good, Near Miss, Miss, and Major Mistake note grades, then calculates an ordered phrase summary from configurable score and broken-phrase thresholds. Strong later notes can recover a phrase after one mistake. `CombatV1` maps the phrase grade to the coarser encounter execution input exactly once, while the diagnostic HUD presents all six note and phrase labels with distinct note colors. | **Partial** | Tune windows, phrase thresholds, and state values through playtesting; reuse this execution truth for later performance slices without coupling it to tactical musical effectiveness. |

## Tactics, Content, and Progression

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| Skills combine musical effects with character-specific interactions | No skill or loadout model exists; evaluators are selected by character profile | **Missing** | Prototype a minimal skill schema around one tactical decision before loadouts or acquisition. |
| Rhythm, Melody, and Harmony contributions interact with opponent preferences | Enemy data contains HP, attack power, phase length, and neutral hits; no contribution or preference data exists | **Missing** | Treat the three-category taxonomy as working, not final. Test party usefulness and discovery before broad authoring. |
| Levels amplify successful play without replacing execution | Character level and long-term progression are absent | **Missing** | Defer formula design until the base Groove relationship is playable. |
| Characters equip roughly 4–6 of their learned skills | No skill acquisition or loadout system exists; exact size is open | **Open** | Avoid building inventory breadth before a minimal skill loop validates cadence. |
| Improvisation is an advanced unlock | No improvisation system exists | **Missing** | Keep outside the first combat migration slices. |
| Duets, Ensembles, and Finale/Limit Performances express advanced mastery | A single-character limit break extends ATTACK and multiplies damage | **Contradiction** | Preserve no product semantics from the current limit gauge by default. V1 explicitly leaves the advanced hierarchy and resource model unresolved. |

## Encounters and Audio

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| Wild creatures, musicians, and bosses share a musical language with encounter-specific behavior | Legacy encounters are Resource-authored enemy parties with neutral timing patterns. V1 now has separate `OpponentData`, `OpponentPhrase`, and prompt-event resources, with one authored Drum Golem phrase and no legacy HP/attack fields. | **Partial** | Extend the V1 opponent model only when concrete behavior, preference, or phrase-variety slices require it; do not fold it back into legacy `EnemyData`. |
| Approach transforms overworld music into combat without unnecessary discontinuity | The repository has one local combat scene and no overworld transition. The V1 harness now has three temporary same-length backing loops for focused playtest comparison, not an overworld-to-combat transformation. | **Missing** | Defer full transition architecture, but keep continuous musicality as a constraint on combat prototypes. |
| The arrangement audibly communicates state and becomes a primary reward | The V1 harness retains symbolic phrase-audio handoffs, gives each phrase cue a readable visual equivalent, and offers three switchable procedural backing loops while showing cadence and all three meters. The backing choice does not respond to encounter state; there is still no evolving arrangement, stems, or state-driven mix. | **Missing** | Use the human playtest to select or reject a backing direction, then prototype the smallest audible Groove/Composure/Multiplier feedback alongside the core cadence rather than as a late polish pass. |
| Difficulty grows through phrase complexity, not primarily BPM | The V1 phrase model supports authored whole-, half-, and quarter-beat prompt events across one to four fixed-four-beat bars. Rests arise from empty offsets; accents, melodic motion, layers, changing meter, and tempo manipulation are not modeled. | **Partial** | Validate the first listening/response slice before adding richer phrase concepts; changing meter and tempo remain explicitly deferred. |

## Reusable Technical Foundations

These are implementation assets, not V1 product rules:

- `BeatClock` provides an audio-corrected timing source.
- `RhythmInput`, `ActiveNote`, lookahead, and expiry provide tested note-timing
  machinery.
- Character input profiles and evaluators demonstrate distinct per-character
  interaction seams.
- Resource-backed encounters and deep-copy rules provide safe authoring/runtime
  separation.
- Visual announcement and scoreable-note parity tests protect player trust.
- Continuous audio during `DECISION` demonstrates the basis of a Tactical Vamp.
- `CombatV1` provides an isolated cadence and encounter-state seam that reuses
  `BeatClock` and `RhythmInput` through injection. It owns provisional V1
  Groove/Composure/Multiplier and terminal rules, plus the authored opponent
  phrase timing and Response-grading seams. It now repeats the Settle-free core
  cadence until deterministic Jam/loss resolution, but does not yet produce
  Character Performance results or party ordering.
- `CombatV1HUD` provides a separately testable, snapshot-first presentation
  adapter over that seam. It does not reuse legacy HP/limit nodes or own gameplay
  calculations, and it guard-disconnects every signal during teardown.

Preserve these only where they support the selected V1 slice. Their existing names
and ownership do not constrain the target domain model.

## Decisions Requiring Review

The specification does not automatically replace technical ADRs. Review these when
a migration slice reaches them:

- **ADR-005:** the composition seams align with distinct rhythm languages, but the
  evaluator contract currently returns damage and assumes one active character.
- **ADR-006 and ADR-007:** neutral deterministic translation and visual/score
  parity may support authored Responses, but V1 also calls for interpretation,
  harmonization, layered phrases, and improvisational opponents.
- **ADR-008:** continuous music and untimed choice align with Tactical Vamps; the
  `DECISION → ATTACK/DEFEND` graph and fixed next-beat snap are legacy details.

Mark an ADR superseded only when a concrete replacement and its trade-off are
chosen.

## Recommended First Prototype Slice

Before skills, progression, bosses, or overworld transitions, build one narrow
conversation loop:

1. Settle for a fixed musical interval.
2. Play one authored Enemy Phrase without required input.
3. Ask the active character to reproduce it during Response using their existing
   rhythm language.
4. Convert the existing timing result into minimal Groove, Composure, and shared
   Multiplier state.
5. Enter an indefinite Tactical Vamp that keeps the arrangement and clock running.
6. Repeat until Groove reaches a provisional Jam or Composure reaches zero.

This slice is now tracked as Phase A of
[Combat V1 epic #8](https://github.com/Parz1val1/rhythm-game-prototype/issues/8),
with implementation issues #9–#14 and the human playtest gate in #15. It targets
the highest-value questions in section 18 while reusing the strongest current
timing seams.
