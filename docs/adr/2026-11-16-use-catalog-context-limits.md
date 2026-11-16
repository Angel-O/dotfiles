# Use catalog context limits in the portable OpenCode environment

## Version 1 — 2026-11-16

### Decision

Disable OpenCode's built-in OpenAI context-cap plugin in the portable
environment. Use the model catalog's context limits for ChatGPT-authenticated
models while retaining automatic compaction.

### Rationale

Our workers perform bounded tasks and benefit from access to the larger
catalog limits before compaction. OpenCode's lower default caps aim to
conserve ChatGPT subscription usage; removing them may consume the allowance
faster and does not guarantee that the backend accepts every catalog limit.

### Alternatives discarded

| Alternative | Why it was discarded |
| --- | --- |
| Keep OpenCode's default caps | Workers would continue to compact substantially earlier than the catalog limits require. |
| Override Luna's limits explicitly | It would leave other models capped and require maintaining model-specific values. |
