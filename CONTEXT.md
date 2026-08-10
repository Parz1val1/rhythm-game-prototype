# Domain Context

Use these canonical terms in product discussion, plans, tests, and code names. This
is a glossary only; product rules and implementation belong in the documents routed
from `AGENTS.md`.

## Rhythm Language

**Beat** — The primary musical pulse used to schedule combat events.

**Sub-beat** — A fractional position between beats, such as a half beat or quarter
beat.

**Beat offset** — A hit's beat or sub-beat position within a repeating pattern. It
is musical position, not elapsed wall-clock time or position in a list.

**Timing grade** — `perfect`, `good`, or `miss`, describing how close a player's
input was to its intended musical time.

**Chord** — Two character inputs performed closely enough together to count as one
combined musical action.

## Pattern and Input Language

**Enemy pattern** — The repeating sequence an enemy performs during its turn.

**Neutral hit** — One character-independent event in an enemy pattern. It says
when the event occurs and whether it requires one or two simultaneous lanes, but
does not name a key, arrow, or hand.

**Lane** — One simultaneous input requirement within a neutral hit. A two-lane hit
becomes a combined percussive action or a pair of directional actions according to
the defending character's vocabulary.

**Input vocabulary** — The musical actions a character can perform. Raw controller
or keyboard bindings are controls for a vocabulary; they are not the vocabulary
itself.

**Directional vocabulary** — Luthier Frett's four-direction melodic vocabulary:
up, right, down, and left.

**Percussive vocabulary** — Beatrice Styx's two-hand drum vocabulary: left, right,
and both hands together.

**Pattern translation** — The deterministic conversion of neutral hits into the
active defender's input vocabulary. The same enemy pattern and defender must
produce the same result on replay.

## Combat Language

**DECISION** — The menu phase. The player selects Attack, Defend, Item, or Run while
the music and musical clock continue.

**ATTACK** — The player's performance phase. Timing and character-specific musical
quality determine damage, combo progress, and limit charge.

**DEFEND** — One living enemy's pattern phase. The player performs translated
inputs to block, reduce, or counter incoming damage.

**Defensive stance** — The temporary damage-reduction state created by choosing
Defend before entering DEFEND. It is a stance, not another phase.

**Combo** — Consecutive successful ATTACK inputs that increase the current damage
multiplier; misses break the streak.

**Limit gauge** — A character's charge toward a limit break. It belongs to the
current live combat state.

**Limit break** — A player-triggered extended ATTACK performance with a damage
multiplier, available when the active character's limit gauge is full.
