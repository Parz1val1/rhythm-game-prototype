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
| Encounters are musical conversations culminating in a Jam | `CombatV1EncounterState` produces a typed one-shot `JAM` when configurable Groove reaches its provisional threshold; the separately configured legacy flow still resolves victory through enemy HP | **Partial** | Route later V1 performance slices through the new state seam, then retire damage framing only as those slices replace the legacy flow. The final maximum-Groove interaction remains open. |
| Groove begins empty and measures synchronization | `CombatV1EncounterState` initializes Groove at zero, clamps it to configured bounds, and applies Multiplier-adjusted gains through one typed performance-result interface | **Partial** | Keep the formula provisional; later slices must supply authored performance and opponent-effectiveness results without moving Multiplier math into callers. |
| Shared Composure begins full and reaches zero on execution failure | `CombatV1EncounterState` initializes one shared Composure value at its configured maximum and resolves a typed one-shot `LOSS` at zero; legacy characters still own individual HP outside V1 | **Partial** | Preserve the V1 state independently from legacy HP and connect future execution grading through the typed state seam. |
| Multiplier is shared, band-wide momentum that modifies Groove | `CombatV1EncounterState` owns one configurable baseline/minimum/maximum Multiplier, applies it to Groove, raises it for correct execution, reduces it for mistakes, and resets excess momentum on a major mistake | **Partial** | Tune the provisional changes through playtesting; do not duplicate Multiplier math in performance callers or reuse evaluator-local damage multipliers. |
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
configuration, not final balance. The coarse execution values (`CORRECT`,
`NEAR_MISS`, `MISTAKE`, `MAJOR_MISTAKE`) are an input seam for later performance
grading; they do not define timing windows or replace the six target grades.

An implementation-time product-owner decision settled the provisional competing
terminal rule for Issue #10: if one atomic result reaches both the Jam threshold
and zero Composure, `JAM` wins. The final maximum-Groove interaction remains open.

## Cadence and Interaction

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| `Approach -> Settle -> Enemy Phrase -> Response -> Tactical Vamp <-> Character Performance -> Full-Band Vamp -> Resolution` | `CombatV1` exposes `Settle -> Enemy Phrase -> Response -> Tactical Vamp <-> Character Performance -> Full-Band Vamp -> Resolution`, reuses injected `BeatClock`/`RhythmInput`, schedules an authored phrase during Enemy Phrase, and enters `Resolution` from its owned typed Jam/loss state. `combat_v1_prototype.tscn` remains separate from configured `test_scene.tscn`; character performance and full-band transitions are placeholders. | **Partial** | Keep `CombatV1` as the migration seam. Add party ordering and performance-result production in later slices; leave the legacy `CombatScene` phase graph unchanged until a replacement is implemented. |
| Enemy Phrase is primarily a listening phase followed by a distinct Response | `CombatV1` deep-copies a V1 opponent resource, spends configurable four-beat bars in Settle, then reproduces the opponent's one-to-four-bar phrase from audio-corrected whole/half/quarter beat signals. One phrase-event signal carries prompt plus audio/visual cue data. Listening phases suppress `RhythmInput` scoring, then restore its prior state for the distinct Response cadence, so inputs cannot produce grades or change V1 encounter state. | **Aligned seam** | Preserve the single event handoff and input-free scheduling while Issue #12 adds response prompting and grading. |
| Tactical Vamps continue indefinitely with no time pressure | `CombatV1` enters Tactical Vamp without a beat timeout while its injected `BeatClock` and optional `RhythmInput` listeners remain active; performance-selection and full-band commands are placeholder boundaries. | **Aligned seam** | Preserve the no-time-pressure seam, then replace placeholder commands with the selected performance and party rules. |
| Party members select skills and perform separate multi-bar interactions | The prototype uses one active character and four generic actions: Attack, Defend, Item, Run | **Contradiction** | Introduce a skill/performance seam and party cadence before content breadth. Item existence remains open. |
| Character rhythm languages should make the player's hands think differently | Luthier has four-direction melodic input; Beatrice has two-hand percussion, chords, alternation, and separate visuals/evaluators | **Partial** | Retain and deepen these proven character seams; add held notes, spatial targets, rolls, fills, and skill-specific variations only as tested slices. |
| Performance grading includes six working levels and phrase-level recovery | `RhythmInput` and evaluators use `perfect`, `good`, and `miss` at note level. The V1 state accepts the coarser typed execution results `CORRECT`, `NEAR_MISS`, `MISTAKE`, and `MAJOR_MISTAKE` but intentionally performs no timing-grade conversion | **Partial** | Add the six-grade-to-execution mapping with an authored performance slice; keep exact windows and phrase recovery open. |

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
| Approach transforms overworld music into combat without unnecessary discontinuity | The repository has one local combat scene and placeholder backing audio; no overworld transition exists | **Missing** | Defer full transition architecture, but keep continuous musicality as a constraint on combat prototypes. |
| The arrangement audibly communicates state and becomes a primary reward | Audio feedback plays note events; there is no evolving arrangement state, stems, or state-driven mix | **Missing** | Prototype the smallest audible Groove/Composure/Multiplier feedback alongside the core cadence rather than as a late polish pass. |
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
  phrase timing seam, but not Response grading or performance-result production.

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
