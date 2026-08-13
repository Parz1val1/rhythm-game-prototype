# Song of the Stars — Rhythm Combat Prototype

This repository is a Godot 4.6 prototype for **Song of the Stars**, a rhythm RPG
where musical performance drives turn-based combat. It currently focuses on the
combat loop: choose an action, perform character-specific rhythm inputs, read and
block enemy patterns, build combos and a limit gauge, then replay encounters with
different characters.

The prototype has two playable input styles:

- **Beatrice Styx:** two-hand percussion using `F` / `J` or the left / right
  controller triggers; both inputs together form her chord.
- **Luthier Frett:** four-direction melodic input using the arrow keys, D-pad, or
  positionally matching face buttons (top/up, bottom/down, left/left, right/right).

The current entry point is `test_scene.tscn`. Product scope and future work are
tracked in [PRODUCT.md](docs/PRODUCT.md) and [ROADMAP.md](docs/ROADMAP.md).

## Quick Start

Verified local setup:

- Windows with PowerShell is the tested development environment; supported release
  platforms have not been decided.
- Godot `4.6.3-stable` Mono is required for the verified workflow.

No package-manager dependencies need to be installed. In PowerShell:

```powershell
$env:GODOT_PATH = "C:\Users\Tim\External Applications\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
& $env:GODOT_PATH --editor --path .
```

Run the configured main scene directly:

```powershell
& $env:GODOT_PATH --path .
```

The prototype also maps `Space` to limit-break activation. In the test scene only,
`L` fills the current limit gauge for debugging. Character and encounter selectors
appear on the replay overlay.

In the standalone Combat V1 playtest harness, press `Enter`, `Space`, or controller
Start to submit a Response or leave a Tactical Vamp. Use `1`–`3` or the controller
shoulder buttons to compare the temporary backing loops.

## Verification

See [the development guide](docs/DEVELOPMENT.md#testing) for the canonical
single-test and full-suite commands. The full-suite command treats engine
diagnostics and missing completion markers as failures; visible `PASS` counts alone
are not sufficient.

No export/build preset, formatter, linter, separate type checker, or CI workflow is
currently configured.

## Documentation

- [AGENTS.md](AGENTS.md) — progressive context router for coding agents
- [Domain context](CONTEXT.md) — canonical combat and rhythm vocabulary
- [Product](docs/PRODUCT.md) — what is being built and current scope
- [Architecture](docs/ARCHITECTURE.md) — current modules, data flow, and boundaries
- [Decisions](docs/DECISIONS.md) — accepted technical choices and constraints
- [Development](docs/DEVELOPMENT.md) — Godot setup, logging, testing, and local tooling
- [Roadmap](docs/ROADMAP.md) — current priorities and known future work
- [Current plan](plans/current.md) — active implementation-plan status

Historical design and implementation records remain under `docs/superpowers/`.
They explain how the prototype evolved but are not the current source of truth.
