---
name: write-bead
description: Use ONLY when creating or materially updating a Bead description; defines the required authoring structure for epics and concrete implementation Beads.
---

# Write Bead

Use this authoring contract only when creating or materially updating a Bead description.

Todos may be contextless or contextual under the supported policy; undefined work requiring refinement is outside this structure.

For an epic child, reference shared epic context and approved architecture rather than duplicating them, while including enough task-specific problem, scope, approach, criteria, constraints, and validation detail for implementation and review from the child record. An epic may describe shared outcome-level validation where useful, but does not prescribe a testing methodology for children; each concrete child selects and records its own methodology.

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

For each concrete Bead, agree its testing methodology and validation plan with the user before implementation. Consult the on-demand `testing-rules` skill when detailed methodology selection is needed; do not load it routinely. Record the task-specific work type, behavior at risk, selected methodology, checks and owner/environment, observable pass criteria, limitations, and blocking stages in this existing `Validation` section. An epic may record shared outcome-level validation if useful, but need not choose a methodology before architecture and does not impose one on children. Each concrete slice selects its own relevant methodology and behavior. A bug investigation supplies reproduction evidence and the controller ensures the concrete Bead records its selected methodology.

Apply the task-specific methodology selected using `testing-rules` where needed; do not require every epic or child to repeat the full manifest. Documentation-only changes need accuracy/consistency review, not artificial tests or test-scope review. Preserve relevant behavioral validation for executable workflows/templates. Agents run safe, reasonably available programmatic checks; planned human QA is for judgment or access/environment limits, not complexity. Record QA steps, expected result, owner, and blocking stage. Replacing promised automation with human QA requires user agreement.

The user may clearly change or drop a testing methodology or testing requirement at any time; no special waiver wording or ceremony is required. The controller updates the current strategy and communicates it to affected workers and reviewers. Report what was and was not checked, without claiming an unrun check passed. This does not change unrelated authorization, safety, or delivery gates.

`## Architect notes` is the exact epic-only appendix heading added after explicit architecture approval. It is not an eighth mandatory section for implementation Beads. Preserve existing description content verbatim by default, including the seven original sections and existing architect notes. Rewrite existing content only after presenting the proposed changes and obtaining explicit user approval for that rewrite; architecture approval alone is insufficient. Preserve content outside the approved rewrite scope and retain the seven required headings in order. Rewrite approval authorizes only the description revision, not child publication, status changes, or implementation.
