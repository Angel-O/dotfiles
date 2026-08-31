---
description: Orchestrate an ordinary implementation task with custom agents
agent: orchestrator
---

Orchestrate this request using the custom agent lifecycle: `$ARGUMENTS`.

Load the `herdr` skill. Require every implementation, design, or review delegate to load `ponytail` in its own session. Treat this as ordinary work unless the user chooses architecture for a potentially large initiative; do not force an architect or planner.

For ordinary work, create a dedicated Herdr tab rooted at the current working directory and read its `root_pane.pane_id` from the JSON result. Start the worker exactly with `herdr agent start <worker-name> --kind opencode --pane <root-pane-id> -- --agent worker`, then submit a self-contained contract with `herdr agent prompt <worker-name> "<contract>" --wait`. Do not run `opencode` directly or pass model, variant, or reasoning flags; each agent definition owns those settings.

If the user selects architecture, first create a dedicated Herdr tab, read its root pane ID, and start the architect exactly with `herdr agent start <architect-name> --kind opencode --pane <root-pane-id> -- --agent architect`. Submit the design prompt with `herdr agent prompt <architect-name> "<design-prompt>" --wait`, wait for explicit user approval and the architect's structured response, then invoke the `planner` subagent before starting the worker. Invoke one `reviewer` subagent session and reuse it for every review and rereview.
