---
name: write-bead
description: Use ONLY when creating or materially updating a Bead description; defines the required authoring structure for epics and concrete implementation Beads.
---

# Write Bead

Use this authoring contract only when creating or materially updating a Bead description.

Todos are unscoped, undefined work requiring refinement and are outside this structure.

For an epic child, reference shared epic context and approved architecture rather than duplicating them, while including enough task-specific problem, scope, approach, criteria, constraints, and validation detail for implementation and review from the child record.

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

`## Architect notes` is the exact epic-only appendix heading added after explicit architecture approval. It is not an eighth mandatory section for implementation Beads. Preserve all seven original sections and their content exactly when appending it.
