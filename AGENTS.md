# Rhythm Game Prototype — Agent Router

This repository is the Godot combat prototype for **Song of the Stars**, a rhythm
RPG. Preserve the audio-aligned, deterministic combat loop while making scoped,
testable changes.

## Load Context Progressively

1. Read this file and classify the task.
2. Load only the linked context whose trigger matches the task.
3. Inspect the affected implementation and its tests.
4. Expand into adjacent systems only when evidence requires it.

## Context

- **Domain vocabulary or combat terminology** → [CONTEXT.md](CONTEXT.md)
- **Product behavior, player experience, or scope** → [docs/PRODUCT.md](docs/PRODUCT.md)
- **System boundaries, data flow, or extension seams** → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Established technical choices that a change may challenge** → [docs/DECISIONS.md](docs/DECISIONS.md)
- **Godot setup, commands, tests, logging, or file-editing mechanics** → [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- **Priorities or future work** → [docs/ROADMAP.md](docs/ROADMAP.md)
- **Current medium/large implementation effort** → [plans/current.md](plans/current.md)

Files under `docs/superpowers/` and `docs/status/history/` are historical records,
not current-state instructions. Use them only when a task targets that history or
a current document links to a specific record as design evidence.

## Always-On Invariants and Gotchas

- Treat gameplay `.tres` files as templates. Deep-copy a Character, Enemy, or
  other mutable gameplay Resource before live use with `duplicate(true)`.
- Keep enemy patterns character-neutral and deterministic. Visual announcement
  and scoreable injection must resolve the same `NeutralHit` with the same
  `sequence_index`; whole-beat patterns must preserve alternation.
- Keep `BeatClock` an audio-corrected signal source. Game rules belong in combat
  systems, and `DECISION` must not stop the backing music or clock.
- In autoload scripts, preload cross-file `class_name` types and `DebugLog` because
  Godot 4.6 autoload parse order does not reliably expose global types.
- Convert `StringName` before indexing a `String`-keyed Dictionary, and build typed
  nested arrays with `append()` instead of untyped literal assignment.
- Disconnect autoload/combat signals during teardown with `is_connected()` guards.
- Log meaningful timing, combat, visual, and audio handoffs through `DebugLog`;
  per-frame logging is outside the logging contract.
- Hand-edit small existing `.tscn`/`.tres` changes and inspect their diffs. Scene
  automation may churn formatting and UIDs.
- A test run is green only when every script exits `0`, emits no `FAIL`, `SCRIPT
  ERROR`, or line-leading `ERROR:`, and prints `=== done ===`. PASS totals alone
  are not evidence of a green suite.
- Preserve accepted ADRs unless the task explicitly reopens one. Update the
  canonical document when behavior, architecture, or decisions change.

## Workflow and Agent Skills

Use the lightest process that fits:

- **Small/local change:** this file → relevant code/test → implement → focused
  verification → diff review. A separate plan is unnecessary.
- **Hard bug or regression:** use `$diagnosing-bugs` to establish a tight red
  feedback loop before fixing it.
- **Behavioral change with a known seam:** use `$tdd` and the repository's headless
  test contract.
- **Medium feature:** relevant context → implementation inspection → scoped plan →
  implement/TDD → verify → review.
- **Large or ambiguous feature:** product/design discussion → `$to-spec` → resolve
  open questions → implementation plan/tickets → `$implement` → verification →
  `$code-review` → documentation update.
- **Agent-facing documentation:** use `$writing-for-agents`; keep knowledge here and
  reusable procedure in skills.

## Agent Skill Configuration

- Issue tracker → [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md)
- Triage vocabulary → [docs/agents/triage-labels.md](docs/agents/triage-labels.md)
- Domain sources → [docs/agents/domain.md](docs/agents/domain.md)

The Matt Pocock engineering skills are installed at user scope. Their procedures
do not override this repository's invariants, ADRs, or verification contract.
