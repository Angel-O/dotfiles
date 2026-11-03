---
name: decomposition-rules
description: Canonical DEC-01 through DEC-05 rules for reviewing architecture-backed executable task proposals.
---

# Decomposition rules

For architecture-backed work, the architect authors concrete executable slices and self-assesses each rule below. The independent reviewer evaluates the actual proposal against approved scope and this manifest; author labels are not evidence. Record `PASS`, `FAIL`, or `N/A` per rule with evidence. `N/A` requires a reason. Missing or inconclusive evidence is not a pass. A failed rule or missing required evidence blocks publication and launch until the evidenced defect is corrected. Unresolved product or architecture decisions return to the user; do not turn them into accepted planning gaps.

| Rule | Applicability | Evidence required | Failure condition |
| --- | --- | --- | --- |
| DEC-01 Preserve approved scope | Every proposal | Trace each approved capability and acceptance criterion to proposed tasks; show exclusions and no unauthorized additions. | An approved outcome is omitted, or scope is invented/expanded. |
| DEC-02 Independently acceptable outcomes | Every proposed executable task | State the observable result and acceptance evidence; explain why proposed tasks are not multiple independently acceptable outcomes bundled together. | A task bundles outcomes that can be accepted independently, including when they share components, owners, or tests. |
| DEC-03 Finite task boundary | Every proposed executable task | State boundary, exclusions, prerequisites, and evidence that a worker can meet acceptance without substantial replanning. | Task is an umbrella/component workstream, lacks a credible completion boundary, or requires substantial worker replanning. |
| DEC-04 Bounded enabling work | When enabling work is proposed | Identify the specific downstream outcome enabled and a verifiable acceptance result for the enabling capability. | Enabling work is broad, speculative, or has no concrete downstream need or verifiable result. |
| DEC-05 Genuine prerequisites and compatible boundaries | Every proposed dependency and shared boundary | Identify the concrete prerequisite output and explain why the dependent task cannot implement or validate without it; show compatible ownership and interfaces. | An ordering preference is represented as a blocker, or ownership/interfaces conflict or leave a required handoff undefined. |

## Illustrative examples

These examples are not exhaustive and assume the stated scope is approved. A passing example illustrates only its named rule; it does not approve the whole proposal. Target the smallest coherent acceptance boundary, not the smallest code change. Do not prescribe task counts, time, or lines of code, or fragment work mechanically.

### DEC-01 — Preserve approved scope

- **Fail:** Approved account-record download and deletion are in scope, but the proposal does not assign deletion to a task. An incomplete trace means evidence is missing, not proof the capability was actually omitted; resolve the trace. If deletion behavior is undecided, return it upstream.
- **Pass:** Trace both download and deletion to proposed tasks and their acceptance criteria, with exclusions and no added capability. **Why:** the trace accounts for every approved outcome without inventing scope.

### DEC-02 — Independently acceptable outcomes

- **Fail:** Bundle independently acceptable comments and export outcomes because they share an editor and tests.
- **Pass:** Give comments and export separate acceptance boundaries and evidence. **Why:** shared implementation or tests do not make outcomes inseparable. Form, handler, and confirmation may remain together when they produce one coherent outcome; this rule does not require layer or component splits.

### DEC-03 — Finite task boundary

- **Fail:** “Build the inventory service” leaves the worker to choose scope and completion.
- **Pass:** Define a receive-stock operation with prerequisites, exclusions, and observable evidence of the resulting stock change. **Why:** the outcome and completion boundary are verifiable. Its implementation may span storage, logic, and interface; a narrower title alone is not a finite boundary.

### DEC-04 — Bounded enabling work

- **Fail:** Add a general data-quality framework on speculation, without a concrete downstream need.
- **Pass:** For an approved import that must reject duplicates under an approved matching rule, specify verifiable duplicate detection needed by that import. **Why:** this enables a defined outcome with evidence. Non-user-facing enabling work is legitimate when bounded this way; undecided matching behavior returns upstream.

### DEC-05 — Genuine prerequisites and compatible boundaries

- **Fail:** Block deployment on an unrelated dashboard because that is preferred ordering.
- **Pass:** Identify the required signed build artifact and verification information, a compatible producer/consumer interface, and why deployment acceptance needs that output. **Why:** this is a concrete dependency, not an ordering preference. Implementation may proceed against the agreed interface; validation that requires the delivered artifact waits for the real output.

The smallest coherent acceptance boundary is the target, not the smallest code change. A shared component, owner, or test does not justify combining independently acceptable outcomes. Keep workers' ordinary implementation choices open; this manifest does not prescribe symbols or files. Readiness, priority, authorization, and whole-initiative completion remain distinct. Routine standalone tasks do not require architecture or this decomposition process.
