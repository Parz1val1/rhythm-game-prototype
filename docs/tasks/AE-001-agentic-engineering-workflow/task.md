# AE-001: Agentic Engineering Workflow

> **Historical unexecuted proposal.** This packet predates the repository's V1/V2
> documentation normalization. Its status and acceptance criteria are preserved as
> planning history, not active work. Current guidance starts at `AGENTS.md` and
> `plans/current.md`.

<!-- AE_TASK_METADATA_V1
id=AE-001
title=Agentic Engineering Workflow
design_status=Approved
engineering_status=Not started
human_validation_status=Not ready
base_branch=main
base_revision=57bf32a5c0940131ff8bfc520512c4712438594e
delivery_branch=feat/agentic-engineering-workflow
validation_path=docs/tasks/AE-001-agentic-engineering-workflow/validation.md
plan_path=docs/superpowers/plans/2026-08-01-agentic-engineering-workflow.md
END_AE_TASK_METADATA_V1 -->

## Status

- **Design:** Approved
- **Engineering:** Not started
- **Human validation:** Not ready

Only the human validator may set Human validation to `Accepted`, `Iterate`, or `Rejected`. Readiness is evidence-first: engineering must first complete the validation receipt and every required automated evidence row, then check every automated acceptance item below, and only then change Engineering to `Implemented` and Human validation to `Ready for validation`.

## Lifecycle schema

Task metadata and displayed status must use these exact, case-sensitive axes:

- **Design:** `Draft`, `Approved`, or `Superseded`
- **Engineering:** `Not started`, `In progress`, `Blocked`, `Implemented`, or `Superseded`
- **Human validation:** `Not ready`, `Ready for validation`, `Accepted`, `Iterate`, `Rejected`, or `Not applicable`

`Accepted`, `Iterate`, and `Rejected` are human-only decisions. `Implemented` and `Ready for validation` require the evidence and acceptance ordering above. `Not applicable` is invalid for AE-001 because this task has an approved human-validation deliverable.

## Goal

Establish an executable, tool-neutral repository contract that gives human and agent contributors one reliable route from setup through implementation, automated verification, review, and human validation.

## Product/design question

Can a new human or agent enter this repository, find the current work and governing rules quickly, run one canonical command, and receive a trustworthy failure whenever the repository contract or Godot project is broken?

## Base and delivery

- **Policy comparison base:** `main`
- **Base revision:** `57bf32a5c0940131ff8bfc520512c4712438594e`
- **Exact delivery branch:** `feat/agentic-engineering-workflow`

`main` is the policy comparison base for changed-line checks. This task does not claim that GitHub branch protection is configured; that external state is unconfirmed.

## Scope

- Make `AGENTS.md` the sole concise canonical repository contract and make `CLAUDE.md` a thin, exact adapter to it.
- Preserve the current untracked `STATUS.md` contents verbatim as dated history, then replace `STATUS.md` with a concise tracked current-state router.
- Add entry-point and setup documentation: `README.md`, `docs/setup.md`, and `docs/engineering/godot.md`.
- Add reusable task and validation templates with parseable lifecycle metadata and human-only validation decisions.
- Add a strict PowerShell repository-contract verifier with self-tests.
- Add `scripts/verify.ps1` as the canonical command. It must perform a Godot import, run every `test/test_*.gd` script through a strict runner, run documentation/contract checks, and apply changed-line hygiene where a valid comparison base is available.
- Repair only the stale or broken tests identified by the audit so the canonical runner can distinguish a genuinely green suite from a false green.
- Add GitHub Actions that uses the exact canonical verification command with Godot `4.6.3`, least-privilege permissions, stable unique workflow/job names, cancellation of superseded runs, and no secrets.
- Stop tracking `.claude/settings.local.json`, ignore it and `.claude/worktrees/`, and preserve both local paths rather than deleting them.
- Keep the existing superpowers plans/specification as historical records; do not rewrite them to represent current state.
- Define agent routing: the root agent advises/controls, planning and documentation use `gpt-5.6-sol`, implementation and fixes require `gpt-5.6-luna`, and review uses `gpt-5.6-sol`.

## Out of scope

- Gameplay features, balance changes, broad refactors, or changes beyond the three audited stale tests.
- Introducing a formatter, linter, test framework, package manager, dependency scanner, export preset, or unrelated dependency.
- Rewriting historical superpowers plans/specifications as if they were live trackers.
- Deleting user-owned `.claude/worktrees/`, the local `.claude/settings.local.json`, or any unrelated working-tree changes.
- Committing, pushing, opening a pull request, deploying, changing GitHub branch protection, changing repository settings, or writing to any external service without explicit authorization.
- Claiming GitHub branch protection or CI success without direct evidence.

## Audited baseline

| Area | Current evidence |
|---|---|
| Engine | Godot `4.6.3-stable` Mono |
| Main scene | `res://test_scene.tscn` |
| Test inventory | 35 `test/test_*.gd` scripts |
| Existing reported result | 406 `PASS` lines and 0 `FAIL` lines |
| False-green evidence | Every observed test process exits `0`, while raw aggregate output contains 3 `SCRIPT ERROR` events and 2 `ERROR` lines |
| Broken tests | `test_character_input_profile.gd` aborts on an untyped literal assigned to `Array[Array]`; `test_defend_percussive.gd` reads removed `valid_inputs`; `test_string_golem.gd` exercises the stale legacy encounter factory and emits compile/resource errors |
| Import | `godot --import` exits `0` |
| Repository entry points | No `README.md`, export preset, CI workflow, or package manager |
| GitHub policy | Branch protection unconfirmed; the available `gh` credential is invalid |
| User-owned paths | `.claude/worktrees/` and `STATUS.md` are untracked |
| Machine-local policy | `.claude/settings.local.json` is tracked and must become ignored/untracked without deleting the local file |

## Concrete deliverable

A reviewable branch whose concise repository contract, task packet, setup guidance, strict PowerShell checks, canonical Godot verification, targeted test repairs, and GitHub Actions workflow all agree on the same lifecycle and command. The deliverable includes a completed validation handoff with real automated evidence, but no human acceptance decision made on the human's behalf.

## Exact repository file scope

Scope review and content hygiene are separate checks. Scope review must enumerate both tracked changes and untracked new files. The deterministic actual set is the sorted, unique union of `git diff --name-only main --` and `git ls-files --others --exclude-standard`; a plain `git diff` is insufficient. That union must equal this exact allowlist:

```text
.claude/settings.local.json
.github/workflows/verify.yml
.gitignore
AGENTS.md
CLAUDE.md
README.md
STATUS.md
docs/engineering/godot.md
docs/setup.md
docs/status/history/2026-08-01-pre-agentic-workflow.md
docs/superpowers/plans/2026-08-01-agentic-engineering-workflow.md
docs/tasks/AE-001-agentic-engineering-workflow/task.md
docs/tasks/AE-001-agentic-engineering-workflow/validation.md
docs/tasks/_template/task.md
docs/tasks/_template/validation.md
scripts/check-changed-lines.ps1
scripts/check-repository-contract.ps1
scripts/run-godot-tests.ps1
scripts/test-check-repository-contract.ps1
scripts/test-run-godot-tests.ps1
scripts/verify.ps1
test/test_character_input_profile.gd
test/test_defend_percussive.gd
test/test_string_golem.gd
```

The index-only removal of `.claude/settings.local.json` counts as an expected repository change even though its local file must remain byte-identical. Personal files under `~/.codex/` are outside the repository set and are governed by their separate scoped authorization gate.

Content hygiene must inspect only added lines from tracked modifications, using a zero-context diff against `main` and excluding diff headers. It must inspect the full content of each untracked addition because every line is new. It must skip deleted paths, including the index-only `.claude/settings.local.json` deletion. Both applicable sources are checked for trailing whitespace and line-start conflict markers; the exact changed-path union remains a separate scope assertion.

## Verification staging

- **Task 5 bootstrap:** repository-contract component self-tests, Godot-runner self-tests, and isolated canonical-orchestration self-tests must be green. Before `.github/workflows/verify.yml` exists, the direct real-repository contract check is expected to exit nonzero with the single failure `REQUIRED_FILE_MISSING .github/workflows/verify.yml`. Task 5 records that expected bootstrap result, does not run the canonical command against the real repository, and must not claim the repository is fully green.
- **Task 6 completion:** after creating and statically validating `.github/workflows/verify.yml`, Task 6 owns the first real-repository canonical `scripts/verify.ps1` run and the first fully green real-repository contract check. Any additional failure blocks completion.

## Automated acceptance checklist

- [ ] `AGENTS.md` is the sole concise canonical contract; `CLAUDE.md` is a thin exact adapter and contains no divergent rules.
- [ ] `README.md`, `docs/setup.md`, and `docs/engineering/godot.md` route a zero-context contributor to prerequisites, the task packet, status, and the exact canonical command.
- [ ] Immediately before either user-owned file is mutated, `validation.md` records SHA-256 hashes and capture times for the original untracked `STATUS.md` and tracked `.claude/settings.local.json`.
- [ ] The original untracked `STATUS.md` is preserved byte-for-byte at `docs/status/history/2026-08-01-pre-agentic-workflow.md`; the new `STATUS.md` is a concise tracked current-state router.
- [ ] `docs/tasks/_template/task.md` and `docs/tasks/_template/validation.md` enforce parseable statuses, automated acceptance, a validation handoff, and the human-only final decision rule.
- [ ] `.gitignore` ignores `.claude/settings.local.json` and `.claude/worktrees/`; `.claude/settings.local.json` is removed from the index only, and both local paths still exist unchanged.
- [ ] The strict contract verifier passes its component self-tests, including malformed/missing metadata, every exact lifecycle enum and invalid transition, adapter drift, broken links, missing required files, and forbidden placeholders.
- [ ] The strict Godot runner passes its PowerShell self-tests, including nonzero exit, `FAIL`, `SCRIPT ERROR`, `ERROR`, missing completion marker, and timeout cases even when the fake process exits `0`.
- [ ] `test_character_input_profile.gd`, `test_defend_percussive.gd`, and `test_string_golem.gd` are repaired against current interfaces without changing gameplay behavior.
- [ ] Task 5's isolated orchestration self-tests pass; its direct real-repository contract check reports only `REQUIRED_FILE_MISSING .github/workflows/verify.yml`; no real-repository canonical run or full-green claim occurs in Task 5.
- [ ] `scripts/verify.ps1` runs Godot import, all 35 headless tests, contract checks, and applicable changed-line hygiene; any failed stage makes the command nonzero.
- [ ] After Task 6 creates the workflow, Task 6's first full real-repository contract check and canonical verification command exit `0`, contain no `FAIL`, `SCRIPT ERROR`, or `ERROR` diagnostics, and report the expected test-script and assertion totals from the repaired suite.
- [ ] `.github/workflows/verify.yml` uses Godot `4.6.3`, the exact canonical command, `contents: read`, stable unique workflow/job names, concurrency cancellation, no repository secrets, and no write-capable event.
- [ ] Static workflow/contract checks prove the documented local command and CI command are byte-for-byte identical.
- [ ] The sorted union of tracked changes and untracked new files equals the exact allowlist above; separately, added lines in tracked modifications and full contents of untracked additions pass whitespace/conflict-marker checks while deletions are skipped; the scope contains no unrelated/user-owned changes or modified historical plans/specifications.
- [ ] `validation.md` contains the real command outputs/evidence references, completed nonvisual handoff, known limitations, pre-mutation hash receipt, and requested human decisions; every required evidence row is complete before these acceptance boxes are checked.

## Human validation deliverable

The human receives [validation.md](./validation.md) with access instructions, exact happy-path and negative trials, required evidence, limitations, and explicit decisions to make. Screenshots are `N/A` because this is a nonvisual process task. After the validation receipt and all required evidence are complete, engineering checks every acceptance item; only then may automated completion move Human validation to `Ready for validation`. The human records `Accepted`, `Iterate`, or `Rejected` after performing or reviewing the trials.

## Blockers and authorization gates

- **Implementation blocker:** this session exposes only `gpt-5.6-sol` and `gpt-5.6-terra` as spawn overrides, not the required `gpt-5.6-luna`. Implementation must not start until a new session exposes Luna or the human explicitly approves a fallback.
- The official Codex documentation confirms that `gpt-5.6-luna`, global `agents.default_subagent_model`, and standalone custom agent TOMLs are supported. Global routing remains local configuration, takes effect only in a new session, and is not repository truth.
- Editing `~/.codex/config.toml` or `~/.codex/agents/*.toml` requires scoped filesystem authorization and preservation of the current files before any change.
- Commits, pushes, PRs, deployments, GitHub settings, and branch-protection changes require separate explicit authorization.
- GitHub branch protection is unconfirmed and the current `gh` credential is invalid; neither fact blocks local implementation or static workflow validation.

## Engineering status

Not started. Planning artifacts do not satisfy engineering acceptance, and no implementation should begin while the Luna routing gate is unresolved.

## Human-validation status

Not ready. The handoff structure exists, but implementation evidence and automated acceptance are pending.

## Links

- [Validation handoff](./validation.md)
- [Implementation plan](../../superpowers/plans/2026-08-01-agentic-engineering-workflow.md)
