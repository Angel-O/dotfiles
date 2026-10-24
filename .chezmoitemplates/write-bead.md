---
name: write-bead
description: Use ONLY when creating or materially updating a Bead description; defines the required authoring structure for epics and concrete implementation Beads.
---

# Write Bead

Use this authoring contract only when creating or materially updating a Bead description.

Todos may be contextless or contextual under the supported policy; undefined work requiring refinement is outside this structure.

For an epic child, reference shared epic context and approved architecture rather than duplicating them, while including enough task-specific problem, scope, approach, criteria, constraints, and validation detail for implementation and review from the child record. Inherit the epic's validation strategy and identify the relevant portion instead of repeating it.

## Required Structure

Epics and concrete implementation Beads use these exact Markdown headings in this order:

1. `## Problem and desired outcome`
2. `## User stories`
3. `## Scope and non-goals`
4. `## Approved approach / design`
5. `## Acceptance criteria`
6. `## Decisions and constraints`
7. `## Validation`

Preserve the headings and order. Never invent missing information. Pending information may be explicit only when it is not required for the next stage; required missing information blocks that stage. Distinguish proposed decisions from approved decisions.

`User stories` is mandatory. Identify who benefits, what they need, and why. User stories do not replace acceptance criteria.

`Acceptance criteria` states what must be true. `Validation` states how those truths will be established. Keep both bounded to the approved scope.

## Validation Contract

For each epic or standalone concrete Bead, agree a concise validation plan with the user before implementation: behavior/risks, checks and owner/environment, observable pass criteria, and limits/blocking stages. Children inherit the relevant epic strategy; material deviations require renewed agreement.

Validate the requested behavior with meaningful, maintainable tests. Do not add tests that merely pin implementation details or policy wording. Documentation-only changes require no tests; review accuracy and consistency. Preserve relevant behavioral validation for executable workflows/templates. Agents run safe, reasonably available programmatic checks; planned human QA is for judgment or access/environment limits, not complexity. Record QA steps, expected result, owner, and blocking stage. Replacing promised automation with human QA requires user agreement.

Required validation blocks approval/considered done until passed; not run, blocked, or inconclusive is not passed. Only the user may waive a required gate, recording missing evidence, risk, and affected gate. The canonical Bead records the agreed strategy and deviations.

`## Architect notes` is the exact epic-only appendix heading added after explicit architecture approval. It is not an eighth mandatory section for implementation Beads. Preserve all seven original sections and their content exactly when appending it.
