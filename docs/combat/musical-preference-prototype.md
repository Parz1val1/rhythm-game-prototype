# Musical Contributions and Opponent Preferences Prototype

This record owns the provisional implementation and playtest questions for
[issue #19](https://github.com/Parz1val1/rhythm-game-prototype/issues/19).
[Combat System v1](COMBAT_SPEC_V1.md) remains the target. The categories, weights,
thresholds, and discovery presentation below are prototype choices, not final
balance or taxonomy decisions.

## Prototype Rules

Each `CombatV1Skill` authors one or more contributions from the working `Rhythm`,
`Melody`, and `Harmony` taxonomy. `OpponentData` authors a non-negative Groove
effectiveness weight for each category. Missing weights are neutral at `1.0`.

The Drum Golem is the first differentiated opponent:

| Contribution | Weight | Qualitative feedback |
|---|---:|---|
| Rhythm | 0.5 | Weak |
| Melody | 1.5 | Strong |
| Harmony | 1.0 | Neutral |

For a multi-contribution Skill, the prototype uses the arithmetic mean of its
contribution weights. Syncopated Fill therefore resolves at `(0.5 + 1.0) / 2 =
0.75`. This averaging rule is deliberately provisional.

Character Performance Groove uses:

`execution Groove × opponent preference weight × pre-result Multiplier`

Preference never changes execution truth. Composure loss and Multiplier movement
remain driven by execution, so a perfectly executed weak contribution earns less
Groove without losing Composure. Response has no selected Skill contribution and
continues to use neutral `1.0` effectiveness.

## Discovery and Feedback

All three preferences begin `Unknown` in each encounter. Completing a Skill
reveals only the categories that Skill contributed. Discovery is encounter-local;
there is no Bestiary, Songbook, durable save, or cross-encounter persistence in
this slice.

The diagnostic HUD keeps the two kinds of feedback separate:

- the performance panel reports the execution grade;
- the opponent-preference panel reports known `Weak`, `Neutral`, or `Strong`
  categories and the last Skill's opponent response; and
- Tactical Vamp lists every contribution on a multi-contribution Skill.

The qualitative thresholds are provisional: weights below `0.75` are Weak, above
`1.25` are Strong, and the inclusive middle range is Neutral.

## Party Usefulness

Both prototype party members retain a preference-independent support route:

- Luthier's Steadying Harmony restores 20 Composure and intentionally contributes
  no direct Groove.
- Beatrice's Syncopated Fill now combines Rhythm and Harmony, retains its
  preference-scaled Groove effect, and restores 20 Composure on correct execution.

These are playtest tools, not final loadouts or balance. Syncopated Fill still
costs 20 Inspiration, while Steadying Harmony costs 30.

## Automated Evidence

Focused tests establish that weak Rhythm reduces Groove without harming
Composure, strong Melody increases Groove, hybrid contributions average their
weights, discovery reveals only attempted categories, the HUD separates execution
from preference, and Beatrice's support effect remains useful after a mistake.
Automated evidence cannot determine whether the choices feel tactically satisfying.

## Human Playtest Gate

The working taxonomy remains open until hands-on play answers:

- Does `Unknown` create useful curiosity or hide too much before the first choice?
- After one attempt, is the Weak/Neutral/Strong feedback actionable without
  looking like an elemental weakness chart?
- Does the distinction between a strong execution grade and a weak opponent
  response remain immediately clear?
- Does averaging Rhythm and Harmony make Syncopated Fill understandable, or does
  a multi-category Skill need a different rule?
- Do Steadying Harmony and Syncopated Fill keep both characters tactically welcome
  without making preference irrelevant?
- Are Rhythm, Melody, and Harmony sufficient for the next content slice, or should
  the taxonomy reopen before broader authoring?

Record the human outcome here before advancing the taxonomy or closing the issue's
playtest acceptance criterion.
