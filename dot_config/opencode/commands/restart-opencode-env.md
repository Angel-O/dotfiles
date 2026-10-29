---
description: Restart the OpenCode service independently and verify its status
---

Run `~/.local/bin/opencode-env-restart start` to launch the existing `~/.local/bin/opencode-env service restart` in a detached process. The helper returns a run ID; that confirms only launch, not completion.

Check the result with `~/.local/bin/opencode-env-restart status <run-id>`. If the shell request is cancelled or the result is `running`/`unverified`, do not retry; report that activation is pending or unverified. If this turn is interrupted, check that receipt when the conversation resumes; if the run ID is unavailable, `~/.local/bin/opencode-env-restart status` reports the latest run. A `succeeded` receipt with exit code 0 means only that the wrapper returned successfully. Then query `~/.local/bin/opencode-env api get /api/agent` and compare the intended agent's effective `model` with the requested selector. Report activation only when that live configuration matches; a saved file, launcher check, healthy server, or completed restart alone is insufficient. Existing session selections are not changed, and an interrupted agent turn is not assumed to resume.
