---
description: Orchestrate an ordinary implementation task with custom agents
agent: orchestrator
---

Orchestrate this request using the custom agent lifecycle: `$ARGUMENTS`.

Load the `herdr` skill. Require every implementation, design, or review delegate to load `ponytail` in its own session. Treat this as ordinary work unless the user chooses architecture for a potentially large initiative; do not force an architect or planner.

For ordinary work, create a dedicated Herdr tab rooted at the current working directory, start the custom `worker` as its primary OpenCode agent with `--agent worker`, wait for readiness, and submit a self-contained implementation contract. If the user selects architecture, first start the custom `architect` in its own interactive Herdr tab with `--agent architect`, wait for explicit user approval and its structured response, then invoke the `planner` subagent before starting the worker. Invoke one `reviewer` subagent session and reuse it for every review and rereview.
