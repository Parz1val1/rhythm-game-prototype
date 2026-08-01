# Enemy Design Ideas Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a lightweight, expandable catalog for enemy concepts and seed it with the Anklyosaurus idea.

**Architecture:** Add one standalone Markdown document under `docs/` so creative concepts remain separate from status tracking and implementation resources. Keep the first entry concise, recording only its world, visual concept, signature feature, and design seed.

**Tech Stack:** Markdown documentation; PowerShell/Git for verification.

## Global Constraints

- Do not modify gameplay code, encounter resources, tests, or project configuration.
- Preserve the requested spelling `Anklyosaurus`.
- Keep the catalog lightweight and easy to extend with future entries.

---

### Task 1: Add the enemy idea catalog

**Files:**
- Create: `docs/enemy-design-ideas.md`

**Interfaces:**
- Consumes: The approved Anklyosaurus concept from the user.
- Produces: A discoverable Markdown catalog with one initial enemy entry.

- [x] **Step 1: Create the catalog with the approved entry**

```markdown
# Enemy Design Ideas

## Anklyosaurus

- **World:** Drum Planet
- **Visual concept:** An ankylosaurus with a xylophone built into its back.
- **Signature feature:** Its tail is made of, or ends in, mallets that strike the xylophone.
- **Design seed:** A musical dinosaur enemy whose body and tail are also its percussion instrument.
```

- [x] **Step 2: Verify the documentation-only diff**

Run: `git diff --check` and inspect `git diff -- docs/enemy-design-ideas.md`

Expected: no whitespace errors, exactly one new catalog file, and no gameplay or test files changed.
