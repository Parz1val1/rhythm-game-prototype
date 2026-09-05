# Combat System v1 Reconciliation

Last reviewed: 2026-08-26.

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
| Shared Composure begins full and reaches zero on execution failure | `CombatV1EncounterState` initializes one shared Composure value at its configured maximum and resolves a typed one-shot `LOSS` at zero. Response and Character Performance summaries produce the matching execution inputs; Steadying Harmony can restore bounded shared Composure after correct execution. The diagnostic HUD presents the shared meter and a nonviolent lost-groove outcome, while legacy characters still own individual HP outside V1. | **Partial** | Preserve the V1 state independently from legacy HP and route later party performances through the same typed state seam. |
| Multiplier is shared, band-wide momentum that modifies Groove | `CombatV1EncounterState` owns one configurable baseline/minimum/maximum Multiplier, applies it to Groove, raises it for correct execution, reduces it for mistakes, and resets excess momentum on a major mistake. The diagnostic HUD displays that shared value directly from `CombatV1.get_state()`. | **Partial** | Tune the provisional changes through playtesting; do not duplicate Multiplier math in performance callers or reuse evaluator-local damage multipliers. |
| Each character owns persistent Inspiration used by skills | `CombatV1SessionState` owns individually configured character balances independent of legacy `CharacterData` and encounter-wide Multiplier. Good/Great/Perfect Response and Character Performance notes/phrases generate provisional Inspiration; authored Skill costs spend atomically from the visible balance down to zero, and a configured safety floor is restored when a new encounter starts. Reusing the injected session preserves every party balance across fresh encounters, while issue #18 switches the active balance, cost, and affordability between Luthier and Beatrice. Durable saves, cross-character effects, and final rates are absent. | **Partial** | Preserve the encounter-independent session owner and never alias the legacy limit gauge. Durable persistence and any separate Finale/Limit resource remain future decisions. |
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
| `Approach -> Settle -> Enemy Phrase -> Response -> Tactical Vamp <-> Character Performance -> Full-Band Vamp -> Resolution` | `CombatV1` now runs `Settle -> Enemy Phrase -> Response -> Luthier Tactical Vamp/Character Performance -> Beatrice Tactical Vamp/Character Performance -> one-bar Full-Band Vamp -> Enemy Phrase -> ... -> Resolution`. Response and Skill results preserve encounter-wide state across rounds, and typed Jam/loss outcomes end the cadence. Fixed authored order and one performance per configured member are provisional issue #18 choices. | **Partial** | Playtest the two-member exchange before changing the target cadence or accepting a canonical ordering rule; leave the legacy `CombatScene` phase graph unchanged until its replacement is ready. |
| Enemy Phrase is primarily a listening phase followed by a distinct Response | `CombatV1` deep-copies a V1 opponent resource, spends configurable four-beat bars in Settle, then reproduces the opponent's one-to-four-bar phrase from audio-corrected whole/half/quarter beat signals. Listening phases suppress `RhythmInput` scoring. Each heard event carries the actions from its already-prepared Response targets so the active-language board can flash a brief translucent lane or grouped chord without reconstructing mapping, while the replaceable feedback adapter plays those same mapped actions as the melody/rhythm lesson. Recovered subdivisions announce once per round. Response begins after the phrase duration with a separately configurable input-free handoff, provisionally one fixed four-beat bar, before scoring resumes and notation receives its independently configurable approach lead. The highway then uses the atomically published BeatClock position for target travel and grading parity; same-event targets share a connector and synchronized pulse. Repeated rounds refresh target identities, announcement guards, and previews without repeating Settle. | **Aligned seam** | Preserve input-free listening and handoff, the single mapped phrase-announcement seam, the snapshot-first Response schedule, and synchronized audible/visual grouped cues across active-character resets and later phrase variety. Keep the preview lifetime, timbre, handoff, and lead values as playtest tuning rather than final cadence rules. |
| Tactical Vamps continue indefinitely with no time pressure | `CombatV1` leaves Tactical Vamp unchanged for any number of BeatClock cycles while its backing harness audio, clock, and timing/input subscriptions continue. The HUD presents two Skill purposes and waits for explicit selection. Confirmation queues a complete input-free four-beat count-in, publishes its BeatClock-derived progress, and presents a committed listening transition; no Skill is auto-selected and no meter drains while waiting. Resolution and teardown clear the transition presentation. | **Aligned seam** | Preserve indefinite choice, explicit committed-transition feedback, and beat-aligned commitment when party selection and production presentation replace the two-choice harness. |
| Party members select skills and perform separate multi-bar interactions | The V1 harness presents separate two-Skill lists for Luthier and Beatrice, commits one during each member's indefinite Tactical Vamp, and grades both multi-bar interactions before Full-Band Vamp. Fixed authored order is implemented, while runtime reorder, availability, and the final performance count remain open. | **Partial** | Use issue #18 playtesting to evaluate order and cadence; do not promote the fixed two-performance prototype to a production rule. |
| Character rhythm languages should make the player's hands think differently | Luthier uses four directional melodic inputs with travelling notes/chords and plucked feedback. Beatrice uses two-hand F/J or trigger inputs with alternating/rolling Skills, closing-circle targets, drum-bus feedback, and her own profile/evaluator metadata. Active handoffs clear prior notes and presentation state while the shared clock continues. Production glyph adaptation, remapping, and calibration remain absent. | **Partial** | Playtest whether the switch feels refreshing or disruptive, retain the profile/schedule seams, and defer production input/presentation polish. |
| Performance grading includes six working levels and phrase-level recovery | `CombatV1ResponseGrader` produces configurable Perfect, Great, Good, Near Miss, Miss, and Major Mistake note grades, then calculates an ordered phrase summary from configurable score and broken-phrase thresholds. Strong later notes can recover a phrase after one mistake. `CombatV1` maps the phrase grade to the coarser encounter execution input exactly once. Each published note result retains target/group identity, expected and actual action, signed offset, and lane; the highway uses that truth for independent lane-local burst/ring cues while the HUD keeps all six readable labels. | **Partial** | Tune windows, phrase thresholds, state values, and feedback intensity through playtesting; reuse this execution truth for later performance slices without coupling it to tactical musical effectiveness. |

## Tactics, Content, and Progression

| V1 target | Current evidence | Classification | Migration disposition |
|---|---|---|---|
| Skills combine musical effects with character-specific interactions | `CombatV1Skill` Resources own purpose copy, contribution metadata, Inspiration cost, bar duration, timed action events, and ordered effect adapters. Bright Motif and Steadying Harmony exercise Luthier's melodic/chord language; Driving Backbeat and Syncopated Fill exercise Beatrice's alternating/rolling percussion language. Per-character authored Skill lists switch without Skill-specific orchestrator branches. Final loadout size, broader effects, and rates remain unresolved. | **Partial** | Reuse the validated schedule/effect and Inspiration seams; playtest the current party breadth before broader authoring or final balance. |
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
| The arrangement audibly communicates state and becomes a primary reward | The V1 harness retains symbolic phrase-audio handoffs, gives each phrase cue a readable visual equivalent, and offers three switchable procedural backing loops while showing cadence, shared Groove/Composure/Multiplier, and character-owned Inspiration. Accepted Response inputs add four lane-specific synthesized plucks over that backing; imperfect grades use softer, muted variants sourced from the same deterministic result event. The replaceable adapter has no BeatClock reference and cannot alter the backing schedule. The backing still does not evolve with encounter state, and there are no stems or state-driven mix. | **Partial** | Validate lane distinction and whether muted imperfect feedback remains musical in the resumed playtest, then prototype the smallest audible Groove/Composure/Multiplier/Inspiration feedback without turning the placeholder input adapter into an arrangement system. |
| Difficulty grows through phrase complexity, not primarily BPM | The V1 phrase model supports authored whole-, half-, and quarter-beat prompt events across one to four fixed-four-beat bars. Rests arise from empty offsets; accents, melodic motion, layers, changing meter, and tempo manipulation are not modeled. | **Partial** | Validate the first listening/response slice before adding richer phrase concepts; changing meter and tempo remain explicitly deferred. |

## Reusable Technical Foundations

These are implementation assets, not V1 product rules:

- `BeatClock` provides an audio-corrected timing source and publishes continuous
  musical position atomically before boundary signals.
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
  phrase timing and Response-grading seams. Its snapshot-first Response seam
  publishes stable identity, action, authored-event group, authored offset,
  configurable handoff and approach lead, their combined scoreable due beat, and
  current musical position; authored events can expand into one to four same-beat
  targets. The phrase-event
  seam reads its preview actions from those prepared targets, and
  `ResponseNoteHighway` uses them for transient grouped listening previews before
  using the same schedule for movement, grouped chord treatment, and independent
  target/lane feedback. `CombatV1ResponsePerformanceFeedback` consumes the mapped
  phrase event for its heard lesson and the grade event for lane-specific result
  one-shots; it owns no timing source.
  `CombatV1` now repeats the Settle-free core cadence through selected multi-bar
  Character Performances for each fixed-order party member and one input-free
  Full-Band Vamp until deterministic Jam/loss resolution. Party-member Resources
  own profile/style/Skill identity and explicitly copy nested templates. Final
  ordering and the full-game number of performances per exchange remain open.
- `CombatV1HUD` provides a separately testable, snapshot-first presentation
  adapter over that seam. It does not reuse legacy HP/limit nodes or own gameplay
  calculations, and it guard-disconnects every signal during teardown. The highway
  switches between Luthier's four travelling lanes and Beatrice's two closing-
  circle targets. Production art, adaptive glyphs, and final spatial-percussion
  polish remain future work.

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

## First Prototype Slice — Approved

The approved first slice established one narrow conversation loop before skills,
progression, bosses, or overworld transitions:

1. Settle for a fixed musical interval.
2. Play one authored Enemy Phrase without required input.
3. Ask the active character to reproduce it during Response using their existing
   rhythm language.
4. Convert the existing timing result into minimal Groove, Composure, and shared
   Multiplier state.
5. Enter an indefinite Tactical Vamp that keeps the arrangement and clock running.
6. Repeat until Groove reaches a provisional Jam or Composure reaches zero.

This slice was completed as Phase A of
[Combat V1 epic #8](https://github.com/Parz1val1/rhythm-game-prototype/issues/8),
with implementation issues #9–#14, required Response-playability and musical-agency
rework in #34 and #36–#38, and the human playtest gate in #15. The final replay on
2026-08-19 approved the core cadence and unblocked Phase B. Settle, the one-bar
Response handoff, note approach time, exact reproduction, and the indefinite
Tactical Vamp remain provisional prototype defaults rather than final production
rules.
