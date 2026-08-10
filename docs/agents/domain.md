# Agent Domain Sources

This is a single-context repository. Load its domain knowledge progressively:

- Domain terms used by the task → [`CONTEXT.md`](../../CONTEXT.md)
- Player-facing behavior or scope → [`docs/PRODUCT.md`](../PRODUCT.md)
- System boundaries, data flow, or seams → [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md)
- Established technical choices touched by the task → [`docs/DECISIONS.md`](../DECISIONS.md)
- Priorities → [`docs/ROADMAP.md`](../ROADMAP.md)
- Active medium/large effort → [`plans/current.md`](../../plans/current.md)

This repository keeps lightweight ADR entries together in `docs/DECISIONS.md`
rather than individual files under `docs/adr/`. Use glossary terms as defined and
surface an ADR conflict explicitly instead of silently choosing new terminology or
architecture.

Start with `AGENTS.md`, select only the sources triggered by the task, then inspect
the relevant implementation. Historical records under `docs/superpowers/` and
`docs/status/history/` are evidence, not current instructions.
