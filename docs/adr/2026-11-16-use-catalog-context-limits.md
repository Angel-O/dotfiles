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

## Version 2 — 2026-11-25

### Decision

Keep OpenCode's built-in OpenAI context-cap plugin enabled in the portable
environment. The user intentionally reverses Version 1: retain OpenCode's
built-in caps rather than disabling them in favor of catalog context limits.

### Rationale

The user authorized restoring the built-in caps after investigating the
configuration change. This policy does not claim measured quota savings or
guarantee effective runtime behavior.

### Alternatives discarded

| Alternative | Why it was discarded |
| --- | --- |
| Continue disabling OpenCode's built-in caps | The user intentionally chose to restore the built-in policy after investigation. |
