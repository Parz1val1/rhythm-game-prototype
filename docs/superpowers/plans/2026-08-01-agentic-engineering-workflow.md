# Agentic Engineering Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish one executable, tool-neutral repository contract that routes a zero-context contributor from setup through strict automated verification, review, and a human-owned validation decision.

**Architecture:** `AGENTS.md` is the only canonical prose contract, while short routers and templates point to a machine-checkable task lifecycle. PowerShell scripts expose reusable result objects for contract checking and Godot process execution; `scripts/verify.ps1` composes those checks, and GitHub Actions invokes that exact command. Personal Codex model routing is a separately authorized, machine-local prerequisite and never a repository source of truth.

**Tech Stack:** Godot `4.6.3-stable` Mono, GDScript, PowerShell 7, Git, GitHub Actions YAML, Markdown, TOML.

## Global Constraints

- Work on exact delivery branch `feat/agentic-engineering-workflow` against policy comparison base `main` at revision `57bf32a5c0940131ff8bfc520512c4712438594e`.
- Before repository edits, verify `git branch --show-current` is `feat/agentic-engineering-workflow` and `git rev-parse main` is `57bf32a5c0940131ff8bfc520512c4712438594e`; stop on either mismatch.
- The root agent is the advisor/controller. Planning, documentation, and review use `gpt-5.6-sol`; implementation and fixes require `gpt-5.6-luna`.
- Do not begin implementation until a new session exposes `gpt-5.6-luna`, or the human explicitly authorizes a named fallback.
- Global Codex configuration under `~/.codex/` is machine-local, requires separately scoped filesystem approval, must preserve existing content, and takes effect only after a new session.
- Never describe personal Codex routing as repository truth or as proof that a worker actually used a model; the new session must expose and report the route.
- `AGENTS.md` is the sole concise canonical repository contract. `CLAUDE.md` is only an exact adapter to `AGENTS.md` and may contain no additional rules.
- The canonical local and CI command is byte-for-byte `pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1`.
- Canonical verification must import the project, execute every discovered `test/test_*.gd`, reject false-green diagnostics, run repository-contract checks, and run changed-line hygiene when a valid comparison base exists.
- Scope is the sorted unique union of `git diff --name-only main --` and `git ls-files --others --exclude-standard`; it must equal the repository-relative allowlist in the approved task, including untracked files and the index-only Claude-settings deletion.
- Do not stage paths merely to make them visible to scope checks; intent-to-add is prohibited without separate staging authorization.
- Godot subprocess success requires exit code `0`, no timeout, no `FAIL`, `SCRIPT ERROR`, or `ERROR` diagnostic, and, for tests, the exact completion marker `=== done ===`.
- Preserve the pre-change untracked `STATUS.md` byte-for-byte at `docs/status/history/2026-08-01-pre-agentic-workflow.md` before replacing it with a concise tracked router.
- Stop tracking `.claude/settings.local.json` without deleting or changing its local bytes; ignore it and `.claude/worktrees/`, and do not alter or delete the worktree directory.
- Keep every pre-existing file under `docs/superpowers/plans/` and `docs/superpowers/specs/` unchanged; this new implementation plan is the sole allowed addition in those historical directories.
- Repair only `test/test_character_input_profile.gd`, `test/test_defend_percussive.gd`, and `test/test_string_golem.gd`; do not change gameplay code to make them pass.
- Do not introduce a formatter, linter, test framework, package manager, dependency scanner, export preset, or unrelated dependency.
- Do not claim or change GitHub branch protection. Its state is unconfirmed and the invalid `gh` credential does not block local work or static workflow checks.
- Use no secrets, write-capable event, or write permission in GitHub Actions; set workflow permissions to `contents: read`.
- Only the human may set `Accepted`, `Iterate`, or `Rejected`. Engineering may set Engineering to `Implemented` and Human validation to `Ready for validation` only after all automated acceptance checks and evidence are complete.
- Commits, pushes, pull requests, deployments, repository settings, and branch-protection changes are explicit authorization gates. This plan contains no such execution step and implementation must leave changes uncommitted unless the human separately authorizes one.
- Preserve unrelated working-tree changes and user-owned files. Stop and ask before touching anything outside the exact file map below.

---

## Baseline and exact file map

The approved historical audit starts with 35 discovered test scripts, 406 visible `PASS` lines, zero visible `FAIL` lines, three `SCRIPT ERROR` events, and two `ERROR` lines. The strict runner must dynamically discover the repaired suite and count observed assertions; only its verified output supplies the receipt totals.

| Area | Create | Modify or index-only |
|---|---|---|
| Personal, approval-gated | `~/.codex/agents/{planner,documenter,reviewer,implementer}.toml`; timestamped sibling backups | `~/.codex/config.toml`; preserve unrelated content |
| Repository route | `README.md`; `docs/setup.md`; `docs/engineering/godot.md`; `docs/status/history/2026-08-01-pre-agentic-workflow.md` | `AGENTS.md`; `CLAUDE.md`; `STATUS.md`; `.gitignore`; untrack-only `.claude/settings.local.json` |
| Approved plan | `docs/superpowers/plans/2026-08-01-agentic-engineering-workflow.md` | No pre-existing historical plan/specification |
| Task contract | `docs/tasks/_template/task.md`; `docs/tasks/_template/validation.md`; `scripts/check-changed-lines.ps1`; `scripts/check-repository-contract.ps1`; `scripts/test-check-repository-contract.ps1` | None |
| Godot verification | `scripts/run-godot-tests.ps1`; `scripts/test-run-godot-tests.ps1`; `scripts/verify.ps1` | `test/test_character_input_profile.gd`; `test/test_defend_percussive.gd`; `test/test_string_golem.gd` |
| CI and handoff | `.github/workflows/verify.yml` | `docs/tasks/AE-001-agentic-engineering-workflow/task.md`; `docs/tasks/AE-001-agentic-engineering-workflow/validation.md` |

## Shared interfaces

`scripts/check-repository-contract.ps1` must support both direct execution and dot-sourcing:

```powershell
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BaseRef = 'main',
    [switch]$LibraryOnly
)

function Test-RepositoryContract {
    param([string]$RepositoryRoot, [string]$BaseRef = 'main')
    # Returns [pscustomobject]@{
    #   Succeeded = [bool]; Failures = [string[]];
    #   RequiredFileCount = [int]; CheckedTaskCount = [int]
    # }
}
```

`scripts/check-changed-lines.ps1` must expose these exact repository-scope interfaces:

```powershell
function Get-RepositoryScopeAllowlist {
    param([string]$TaskPath)
    # Returns the sorted unique repository-relative paths from the
    # "Exact repository file scope" text block; rejects duplicates.
}
function Test-ChangedLines {
    param([string]$RepositoryRoot, [string]$BaseRef, [string[]]$AllowedPaths)
    # Returns Succeeded, ActualPaths, MissingPaths, ExtraPaths,
    # HygieneFailures, and FailureReasons.
}
```

Direct execution accepts `-RepositoryRoot`, `-BaseRef`, and `-TaskPath`; `-LibraryOnly` defines functions without exiting.

`scripts/run-godot-tests.ps1` must expose these exact functions when dot-sourced with `-LibraryOnly`:

```powershell
function Invoke-GodotProcessStrict {
    param(
        [string]$GodotPath,
        [string]$ProjectPath,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 120,
        [string]$RequiredCompletionPattern = ''
    )
    # Returns Succeeded, ExitCode, TimedOut, OutputLines,
    # PassCount, CompletionFound, and FailureReasons.
}

function Invoke-GodotTestSuite {
    param(
        [string]$GodotPath,
        [string]$ProjectPath,
        [string[]]$TestPaths = @(),
        [int]$TimeoutSeconds = 120,
        [string[]]$GodotPrefixArguments = @()
    )
    # Returns Succeeded, ScriptCount, AssertionCount, Results,
    # and FailureReasons; empty TestPaths means sorted discovery.
}
```

Direct script execution accepts `-GodotPath`, `-ProjectPath`, `-TestPaths`, and `-TimeoutSeconds`, prints one result per script plus `GODOT TEST SUMMARY scripts=<N> assertions=<N> failures=<N>`, and exits nonzero on any failure. `scripts/verify.ps1` dot-sources both libraries, invokes the strict process primitive for import, invokes the suite, then invokes `Test-RepositoryContract` and hygiene in that order.

---

### Task 1: Authorize and establish scoped personal Codex routing

**Files:** Modify with approval `~/.codex/config.toml`; create or modify with approval `~/.codex/agents/{planner,documenter,reviewer,implementer}.toml`; preserve timestamped sibling backups; modify `docs/tasks/AE-001-agentic-engineering-workflow/task.md` only after routing and branch gates pass.

**Interfaces:**

- Consumes: the human's scoped authorization to write only the listed `~/.codex/` paths.
- Produces: default subagent model `gpt-5.6-luna`; named Sol/Luna roles; a required new-session gate; an evidence-backed Engineering `In progress` task packet before repository implementation.

- [ ] **Step 1: Prove the repository and routing preconditions without writing.**

Run from the repository root:

```powershell
git branch --show-current
git rev-parse main
git status --short --branch
Get-Content -Raw "$HOME/.codex/config.toml"
Get-ChildItem "$HOME/.codex/agents" -File -ErrorAction SilentlyContinue
```

Expected: branch is `feat/agentic-engineering-workflow`; `main` resolves to `57bf32a5c0940131ff8bfc520512c4712438594e`; current user-owned changes are visible; no file is modified.

- [ ] **Step 2: Request one scoped filesystem approval and stop if it is denied.**

Request permission to preserve and edit only `~/.codex/config.toml` and the four exact TOML files under `~/.codex/agents/`. State that the change is global, machine-local, restart-required, and not repository truth.

Expected: explicit approval exists before any write. Denial leaves all five paths byte-for-byte unchanged and keeps implementation blocked.

- [ ] **Step 3: Preserve existing machine-local files before changing them.**

For each existing target, copy it to a sibling named `<name>.pre-ae-001-20260801T<HHmmss>.bak`; create `~/.codex/agents/` only if approved and absent. Record SHA-256 values before and after copying with `Get-FileHash`.

Expected: each existing source has a byte-identical backup; no repository path changes.

- [ ] **Step 4: Merge the routing registry without replacing unrelated configuration.**

Preserve all current keys and add or update only these TOML entries in `~/.codex/config.toml`:

```toml
[agents]
default_subagent_model = "gpt-5.6-luna"

[agents.planner]
description = "Plans repository work using GPT-5.6 Sol."
config_file = "agents/planner.toml"

[agents.documenter]
description = "Writes and revises documentation using GPT-5.6 Sol."
config_file = "agents/documenter.toml"

[agents.reviewer]
description = "Reviews specifications and implementation using GPT-5.6 Sol."
config_file = "agents/reviewer.toml"

[agents.implementer]
description = "Implements features and fixes using GPT-5.6 Luna."
config_file = "agents/implementer.toml"
```

Expected: a TOML parser can read the merged file and unrelated tables are unchanged.

- [ ] **Step 5: Write the four minimal role files.**

Use exactly `model = "gpt-5.6-sol"` in `planner.toml`, `documenter.toml`, and `reviewer.toml`; use exactly `model = "gpt-5.6-luna"` in `implementer.toml`. Do not copy repository instructions into these files.

Expected: each file has one model assignment, and Sol/Luna roles match the Global Constraints.

- [ ] **Step 6: Verify the restart/branch gates, then transition Engineering to `In progress`.**

Parse all TOML files, re-run `git status --short`, and end the session. In a new session, confirm Luna is available, then re-run `git branch --show-current` and `git rev-parse main`. Before any other repository implementation edit, use `apply_patch` on `task.md` to change both `engineering_status=Not started` and displayed `**Engineering:** Not started` to `In progress`; update its Engineering status prose with capture time, exact branch, base revision, and confirmed Luna route. Leave Design and Human validation unchanged.

Expected: if any gate fails, no task status changes. Otherwise metadata/display both read `In progress`, the evidence prose names `feat/agentic-engineering-workflow`, `57bf32a5c0940131ff8bfc520512c4712438594e`, time, and Luna, and all later repository tasks begin from that state.

---

### Task 2: Preserve status history and establish the canonical documentation route

**Files:** Create `docs/status/history/2026-08-01-pre-agentic-workflow.md`, `README.md`, `docs/setup.md`, and `docs/engineering/godot.md`; modify `STATUS.md`, `AGENTS.md`, `CLAUDE.md`, `.gitignore`, and `docs/tasks/AE-001-agentic-engineering-workflow/validation.md`; make an index-only change to `.claude/settings.local.json`.

**Interfaces:**

- Consumes: approved task packet at `docs/tasks/AE-001-agentic-engineering-workflow/` and canonical command string.
- Produces: a single source of rules in `AGENTS.md`; stable links consumed by Task 3; durable pre-mutation receipt values consumed by Task 7.

- [ ] **Step 1: Capture and durably record byte-level evidence before either user-owned mutation.**

Run:

```powershell
$captureTime = Get-Date -Format o
$statusHash = (Get-FileHash -Algorithm SHA256 -LiteralPath ./STATUS.md).Hash
$settingsHash = (Get-FileHash -Algorithm SHA256 -LiteralPath ./.claude/settings.local.json).Hash
$settingsIndex = @(git ls-files --stage -- .claude/settings.local.json)
git status --short -- STATUS.md .claude/settings.local.json .claude/worktrees
```

Immediately use `apply_patch` to replace the four pre-mutation receipt values in `validation.md` with `$captureTime`, `$statusHash`, `$settingsHash`, and the exact `$settingsIndex` line. Re-read the receipt before changing `STATUS.md` or the index.

Expected: the durable receipt contains concrete timestamp, hashes, and tracked index entry; neither user-owned file nor the index has changed yet.

- [ ] **Step 2: Preserve status before replacing it.**

Use `Copy-Item -LiteralPath ./STATUS.md -Destination ./docs/status/history/2026-08-01-pre-agentic-workflow.md`, then compare both files with `Get-FileHash` before applying any change to `STATUS.md`.

Expected: source and history SHA-256 equal the exact `STATUS.md` hash read back from the durable receipt.

- [ ] **Step 3: Rewrite `AGENTS.md` as the concise canonical contract.**

Retain the executable Godot path/discovery guidance, DebugLog category/event-boundary rules, autoload preload workaround, String/StringName dictionary rule, typed-array `append()` rule, scene reload persistence, signal cleanup, whole-beat discriminator warning, and `.duplicate(true)` resource-loading rule. Replace stale pass totals and duplicate run loops with the canonical command; add the AE lifecycle, human-only decision rule, exact model roles, preservation rules, and explicit authorization gates.

Expected: `AGENTS.md` contains all live rules once, names `scripts/verify.ps1`, and does not claim branch protection.

- [ ] **Step 4: Reduce `CLAUDE.md` to an exact adapter.**

Use this complete semantic content, with no copied rules or extra commands:

```markdown
# Claude Code Repository Instructions

Read and follow [AGENTS.md](./AGENTS.md). It is the sole canonical repository contract.
```

Expected: the adapter has one heading, one link, and one source-of-truth sentence.

- [ ] **Step 5: Create zero-context routes and the concise current status.**

`README.md` must route in this order: prerequisites to `docs/setup.md`, current work to `STATUS.md`, rules to `AGENTS.md`, Godot details to `docs/engineering/godot.md`, task packet to AE-001, and the canonical command. `docs/setup.md` must require PowerShell 7, Git, and Godot `4.6.3-stable` Mono; document `GODOT_PATH` and the known Windows console path without making it portable truth. `docs/engineering/godot.md` owns architecture and Godot-specific conventions. New `STATUS.md` identifies AE-001, `In progress`/`Not ready`, delivery branch/base revision, task and validation links, and no historical backlog copy.

Expected: a contributor starting at README can reach every required resource with one link traversal and sees one exact verify command.

- [ ] **Step 6: Ignore but preserve Claude machine-local state.**

Add anchored entries `/.claude/settings.local.json` and `/.claude/worktrees/` to `.gitignore`. Run `git rm --cached -- .claude/settings.local.json`, never `Remove-Item`, then verify the file and directory still exist and the settings hash is unchanged.

Expected: `git ls-files --error-unmatch .claude/settings.local.json` fails; `Test-Path` returns true for both local paths; settings SHA-256 equals the exact value read from the durable receipt.

- [ ] **Step 7: Verify this documentation unit independently.**

Run:

```powershell
Get-FileHash ./STATUS.md,./docs/status/history/2026-08-01-pre-agentic-workflow.md
git check-ignore -v .claude/settings.local.json .claude/worktrees/
rg -n "pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1" AGENTS.md README.md docs/setup.md docs/engineering/godot.md
git diff -- AGENTS.md CLAUDE.md README.md STATUS.md docs/setup.md docs/engineering/godot.md .gitignore
```

Expected: history retains the recorded old hash; current status differs; ignore matches are anchored; all documented commands are byte-for-byte identical; no historical superpowers file is modified.

---

### Task 3: Define lifecycle templates and build the strict repository-contract checker

**Files:** Create `docs/tasks/_template/task.md`, `docs/tasks/_template/validation.md`, `scripts/check-changed-lines.ps1`, `scripts/check-repository-contract.ps1`, and `scripts/test-check-repository-contract.ps1`.

**Interfaces:**

- Consumes: required documentation paths and canonical command from Task 2.
- Produces: `Test-RepositoryContract`, `Get-RepositoryScopeAllowlist`, and `Test-ChangedLines` result objects used by Task 5; CLI exit status used by humans and CI.

- [ ] **Step 1: Write templates with parseable metadata and no ambiguous authority.**

Task metadata keys are exactly `id`, `title`, `design_status`, `engineering_status`, `human_validation_status`, `base_branch`, `base_revision`, `delivery_branch`, `validation_path`, and `plan_path` between `AE_TASK_METADATA_V1` markers. Exact task enums are Design `Draft|Approved|Superseded`, Engineering `Not started|In progress|Blocked|Implemented|Superseded`, and Human validation `Not ready|Ready for validation|Accepted|Iterate|Rejected|Not applicable`. Validation keys remain exactly `task_id`, `handoff_status`, `screenshots`, `human_decision`, and `decision_owner`; exact enums are handoff `Not ready|Ready`, screenshots `N/A|Required|Provided`, decision `Pending|Accepted|Iterate|Rejected`, and owner `human`. Metadata and displayed status lines must agree byte-for-byte, including `screenshots=N/A` and `**Screenshots:** N/A`.

Expected: templates include unchecked automated acceptance, evidence table, exact trials, limitations, and a human-only decision section; sample values are valid neutral values rather than forbidden placeholder words.

- [ ] **Step 2: Write failing fixture cases before the checker implementation.**

The self-test creates isolated repositories beneath a unique directory in `[System.IO.Path]::GetTempPath()`, invokes the contract/scope functions, and removes only that resolved fixture root in `finally`. Define valid fixtures for blocker recovery and active-task supersession, plus named negatives for missing/malformed/duplicate metadata; unsupported enum or display mismatch; lifecycle regression; skipped gate; invalid blocker recovery; transition away from Superseded or a human final state; unchecked acceptance with `Implemented`/`Ready for validation`; required evidence pending at readiness; nonhuman `Accepted|Iterate|Rejected`; adapter drift; broken link; missing file; forbidden phrase; command/workflow drift; all three secret-context forms; historical modification; modified plan present at BaseRef; and an extra untracked file. Add hygiene fixtures proving unchanged tracked whitespace is ignored, a tracked diff-added dirty line fails, a deletion is skipped, and dirty full content in an untracked addition fails. Build the untracked-scope fixture with `git init` and `$emptyTree = git mktree`; stage nothing.

Expected before implementation: the positive fixture or at least one negative expectation fails because `Test-RepositoryContract` is absent or incomplete.

- [ ] **Step 3: Run the self-test to capture the red state.**

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
```

Expected: nonzero exit with a named case showing the checker is not implemented; no repository file outside the two scripts/templates changes.

- [ ] **Step 4: Implement deterministic metadata and lifecycle validation.**

Parse marker blocks line-by-line as `key=value`; reject blank keys/values, non-matching lines, duplicate blocks/keys, unknown keys, missing keys, invalid enum values, and metadata/display disagreement. When the task packet exists at `BaseRef`, read prior task and validation metadata with `git show <BaseRef>:<path>` and enforce this complete graph (unchanged values are allowed):

```text
design: Draft -> Approved | Superseded; Approved -> Superseded; Superseded is terminal
engineering: Not started -> In progress | Blocked | Superseded; In progress -> Blocked | Implemented | Superseded; Blocked -> In progress | Superseded; Implemented -> Superseded; Superseded is terminal
task human validation: Not ready -> Ready for validation | Not applicable; Ready for validation -> Accepted | Iterate | Rejected | Not applicable; Accepted, Iterate, Rejected, and Not applicable are terminal
validation handoff: Not ready -> Ready
human decision: Pending -> Accepted | Iterate | Rejected; all three final states are terminal
screenshots: N/A is terminal; Required -> Provided; Provided is terminal
```

Reject regressions and skipped arrows; `Blocked -> In progress` is the sole blocker-recovery edge. A new packet absent at BaseRef is validated by snapshot invariants. `Implemented` requires checked acceptance; `Ready for validation` requires it plus a complete receipt, no pending required evidence, and handoff `Ready`, while decision may remain `Pending` and unauthorized live CI is `Not required — push not authorized`. `Accepted|Iterate|Rejected` must match `human_decision` and only the human sets them. Pre-decision supersession sets both Design and Engineering `Superseded`, Human validation `Not applicable`, and decision `Pending`; after a human final state, both work axes may become `Superseded` while that final state remains immutable. A human `Iterate` reopens work only through a separately approved follow-up packet.

Expected: every metadata failure includes file path, stable code such as `METADATA_DUPLICATE_KEY`, and actionable detail.

- [ ] **Step 5: Implement repository-only files, exact scope, content, workflow, and history checks.**

Required-file checks accept repository-relative paths only and explicitly exclude `~/.codex/config.toml` and `~/.codex/agents/*.toml` from repository truth. Compare normalized `CLAUDE.md` to Task 2's adapter, resolve relative Markdown links, and scan `Ready for validation`/`Implemented` live artifacts for the four case-insensitive phrases built from `('T' + 'BD')`, `('T' + 'ODO')`, `('implement' + ' later')`, and `('fill' + ' in details')`. Require exact canonical commands and workflow invariants. Reject any GitHub expression matching `(?is)\$\{\{[^}]*\bsecrets\b[^}]*\}\}`, covering dot, bracket, and whitespace access. For historical superpowers paths, permit this plan only when `git cat-file -e <BaseRef>:<plan-path>` proves it was absent and newly added; reject it when present at BaseRef, and reject every other historical modification.

Implement `Test-ChangedLines` with tracked and untracked path sets whose sorted unique union is compared separately to the allowlist. For tracked modifications that still exist, inspect only payload lines added by `git diff --unified=0 --no-color <BaseRef> -- <path>` (exclude `+++` headers); skip deleted paths. For untracked additions, inspect full file contents. Reject trailing whitespace or line-start conflict markers in inspected content and return stable missing/extra/dirty failures without staging.

Expected: `Test-RepositoryContract` returns all failures in one result rather than stopping at the first.

- [ ] **Step 6: Implement safe direct-execution behavior.**

When not `-LibraryOnly`, the contract and changed-lines scripts print stable per-failure lines plus summaries and exit `0` only when their result's `Succeeded` is true. Dot-sourcing with `-LibraryOnly` defines functions and does not exit the caller.

Expected: callers in Task 5 can consume the object without parsing console text.

- [ ] **Step 7: Run every self-test and verify fixture cleanup.**

Run the self-test twice, then search the system temp directory for its unique prefix.

Expected: both runs exit `0`, report one pass for the valid fixture and one expected rejection for every named negative fixture, and leave no fixture directory behind.

---

### Task 4: Build a strict Godot runner and repair the three audited stale tests

**Files:** Create `scripts/run-godot-tests.ps1` and `scripts/test-run-godot-tests.ps1`; modify only `test/test_character_input_profile.gd`, `test/test_defend_percussive.gd`, and `test/test_string_golem.gd`.

**Interfaces:**

- Consumes: Godot executable, project root, optional test paths, and the exact interfaces in Shared interfaces.
- Produces: strict process and suite result objects used by Task 5; dynamically discovered script and observed assertion totals.

- [ ] **Step 1: Write fake-process scenarios before the runner.**

Within the self-test's unique temp directory, create a fake Godot PowerShell script selected by `-Scenario`. Scenarios are: `clean` prints one PASS and `=== done ===` then exits `0`; `nonzero` prints completion then exits `7`; `fail-line` prints `  FAIL  fixture` and completion then exits `0`; `script-error` prints `SCRIPT ERROR: fixture` and completion then exits `0`; `error-line` prints `ERROR: fixture` and completion then exits `0`; `missing-completion` prints one PASS and exits `0`; `timeout` sleeps past the one-second limit and would then exit `0`; `benign-word` prints a sentence containing “error handling” plus PASS/completion and exits `0`.

Expected: self-tests assert only `clean` and `benign-word` succeed; each rejection asserts its stable reason code.

- [ ] **Step 2: Run the self-test to capture the red state.**

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
```

Expected: nonzero exit because `Invoke-GodotProcessStrict` is absent or incomplete.

- [ ] **Step 3: Implement the strict process primitive.**

Use `System.Diagnostics.ProcessStartInfo` with argument-list entries, redirected stdout/stderr, no shell, and asynchronous line capture. On timeout, kill the process tree and wait for exit. Reject with stable reasons `TIMEOUT`, `NONZERO_EXIT`, `FAIL_DIAGNOSTIC`, `SCRIPT_ERROR_DIAGNOSTIC`, `ERROR_DIAGNOSTIC`, and `MISSING_COMPLETION`. Match diagnostics only at line start using `^\s*FAIL(?:\s|:)`, `^\s*SCRIPT ERROR(?:\s|:)`, and `^\s*ERROR(?:\s|:)`; match test completion with `^=== done ===\s*$`.

Expected: a process that exits `0` still fails for every specified false-green output; prose containing lowercase “error” does not fail.

- [ ] **Step 4: Implement sorted discovery and suite aggregation.**

If `TestPaths` is empty, discover `test/test_*.gd` under `ProjectPath`, sort by invariant full path, convert each to `res://test/<name>`, and invoke arguments `--headless --path <ProjectPath> -s <resource-path>` after optional fake-process prefix arguments. Continue after failures, count lines matching `^\s*PASS\s+`, retain per-script results, and make aggregate `Succeeded` false if any script fails.

Expected: direct execution prints all scripts, the exact summary format, and a nonzero exit for any failed member.

- [ ] **Step 5: Make `test_character_input_profile.gd` use its declared typed interface.**

Replace the untyped nested literal assignment with:

```gdscript
var drum_chord: Array = [&"drum_left", &"drum_right"]
var direction_chord: Array = [&"left", &"right"]
p.chord_inputs.append(drum_chord)
p.chord_inputs.append(direction_chord)
```

Expected: the existing `Array[Array]` checks run; no production resource changes.

- [ ] **Step 6: Make `test_defend_percussive.gd` assert current profile inputs.**

Remove the unused `CharacterData` load. Replace both `valid_inputs` assertions with membership in `beatrice_profile.input_map.values()`; retain the `chord_names[0] == &"drum_both"`, defense type, and evaluator assertions. Do not restore `valid_inputs` in production code.

Expected: all nine checks complete against `CharacterInputProfile.input_map`.

- [ ] **Step 7: Make `test_string_golem.gd` use the resource-backed encounter.**

Preload `res://encounters/encounter_definition.gd`, load `res://encounters/string_golem.tres` as that type, assert one enemy, and inspect `definition.enemies[0]`. Assert exact values `enemy_name == "String Golem"`, `max_hp == 130`, `attack_power == 18`, `phase_length == 8`, eight single-lane hits, and sorted offsets `[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]`. Remove all use of `EncounterManager._generate_enemies()`.

Expected: eight encounter checks pass without legacy factory compile/resource diagnostics.

- [ ] **Step 8: Verify the runner and repaired tests independently.**

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
pwsh -NoLogo -NoProfile -File ./scripts/run-godot-tests.ps1 -GodotPath $env:GODOT_PATH -ProjectPath (Get-Location).Path -TestPaths @('test/test_character_input_profile.gd','test/test_defend_percussive.gd','test/test_string_golem.gd')
```

Expected: self-tests exit `0` with all eight scenarios accounted for; the targeted run reports `scripts=3`, its dynamically observed assertion count, `failures=0`, and no rejected diagnostic.

---

### Task 5: Compose the canonical verification command and changed-line hygiene

**Files:** Create `scripts/verify.ps1`; integrate `scripts/check-changed-lines.ps1`; modify `scripts/run-godot-tests.ps1` or `scripts/check-repository-contract.ps1` only if integration exposes a verified defect.

**Interfaces:**

- Consumes: `Invoke-GodotProcessStrict`, `Invoke-GodotTestSuite`, `Test-RepositoryContract`, `Get-RepositoryScopeAllowlist`, and `Test-ChangedLines` from Tasks 3–4.
- Produces: sole command `pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1`, stage results, and process exit status used by Task 6.

- [ ] **Step 1: Write orchestration assertions into the two self-test scripts.**

Add isolated checks proving the orchestrator stops with nonzero status when import, suite, contract, or hygiene fails; use injected function results or isolated fixture repositories rather than altering the real project. Assert stage order `IMPORT`, `GODOT_TESTS`, `CONTRACT`, `HYGIENE` and that the final summary names every stage.

Expected before orchestration exists: the new assertions fail with a missing-script error.

- [ ] **Step 2: Implement Godot path resolution and strict import.**

Resolve executable in this order: explicit `-GodotPath`, nonempty `$env:GODOT_PATH`, then `Get-Command godot`; fail with setup guidance if none resolves. Dot-source the runner with `-LibraryOnly`, then call `Invoke-GodotProcessStrict` with `--headless --path <root> --import`, no completion pattern, and a 180-second timeout.

Expected: import fails on timeout, nonzero exit, or line-start `SCRIPT ERROR:`/`ERROR:` even if Godot exits `0`.

- [ ] **Step 3: Wire the suite and contract exactly once.**

Invoke `Invoke-GodotTestSuite` with empty test paths for sorted discovery, then dot-source the checker and invoke `Test-RepositoryContract -RepositoryRoot <root> -BaseRef main`. Do not filter process output before strict evaluation. Accumulate stage failures and continue far enough to print an actionable final summary.

Expected: isolated orchestration tests prove the result propagates dynamic script/assertion counts and makes any injected suite or contract failure nonzero; no real-repository canonical run occurs.

- [ ] **Step 4: Integrate deterministic scope and changed-line hygiene.**

Resolve comparison base with `git merge-base main HEAD`; if unavailable, try exact revision `57bf32a5c0940131ff8bfc520512c4712438594e`. Parse the exact allowlist from `task.md`, call `Test-ChangedLines`, and report its tracked-plus-untracked enumeration. This comparison, not plain diff, is authoritative. When neither base resolves, print `HYGIENE SKIP no valid comparison base` and do not claim that scope or hygiene passed.

Expected: missing/extra paths—including an invalid untracked file—plus whitespace, conflict, or history violations fail; unavailable base is a visible non-successful skip.

- [ ] **Step 5: Emit stable stage and final summaries.**

Print `VERIFY STAGE <name> PASS|FAIL|SKIP <detail>` for each stage and `VERIFY SUMMARY scripts=<N> assertions=<N> failed_stages=<N>`. Exit `0` only when import, suite, and contract pass and any applicable hygiene check passes.

Expected: callers need no output filtering to determine success, counts, or failed stage.

- [ ] **Step 6: Finish green component/orchestration tests and record the one known real-repository gap.**

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
pwsh -NoLogo -NoProfile -File ./scripts/check-repository-contract.ps1
```

Expected: both isolated self-test scripts exit `0`, including canonical-orchestration fixtures. The direct real-repository contract checker exits nonzero with exactly `REQUIRED_FILE_MISSING .github/workflows/verify.yml` and no other failure. Task 5 does not invoke the canonical command against the real repository and makes no canonical/full-green claim.

---

### Task 6: Add pinned, least-privilege GitHub Actions verification

**Files:** Create `.github/workflows/verify.yml`; modify `scripts/test-check-repository-contract.ps1`; modify `scripts/check-repository-contract.ps1` only if static validation exposes a verified defect.

**Interfaces:**

- Consumes: canonical command from Task 5 and workflow invariants enforced by Task 3.
- Produces: stable workflow name `Verify Repository Contract`, stable job id `verify_repository_contract`, and static CI evidence for Task 7.

- [ ] **Step 1: Add workflow-negative fixtures before the workflow file.**

Ensure contract self-tests reject: Godot other than `4.6.3`; floating action tags; missing `contents: read`; any permission beyond read; missing `cancel-in-progress: true`; secret expressions in dot form `${{ secrets.TOKEN }}`, bracket form `${{ secrets['TOKEN'] }}`, and whitespace form `${{ secrets [ 'TOKEN' ] }}`; `pull_request_target`; `workflow_run`; scheduled/write-capable events; a renamed workflow/job; and any verify command differing by one byte.

Expected before workflow creation: the real-repository check fails for missing `.github/workflows/verify.yml`; fixture suite still passes its expected rejections.

- [ ] **Step 2: Create the minimal workflow contract.**

Set exact top-level `name: Verify Repository Contract`; events `push`, `pull_request`, and `workflow_dispatch`; top-level `permissions: contents: read`; concurrency group `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true`; one `verify_repository_contract` job on `ubuntu-24.04`. Use checkout pinned to `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`, with `persist-credentials: false`.

Expected: no other action, permission, event, service, credential, or secret is present.

- [ ] **Step 3: Install exact Godot without an unpinned setup action.**

Use a PowerShell step to download the official `Godot_v4.6.3-stable_mono_linux_x86_64.zip` release asset from `godotengine/godot-builds/releases/download/4.6.3-stable/`, expand it under `$RUNNER_TEMP`, set executable permission, resolve the console binary, run `--version`, require output beginning `4.6.3.stable`, and append `GODOT_PATH=<absolute binary>` to `$env:GITHUB_ENV`.

Expected: version mismatch or missing binary fails before repository verification; the workflow remains pinned to Godot `4.6.3`.

- [ ] **Step 4: Invoke the exact canonical command once.**

The verification step's entire command is:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
```

Expected: it is byte-for-byte identical to local documentation and contains no wrapper, filtering, secret, or alternate flags.

- [ ] **Step 5: Verify CI statically without claiming a live run.**

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
rg -n "4\.6\.3|contents: read|cancel-in-progress: true|pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1" .github/workflows/verify.yml
```

Expected: all three PowerShell commands exit `0`; this is the first fully green real-repository canonical run, with 35 dynamically discovered scripts, the observed assertion count, and zero failed stages. Static checks prove workflow invariants; no live Actions evidence exists because publishing is a separate authorization gate.

---

### Task 7: Perform Sol review, final verification, and validation receipt transition

**Files:** Modify `docs/tasks/AE-001-agentic-engineering-workflow/task.md` and `docs/tasks/AE-001-agentic-engineering-workflow/validation.md`; review every path in the exact file map.

**Interfaces:**

- Consumes: final working tree, all component summaries, canonical verification output, preservation hashes, and Sol review.
- Produces: checked automated acceptance, Engineering `Implemented`, Human validation `Ready for validation`, a concrete nonvisual receipt, and no human final decision.

- [ ] **Step 1: Have a `gpt-5.6-sol` reviewer audit scope and interface consistency.**

Review the changed-file list against the exact file map; compare checker and runner function/property names to Shared interfaces; confirm docs and CI contain the byte-identical canonical command; inspect the three test diffs for test-only stale-interface changes; confirm old superpowers files are unchanged; and run the checker's forbidden-placeholder scan over live `Ready for validation`/`Implemented` artifacts.

Expected: review returns zero unresolved blocking findings. Route any fixes to `gpt-5.6-luna`, then repeat the affected component test and Sol review.

- [ ] **Step 2: Run the complete verification sequence from a clean process.**

Run from repository root and retain exact stdout, stderr, and exit codes:

```powershell
git status --short --branch
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
pwsh -NoLogo -NoProfile -File ./scripts/check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/check-changed-lines.ps1
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
git diff --check
```

Expected: all checks exit `0`; canonical verification reports 35 scripts, the dynamically observed assertion total, and zero failed stages; diff check is silent.

- [ ] **Step 3: Prove preservation and scope from final state.**

Read the timestamp and two original hashes from the durable pre-mutation receipt. Compare the dated history to the recorded STATUS hash and local Claude settings to its recorded hash; confirm settings is absent from `git ls-files` and both machine-local paths exist and match ignore rules. Re-run `Test-ChangedLines` and retain its exact sorted tracked-plus-untracked enumeration; verify the plan was absent at BaseRef and no other historical file changed.

Expected: preservation matches the recorded values and actual scope equals the approved repository-relative allowlist with no missing, extra, or dirty path.

- [ ] **Step 4: Complete every required evidence row and receipt field first.**

In `validation.md`, record working-tree identity `feat/agentic-engineering-workflow` based on `57bf32a5c0940131ff8bfc520512c4712438594e`, exact command/exit summaries, the runner-observed script/assertion totals, exact changed/new path enumeration, pre/post preservation values, static CI result, and actual deviations. Complete every required evidence row. Set the live CI row exactly to `Not required — push not authorized`; it is not pending and does not block readiness. Keep `human_decision=Pending`, because the pending prohibition applies only to required engineering evidence.

Expected: all required evidence and receipt values are concrete; known limitations remain truthful; metadata/display both use `screenshots=N/A`; only the human-decision row remains pending.

- [ ] **Step 5: Check automated acceptance only after the receipt is complete.**

Check each automated acceptance item in `task.md` only when its completed receipt/evidence reference proves the result. Do not change lifecycle status in this step.

Expected: every acceptance box is checked, every box has evidence, and statuses still read Engineering `In progress` and Human validation `Not ready`.

- [ ] **Step 6: Apply the evidence-gated status transition.**

Change Engineering metadata/display to `Implemented`, task Human validation metadata/display to `Ready for validation`, and validation handoff metadata/display to `Ready`. Keep `human_decision=Pending` and `decision_owner=human`; do not record a human final state.

Expected: metadata/display agree exactly and the checker accepts snapshot gates plus every transition available from BaseRef.

- [ ] **Step 7: Re-run canonical verification after receipt and status edits.**

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
git diff --check
git status --short --branch
```

Expected: verification exits `0` with 35 scripts, the same observed assertion total copied to the receipt, and zero failed stages; diff check is silent; branch is exact; changes remain uncommitted.

- [ ] **Step 8: Hand off only the human decisions and gated external actions.**

Ask the human to perform/review the seven trials in `validation.md` and choose `Accepted`, `Iterate`, or `Rejected`. Separately ask whether publishing, a live CI run, or future branch-protection work is authorized; do not infer authorization from validation readiness.

Expected: Human validation remains `Ready for validation` until the human records a decision. No publish, pull request, deployment, settings change, or branch-protection claim occurs as part of this plan.

---

The implementation is complete only when every task has independently verifiable evidence, the final canonical command is green, the receipt is Ready, and the human decision remains pending for the human.
