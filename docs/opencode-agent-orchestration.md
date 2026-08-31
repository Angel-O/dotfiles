# OpenCode Agent Orchestration

Status: active. This specification is additive: it defines custom agents and leaves built-in agent definitions unchanged.

## Agents

| Agent | Mode | Model | Reasoning | Tools | Responsibility |
| --- | --- | --- | --- | --- | --- |
| `orchestrator` | primary | `openai/gpt-5.6-terra` | medium | question, bash, read, glob, grep, task, webfetch, todowrite, skill, apply_patch, lsp, quota_status, handoff_session, read_session, history-search | Owns delivery, scope, delegate prompts, coordination, Git operations, and the sole reviewer lane. It does not code or explore. |
| `reviewer` | subagent | `openai/gpt-5.6-sol` | medium | read, glob, grep, lsp, skill | Static-only checks of functional requirements, bugs, and regressions; reports findings and cannot run commands, edit, or delegate. |
| `worker` | primary | `openai/gpt-5.6-luna` | high | bash, read, glob, grep, webfetch, todowrite, skill, apply_patch, lsp | Implements its supplied scope, adds tests and appropriate documentation, runs localized tests and one final full suite, and reports results. Git is denied in Bash. |
| `architect` | primary | `openai/gpt-5.6-sol` | high | read, glob, grep, webfetch, lsp, skill | Designs large cross-area work interactively until explicit user approval, then emits a structured approved response. It does not implement. |
| `planner` | subagent | `openai/gpt-5.6-terra` | medium | read, glob, grep, lsp, skill | Decomposes an approved architecture into implementation-ready slices and reports blockers or inconsistencies without changing architecture or implementing. |

Permissions deny all unspecified tools. Custom agent files are installed under the managed OpenCode configuration directory; this feature does not add or alter any built-in agent definition.

## Lifecycle

Routine deliverables go directly from the orchestrator to workers. For a potentially large initiative, the user decides whether architecture is required. If selected, the mandatory sequence is interactive architect design, explicit user approval, the architect's structured approved response, planner decomposition, and worker implementation.

The orchestrator loads Ponytail before any implementation, design, or review delegate. It owns reviewer invocation and exactly one reviewer lane. The reviewer reports static findings only; the orchestrator sends findings to the worker for correction and returns the result to that same reviewer. No other reviewer lane is created.

The Bead workflow retains private tracking and Herdr safety rules. It starts the custom worker directly with its fixed role, model, and reasoning effort; it does not pause for manual model selection. The separate `/orchestrate` manual command uses the same orchestrator lifecycle without forcing architect or planner for ordinary work.

Commit correlation and Bead closure are prohibited during implementation, commit, push, and PR creation. Both occur only after merge through the `beads-hub-closeout` workflow.
