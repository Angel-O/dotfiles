# OpenCode Agent Orchestration

Status: active. This specification is additive: it defines custom agents and leaves built-in agent definitions unchanged.

## Agents

| Agent | Mode | Model | Reasoning | Tools | Responsibility |
| --- | --- | --- | --- | --- | --- |
| `orchestrator` | primary | `openai/gpt-5.6-terra` | high | question, bash, read, glob, grep, task, webfetch, todowrite, skill, apply_patch, lsp, quota_status, handoff_session, read_session, history-search | Owns delivery, scope, delegate prompts, coordination, Git operations, and the sole reviewer lane. It does not code or explore. |
| `integration` | subagent | `openai/gpt-5.6-luna` | medium | bash, external_directory, read, glob, grep, skill (diagramming denied) | Runs supplied repository-wide integration commands without editing files or modifying Git state and reports exact results. |
| `investigator` | subagent | `openai/gpt-5.6-sol` | medium | bash, external_directory (ask), read, glob, grep, webfetch, skill | Performs bounded read-only discovery and bug verification with a fixed model and evidence-oriented report. |
| `reviewer` | subagent | `openai/gpt-5.6-sol` | medium | bash, external_directory, read, glob, grep, lsp, skill (diagramming denied) | Static-only checks of functional requirements, bugs, and regressions; reports findings, uses only read-only Git commands, and cannot edit or delegate. |
| `worker` | primary | `openai/gpt-5.6-luna` | high | bash, read, glob, grep, webfetch, todowrite, skill, apply_patch, lsp | Implements its supplied scope, adds tests and appropriate documentation, runs focused and affected-scope tests, and reports results. Repository-wide integration and full suites run separately. Git is denied in Bash. |
| `architect` | primary | `openai/gpt-5.6-sol` | high | question, read, glob, grep, webfetch, lsp, skill | Designs large cross-area work interactively, collects questions and approval through questionnaires in its own pane, then emits a structured approved response. It does not implement. |
| `planner` | subagent | `openai/gpt-5.6-terra` | medium | read, glob, grep, lsp, skill | Decomposes an approved architecture into implementation-ready slices and reports blockers or inconsistencies without changing architecture or implementing. |

Permissions deny all unspecified tools. Custom agent files are installed under the managed OpenCode configuration directory; this feature does not add or alter any built-in agent definition.

## Lifecycle

Routine deliverables go directly from the orchestrator to workers. For a potentially large initiative, the user decides whether architecture is required. If selected, the architect uses its `question` tool for every user question and final approval in its own pane. A blocked questionnaire is interactive work rather than a handoff. The mandatory sequence continues only after questionnaire approval and the architect's structured approved response, followed by planner decomposition and worker implementation.

The orchestrator requires every implementation, design, or review delegate to load Ponytail in its own session. Commands create Herdr lanes for the primary worker and architect agents; the task tool is reserved for the fixed-model investigator and the integration, planner, and reviewer subagents. The orchestrator owns exactly one reviewer session for the run and reuses it sequentially for every review and rereview. After worker handoff, it runs repository-wide integration validation, when warranted, in parallel with review. It skips expensive integration validation for documentation-only changes and narrow follow-up corrections unlikely to affect integration behavior. The reviewer reports static findings only; the orchestrator sends only findings accepted through the scope and complexity gate to the worker and returns the result to that same reviewer.

The Bead workflow retains private tracking and Herdr safety rules. It starts the custom worker directly with its fixed role, model, and reasoning effort; it does not pause for manual model selection. The separate `/orchestrate` manual command uses the same orchestrator lifecycle without forcing architect or planner for ordinary work.

Commit correlation and Bead closure are prohibited during implementation, commit, push, and PR creation. Both occur only after merge through the `beads-hub-closeout` workflow.

## Contract-First Parallelism

Epic children receive explicit contracts covering ownership, inputs, promised interfaces, dependencies, integration points, and acceptance criteria. Children that can implement against an agreed interface run in parallel, especially across repositories. A final commit, pin, release, integration, or delivery dependency belongs in the contract's finalization conditions rather than as a whole-child blocker. Implementation is sequenced only when a child cannot implement or validate without concrete output from another child. Children that mix parallelizable preparation with blocked finalization contract those phases explicitly or split them into separate children.

The orchestrator owns propagation of shared-interface changes. It does not notify or interrupt workers for speculative or proposed changes. Once review or implementation confirms a contract change, it updates the affected contracts and promptly notifies only the affected workers before they continue against a stale interface.

## Scope And Complexity Gate

This gate is the orchestrator's single most important responsibility during review and the enforcement point for Ponytail: prevent reviewer findings from driving implementation into complexity through unlikely edge cases, invented scope, or unjustified hardening. The reviewer owns implementation evidence; the orchestrator does not inspect the diff to adjudicate findings. It decides from the requested outcome, agreed contract, acceptance criteria, and broader orchestration context whether a correction is necessary. It resolves clearly required or clearly unnecessary findings without bothering the user. Suspicious or genuinely uncertain findings are escalated to the user, and uncertainty never defaults toward complexity. Only accepted findings reach workers, rewritten as the smallest required correction.

## Worker Lifecycle

The orchestrator owns worker startup and shutdown. A user stop request, cancellation, or withdrawal of authorization is acted on immediately through the Herdr agent surface. Stopping work leaves the worker pane, workspace, and worktree intact unless the user explicitly requests cleanup.
