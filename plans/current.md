# Current Implementation Plan

No combined application implementation plan is currently active.

The phased transition is tracked by
[Combat V1 epic #8](https://github.com/Parz1val1/rhythm-game-prototype/issues/8).
Phase A and its playtest revisions are complete. The human playtest in
[#15](https://github.com/Parz1val1/rhythm-game-prototype/issues/15) approved the
core conversation cadence and explicitly unblocked Phase B.

Phase B began with
[#16](https://github.com/Parz1val1/rhythm-game-prototype/issues/16), which now has
the smallest Skill model, two multi-bar Character Performances, and the provisional
single-performance exchange cadence implemented and approved in a human playtest.
The playtest's vertical-navigation/controller-A correction is in place.
[#17](https://github.com/Parz1val1/rhythm-game-prototype/issues/17) extends that
slice with session-owned per-character Inspiration, provisional grade-based
circulation, atomic floor-protected Skill costs, encounter persistence, and
diagnostic presentation.
[#18](https://github.com/Parz1val1/rhythm-game-prototype/issues/18) now prototypes
fixed authored Luthier-to-Beatrice order, one Character Performance per configured
member, distinct four-input and two-input presentation/audio languages, and one
Full-Band Vamp after both members. Human playtesting must evaluate that order,
count-in pacing, and performance count before any canonical cadence decision.
Keep the legacy
prototype runnable while the V1 replacement gate remains open. Preserve the
count-in presentation cleanup already merged through
[#42](https://github.com/Parz1val1/rhythm-game-prototype/issues/42). The Enemy
Phrase repertoire in
[#43](https://github.com/Parz1val1/rhythm-game-prototype/issues/43) should support
the Phase B playtest in #20 but does not block starting #16.

The completed technical spike in
[#45](https://github.com/Parz1val1/rhythm-game-prototype/issues/45) selected Wwise
for #21's later arrangement prototype behind repository-owned timing and musical-
intent interfaces. That production-facing integration follows the #20 Phase B
gate. It does not block #16–#20, and Phase B should remain independent of Wwise
events, States, callbacks, and SDK types.
