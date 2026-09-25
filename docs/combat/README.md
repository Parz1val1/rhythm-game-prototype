# Combat Design

[Combat System v1](COMBAT_SPEC_V1.md) is the approved design target for combat
prototyping. It defines intended player-facing behavior and the questions the
prototype should answer; it does not claim that the current code implements those
rules.

## Authority

Use these sources according to the question being answered:

1. **Target combat behavior** → [Combat System v1](COMBAT_SPEC_V1.md)
2. **Canonical terminology** → [Domain Context](../../CONTEXT.md)
3. **Current implementation** → [Architecture](../ARCHITECTURE.md), code, and tests
4. **Accepted technical choices** → [Technical Decisions](../DECISIONS.md)
5. **Migration status** → [V1 reconciliation](reconciliation-v1.md)
6. **Issue #16 Skill/Character Performance scope and playtest evidence** →
   [Skill and Character Performance prototype](skill-performance-prototype.md)
7. **Issue #17 Inspiration ownership, provisional rates, and Skill costs** →
   [Inspiration prototype](inspiration-prototype.md)
8. **Issue #18 party order, active-character handoffs, and rhythm-language evidence** →
   [Party Character Performance prototype](party-performance-prototype.md)

When current behavior conflicts with Combat System v1, preserve the distinction:
the specification defines the target, while architecture, code, and legacy tests
remain evidence of what exists today. Reopen an accepted technical decision when
the selected migration slice actually requires a different choice.

## Working With the Specification

- Load only the specification sections relevant to the task.
- Keep unresolved items unresolved unless the work explicitly includes deciding
  them.
- Record newly settled terms in `CONTEXT.md` and product behavior in the
  specification rather than duplicating either here.
- Update the reconciliation ledger when a migration changes the current/target
  gap.
- Build migration slices around the prototype questions in section 18 rather than
  mechanically recreating every named system at once.
