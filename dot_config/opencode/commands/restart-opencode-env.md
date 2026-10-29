---
description: Restart the OpenCode service independently and verify its status
---

Run `~/.local/bin/opencode-env-restart start` to launch the detached restart. This confirms launch only.

After interruption, check `~/.local/bin/opencode-env-restart status <run-id>` (or omit the ID for the latest run) before retrying. Report activation only when the receipt is `succeeded` with exit code 0 and `~/.local/bin/opencode-env api get /api/agent` shows the requested selector for the intended agent; otherwise report pending or failure.
