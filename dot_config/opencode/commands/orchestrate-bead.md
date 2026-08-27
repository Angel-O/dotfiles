---
description: Start a Herdr worker for a private Bead and pause for model selection
---

Act as the orchestrator for private Bead `$1`.

Load the `beads-hub` and `herdr` skills and follow their contracts. If `$1` is missing, ask for the Bead ID and do nothing else. Otherwise, verify the Bead and its repository context, create a dedicated Git worktree for its implementation, and start one Herdr worker agent in that worktree.

The worker owns implementation, formatting, tests, builds, static tooling, and all other verification. Explicitly instruct the worker not to create or run a reviewer lane.

You own review. When implementation is ready, launch a reviewer through an OpenCode subagent, not through the worker or a second Herdr lane. The reviewer must perform static analysis only and must not run tests, builds, formatters, linters, or other commands intended to execute the implementation. It should determine whether the functional requirements are met and identify concrete bugs or regressions. Keep the review pragmatic: follow KISS and YAGNI, avoid speculative complexity, and do not demand handling unrealistic edge cases.

For now, stop immediately after the Herdr worker has started successfully in the dedicated worktree. Do not send the worker its task prompt yet, do not start implementation, and do not launch the reviewer. Report the worker name, pane, and worktree, then wait so the user can select the worker's model and reasoning effort.
