# Combat System v1

- **Status:** Approved design target
- **Authority:** Canonical for intended combat mechanics and player-facing behavior
- **Implementation status:** Partially implemented

When this specification conflicts with descriptions of existing prototype
behavior, this specification defines the target. Architecture documents, code,
and tests continue to describe the current implementation until the relevant
migration lands. Items identified as open questions remain intentionally
unresolved.

## Combat Vision

Combat in *Song of the Stars* is a **musical conversation rather than conventional violence represented through music**.

Enemies challenge the party musically. The player listens to their performance, demonstrates understanding by responding to it, and then answers with performances of their own. Successful exchanges gradually bring both sides into sync until the encounter becomes a shared jam.

Combat should combine three experiences:

- **Listening** — understanding what another performer is communicating.
- **Tactics** — deciding how the party should respond and manipulate the developing song.
- **Performance** — physically executing rhythm-game skills using each character's unique musical control language.

The ultimate goal is for an encounter to feel as though the player and opponent have collaboratively constructed a piece of music through the battle itself.

Combat should be tactically interesting even without rhythm mechanics, satisfying to physically perform, and musically rewarding simply to listen to.

---

# 1. Encounter Types

Combat uses a shared musical language but supports multiple kinds of encounters.

## Wild Musical Creatures

Musical creatures visibly inhabit the overworld and can generally be approached or avoided.

These creatures combine qualities of real or mythical animals with musical instruments and concepts. A general name for this class of creature is still TBD.

Wild encounters emphasize **communication and discovery**.

The creature presents its musical language, and the party attempts to understand and connect with it.

Different species have different musical preferences, behaviors, phrases, and challenges.

## Musician Encounters

Other musicians understand the musical exchange and can deliberately challenge the party.

These encounters can behave more like competitions, duels, performances, or friendly challenges.

Musicians can express personality through gameplay. An arrogant musician might constantly attempt solos, a nervous performer might rush the tempo, while an improvisational performer might rarely repeat the same phrase.

## Boss Encounters

Bosses use the established combat language but are expected to bend or break its normal rules.

Possible boss mechanics include:

- changing tempo;
- unusual time signatures;
- changing musical preferences;
- layered or overlapping phrases;
- removing instruments from the arrangement;
- splitting the party;
- extended solos;
- disrupting the player's multiplier;
- manipulating the backing arrangement;
- unique call-and-response structures.

Boss encounters can represent dangerous creatures or antagonists, but they can also represent legendary musicians or other characters challenging the party without literal physical violence.

---

# 2. Overworld-to-Combat Transition

Whenever possible, entering combat should feel like a transformation of the existing musical experience rather than loading an unrelated battle track.

Wild musical creatures can be **heard as well as seen** while exploring.

As the player approaches a creature:

1. The creature's musical contribution becomes louder.
2. Its part begins interacting more strongly with the overworld arrangement.
3. The music builds toward the encounter.
4. The creature makes contact with the party.
5. Camera, presentation, and arrangement transition into battle without unnecessarily breaking musical continuity.

The exact method of changing tempo between exploration and combat requires experimentation. The transition should prioritize musicality over rigid adherence to one implementation.

---

# 3. Core Encounter Cadence

The working combat structure is:

**Approach → Settle → Enemy Phrase → Response → Tactical Vamp → Character Performance → Tactical Vamp → Character Performance → Full-Band Vamp → Repeat**

The exact number and ordering of character performances may change through prototyping.

## Settle

After transitioning into combat, the player receives approximately 1–2 bars without required input.

This establishes:

- tempo;
- beat;
- battle arrangement;
- opponent;
- active party.

Characters visibly move with the beat to reinforce the pulse.

This moment should feel like musicians finding the groove before beginning an exchange.

## Enemy Phrase

The opponent performs a musical phrase, generally lasting approximately 1–4 bars.

The player primarily listens.

Enemy phrases communicate information and establish the musical challenge the player must answer.

Difficulty can increase through musical complexity rather than relying primarily on increased speed.

Potential progression includes:

- quarter and eighth notes;
- rests;
- accents;
- syncopation;
- longer phrases;
- melodic movement;
- subdivisions;
- layered rhythms;
- changing meters;
- tempo manipulation;
- increasingly complex musical structures.

## Response

The player responds to the opponent's phrase.

Early encounters may primarily require reproducing what was heard. More advanced encounters may ask the player to interpret, harmonize with, or otherwise respond to the phrase.

This phase represents **musical comprehension**.

Performance during Response affects Groove, Composure, Multiplier, and potentially Inspiration.

## Character Performances

After responding, party members get opportunities to contribute their own parts to the developing arrangement.

Each character selects a skill and performs its associated rhythm-game interaction.

Skills generally last multiple bars rather than functioning as single-button RPG attacks. Exact durations remain a prototype variable.

Character performances represent **musical expression** rather than comprehension.

## Tactical Vamps

Between performances, the music continues while the player is free to make tactical decisions.

There is no time pressure.

The arrangement can vamp indefinitely while the player:

- selects skills;
- uses items;
- reviews battle state;
- considers musical preferences;
- changes tactics;
- listens to the arrangement they have created.

Listening is intentionally part of the reward loop.

**The player should never be punished for stopping to listen to the music.**

Once an action is selected, an appropriate musical transition or count-in returns the player to active performance.

---

# 4. Character Rhythm Languages

Each playable character has a distinct **rhythm-game design language** based on how their instrument feels to perform.

Characters should not merely use differently colored versions of the same note chart.

Different characters should ask the player's hands to think differently.

## Luthier — Strings / Melody

Working interaction language:

- four-input note lanes;
- Guitar Hero-style patterns;
- held notes;
- chords;
- arpeggios;
- melodic sequences.

Individual skills use variations of this vocabulary rather than identical charts.

## Beatrice — Percussion / Rhythm

Working interaction language:

- two primary inputs representing drumsticks;
- spatial timing targets;
- osu-style closing circles;
- left/right alternation;
- simultaneous hits;
- rolls;
- fills;
- accented beats.

Future characters can explore other interaction languages, including:

- multi-input chord structures;
- analog-stick pitch manipulation;
- dynamics;
- continuous parameter control;
- sustained notes;
- articulation;
- breath-like mechanics.

Accessibility and alternate control methods must eventually be considered when character mechanics become more concrete.

---

# 5. Skills

A character's action is primarily determined by selecting a **skill**, with the skill determining both its musical effect and its rhythm-game interaction.

Skills should not merely be attacks with different Groove values.

A skill can manipulate:

- Groove;
- Composure;
- Multiplier;
- Inspiration;
- tempo;
- phrase length;
- musical complexity;
- subsequent character performances;
- enemy phrases;
- arrangement layers;
- musical contribution type;
- other properties of the current performance.

Traditional RPG functions can therefore exist through musical systems.

For example:

**Damage → Groove contribution**

**Healing → Composure recovery**

**Defense → making upcoming musical challenges safer or easier**

**Buffing → improving later performances or modifying the song**

**Debuffing → disrupting an opponent's musical influence**

Skills should communicate these effects musically whenever practical.

---

# 6. Groove — Victory State

**Groove** represents how successfully the party has connected and synchronized with the opponent.

Groove begins empty and fills toward a successful resolution.

Accurate performances generate Groove.

The amount generated can depend on:

- performance quality;
- Multiplier;
- opponent musical preferences;
- skill properties;
- character progression;
- other musical state modifiers.

When Groove reaches its maximum, the encounter resolves successfully in a **Jam**.

The exact final interaction at maximum Groove remains TBD. It may eventually involve a finishing performance, full-band sequence, or other celebratory resolution rather than simply ending immediately.

Groove is not enemy HP.

The opponent is not being damaged. The increasing meter represents both sides becoming musically synchronized.

The arrangement should increasingly communicate this state without requiring the player to look exclusively at UI.

---

# 7. Composure — Failure State

**Composure** represents the band's ability to maintain confidence, timing, and cohesion during the exchange.

Composure begins full.

Mistakes reduce it.

When Composure reaches zero, the band loses the musical exchange and exits the encounter.

Ordinary failure should generally be framed as being shown up, losing the groove, or otherwise failing the performance rather than being physically defeated.

Exact consequences outside combat remain TBD.

Composure should primarily respond to **execution**, not tactical musical preference.

If Beatrice perfectly performs a Rhythm skill against an opponent that does not particularly enjoy Rhythm, the skill may produce little Groove but should not reduce Composure.

She played correctly; it simply wasn't the most effective tactical choice.

---

# 8. Performance Grading

Performance uses multiple levels of timing accuracy rather than simple success/failure.

Working behavior:

| Grade | Groove | Composure | Multiplier |
|---|---|---|---|
| Perfect | High gain | No loss | Strong increase |
| Great | Good gain | No loss | Increase |
| Good | Moderate gain | No loss | Maintain or slight increase |
| Near Miss | Small gain | Small loss | Usually maintain |
| Miss | No gain | Moderate loss | Decrease |
| Major Mistake / Broken Phrase | No gain | Large loss | Major decrease or reset |

Exact timing windows and values are prototype variables.

Near misses affecting **both Groove and Composure** are particularly desirable: the player successfully continued the musical exchange but did so shakily.

Phrase-level performance can also matter in addition to individual notes so that recovering after a mistake is meaningful.

---

# 9. Multiplier — Momentum and Mastery

Multiplier is a shared band-wide representation of sustained performance quality.

It begins at a baseline value and increases through consistently strong execution.

Multiplier increases Groove generation and can interact directly with skills.

Mistakes reduce it, while major mistakes may reset it.

Potential skill interactions include:

- adding a fixed amount to Multiplier;
- doubling current Multiplier;
- protecting Multiplier from a limited number of mistakes;
- transferring accumulated momentum into Groove;
- increasing skill effects based on Multiplier;
- risking Multiplier for unusually powerful outcomes.

Example design:

**Double Down**

Spend significant Inspiration to double the band's current Multiplier. A subsequent major mistake can reset the accumulated Multiplier, creating a high-risk opportunity to rapidly finish an encounter.

Multiplier should create moments where the player voluntarily takes on additional pressure because they believe they can execute the performance.

---

# 10. Inspiration — Character Resource

Each character has an individual **Inspiration** meter.

Inspiration functions as the primary resource used to activate stronger skills.

Unlike traditional MP, Inspiration is intended to circulate relatively freely.

## Persistence

Inspiration persists between encounters.

However, it should regenerate quickly enough through ordinary combat that players generally treat it as something to **manage within encounters rather than hoard across the game**.

Characters maintain a minimum Inspiration floor so that using powerful abilities does not make subsequent encounters feel resource-starved.

Exact floor values and regeneration rates require prototyping.

## Generation

Inspiration can be generated through:

- ordinary/basic performances;
- Perfect notes;
- Perfect phrases;
- sustained high-quality performance;
- specific skills;
- party interactions.

Some support skills may generate Inspiration for **other party members**.

This enables musical setups such as one performer establishing the groove and inspiring another character to execute a more expensive technique.

## Spending

More powerful or transformative skills consume Inspiration.

Strong performance therefore creates a positive loop:

**Perform well → become Inspired → access more expressive techniques → manipulate the song → create new performance opportunities.**

---

# 11. Musical Contributions and Opponent Preferences

The working musical contribution system uses three primary categories:

**Rhythm**

**Melody**

**Harmony**

Skills can belong to one or potentially multiple categories.

Characters naturally specialize but can learn skills outside their primary musical role.

For example:

- Beatrice naturally specializes in Rhythm.
- Luthier naturally specializes in Melody.
- Later techniques may allow either character to contribute in other ways.

## Preferences

Enemies do not use a rigid elemental rock-paper-scissors chart.

Instead, different opponents have **musical preferences**.

An opponent might respond strongly to Melody, moderately to Harmony, and only slightly to Rhythm.

Using a preferred musical contribution increases Groove generation.

This represents bringing something exciting or complementary to the musical exchange rather than exploiting an arbitrary weakness.

A creature that already embodies percussion may be difficult to impress with straightforward Rhythm but become fascinated by Melody.

Preferences should encourage party synergy rather than benching characters.

A character whose natural contribution is ineffective can still manipulate tempo, Multiplier, Composure, Inspiration, or another character's upcoming performance.

## Discovery

Musical preferences may initially be unknown.

Players can experiment during encounters and learn what different creatures respond to.

Discovered information can eventually be recorded in a Bestiary, Songbook, Field Guide, or equivalent system.

This gives encountering new musical creatures an element of experimentation and discovery.

More advanced enemies and bosses may dynamically change preferences during an encounter.

---

# 12. Level and Long-Term Progression

Characters can level up, but traditional stat growth should remain limited unless later design demonstrates a need for it.

Level primarily represents the band's growing experience.

Higher-level characters can translate successful performance into Groove more efficiently, allowing returning players to resolve encounters in earlier areas more quickly.

Level should **never replace execution**.

A high-level character performing terribly should not automatically defeat an early enemy.

Conceptually:

**Performance Quality × Progression × Musical Effectiveness × Multiplier → Groove Contribution**

Exact formulas are deliberately unspecified.

Musical performance establishes the foundation; progression amplifies successful play rather than replacing it.

---

# 13. Skill Loadouts and Acquisition

Characters learn more skills than they can bring into an encounter.

Before combat, players customize each character's equipped **skill loadout** through an overworld/menu interface analogous to choosing equipment or abilities in a traditional JRPG.

Exact loadout size remains TBD, with approximately 4–6 equipped skills per character as an initial range worth testing.

Skills can be acquired through:

### Level Progression
Core techniques associated with a character's natural development.

### Story Progression
Signature abilities tied to important character or narrative moments.

### Exploration and Secrets
Optional techniques learned through puzzles, hidden locations, musicians, creatures, side quests, or musical discoveries.

Finding a skill should ideally feel like **learning a new musical technique**, not simply obtaining a skill book from a chest.

---

# 14. Improvisation

Improvisation is intended as an **advanced skill rather than a baseline combat requirement**.

Early gameplay teaches players through authored rhythm challenges.

Later, characters can unlock Improvise abilities that remove some of those constraints and allow more personal musical expression.

The system should remain guided enough that players without musical training can produce satisfying results.

Different characters can improvise through their own control languages.

Examples include:

- constrained melodic improvisation;
- open percussion patterns;
- chord selection;
- dynamics;
- pitch bending;
- synthesizer parameter manipulation.

Unlocking improvisation should feel like a meaningful moment of musical growth:

The player has spent the game learning how to perform music the game gives them.

Eventually, the game asks them what **they** want to play.

---

# 15. Duets, Ensembles, and Limit-Style Performances

Advanced multi-character performances are planned but not yet fully designed.

Potential hierarchy:

**Techniques** — individual character skills using Inspiration.

**Duets / Ensembles** — multiple characters combine their musical and control languages.

**Finale / Limit Performance** — rare, powerful full-party or character-defining performances.

Duets could combine rhythm interfaces simultaneously or sequentially.

For example, a Luthier/Beatrice duet could combine Luthier's note lanes with Beatrice's percussion prompts, requiring the player to manage both musical parts.

These mechanics should represent increasing player mastery of the ensemble.

A separate Limit-style resource may eventually build across multiple encounters, but its theme, behavior, and relationship with Inspiration remain unresolved.

---

# 16. Audio as Combat and Overworld Feedback

Important game state should be **audible whenever practical**, while retaining clear visual UI and accessibility support.

The music itself can communicate party state.

## Inspiration

When a character reaches full or significant Inspiration, their presence in the overworld arrangement can subtly change.

Examples include:

- additional ornamentation;
- fills;
- countermelodies;
- stronger instrumental presence;
- character-specific musical flourishes.

Players may gradually learn to recognize these cues without consciously checking the UI.

## Composure

Low Composure should subtly affect the overworld arrangement.

Possible effects include:

- slight controlled dissonance;
- altered voicings;
- missing supporting layers;
- less confident musical phrasing;
- subtle timing instability;
- unresolved musical tension.

This should **not** resemble an irritating low-health alarm.

The altered arrangement should remain enjoyable to listen to while making the player intuitively feel that the band is not fully together.

Recovering Composure should allow the music to resolve naturally back into its confident state.

## Combat State

The developing battle arrangement should likewise communicate:

- rising Groove;
- increasing Multiplier;
- character contributions;
- opponent synchronization;
- active musical effects.

The long-term goal is for experienced players to be able to **hear significant portions of the combat state** rather than relying exclusively on meters and status icons.

---

# 17. Arrangement as Reward

The soundtrack is not merely accompaniment to combat.

It is one of combat's primary rewards.

As an encounter progresses:

- character performances add or modify musical layers;
- successful exchanges make the arrangement increasingly cohesive;
- high Groove should sound more complete and energetic;
- high Multiplier should communicate momentum;
- opponent parts increasingly fit with the party;
- player decisions audibly affect the resulting composition.

Tactical vamps intentionally give the player time to hear what they have created.

By the end of a successful encounter, music that began as a confrontation should feel like a **jam session**.

This transformation is one of the core fantasies the combat prototype must validate.

---

# 18. Prototype Priorities

Combat v1 intentionally leaves numerical tuning unresolved.

The prototype should test experience and relationships before balancing exact values.

Primary questions:

1. Is listening to an enemy phrase before responding enjoyable?
2. Does reproducing the enemy's phrase feel like musical communication rather than memorization homework?
3. Are character-specific rhythm languages enjoyable to switch between?
4. What skill-performance duration feels best?
5. Do tactical vamps improve pacing or interrupt it?
6. Does the accumulating arrangement make player actions feel musically meaningful?
7. Can Groove and Composure create exciting simultaneous near-win/near-loss states?
8. Does Multiplier create satisfying risk/reward?
9. Does Inspiration regenerate quickly enough to encourage spending?
10. Do musical preferences create meaningful tactical decisions?
11. Can character support skills remain valuable even against opponents that dislike their primary contribution type?
12. Can combat become musically more difficult without relying primarily on increasing BPM?
13. Does level progression make returning to earlier areas feel appropriately powerful without invalidating player execution?
14. Can important battle state be communicated through audio without becoming distracting?
15. Most importantly: **does the player feel like they are participating in the creation of the song?**

---

# 19. Open Questions

The following remain intentionally unresolved:

- General name for wild musical creatures.
- Exact skill loadout size.
- Exact timing windows and performance grades.
- Groove and Composure formulas.
- Multiplier progression and maximum.
- Inspiration maximum, floor, generation rate, and costs.
- Exact consequences of losing an encounter.
- Exact behavior when Groove reaches maximum.
- Whether items exist and how they interact with musical systems.
- How party order is determined or changed.
- Exact relationship between Response and individual character control languages.
- Whether Rhythm / Melody / Harmony are sufficient as the complete contribution taxonomy.
- Final design of Duets and Ensembles.
- Whether Limit-style performances require a separate persistent resource.
- How much arrangement state persists after combat.
- How Composure is recovered outside encounters.
- How accessibility options affect character-specific rhythm mechanics.
- Exact implementation of dynamic music, stems, transitions, and tempo changes.

These questions should be answered through subsequent character, world, narrative, and prototype development rather than prematurely fixed in the abstract.
