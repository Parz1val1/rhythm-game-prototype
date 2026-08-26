# Technical Decisions

These entries record decisions supported by the current implementation and its
historical design documents. Reconsider them only with explicit scope and update
this file when a decision changes.

[Combat System v1](combat/COMBAT_SPEC_V1.md) is authoritative for target combat
behavior, while these ADRs record technical choices. An ADR tied to the legacy
HP/damage or `ATTACK`/`DEFEND`/`DECISION` model remains evidence for current code,
not a reason to dilute the target. Reopen it when a concrete migration slice
requires a replacement; see the [reconciliation ledger](combat/reconciliation-v1.md).

## ADR-001 — Use Godot 4.6 and GDScript for the prototype

**Status:** Accepted

**Decision:** Build the prototype as one Godot `4.6.3-stable` project using
GDScript, Godot scenes/Resources, and the GL Compatibility renderer. Mono remains
enabled but C# is unused.

**Context:** The project needs rapid iteration on timing, input, audio, data, and UI
inside one engine.

**Rationale:** The original design selected Godot's signal, autoload, Resource,
and application-runtime systems. Evidence-backed native middleware may be vendored
behind repository-owned interfaces without adding a package-manager ecosystem or
moving application orchestration out of Godot.

**Consequences:** Engine version and parse behavior matter; there is currently no
independent build tool, package manager, or non-Godot type-check step. A pinned
community native integration now adds its own version, platform, licensing, and
export obligations; ADR-010 constrains that dependency.

## ADR-002 — Keep `BeatClock` audio-corrected and free of game logic

**Status:** Accepted

**Decision:** Derive musical time from audio playback plus AudioServer mix/latency
correction. `BeatClock` emits timing signals; combat and presentation interpret them.

**Context:** Frame time and scheduled playback time do not necessarily match what a
player hears.

**Rationale:** Audio-corrected time prevents systematic scoring offset and keeps one
musical clock reusable across combat and future scenes.

**Consequences:** Gameplay code must not turn `BeatClock` into a game-state manager.
Platform latency still requires a future calibration feature.

## ADR-003 — Use autoloads for timing/input and a static utility for logging

**Status:** Accepted

**Decision:** Register `BeatClock` and `RhythmInput` as autoload Nodes. Keep
`DebugLog` as a `class_name` script with static flags/methods.

**Context:** Timing and input span scene lifetimes, while logging needs no Node
lifecycle. Godot 4.6 autoload parse order does not reliably expose other global
`class_name` types.

**Rationale:** This provides global signals without manual scene references and
avoids a logging autoload solely for static behavior.

**Consequences:** Autoload scripts must preload cross-file types and `DebugLog`.
All consumers must clean up global signal connections.

## ADR-004 — Author gameplay templates as Resources and deep-copy live state

**Status:** Accepted

**Decision:** Store characters, profiles, styles, enemies, and encounters in
Inspector-editable `.tres` Resources. Call `duplicate(true)` before mutating a
loaded gameplay Resource in a live fight.

**Context:** Godot caches loaded Resources and shares sub-resources by default.

**Rationale:** Data remains easy to tune without hardcoded constructors while deep
copies prevent one fight's HP/gauge mutations from contaminating later fights.

**Consequences:** Direct mutation of a loaded template is a correctness bug. The
legacy hardcoded encounter factory is retained only for compatibility/tests.

## ADR-005 — Separate character behavior, evaluation, and identity

**Status:** Accepted

**Decision:** Use `CharacterInputProfile` for input/defense behavior,
`AttackEvaluator` implementations for attack scoring, and `SoloStyle` for musical
and visual identity.

**Context:** Beatrice's two-button rhythmic play and Luthier's four-button melodic
play have opposite input shapes but must share combat orchestration.

**Rationale:** Composition keeps `CombatScene` shared and makes new characters plug
into explicit seams instead of forking the combat loop.

**Consequences:** New evaluator keys must be added to the combat factory, profile
aliases must match downstream note vocabulary, and character/profile selection
must remain synchronized.

## ADR-006 — Keep enemy patterns neutral and resolve them deterministically

**Status:** Accepted

**Decision:** Enemy patterns store only `beat_offset` and `lane_count`.
`NeutralPatternTranslator` resolves concrete directions/hands from the defender's
profile. Percussive alternation uses the hit's sequential pattern index.

**Context:** Encoding character-specific directions in enemy data prevented every
character from fighting every enemy and beat-derived alternation collapsed for
evenly spaced whole beats.

**Rationale:** Neutral data decouples encounter design from player vocabulary;
deterministic translation keeps replays, visuals, scoring, and tests reproducible.

**Consequences:** Announcement and injection must call the translator with the same
pattern index. Avoid using `beat_offset` arithmetic as a sequence discriminator.

## ADR-007 — Pre-inject notes and keep visual/scoring resolution in parity

**Status:** Accepted

**Decision:** Pre-inject upcoming whole-beat notes at the half beat, anchor expiry
to the actual due time, and resolve announcements through the same translation
path as scoreable notes.

**Context:** Injecting only on the due beat removed the early input window; duplicate
injection and divergent visual resolution caused phantom or invisible damage.

**Rationale:** Early queueing creates a symmetric timing window, while one
resolution rule keeps the visible and scoreable note sets aligned.

**Consequences:** Do not re-add DEFEND notes in the beat handler. New subdivisions
must preserve due-time anchoring and visual/score parity tests.

## ADR-008 — Keep the music running during decisions

**Status:** Accepted

**Decision:** `DECISION` pauses action injection/scoring but not audio or
`BeatClock`. Chosen actions normally execute on the next beat. A failed run shows a
short real-time message before forced `DEFEND`.

**Context:** The combat system needed menu choices without breaking musical
continuity and needed failed escape feedback readable by the player.

**Rationale:** Continuous music preserves rhythm-game feel; beat snapping keeps
normal re-entry aligned. The failed-run pause is intentionally narrative rather
than beat-quantized.

**Consequences:** UI setup must synchronize current phase because one-shot signals
may have fired before connection. Failed-run timing is an explicit exception to
normal beat-quantized action execution.

## ADR-009 — Treat raw engine diagnostics as test failures

**Status:** Accepted

**Decision:** A headless test is successful only when the process exits `0`, emits
no `FAIL`, `SCRIPT ERROR`, or `ERROR` diagnostic, and prints `=== done ===`.

**Context:** The existing suite can print many `PASS` lines and exit `0` after a
script error or incomplete run.

**Rationale:** Assertion counts alone produced a false-green repository status.

**Consequences:** Full-suite commands and any future CI runner must inspect raw
output and completion markers. Current violations remain tracked in the roadmap.

## ADR-010 — Adopt Wwise behind owned audio interfaces for the Phase C prototype

**Status:** Accepted for the Phase C/#21 prototype; shipping remains conditional

**Decision:** Use Wwise 2025.1.9.9197 with community integration tag
`wwise_v2025.1.9` for the arrangement prototype in #21 after the #20 Phase B
gate. Preserve the repository-owned `BeatClock` timing interface and express
arrangement intent in repository language. The isolated Wwise adapter boundary
may know Wwise events,
States, RTPCs, playing IDs, callback dictionaries, or SDK types; combat remains
independent of them. `WwiseRuntimeBridge` owns direct engine calls while the
adapter normalizes their results into repository timing and arrangement signals.

Extrapolated continuous segment position is the gameplay timing authority. It is
unrolled and clamped through the adapter before publishing subdivisions or signed
offset snapshots. Wwise callbacks are observations for presentation and
diagnostics, not scoring authority. The integration-provided
`WwiseRuntimeManager` remains the sole owner of `RenderAudio()`.

**Context:** Issue #45 demonstrated complete beat/subdivision recovery, bounded
continuous-position noise, bar-quantized layer/section changes, stable editor
playback, and a clean Windows release runtime. Callback delivery had observable
gaps at authored transitions while the extrapolated position remained complete,
which makes the authority boundary material rather than stylistic.

**Rationale:** Wwise's authored music transitions reduce custom arrangement work
without requiring Combat V1 to adopt middleware vocabulary. A repository-owned
adapter preserves the proven timing interface, calibration seam, and native Godot
audio rollback path.

**Consequences:** The repository commits the generated Windows bank and exactly
the editor/profile, template-debug/profile, and template-release/release core DLLs
needed by the spike. Wwise-specific installation, authoring, bank, export, and
binary policy stays in `spikes/wwise/README.md`, not the combat specification.
Adding a DSP binary requires a generated-bank dependency and license review.

The exact Wwise SDK patch and integration tag are one pin. Any upgrade must
regenerate banks, validate `PluginInfo.json`, import the editor with its known
teardown caveat, rerun focused adapter tests and a timing soak, perform teardown
checks, and verify a packaged export. Keep native audio selectable through #21's
first real-combat playtest and its lifecycle, continuity, transition, teardown,
and export checks. Shipping and every additional target platform require separate
licensing and platform evidence. Future #25
calibration applies a signed scoring/input offset; it does not rewrite musical
position.

## ADR-011 — Author Skills as data and apply effects through Resource adapters

**Status:** Accepted for the Combat V1 prototype

**Decision:** Represent each Combat V1 Skill as a deep-copied Resource that owns
its player-facing metadata, bar count, timed interaction events, and ordered effect
Resources. `CombatV1` grades the shared Character Performance schedule and invokes
each effect through `apply(encounter_state, execution)`. Concrete effect Resources
adapt execution to encounter-state operations; the orchestrator does not branch on
Skill IDs or concrete effect types.

**Context:** Issue #16 needs two Skills with different multi-bar interactions and
tactical outcomes, while later Skills must be addable without editing the central
cadence for every effect. The final full-game skill schema, party order, loadouts,
opponent preferences, and effect targeting are still unresolved.

**Rationale:** Authored schedules keep physical interaction beside the Skill that
defines it. A narrow effect interface makes the module deeper: the cadence owns
timing and grading once, encounter state owns its formulas, and content composes
the two without Skill-specific orchestration.

**Consequences:** Loaded Skill templates must be deep-copied before live use.
Effects must use encounter-state methods rather than mutate public snapshots, and
their order is observable when effects depend on prior state. The issue #18 party
harness now sources per-character Skill lists through the same interface. Its
fixed order and two Character Performances per exchange are scoped product
experiments, not technical constraints imposed by this ADR.

## ADR-012 — Keep Inspiration in injected, character-owned session state

**Status:** Accepted for the Combat V1 prototype

**Decision:** Keep Inspiration in a separately owned `CombatV1SessionState` and
inject that session plus an active character identity into each `CombatV1`
encounter. Give each registered character independently copied Inspiration
bounds, starting value, and grade/source generation settings. Route graded
performance into that owner and check/spend authored Skill costs atomically at
commitment without crossing the configured floor. Publish copied character and
party snapshots through the public Combat V1 state/presentation boundary.

**Context:** Issue #17 requires Inspiration to persist between encounters while
Groove, Composure, and shared Multiplier remain encounter-local. Legacy
`CharacterData` Resources also hold mutable HP and a limit gauge; storing
Inspiration beside those values would either leak Resource-template state or
conflate an unresolved Finale/Limit concept with the new character economy.

**Rationale:** An injected in-memory owner gives character progression a longer
lifetime than an encounter without introducing save files, an autoload, or a
production world-state architecture prematurely. One session-owned affordability
rule prevents the orchestrator and HUD from disagreeing about minimum floors.

**Consequences:** The harness or another future composition root must retain the
session across encounter replacement. Encounter setup/reset must never clear
registered Inspiration; fight-local state must still reset and gameplay Resources
must still be deep-copied. The issue #18 harness now switches two independently
owned balances in fixed authored order; final party ordering, availability,
cross-character effects, durable saves, final rates, and any separate Finale/Limit
resource remain unresolved or out of scope.
