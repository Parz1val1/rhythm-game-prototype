# AE-001 Validation Handoff

> **Historical validation draft.** This handoff belongs to the unexecuted AE-001
> proposal and is preserved for context. It does not describe the current
> repository workflow or an active validation request.

<!-- AE_VALIDATION_METADATA_V1
task_id=AE-001
handoff_status=Not ready
screenshots=N/A
human_decision=Pending
decision_owner=human
END_AE_VALIDATION_METADATA_V1 -->

- **Handoff status:** Not ready
- **Task type:** Nonvisual engineering-process change
- **Screenshots:** N/A
- **Human validation decision:** Pending

Allowed metadata values are exact and case-sensitive:

- `handoff_status`: `Not ready` or `Ready`
- `screenshots`: `N/A`, `Required`, or `Provided`
- `human_decision`: `Pending`, `Accepted`, `Iterate`, or `Rejected`

`decision_owner` must remain `human`. Only the human may replace `Pending` with `Accepted`, `Iterate`, or `Rejected`.

The task packet's exact status axes are Design `Draft|Approved|Superseded`, Engineering `Not started|In progress|Blocked|Implemented|Superseded`, and Human validation `Not ready|Ready for validation|Accepted|Iterate|Rejected|Not applicable`. AE-001 remains Design `Approved`, Engineering `Not started`, and Human validation `Not ready`. Validation `handoff_status=Ready` corresponds to task Human validation `Ready for validation`; it is not itself a human decision.

## How to access

1. Check out `feat/agentic-engineering-workflow` at or after its implementation revision.
2. Open [task.md](./task.md), then follow the repository routes in `README.md`, `STATUS.md`, `docs/setup.md`, and `docs/engineering/godot.md`.
3. Confirm Godot `4.6.3-stable` Mono is installed and set `GODOT_PATH` to its console executable when it is not discoverable automatically.
4. From the repository root, run the exact canonical command:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
```

This file describes the planned handoff. Do not infer successful implementation from the presence of this document. The validation receipt and every required evidence row must be completed first; engineering then checks every automated acceptance item in [task.md](./task.md); only after both steps may Engineering become Implemented and Human validation become Ready for validation. Evidence explicitly marked Not required does not block readiness.

## What will change

- Repository guidance will have one source of truth in `AGENTS.md`; `CLAUDE.md` will be a thin exact adapter.
- `README.md`, setup/Godot guidance, task templates, validation templates, and a concise `STATUS.md` will route contributors through the same lifecycle.
- The current untracked `STATUS.md` will be preserved verbatim in dated history before the router replaces it.
- A strict PowerShell contract verifier and strict Godot test runner will reject false-green output.
- `scripts/verify.ps1` will become the sole canonical verification entry point locally and in CI.
- Three stale tests will be updated to current repository interfaces without changing gameplay behavior.
- GitHub Actions will run the exact canonical command with Godot `4.6.3` under least-privilege, secret-free settings.
- `.claude/settings.local.json` will become ignored and untracked while remaining on disk; `.claude/worktrees/` will remain untouched and ignored.
- If separately authorized, personal Codex configuration will recommend Luna for implementation workers and Sol for planning, documentation, and review. That local configuration is not repository truth and requires a new session.

## Planned verification commands

At the end of Task 5, run the component and orchestration checks:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
pwsh -NoLogo -NoProfile -File ./scripts/check-repository-contract.ps1
```

Expected at Task 5: both component self-test commands and isolated orchestration cases exit `0`. The direct real-repository contract check exits nonzero with the single failure `REQUIRED_FILE_MISSING .github/workflows/verify.yml`, because Task 6 has not created the workflow. Do not run the canonical command against the real repository in Task 5. No other failure is allowed, and this bootstrap state is not a fully green repository.

After Task 6 creates and statically validates the workflow, run these from the repository root in this order:

```powershell
git status --short --branch
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
pwsh -NoLogo -NoProfile -File ./scripts/check-repository-contract.ps1
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
git diff --check
$tracked = @(git diff --name-only main --)
$untracked = @(git ls-files --others --exclude-standard)
@($tracked + $untracked) | Sort-Object -Unique
```

For a direct runner diagnostic when needed:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/run-godot-tests.ps1 -GodotPath $env:GODOT_PATH -ProjectPath (Get-Location).Path
```

CI must use this command byte-for-byte, with `GODOT_PATH` supplied by its pinned Godot setup step:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1
```

## Exact human trials

### Trial 1: Zero-context route

1. Start at `README.md` without using prior session context.
2. Locate prerequisites, the canonical command, the current task, Godot-specific conventions, and human-validation rules.
3. Follow each link once.

Expected: all routes resolve; no current rule requires reading `CLAUDE.md` or a historical superpowers document; no command disagrees with the canonical command.

### Trial 2: Canonical happy path

1. Set `GODOT_PATH` to the Godot `4.6.3-stable` Mono console executable.
2. Run `pwsh -NoLogo -NoProfile -File ./scripts/verify.ps1`.
3. Read the stage summary and final exit code.

Expected: import, every discovered `test/test_*.gd`, repository-contract checks, and applicable changed-line hygiene run exactly once; the summary includes discovered script and assertion counts; exit code is `0`; raw output contains no `FAIL`, `SCRIPT ERROR`, or `ERROR` diagnostic.

### Trial 3: False-green output rejection

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-run-godot-tests.ps1
```

Expected: isolated fixtures prove that the runner returns nonzero for each of these cases even when the fake Godot process exits `0`: a `FAIL` line, `SCRIPT ERROR`, `ERROR`, missing completion marker, and timeout. A clean fixture passes. No real project file is altered.

### Trial 4: Contract drift rejection

Run:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/test-check-repository-contract.ps1
```

Expected: isolated fixtures prove rejection of missing required files, malformed or duplicate metadata keys, unsupported status values/transitions, a non-thin or divergent `CLAUDE.md` adapter, broken task links, unchecked acceptance with a `Ready for validation`/`Implemented` claim, human decisions attributed to engineering, and forbidden placeholders in lifecycle-complete artifacts. A complete valid fixture passes.

The lifecycle fixtures must cover the complete exact task axes: Design `Draft|Approved|Superseded`; Engineering `Not started|In progress|Blocked|Implemented|Superseded`; Human validation `Not ready|Ready for validation|Accepted|Iterate|Rejected|Not applicable`. They must also prove that only a human may set `Accepted`, `Iterate`, or `Rejected`.

### Trial 5: Current-interface repairs

Inspect the three test diffs and the strict-runner output.

- `test/test_character_input_profile.gd` must build typed nested arrays with `append()` and continue testing the `chord_inputs: Array[Array]` interface.
- `test/test_defend_percussive.gd` must derive allowed aliases from `input_map.values()` and must not restore or reference `valid_inputs`.
- `test/test_string_golem.gd` must load `encounters/string_golem.tres` and assert the resource-backed encounter values (including the current `max_hp = 130`) rather than use `EncounterManager._generate_enemies()`.

Expected: the changes update stale expectations only; no gameplay file changes are used to make these tests pass.

### Trial 6: User-owned state preservation

Compare the implementation receipt with the final diff and working tree.

Expected: the receipt contains hashes captured immediately before mutation; `docs/status/history/2026-08-01-pre-agentic-workflow.md` has the recorded pre-mutation `STATUS.md` hash; `.claude/settings.local.json` still exists locally with its recorded pre-mutation hash but is absent from the index; `.claude/worktrees/` still exists unchanged and is ignored.

Then enumerate scope exactly:

```powershell
$tracked = @(git diff --name-only main --)
$untracked = @(git ls-files --others --exclude-standard)
$actual = @($tracked + $untracked) | Sort-Object -Unique
$actual
```

Expected: `$actual` equals the exact allowlist in [task.md](./task.md), with no missing or extra path. This union is authoritative for scope review because plain `git diff` omits untracked new files.

Content hygiene is evaluated separately: inspect only added lines from `git diff --unified=0 --no-color main --` for tracked modifications, excluding diff headers; inspect the full contents of untracked additions; skip deleted paths. Applicable content must have no trailing whitespace or line-start conflict markers. In particular, the index-only deletion of `.claude/settings.local.json` is in scope but is not content-scanned.

### Trial 7: CI contract

Inspect `.github/workflows/verify.yml` and, if a push is separately authorized, review the workflow run.

Expected: stable unique workflow/job names, `contents: read`, cancellation of superseded work on the same ref, no secrets, no write-capable event, exact Godot `4.6.3`, and the byte-for-byte canonical command. A live green run is required evidence only if publishing the branch is separately authorized.

## Decisions requested from the human

After `handoff_status=Ready` and task Human validation is `Ready for validation`, decide:

1. Is the zero-context route concise and clear enough to use as the repository's working contract?
2. Are verifier and runner failure messages actionable when a negative fixture fails?
3. Do the task lifecycle and human-only validation gate match the intended division of authority?
4. Should the branch be `Accepted`, sent back as `Iterate` with specific changes, or `Rejected`?

## Unauthorized follow-up note

GitHub branch-protection configuration or verification is not an acceptance decision for AE-001. It may be considered only as a separate future task with explicit authorization; this task neither claims nor changes it.

## Known limitations

- The current session cannot spawn `gpt-5.6-luna`; implementation is blocked until a new session exposes Luna or the human explicitly approves a fallback.
- Personal files under `~/.codex/` are machine-local, require scoped authorization, and take effect only in a new session. Their presence cannot prove that a specific spawned agent used the intended model; the new session must expose and report the route.
- GitHub branch protection is unconfirmed and the available `gh` credential is invalid. No branch-protection or other repository setting change is included.
- A live Actions result cannot exist until a push is explicitly authorized. Static workflow validation does not substitute for a live run when delivery reaches that gate.
- No formatter, linter, dependency scanner, new test framework, export preset, package manager, or gameplay validation is introduced by this task.
- Godot import exiting `0` is not, by itself, proof of a clean project; the canonical command also scans raw diagnostics and runs all strict tests.

## Evidence table

| Evidence | Required result | Status | Reference |
|---|---|---|---|
| Task 5 contract component self-tests | All positive and negative fixtures, including complete lifecycle axes, behave as specified | **Pending — implementation not started** | Pending command output |
| Strict-runner self-tests | Clean fixture passes; every false-green/timeout fixture fails | **Pending — implementation not started** | Pending command output |
| Task 5 orchestration self-tests | Stage order and injected import/suite/contract/hygiene failures behave as specified | **Pending — implementation not started** | Pending command output |
| Task 5 real-repository bootstrap | Nonzero for exactly missing `.github/workflows/verify.yml`; no other failure; no green claim | **Pending — implementation not started** | Pending bootstrap command output |
| Godot import | Exit `0` with no rejected diagnostics | **Pending — implementation not started** | Pending canonical-run output |
| Full headless suite | Every discovered script completes; no `FAIL`, `SCRIPT ERROR`, or `ERROR`; totals reported | **Pending — implementation not started** | Pending canonical-run output |
| Task 6 first full repository green | After workflow creation, contract checker and canonical command both exit `0` | **Pending — implementation not started** | Pending Task 6 command output |
| Repository contract | All required files, metadata, links, adapter rules, and lifecycle invariants pass after Task 6 | **Pending — implementation not started** | Pending contract-check output |
| Exact file scope | Tracked-change plus untracked-file union equals the task allowlist | **Pending — implementation not started** | Pending exact-enumeration output |
| Content hygiene | Tracked modifications' added lines and untracked additions' full contents pass; deletions are skipped | **Pending — implementation not started** | Pending canonical-run hygiene output |
| User-owned path preservation | History copy matches; local Claude settings/worktrees preserved | **Pending — implementation not started** | Pending hash/index receipt |
| CI static contract | Pinned engine, least privilege, cancellation, stable names, no secrets, exact command | **Pending — implementation not started** | Pending contract-check output |
| CI live run | Canonical job green | **Not required — push not authorized** | No workflow run is expected for this local handoff |
| Human decision | `Accepted`, `Iterate`, or `Rejected`, recorded by the human | **Pending — handoff is Not ready** | Pending human entry |

## Validation receipt

Required receipt fields must be completed before the automated acceptance boxes are checked. Values are honestly Pending while implementation has not started.

### Pre-mutation user-owned file receipt

Capture these values immediately before the first mutation of either file:

```powershell
Get-Date -Format o
Get-FileHash -Algorithm SHA256 -LiteralPath ./STATUS.md
Get-FileHash -Algorithm SHA256 -LiteralPath ./.claude/settings.local.json
git ls-files --error-unmatch -- .claude/settings.local.json
```

| Field | Value |
|---|---|
| Capture timestamp | **Pending — implementation not started** |
| Pre-mutation `STATUS.md` SHA-256 | **Pending — implementation not started** |
| Pre-mutation `.claude/settings.local.json` SHA-256 | **Pending — implementation not started** |
| Pre-mutation `.claude/settings.local.json` index state | **Pending — implementation not started** |

### Implementation and verification receipt

| Field | Value |
|---|---|
| Implementation revision or working-tree identifier | **Pending — implementation not started** |
| Canonical verification command and exit | **Pending — implementation not started** |
| Contract-verifier self-test result | **Pending — implementation not started** |
| Strict-runner self-test result | **Pending — implementation not started** |
| Task 5 orchestration self-test result | **Pending — implementation not started** |
| Task 5 expected missing-workflow bootstrap result | **Pending — implementation not started** |
| Task 6 first fully green contract/canonical result | **Pending — implementation not started** |
| Godot test-script and assertion totals | **Pending — implementation not started** |
| Exact sorted changed/new file enumeration | **Pending — implementation not started** |
| Post-change `STATUS.md` history-copy SHA-256 | **Pending — implementation not started** |
| Post-change local `.claude/settings.local.json` SHA-256 and index state | **Pending — implementation not started** |
| Deviations from the approved scope | **Pending — implementation not started** |

When every required field and required evidence row is complete, engineering checks the acceptance items in [task.md](./task.md). Only after all boxes are checked may metadata/display status change to `handoff_status=Ready`, Engineering `Implemented`, and Human validation `Ready for validation`. Required evidence may not remain Pending at that point; the live CI row is exempt because it is explicitly Not required while push authorization is absent. The human then records the final decision and notes.
