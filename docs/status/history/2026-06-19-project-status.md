# Song of the Stars — Project Status

> [!IMPORTANT]
> **Archived snapshot:** This file preserves project status as recorded on
> 2026-06-19. It is immutable history, not a current instruction or source of
> truth. Use [AGENTS.md](../../../AGENTS.md), the current
> [roadmap](../../ROADMAP.md), and [active plan](../../../plans/current.md).

> **Purpose:** This is the single source of truth for project progress. It is read by both
> planning (chat) and implementation (Claude Code) sessions. Keep it current: when a task is
> completed, check its box and add a one-line note. When scope changes, update the relevant
> section. The design doc holds the *why*; `CLAUDE.md` holds *how the code works*; this file
> holds *what's done and what's next*.
>
> **Conventions:** `[x]` done · `[~]` in progress / partial · `[ ]` not started.
> Last updated: 2026-06-19.

---

## Current Focus

**Active milestone:** Pre-demo fixes batch (bug + tuning), then choose between limit-break
solos and the demo-infrastructure push.

**Immediately next:** A batched Claude Code prompt covering the phantom-note bug (investigate
report-first), the lingering defend-hitbox UI, enemy HP rebalance, and a debug gauge-fill.

**Health:** Core combat loop is fun with placeholder audio (validated in playtest). Two
opposite-shape characters run through one shared system. Turn-based decision loop in place.
Test suite green at 363 PASS.

---

## Known Issues / Watch List

- [ ] **Phantom notes — Luthier vs chord/multi-enemy.** Directional defender takes damage on
  inputs that look correct; defend hitbox highlights when no note is present. Suspected
  divergence between the neutral-pattern translator, the lane renderer, and the scorer on
  `lane_count 2` (chord) hits and/or multi-enemy injection. **Investigate before fixing.**
  The verification matrix checked resolved directions but NOT visual/score parity under live
  injection — that's the blind spot. Add a parity test as part of the fix.
- [ ] **Lingering defend hitbox UI** persists into DECISION after DEFEND ends. Should clear on
  phase transition.
- [ ] **Enemy balance:** some die in one attack phase, others always take 2+. Buff/even HP so
  most fights last 2–3 attack phases. Data-only tuning (enemies are `.tres`).
- [ ] **Forced DEFEND on failed run** — confirm the transition is beat-quantized like other
  phase transitions, not firing on a wall-clock timer off the display countdown.

### Recurring-bug checklist (learned the hard way)
- Any discriminator derived from `beat_offset` arithmetic must be checked against the
  evenly-spaced-whole-beat case — `% N` on beat-derived integers collapses there. This class
  of bug has appeared twice (the `N−0.5` injection skip, the all-`drum_left` resolution). Also
  note it in `CLAUDE.md`.

---

## Phase 0 — Foundation Hardening ✅ COMPLETE

- [x] ActiveNote struct — replaced fragile parallel arrays in RhythmInput
- [x] Fixed phantom blocking in DEFEND (`note_consumed` param)
- [x] Note lookahead — `note_approaching` fires ~0.92s early (real reaction time at 130 BPM)
- [x] Typed party arrays in CombatScene
- [x] `NoteData.beat_offset` promoted int → float (unlocked sub-beat patterns)
- [x] `duplicate(true)` rule for loaded character resources (documented in CLAUDE.md)
- [x] AudioBus hierarchy — Master → Music/{Strings, Drums, Winds}, Master → SFX/{Hit, UI}

---

## Phase 1 — Shared Character System + Both Characters ✅ COMPLETE

### Shared system
- [x] `CharacterInputProfile` resource (valid inputs, chords, scoring_mode, evaluator, defense type)
- [x] Profile-aware `RhythmInput` — `set_active_profile()`, chord detection, `input_chord` signal
- [x] `SoloStyle` resource — instrument identity; composes with InputProfile (identity vs behavior)
- [x] Pluggable attack evaluator interface + `_create_evaluator()` factory
- [x] Pluggable defense type — directional + percussive seam
- [x] `SequenceEvaluator` — shared combo multiplier (2.5× ceiling, reset on miss)
- [x] Consolidated note injection into a single `_inject_notes_due` path
- [x] Fixed last-half-beat injection off-by-one (`N−0.5` drop); regression test guards it
- [x] Unified input path via `input_map` translation table (replaced overloaded `valid_inputs`;
      "directional-only" now expressible + tested; `is_input_allowed` callers verified safe)

### Beatrice Styx — first playable (2-button rhythm)
- [x] BeatriceInputProfile — `drum_left` (F), `drum_right` (J), `drum_both` chord
- [x] BeatriceEvaluator — timing accuracy + rhythmic coherence (two axes)
- [x] Percussive defense — hand-matched L/R/Both (perfect + correct hand = block + 25% counter)
- [x] Beatrice SoloStyle + CharacterData `.tres`
- [~] Beatrice drum samples via Drums bus — *placeholder samples wired; real composed drums later*
- [ ] Beatrice solo limit break — composed drum solo *(deferred — see Upcoming Milestones)*
- [x] Attack pattern builder display — L/R/Both/rest icons per beat

### Luthier Frett — validation character (4-button pitch)
- [x] LuthierInputProfile — directional, pitch mode (pure addition, no shared-logic change)
- [x] LuthierEvaluator — melodic interval coherence (step 1.4× / skip 1.3× / leap 1.15× / mash 1.0×)
- [x] Luthier directional defense (existing arrow lane)
- [x] Luthier SoloStyle — banjo pentatonic [0,2,7,9], A3 root, gold accent
- [~] Lute/string sample set via Strings bus — *placeholder plucks wired; real samples later*
- [ ] Luthier solo limit break *(deferred — see Upcoming Milestones)*
- [x] Player + enemy dropdowns for rematch testing (Beatrice↔Luthier swap, no state bleed)

> **Architecture validated:** two opposite-shape characters plug into one system through
> profiles + evaluators + defense types, with no changes to core combat logic. The system is
> ready for woodwind, brass, and vocal characters.

---

## Combat Flow Rework ✅ COMPLETE

### Neutral enemies — any character vs any enemy
- [x] Neutral pattern format — `{beat_offset: float, lane_count: int}` (no character vocabulary)
- [x] Per-character defense translation layer (seam entirely in `_inject_notes_due`)
- [x] Deterministic hand/direction resolution (percussive seeded by `sequence_index`,
      directional by `beat_offset`; replayable)
- [x] Existing enemies converted to neutral format
- [x] Full character×enemy matrix verified *(note: verified resolved directions, NOT live
      visual/score parity — see Known Issues)*

### Decision-phase turn system
- [x] DECISION state wrapping action phases (phases unchanged, slot in as resolutions)
- [x] Menu UI — music keeps looping during DECISION (clock + audio continue; only injection/scoring pause)
- [x] Beat-quantized re-entry into action phases (`DECISION_SNAP` countdown)
- [x] Attack action → ATTACK phase
- [x] Defend action → DEFEND, 50% reduced damage
- [x] Item action → heal (key items)
- [x] Run action → 50% escape; on fail → "couldn't escape" message + pause + forced DEFEND
      *(intentional game-feel; confirm beat-alignment — see Known Issues)*
- [x] Party-readiness seam — turn flow uses "active actor" from a party list (length 1);
      no single-hero assumption baked in. Multi-character orchestration deferred.

### Housekeeping
- [ ] Commit/close the turn-system plan doc (check boxes or delete) — untracked + unchecked
      would mislead the next instance.

---

## Pre-Demo Fixes Batch (NEXT)

- [ ] **Phantom-note bug** — investigate report-first, fix, add visual/score parity test (see Known Issues)
- [ ] **Lingering defend hitbox UI** — clear on phase transition
- [ ] **Enemy HP rebalance** — most fights last 2–3 attack phases (data-only)
- [ ] **Debug limit-break gauge fill** — debug-only instant fill for testing solos

---

## Phase 2 — Combat Prototype Completion

### The milestone
- [ ] **Integration pass — full fight, polished, demo-ready** (the publisher-demo checkpoint)

### Supporting polish (some folds into integration)
- [~] Per-character limit break solos (Beatrice + Luthier) — *gauge + extended phase exist;
      per-character sequences pending; design both together for contrast*
- [ ] Per-hit score display (Perfect +12ms style)
- [ ] Composed combat backing track
- [ ] Combat arena placeholder visuals
- [ ] Calibration screen — `input_offset_ms`
- [~] Real audio samples (drums + lute)

---

## Upcoming Milestones (scoped, not yet started)

### Limit break solos (design vision captured)
- [ ] **Beatrice:** quarter notes → eighth notes → fast "drum roll" spam ramp
- [ ] **Luthier:** chord patterns a couple times → faster chords → short fast melodic riff →
      power-chord hit on all 4 buttons (hard on keyboard, easy on controller)
- [ ] Needs the debug gauge-fill (above) for iteration; eventually gauge persists between fights
- [ ] Team-combo limit break — data model only for now (duet/trio/quartet minigames much later)

### Demo infrastructure (before sharing with friends)
- [ ] Latency test/calibration scene — measure visual & audio I/O latency across machines,
      monitors, and audio setups
- [ ] Endless mode — for open-ended playtesting
- [ ] UI layout pass — reposition to better match gameplay
- [ ] Art + audio assets to make it feel real (placeholder → near-real)

### Controller support (wanted early — intended best way to play)
- [ ] Map drum L/R → shoulder triggers; 4-direction → face buttons or d-pad
- [ ] Validate feel on controller (the 4-button power-chord limit break especially)

---

## Phase 3 — Vertical Slice (after prototype is demo-validated)

- [ ] AudioDirector — diegetic stem system, beat-locked transitions
- [ ] Scene transitions (no music restart) + World State manager
- [ ] Overworld scene — String planet (top-down, walk cycle on half-beat)
- [ ] Dungeon scene — Resonance Cave + musical puzzle
- [ ] Boss encounter — String Warden (2-phase enrage)
- [ ] String planet audio pass (3+ diegetic stems; combat = rearranged overworld theme)
- [ ] String planet art pass (sprites, tilesets, UI skin)
- [ ] Vertical slice integration + polish (15–20 min playthrough, save/load, title)

---

## Decisions Log (so they don't get re-litigated)

- **Beatrice is the first character met / first built.** Hardest case (chords, rhythm scoring,
  percussive defense) → builds confidence the abstraction holds.
- **Built the shared system to serve both pitch and rhythm characters up front**, rather than
  hardcoding one. Validated by Luthier plugging in with no core changes.
- **Beatrice percussive defense uses hand-matching** (L note needs L hand), mirroring her attack
  vocabulary and contrasting Luthier's directional defense.
- **Neutral enemy patterns specify timing + lane count**; the defender's profile translates to
  its own vocabulary. `lane_count 1` resolution is deterministic/seeded (replayable).
- **DECISION phase: menu pauses action, music keeps looping**; re-entry is beat-quantized.
- **Failed run → message + pause + forced DEFEND** (intentional, for game feel).
- **Limit break solos deferred** until both can be designed together for contrast.
- **Party combat: designed-for, not built.** Turn flow uses an active-actor list (length 1);
  multi-character orchestration (turn order, party UI, team combos, cross-party targeting) is a
  later milestone, intentionally not built before the single-character loop is proven fun.
