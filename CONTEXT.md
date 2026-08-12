# Domain Context

Use these canonical terms in product discussion, plans, tests, and new code. This
is a glossary only; combat rules belong in
[Combat System v1](docs/combat/COMBAT_SPEC_V1.md), while implementation details
belong in the documents routed from `AGENTS.md`.

## Musical Time and Performance

**Beat** — The primary musical pulse used to schedule combat events.

**Sub-beat** — A fractional position between beats, such as a half beat or quarter
beat.

**Beat offset** — A musical position within a phrase or pattern. It is not elapsed
wall-clock time or position in a list.

**Phrase** — A bounded musical statement performed by an opponent or party member.

**Performance grade** — One of `perfect`, `great`, `good`, `near miss`, `miss`, or
`major mistake / broken phrase`, describing note- or phrase-level execution. Exact
timing windows remain a prototype variable.

**Rhythm language** — A character's instrument-specific physical interaction
vocabulary. Luthier uses a four-input melodic/string language; Beatrice uses a
two-input percussive language.

## Encounter Cadence

**Opponent** — The creature, musician, boss, or other performer engaging the party
in a musical encounter.

**Settle** — The input-free opening bars that establish the tempo, beat,
arrangement, opponent, and active party.

**Enemy Phrase** — The cadence phase in which the opponent performs the musical
challenge and the player primarily listens.

**Response** — The party's answer to an Enemy Phrase. It demonstrates musical
comprehension through reproduction, interpretation, harmonization, or another
context-appropriate response.

**Character Performance** — A party member's multi-bar, skill-driven musical
expression using that character's rhythm language.

**Tactical Vamp** — An indefinitely repeating, no-pressure musical passage during
which the player listens, reviews state, and chooses the next action.

## Combat State

**Groove** — Encounter-wide progress toward musical connection and synchronization
with the opponent. Groove is not enemy health or damage.

**Jam** — The successful resolution reached when Groove is full. Its exact final
interaction remains unresolved.

**Composure** — The band's shared ability to maintain confidence, timing, and
cohesion. Execution mistakes reduce it; reaching zero loses the exchange.

**Multiplier** — Shared band-wide momentum created by sustained execution quality.
It amplifies Groove and can be manipulated or risked by skills.

**Inspiration** — A persistent, per-character resource generated through
performance and spent on stronger skills. It should circulate rather than be
hoarded, with exact values still unresolved.

**Skill** — A selected character action that defines both a musical effect and a
rhythm-game interaction.

**Musical contribution** — A skill's musical role, using the working categories
`Rhythm`, `Melody`, and `Harmony`. Whether those categories are complete remains
unresolved.

**Musical preference** — An opponent's affinity for a musical contribution. It
modifies Groove effectiveness without penalizing correctly executed performance.

**Skill loadout** — The subset of a character's learned skills equipped before an
encounter.

## Advanced Performance

**Improvisation** — Advanced, character-specific musical expression with fewer
authored constraints. It is not a baseline combat requirement.

**Technique** — An individual character skill powered by Inspiration in the
working advanced-performance hierarchy.

**Duet / Ensemble** — A planned performance combining multiple characters' rhythm
languages. Its final interaction model remains unresolved.

**Finale / Limit Performance** — A planned rare character-defining or full-party
performance. Its resource model and relationship to Inspiration remain unresolved.
