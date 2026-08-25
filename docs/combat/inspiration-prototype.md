# Inspiration Prototype

This record describes the provisional implementation for
[issue #17](https://github.com/Parz1val1/rhythm-game-prototype/issues/17).
[Combat System v1](COMBAT_SPEC_V1.md#10-inspiration--character-resource)
defines the product target; the numbers below are adjustable playtest values, not
final progression or balance decisions.

## Ownership and Lifetime

`CombatV1SessionState` owns one independent Inspiration balance for each
registered character. The standalone harness owns the session and injects it into
`CombatV1` through `bind_session(session_state, character_id)` before encounter
setup. Reusing that session for the next encounter preserves every party member's
Inspiration while encounter-owned Groove, Composure, and shared Multiplier reset.

Inspiration is not stored in `CharacterData`, mutable live-combat HP, an authored
`.tres` template, `CombatV1EncounterState`, or the legacy limit gauge. Session
state lasts only as long as its in-memory owner; durable save files and an
eventual production world-state owner remain out of scope.

The runnable harness still performs as Luthier only. Registering additional party
members and exposing their independent snapshots prepares the seam for issue #18;
party ordering, character switching, and support effects targeting other members
are not implemented here.

## Provisional Configuration

`CombatV1.InspirationConfig` is copied into each registered character's session
state. Defaults are:

| Setting | Default |
|---|---:|
| Maximum Inspiration | 100 |
| Minimum Inspiration floor | 20 |
| Initial Inspiration | 50 |
| Good note | 3 |
| Great note | 4 |
| Perfect note | 5 |
| Good phrase | 12 |
| Great phrase | 16 |
| Perfect phrase | 20 |

Great and Perfect values are calculated by adding their configurable bonus to
the ordinary successful note or phrase gain. Near Miss, Miss, and Major Mistake
do not generate Inspiration. Both Response and Character Performance apply these
rules to accepted note grades and the final phrase grade; gains clamp at the
character's configured maximum.

A six-note all-Good Response generates 30 Inspiration. Starting from the default
floor of 20, that ordinary successful exchange restores enough to use the
provisional 30-cost support Skill while remaining at the floor. This is a
circulation test, not a final economy contract.

## Skill Commitment and Presentation

Each authored `CombatV1Skill` declares `inspiration_cost`:

- Bright Motif costs 0 Inspiration.
- Steadying Harmony costs 30 Inspiration.

`get_skill_choices()` publishes the authored cost and current affordability.
`select_skill()` checks and spends atomically before beginning its committed
four-beat count-in. Unaffordable, negative-cost, duplicate, and out-of-cadence
actions do not spend or start a performance; spending can never cross the
character's configured floor.

`CombatV1.get_state()` publishes the active character's identity, current
Inspiration, bounds, and complete party snapshots alongside the encounter-wide
state. `inspiration_changed` publishes immutable-by-convention character
snapshots. The diagnostic HUD observes those public interfaces, names the active
character beside the Inspiration meter, shows each Skill's cost, and marks
unaffordable Skills unavailable without implementing resource rules itself.

Final values, durable saves, cross-character Inspiration effects, and a separate
Finale/Limit resource remain unresolved or explicitly out of scope.
