---
name: scope-complexity-rules
description: Assess reviewer corrections against task goals and avoid unnecessary scope or complexity.
---

# Scope and complexity rules

Assess findings against the authoritative task and, when applicable, its
relevant epic. For non-Bead work, use the agreed request and worker brief. The
task's criteria and latest user direction govern; an epic supplies shared
context but does not silently replace the task's scope.

| Rule | Assessment |
| --- | --- |
| SCG-01 — Preserve real requirements | Does the correction serve a requested outcome or criterion, agreed design, genuine compatibility obligation, or demonstrated failure? Existing implementation details and earlier review decisions do not alone establish a requirement; preserve actual contracts without inventing new guarantees. |
| SCG-02 — Require the simplest sufficient correction | Is the correction sufficient and no more complex than needed for the required outcome? Prefer simplicity, not merely the smallest diff. Do not reject a necessary correction just because it is larger or changes implementation details. |
| SCG-03 — Assess cumulative drift | Do the proposed and prior review-cycle corrections collectively remain aligned with the goal, or are locally plausible changes accumulating into unnecessary scope or complexity? Reassess prior decisions against the goals; a prior decision alone does not make more work required. |

## Illustrative examples

- **SCG-01 pass:** A required operation fails in normal use; a correction that
  restores the specified behavior supports the stated outcome. A genuine
  compatibility contract is likewise part of the required outcome.
- **SCG-01 fail / SCG-02 fail:** Add support for an unrequested hypothetical
  edge case or a broad guarantee not needed by any criterion.
- **SCG-03 fail:** Several successive findings each add separate defensive
  layers or abstractions, although together they substantially exceed the
  agreed outcome; narrow the correction set to what the goal needs.

For each supplied finding return `PASS` only when its rationale supports a
necessary correction. Identify the required outcome and bounded correction
scope; do not prescribe an exact implementation without code access. Return
`REVISE` when it is unnecessary or overbroad, with the goal mismatch and
narrower bounded scope if useful. Return `UNRESOLVED` when goal context,
evidence, or decision authority is missing or genuinely ambiguous. Do not
guess in favor of added complexity.

Judge only supplied rationale and goal alignment. The main reviewer owns
implementation evidence; do not inspect repository code or claim to verify it.
This gate does not approve implementation or resolve product decisions.
