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
| Encounters are musical conversations culminating in a Jam | `CombatScene` emits victory after all enemy HP reaches zero; UI and encounter data present damage and HP | **Contradiction** | Introduce Groove/Jam as the target resolution model. Retire damage framing from player-facing combat as slices migrate. |
| Groove begins empty and measures synchronization | No Groove state or signal exists | **Missing** | Prototype one encounter-wide Groove model before balance formulas. |
| Shared Composure begins full and reaches zero on execution failure | Characters have individual HP; enemy attacks and missed defense notes deal damage | **Contradiction** | Prototype shared Composure independently from tactical preference. Do not rename HP while preserving damage semantics. |
| Multiplier is shared, band-wide momentum that modifies Groove | Attack evaluators own character/phase-local combo counts and damage multipliers | **Partial** | Preserve proven streak math only if useful; move ownership and effects to the encounter model. |
| Each character owns persistent Inspiration used by skills | `CharacterData` owns a limit gauge charged during ATTACK; durable persistence does not exist | **Contradiction** | Design Inspiration as a new resource. Limit-style resources remain open and must not be equated with Inspiration. |
| Correct execution can be tactically ineffective without harming Composure | Current scoring converts execution directly into dealt/blocked damage | **Missing** | Separate execution quality from musical effectiveness before adding preferences. |

## Cadence and Interaction

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| `Approach -> Settle -> Enemy Phrase -> Response -> Tactical Vamp <-> Character Performance -> Full-Band Vamp -> Resolution` | Issue #9 `CombatV1` exposes `Settle -> Enemy Phrase -> Response -> Tactical Vamp <-> Character Performance -> Full-Band Vamp -> Resolution` and reuses injected `BeatClock`/`RhythmInput`; `combat_v1_prototype.tscn` runs it separately from the configured legacy `test_scene.tscn`. Character performance and full-band transitions are explicit placeholders; party ordering, performance rules, V1 resources, and resolution rules remain out of scope. | **Partial** | Keep `CombatV1` as the migration seam. Add authored resources, party ordering, performance systems, and resolution rules in later slices; leave the legacy `CombatScene` phase graph unchanged until a replacement is implemented. |
| Enemy Phrase is primarily a listening phase followed by a distinct Response | `CombatV1` advances through a timed Enemy Phrase without required input, then accepts a separate Response intent; the phrase is still a fixed cadence placeholder, not an authored V1 resource. | **Partial** | Reuse the timing/input seam while adding authored phrase data and response rules in a later slice. |
| Tactical Vamps continue indefinitely with no time pressure | `CombatV1` enters Tactical Vamp without a beat timeout while its injected `BeatClock` and optional `RhythmInput` listeners remain active; performance-selection and full-band commands are placeholder boundaries. | **Aligned seam** | Preserve the no-time-pressure seam, then replace placeholder commands with the selected performance and party rules. |
| Party members select skills and perform separate multi-bar interactions | The prototype uses one active character and four generic actions: Attack, Defend, Item, Run | **Contradiction** | Introduce a skill/performance seam and party cadence before content breadth. Item existence remains open. |
| Character rhythm languages should make the player's hands think differently | Luthier has four-direction melodic input; Beatrice has two-hand percussion, chords, alternation, and separate visuals/evaluators | **Partial** | Retain and deepen these proven character seams; add held notes, spatial targets, rolls, fills, and skill-specific variations only as tested slices. |
| Performance grading includes six working levels and phrase-level recovery | `RhythmInput` and evaluators use `perfect`, `good`, and `miss` at note level | **Partial** | Expand the grading model only alongside Groove/Composure experiments; exact windows remain open. |

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
| Wild creatures, musicians, and bosses share a musical language with encounter-specific behavior | Current encounters are Resource-authored enemy parties with neutral timing patterns | **Partial** | Resource authoring and encounter instantiation may survive; opponent behavior, preferences, and phrase structures require new models. |
| Approach transforms overworld music into combat without unnecessary discontinuity | The repository has one local combat scene and placeholder backing audio; no overworld transition exists | **Missing** | Defer full transition architecture, but keep continuous musicality as a constraint on combat prototypes. |
| The arrangement audibly communicates state and becomes a primary reward | Audio feedback plays note events; there is no evolving arrangement state, stems, or state-driven mix | **Missing** | Prototype the smallest audible Groove/Composure/Multiplier feedback alongside the core cadence rather than as a late polish pass. |
| Difficulty grows through phrase complexity, not primarily BPM | Neutral patterns support beat offsets, lanes, and deterministic translation; richer phrase concepts are absent | **Partial** | Reuse audio-corrected timing while extending rests, accents, syncopation, subdivisions, melodic motion, and eventually meter/tempo experiments. |

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
- `CombatV1` provides an isolated cadence seam that reuses `BeatClock` and
  `RhythmInput` through injection; it does not provide V1 resources or rules.

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
