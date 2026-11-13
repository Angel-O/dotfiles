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

For each epic or standalone concrete Bead, agree a concise testing strategy and validation plan with the user before work starts. Record the strategy in this existing `Validation` section, including the work type, behavior at risk, test-first/baseline/coverage approach, checks and owner/environment, observable pass criteria, limitations, and blocking stages. An epic records its initial strategy before architecture; each concrete slice inherits the relevant strategy and identifies its task-specific behavior. A bug investigation supplies reproduction evidence and the controller ensures the concrete Bead records the strategy. Material deviations require renewed agreement.

Apply TEST-01 through TEST-06 in the installed `Meaningful validation` rules. Documentation-only changes need accuracy/consistency review, not artificial tests or test-scope review. Preserve relevant behavioral validation for executable workflows/templates. Agents run safe, reasonably available programmatic checks; planned human QA is for judgment or access/environment limits, not complexity. Record QA steps, expected result, owner, and blocking stage. Replacing promised automation with human QA requires user agreement.

Required validation blocks approval/considered done until passed; not run, blocked, or inconclusive is not passed. Only the user may waive a required gate, recording missing evidence, risk, and affected gate. The canonical Bead records the agreed strategy and deviations.

`## Architect notes` is the exact epic-only appendix heading added after explicit architecture approval. It is not an eighth mandatory section for implementation Beads. Preserve existing description content verbatim by default, including the seven original sections and existing architect notes. Rewrite existing content only after presenting the proposed changes and obtaining explicit user approval for that rewrite; architecture approval alone is insufficient. Preserve content outside the approved rewrite scope and retain the seven required headings in order. Rewrite approval authorizes only the description revision, not child publication, status changes, or implementation.
