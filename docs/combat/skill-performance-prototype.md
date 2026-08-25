# Skill and Character Performance Prototype

This record owns the provisional product choices and playtest evidence for
[issue #16](https://github.com/Parz1val1/rhythm-game-prototype/issues/16). Combat
System v1 remains the target; this document says exactly what the Phase B
prototype implements and which conclusions it does not support.

## Prototype Loop

The implemented loop after a non-terminal Response is:

`Tactical Vamp -> selected Character Performance -> one-bar Full-Band Vamp -> Enemy Phrase`

- Tactical Vamp is indefinite and has no selection timer, meter drain, or automatic
  choice. The backing music and `BeatClock` continue.
- Navigate the vertically stacked Skills with Up/Down and confirm with controller
  A or keyboard Enter/Space. Controller Start remains available to submit a
  Response but does not confirm a Skill.
- Confirming a Skill starts a complete four-beat count-in. Character Performance
  begins on the following whole-beat boundary.
- The selected Skill owns its performance duration and authored input events.
- Exactly one Character Performance occurs per exchange in this prototype.
- A completed Character Performance enters one input-free four-beat Full-Band
  Vamp, then the next Enemy Phrase begins at phrase offset zero.

The one-performance rule is a deliberate scope constraint, not the intended
full-game cadence. The full game is expected to order performances across multiple
party members and may allow more than one Character Performance before the
Full-Band Vamp. Party ordering, multi-character selection, loadouts, and the final
transition rule remain open for later issues.

## Authored Skills

Both prototype Skills use Luthier's four-lane input language. They differ in
purpose, duration, and physical interaction:

| Skill | Contribution | Interaction | Duration | Tactical effect |
|---|---|---|---:|---|
| Bright Motif | Melody | Rising single-note run ending in a two-note chord | 2 bars | Converts execution into the existing effective Groove result |
| Steadying Harmony | Harmony | Measured two-note chord pulses ending in a four-note chord | 3 bars | Restores 20 Composure on correct execution and contributes no direct Groove |

These are playtest content, not a final balance contract. Contribution names are
descriptive metadata until opponent preferences make Rhythm, Melody, and Harmony
mechanically distinct.

## Authoring and Effect Boundary

`CombatV1Skill` is the minimal authoring model. Each Skill Resource owns player-
facing purpose copy, contribution metadata, bar count, timed `CombatV1SkillEvent`
inputs, and an ordered list of `CombatV1SkillEffect` Resources.

`CombatV1` grades the authored schedule with the existing six-level Response
grader, reduces the phrase result to the encounter's execution vocabulary, and
invokes every configured effect through `apply(encounter_state, execution)`.
Concrete effects adapt that result to encounter state. Adding another effect or
combining existing effects therefore does not require a Skill-specific branch in
the combat orchestrator. See ADR-011 for the accepted technical boundary.

## Human Playtest Record — 2026-08-25

Outcome: the Skill and Character Performance slice passed after one control-layout
correction.

- **Tactical Vamp:** the Skill menu was clearly readable and imposed no time
  pressure.
- **Skill distinction:** both Skills felt physically distinct and served an
  understandable strategic purpose despite their intentionally simple authoring.
- **Tactical clarity:** the descriptions communicated each effect before
  selection, and the resulting Groove or Composure change made sense afterward.
- **Musical handoffs:** both the confirmation count-in and Full-Band Vamp timing
  felt right.
- **Accepted presentation limitation:** the count-in indicator was small and away
  from the note lanes where the player's eyes normally rest. Stronger lane-adjacent
  count-in presentation is optional future polish, not an issue #16 blocker.
- **Control correction:** Left/Right conflicted with the vertically arranged Skill
  choices, and controller Start felt wrong for confirmation. The harness now uses
  Up/Down navigation and controller A confirmation; keyboard Enter/Space remain
  available. Real controller-event regressions protect both behaviors.

The playtest validates the issue #16 single-character loop only. It does not settle
the full-game party cadence, performance count, contribution balance, or loadout
design.
