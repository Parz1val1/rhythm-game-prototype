# Party Character Performance Prototype

This record owns the provisional implementation and pre-playtest observations for
[issue #18](https://github.com/Parz1val1/rhythm-game-prototype/issues/18).
[Combat System v1](COMBAT_SPEC_V1.md) remains the target. The ordering and cadence
below are prototype choices, not settled product rules.

## Prototype Cadence and Order

The standalone Combat V1 harness authors the party in this fixed order:

1. Luthier Frett
2. Beatrice Styx

After a non-terminal Response, every configured party member receives one
Character Performance opportunity in authored order:

`Response -> Luthier Tactical Vamp -> Luthier Character Performance -> Beatrice Tactical Vamp -> Beatrice Character Performance -> Full-Band Vamp -> Enemy Phrase`

- Each Tactical Vamp remains indefinite and preserves the backing music and
  `BeatClock`.
- Each accepted Skill receives the existing complete four-beat count-in.
- One input-free four-beat Full-Band Vamp occurs only after the final configured
  party member performs.
- The next Enemy Phrase resets the active member to the first authored party
  entry without replaying Settle or reconnecting timing/input dependencies.
- All configured entries are treated as living and available in this slice. A
  separate availability, incapacitation, substitution, or reorder model remains
  unresolved.

This is the one ordering rule requested by issue #18. The full game may use a
different order, let the player change it, or vary the number of performances.
No canonical cadence decision should be made from this implementation alone.

## Active Character Synchronization

`CombatV1PartyMember` is a Resource-authored identity/loadout seam. Each entry
owns its character ID and display name, rhythm language, input profile,
presentation style and instrument identity, and Skill list. `CombatV1.bind_party()`
deep-copies the complete nested Resource graph before live use and registers each
member with the injected `CombatV1SessionState`.

Changing the active member atomically refreshes:

- the `RhythmInput` profile, scoring mode, and evaluator identity;
- valid action aliases and the response/performance lane order;
- the visual interaction treatment and instrument accent;
- the instrument audio bus and feedback timbre;
- the visible Skill list, costs, and affordability;
- the active member's independently owned Inspiration snapshot; and
- transient targets, note feedback, chord state, and queued `RhythmInput` notes.

Teardown clears the live profile and note queue. Loaded `.tres` templates,
including externally referenced input profiles, styles, Skills, events, and
effects, remain caller-owned and unmodified.

## Authored Rhythm Languages

| Character | Working language | Presentation | Playtest Skills |
|---|---|---|---|
| Luthier | Four-input melodic strings | Four directional lanes with travelling notes and chords | Bright Motif; Steadying Harmony |
| Beatrice | Two-input percussion | Left/right spatial targets with large closing timing circles, color accents, and `1 e & a` subdivision markers | Driving Backbeat; Syncopated Fill |

Driving Backbeat asks for a steady alternating two-hand pulse. Syncopated Fill
mixes spaced accents with a faster left/right roll and provisionally costs 20
Inspiration. Both route successful execution through the existing Skill-effect
seam; their numbers and tactical breadth are playtest content, not final balance.

## Pre-Playtest Observations — 2026-08-26

- The fixed authored order makes automated cadence and presentation handoffs
  deterministic, but provides no player agency over order.
- Two complete Skill count-ins plus two multi-bar performances make one exchange
  materially longer than the issue #16 single-character loop.
- The switch is mechanically legible in the harness: four directional inputs,
  plucked feedback, and travelling notes give way to two drum inputs, percussion
  feedback, and closing circles without stopping the clock.
- Automated tests establish state isolation and handoff correctness; they cannot
  determine whether the language switch feels refreshing or disruptive.

## Human Playtest Questions

- Does Luthier-to-Beatrice feel like welcome contrast or an interruption?
- Is a full count-in before each member still useful after the first performance?
- Does one performance per configured member make the exchange drag, or does it
  make the party feel present?
- Is fixed authored order readable enough for this prototype, and when does the
  player first want to change it?
- Are Beatrice's closing circles and drum timbre sufficiently distinct while
  remaining as readable as Luthier's directional highway?

Record human observations here before changing Combat System v1 or accepting a
canonical party-order/cadence decision.
