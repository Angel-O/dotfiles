---
description: Write or update a concise project architecture decision record
agent: orchestrator
---

Write an architecture decision record for this project: `$ARGUMENTS`.

Use `docs/adr/` for ADR files and `docs/adr/index.md` for the index. Do not create or change any file until the user explicitly approves the complete draft. Do not stage or commit ADR changes.

## Choose the workflow

Infer the requested workflow from the arguments and conversation when clear. Otherwise, use the `question` tool to ask the user to choose one:

- **New decision:** record a decision the user already knows.
- **Historical discovery:** identify decisions from Git history that may deserve ADRs.
- **Update decision:** append a new version to an existing ADR.

Do not combine separate decisions in one ADR. If the input contains multiple independent decisions, ask the user which one to handle first.

## Read existing records

If `docs/adr/index.md` exists, read it before drafting. Open only ADRs relevant to avoiding a duplicate or updating an existing decision. For an update, identify the exact existing ADR with the user if it is not unambiguous.

## Gather evidence

For a new decision, gather only the missing information needed to state the decision, rationale, and discarded alternatives. Use the current date.

For historical discovery:

1. Ask no more than 10 focused questions in total. Use the answers to narrow the relevant areas, changes, incidents, or time periods; do not run an unguided repository-wide archaeology exercise.
2. Search the targeted Git history for evidence of consequential architectural or otherwise non-obvious decisions. Use relevant commits, diffs, blame, and available pull-request history.
3. Present concise candidate decisions with their supporting history and dates. Do not infer rationale or alternatives that the evidence and user do not support.
4. Ask the user which candidate, if any, to record. Use the date found in Git history for the selected decision.

For an update, preserve every existing version exactly and gather the complete current decision, rationale, and discarded alternatives for the new version. Use the next sequential version number and the date of the updated decision.

Stop without writing if the available evidence and user input cannot support a decision, rationale, and at least one genuinely considered discarded alternative. Never invent historical content merely to complete the format.

## Draft the ADR

For a new ADR, propose a readable filename in this form:

```text
docs/adr/YYYY-MM-DD-short-title.md
```

Use this exact document structure:

```markdown
# <Decision name>

## Version <number> — <YYYY-MM-DD>

### Decision

<Short paragraph explaining the decision.>

### Rationale

<Short paragraph explaining why the decision was taken.>

### Alternatives discarded

| Alternative | Why it was discarded |
| --- | --- |
| <Alternative> | <Concise reason> |
```

Version 1 starts a new ADR. An update appends a complete, self-contained version using the same structure after all existing versions; never rewrite or remove an earlier version.

The index uses this structure:

```markdown
# Architecture decision records

| Latest date | ADR | Description |
| --- | --- | --- |
| <YYYY-MM-DD> | [<Decision name>](<filename>) | <Short description> |
```

Keep one row per ADR. For an update, change that ADR's index row to the latest version date and current short description. Preserve unrelated rows.

Keep every paragraph and table entry concise. Record the decision and its reasons, not a narrative of the discussion.

## Obtain approval

Show the user, before any write:

- the exact target ADR path;
- the complete proposed ADR for a new record, or the exact version block to append for an update;
- the exact new or updated index row.

Use the `question` tool to request explicit approval of that complete draft. If the user requests changes, revise and present the complete draft again. Approval of a candidate, outline, or partial draft is not approval to write files.

## Write only the approved content

After explicit approval, write exactly the approved ADR content and index change through the normal orchestrator delivery workflow. Restrict the change to the selected file under `docs/adr/` and `docs/adr/index.md`. Do not alter unrelated ADRs or project files, and do not stage or commit the changes.

Report the changed paths and any validation performed. If nothing was approved, make no changes.