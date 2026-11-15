---
name: write-bead
description: Use ONLY when creating or materially updating a Bead description; defines capture/readiness gates and authoring requirements for epics and concrete implementation Beads.
---

# Write Bead

Write concise worker contracts, not conversation summaries. Follow `beads-hub` for record operations and context policy.

## Choose the record

- **Epic:** may begin as a shell for architect refinement. Capture known goals and boundaries; identify unresolved decisions without inventing answers. A shell is not an implementation-ready plan.
- **Bug, task, feature or chore:** create only when the problem, outcome, implementation scope and necessary decisions are sufficiently defined for a worker to implement without renewed investigation or scope discovery.
- **Undefined concrete work:** propose a **todo**, even if the user requests a bug or task. Explain what needs refinement; do not silently substitute record types. Ask a focused question first when it can resolve the gap immediately.
- When a todo becomes concrete work, create the implementation Bead from it using `beads-hub`. A todo is capture, not an implementation assignment.

Workers may choose local coding details. They must not have to rediscover the root cause, determine the intended outcome, choose the fundamental scope, or define or infer acceptance criteria.

## Required structures

Use the template for the record type below. Headings are exact and ordered; the text beside each heading defines its content. Keep entries brief and prefer bullets. Never invent facts or approval.

Reference shared epic context and approved architecture rather than copying them, while keeping each concrete child independently actionable. Carry established findings and decisions into the contract; resolve essential scope/design decisions before creating concrete work.

### Task / feature / chore

1. `## Problem and desired outcome` — current problem and intended result.
2. `## User stories` — write stories as “As a [user], I want [capability], so that [benefit],” not separate answers about who, what and why.
3. `## Scope and non-goals` — included changes and explicit exclusions.
4. `## Implementation approach` — bounded technical direction, affected areas and existing patterns to reuse. Leave local coding details to the worker; a simple change may need only one bullet.
5. `## Acceptance criteria` — explicit completion conditions using the AC rules below.
6. `## Decisions and constraints` — settled decisions, applicable restrictions, prerequisites and actual approval requirements/status.
7. `## Validation` — how the ACs will be established, using the validation rules below.

### Bug

1. `## Problem and desired outcome` — labelled bullets for **Expected behavior**, **Actual behavior** and **Root cause**. Add reproduction details or evidence references only where useful; a source-code-based root-cause explanation can be sufficient.
2. `## User stories` — write stories as “As a [user], I want [restored behavior], so that [benefit],” not separate answers about who, what and why.
3. `## Scope and non-goals` — included fixes and explicit exclusions.
4. `## Implementation approach` — targeted fix addressing the established cause, affected paths and relevant invalidation/compatibility requirements. Leave local coding details to the worker, not the fundamental fix direction.
5. `## Acceptance criteria` — explicit completion conditions for the fix and relevant preserved behavior, using the AC rules below.
6. `## Decisions and constraints` — settled decisions, applicable restrictions, prerequisites and actual approval requirements/status.
7. `## Validation` — regression checks and, where relevant, comparable before/after measurements, using the validation rules below.

Do not hand a completed investigation back to the worker as an open diagnostic task. If root cause or fix scope remains unresolved, use the todo gate.

### Epic

1. `## Problem` — current situation, who is affected and why it needs attention. Do not list future goals here.
2. `## High level goals` — bullet-list intended initiative outcomes, not implementation activities or a child-task list. Record each outcome once, here.
3. `## Scope and boundaries` — use labelled bullet groups: **In scope** (included capabilities/areas), **Out of scope** (explicit exclusions), and **Boundaries** (where responsibility starts/stops and interfaces with adjacent work). Do not repeat goals or technical/product restrictions.
4. `## High level approach` — intended strategy, not detailed implementation instructions. Shell epics may leave this for architect refinement.
5. `## Decisions and constraints` — settled decisions, technical/product restrictions and unresolved questions requiring refinement. Distinguish approved decisions from proposals.

Shell epics may explicitly mark unknown information for refinement. Epics do not require a `Validation` section and do not prescribe children's testing methodologies.

## Acceptance criteria

Use a bullet list with sequential identifiers: `- AC1: …`, `- AC2: …`. Never use a prose paragraph.

- Each AC states an explicit, independently assessable completion condition; workers must not define or infer it.
- Cover the intended outcome, required implementation constraints and relevant compatibility behavior.
- Be specific: name the behavior and conditions; avoid “works correctly,” “meaningful improvement” or similar claims without a pass condition.
- Include quantitative thresholds when needed to judge success; agree missing targets rather than inventing them.
- Do not use investigation activities, implementation steps or test commands as acceptance criteria. Put verification procedures in `Validation`.

## Validation

Acceptance criteria state **what must be true**; validation states **how it will be established**.

- For each concrete Bead, agree its testing methodology and validation plan with the user before implementation. Consult `testing-rules` when detailed methodology selection is needed, not routinely.
- Record work type, behavior at risk, selected methodology, checks, owner/environment, observable pass conditions and limitations. Identify any remaining validation agreement and the stage it blocks; do not confuse it with unresolved implementation scope.
- Use task-specific checks rather than repeating a full generic manifest. Documentation-only work needs accuracy/consistency review, not artificial tests or test-scope review. Preserve behavioral checks for executable workflows/templates.
- Agents run safe, reasonably available programmatic checks. Human QA is for judgment or access/environment limits, not complexity; record steps, expected results, owner and blocking stage. Replacing promised automation with human QA requires user agreement.
- The user may change or drop validation requirements without special waiver wording. Update the strategy and affected workers/reviewers; report actual checks and limitations. Unrelated authorization, safety and delivery gates remain unchanged.

## Rewriting existing beads and adding architecture notes

- Preserve existing content by default. Present proposed rewrites and obtain explicit user approval before changing it; architecture approval alone does not authorize rewriting.
- Preserve content outside the approved rewrite scope. Use the applicable heading structure for new Beads; do not migrate existing headings without rewrite approval.
- `## Architect notes` is an epic-only appendix added after explicit architecture approval, not a mandatory section.
- Description approval does not authorize child publication, status changes or implementation.
