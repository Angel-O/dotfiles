---
description: Orchestrate an ordinary implementation task with custom agents
agent: orchestrator
---

Orchestrate this request using the custom agent lifecycle: `$ARGUMENTS`.

Load the `herdr` skill. Require every implementation, design, or review delegate to load `ponytail` in its own session. Treat this as ordinary work unless the user chooses architecture for a potentially large initiative; do not force an architect or planner.

For ordinary work, create a dedicated Herdr tab rooted at the current working directory and read its `root_pane.pane_id` from the JSON result. Start the worker exactly with `herdr agent start <worker-name> --kind opencode --pane <root-pane-id> -- --agent worker`, then submit a self-contained contract with `herdr agent prompt <worker-name> "<contract>" --wait`. Do not run `opencode` directly or pass model, variant, or reasoning flags; each agent definition owns those settings.

If the user selects architecture, first create a dedicated Herdr tab, read its root pane ID, and start the architect exactly with `herdr agent start <architect-name> --kind opencode --pane <root-pane-id> -- --agent architect`. Submit the design prompt with `herdr agent prompt <architect-name> "<design-prompt>" --wait`. The architect must ask every user question and request final approval through its own `question` tool. A blocked questionnaire is interactive work in the architect pane, not a completed handoff; wait for the user to answer there and for the architect's structured approved response before invoking the `planner` subagent or starting the worker. Invoke one `reviewer` subagent session and reuse it for every review and rereview.

After worker handoff, run the reviewer and, when warranted, the `integration` subagent concurrently against the same worktree. The integration contract contains the repository-wide test commands; do not make the implementation worker run them first. Skip expensive integration validation for documentation-only changes and narrow follow-up corrections unlikely to affect integration behavior.

## Scope And Complexity Gate

Treat this gate as the orchestrator's single most important responsibility during review and the enforcement point for `ponytail`: prevent reviewer findings from driving implementation into complexity through unlikely edge cases, invented scope, or unjustified hardening. Reviewer findings are advisory, and the reviewer owns implementation evidence; do not inspect the diff to adjudicate them. Decide from the requested outcome, worker contract, acceptance criteria, and broader orchestration context whether each correction is necessary. Resolve clearly required or clearly unnecessary findings yourself without bothering the user. If a finding is suspicious or necessity, scope, or complexity remains uncertain, ask the user and never guess in favor of complexity. Send only accepted findings to the worker as the smallest required correction.

## Worker Lifecycle

Own worker startup and shutdown. When the user requests a stop, work is cancelled, or continued work is no longer authorized, immediately instruct or interrupt the affected worker through the Herdr agent surface while leaving its pane, workspace, and worktree intact unless cleanup is explicitly requested.
