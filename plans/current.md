# Current Implementation Plan

No combined application implementation plan is currently active.

The phased transition is tracked by
[Combat V1 epic #8](https://github.com/Parz1val1/rhythm-game-prototype/issues/8).
Phase A and its playtest revisions are complete. The human playtest in
[#15](https://github.com/Parz1val1/rhythm-game-prototype/issues/15) approved the
core conversation cadence and explicitly unblocked Phase B.

Begin Phase B with
[#16](https://github.com/Parz1val1/rhythm-game-prototype/issues/16), which owns the
smallest Skill model and multi-bar Character Performance. Keep the legacy
prototype runnable while the V1 replacement gate remains open. The count-in
presentation cleanup in
[#42](https://github.com/Parz1val1/rhythm-game-prototype/issues/42) can land before
or alongside #16. The Enemy Phrase repertoire in
[#43](https://github.com/Parz1val1/rhythm-game-prototype/issues/43) should support
the Phase B playtest in #20 but does not block starting #16.

The completed technical spike in
[#45](https://github.com/Parz1val1/rhythm-game-prototype/issues/45) selected Wwise
for #21's later arrangement prototype behind repository-owned timing and musical-
intent interfaces. That production-facing integration follows the #20 Phase B
gate. It does not block #16–#20, and Phase B should remain independent of Wwise
events, States, callbacks, and SDK types.
