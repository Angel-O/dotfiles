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

For each epic or standalone concrete Bead, agree a concise validation plan with the user before implementation: relevant behavior and risks, checks and execution owner/environment, observable pass criteria, and known limits or blocking stages. Children inherit the epic strategy and identify their relevant portion; add only task-specific checks or material deviations. Routine test selection does not need renewed approval; material deviations do.

Require evidence that exercises changed behavior and acceptance criteria; existing coverage may suffice. Documentation-only changes require no tests: review accuracy and consistency without adding or running tests merely because prose changed. Rendering, installation, and content-preservation checks are justified when executable templates or installation logic change, not to test the documentation they contain. Validate actual executable workflow/template changes with relevant behavior checks. Avoid blanket layers, coverage quotas, and new frameworks. Agents perform reliable, reasonably available, safe programmatic verification. Human QA is for judgment, unavailable access, physical interaction, or environments agents cannot safely exercise—not complexity alone. Agree QA steps, expected results, owner, and blocking stage. Replacing promised automated verification with human QA is a material deviation requiring user agreement. For bug fixes, demonstrate regression failure on buggy behavior and success after the fix where practical; consider whether plausible incorrect code would fail and whether important behavior was mocked away. Distinguish one-off verification from durable regression protection; changed nontrivial behavior generally needs retained coverage. Avoid arbitrary sleeps and assertions on noncontractual internal ordering. Distinguish contractual strings from incidental prose assertions. Remove or weaken tests only for obsolete behavior, demonstrated redundancy, or equivalent/better coverage, and explain why.

Required validation, including agreed human QA, blocks approval/considered done until passed. Not run, blocked, or inconclusive is not passed. Only the user may waive a required gate; record missing evidence, risk, and affected gate without calling it passed. Specify validation owner, expected outcome, and blocking stage for human QA. The canonical Bead records the agreed strategy and deviations.

`## Architect notes` is the exact epic-only appendix heading added after explicit architecture approval. It is not an eighth mandatory section for implementation Beads. Preserve all seven original sections and their content exactly when appending it.
