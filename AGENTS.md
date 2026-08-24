# Rhythm Game Prototype — Agent Router

This repository is the Godot combat prototype for **Song of the Stars**, a rhythm
RPG. Use Combat System v1 as the target for combat prototyping while keeping the
gap between that target and the current implementation explicit.

## Load Context Progressively

1. Read this file and classify the task.
2. Load only the linked context whose trigger matches the task.
3. Inspect the affected implementation and its tests.
4. Expand into adjacent systems only when evidence requires it.

## Git Work Isolation

Before editing repository files, run `git status --short --branch`.

For implementation work, use a dedicated `codex/` branch or isolated worktree. If
the current branch is `main` or `master`, create and switch to
`codex/<issue>-<slug>` before editing. Never implement directly on the default
branch.

If the working tree already contains changes whose ownership or relationship to
the task is unclear, stop and ask before creating a branch, moving changes, or
beginning implementation. Preserve existing changes; do not stash, reset, or
delete them to obtain a clean tree. Creating a branch does not authorize staging,
committing, pushing, or opening a pull request except through the issue handoff
workflow below or when the user explicitly requests those actions.

## Completion and Remote Handoff

For implementation tied to a GitHub issue, completion includes a remote pull
request unless the user requests local-only work. After required verification and
final diff review, stage only task-scoped files, commit them, push the current
`codex/` branch, and open a pull request targeting `main`.

Open a ready-for-review pull request only when the requested scope is complete and
required verification is green. Otherwise, open a draft and state what is failing,
blocked, or intentionally incomplete. The pull request body must link the issue,
use `Closes #N` only when fully complete, and report the implementation summary,
exact verification results, documentation or guardrail changes, and deferred work.

Leave the pull request unmerged for the user. Preserve unrelated working-tree
changes, and do not force-push or rewrite shared history. If authentication or
network access blocks the remote handoff, preserve the local branch and commit and
report the blocker.

## Context

- **Combat mechanics, cadence, resources, or prototype questions** → [docs/combat/README.md](docs/combat/README.md)
- **Domain vocabulary** → [CONTEXT.md](CONTEXT.md)
- **Non-combat product behavior or repository scope** → [docs/PRODUCT.md](docs/PRODUCT.md)
- **System boundaries, data flow, or extension seams** → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Established technical choices that a change may challenge** → [docs/DECISIONS.md](docs/DECISIONS.md)
- **Godot setup, commands, tests, logging, or file-editing mechanics** → [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- **Wwise integration, bank authoring, timing evidence, or dependency upgrades** → [spikes/wwise/README.md](spikes/wwise/README.md)
- **Priorities or future work** → [docs/ROADMAP.md](docs/ROADMAP.md)
- **Current medium/large implementation effort** → [plans/current.md](plans/current.md)

Files under `docs/superpowers/` and `docs/status/history/` are historical records,
not current-state instructions. Use them only when a task targets that history or
a current document links to a specific record as design evidence.

## Always-On Invariants and Gotchas

- Treat gameplay `.tres` files as templates. Deep-copy a Character, Enemy, or
  other mutable gameplay Resource before live use with `duplicate(true)`.
- Keep `BeatClock` an audio-corrected signal source. Game rules belong in combat
  systems, and input-free combat phases must not stop the backing music or clock.
- Keep Wwise behind repository-owned timing/arrangement interfaces; extrapolated
  position is gameplay authority, while callbacks are presentation/diagnostics.
- In autoload scripts, preload cross-file `class_name` types and `DebugLog` because
  Godot 4.6 autoload parse order does not reliably expose global types.
- Convert `StringName` before indexing a `String`-keyed Dictionary, and build typed
  nested arrays with `append()` instead of untyped literal assignment.
- Disconnect autoload/combat signals during teardown with `is_connected()` guards.
- Log meaningful timing, combat, visual, and audio handoffs through `DebugLog`;
  per-frame logging is outside the logging contract.
- Run every Godot process outside the filesystem sandbox. Sandboxed Godot cannot
  access `user://logs` on the primary Windows host and may crash with an OS error
  dialog; if approval is unavailable, report verification as blocked instead of
  launching a sandboxed probe.
- Hand-edit small existing `.tscn`/`.tres` changes and inspect their diffs. Scene
  automation may churn formatting and UIDs.
- A test run is green only when every script exits `0`, emits no `FAIL`, `SCRIPT
  ERROR`, or line-leading `ERROR:`, and prints `=== done ===`. PASS totals alone
  are not evidence of a green suite.
- Treat legacy combat tests and ADRs as evidence of current behavior, not authority
  over Combat System v1. Preserve accepted technical choices until the relevant
  migration explicitly reopens them, and update the canonical document when a
  choice changes.

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
