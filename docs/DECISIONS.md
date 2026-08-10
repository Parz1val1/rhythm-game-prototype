# Technical Decisions

These entries record decisions supported by the current implementation and its
historical design documents. Reconsider them only with explicit scope and update
this file when a decision changes.

## ADR-001 — Use Godot 4.6 and GDScript for the prototype

**Status:** Accepted

**Decision:** Build the prototype as one Godot `4.6.3-stable` project using
GDScript, Godot scenes/Resources, and the GL Compatibility renderer. Mono remains
enabled but C# is unused.

**Context:** The project needs rapid iteration on timing, input, audio, data, and UI
inside one engine.

**Rationale:** The original design selected Godot's audio timing, signal, autoload,
and Resource systems. No separate runtime or dependency ecosystem is required.

**Consequences:** Engine version and parse behavior matter; there is currently no
independent build tool, package manager, or non-Godot type-check step.

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
