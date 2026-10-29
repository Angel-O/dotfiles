---
name: update-agent-models
description: Update custom and built-in OpenCode agent model selectors in machine-local env.local and validate the launcher environment.
---

# Update Agent Model Preferences

For routine agent model changes, edit `~/.config/opencode/env.local`. It is sourced by the managed launcher before its fallbacks. Do not edit portable fallback definitions or generated launcher files, and do not change unrelated entries in `env.local`.

Before changing a selector, resolve the exact `provider/model` ID from the locally available OpenCode catalogue with `opencode models` (filter/search its output as needed). Do not guess an ID or variant; use a variant only if supported by that model.

Custom-agent selectors (only set the agents you intend to change):

- `OPENCODE_AGENT_MODEL_ORCHESTRATOR`
- `OPENCODE_AGENT_MODEL_INTEGRATION`
- `OPENCODE_AGENT_MODEL_INVESTIGATOR`
- `OPENCODE_AGENT_MODEL_REVIEWER`
- `OPENCODE_AGENT_MODEL_WORKER`
- `OPENCODE_AGENT_MODEL_ARCHITECT`
- `OPENCODE_AGENT_MODEL_PLANNER`

Built-in agent selectors:

- `OPENCODE_AGENT_MODEL_PLAN` (defaults to `openai/gpt-5.6-sol#high`, matching but independent of the repository ARCHITECT fallback)
- `OPENCODE_AGENT_MODEL_BUILD` (defaults to `openai/gpt-6.1-sol#medium`)

An explicit `PLAN` or `BUILD` value overrides its default independently. These settings provide model preferences in the portable configuration; they do not force an existing session's selected model or agent to change.

Keep existing local settings and add or edit only the desired exports, for example `export OPENCODE_AGENT_MODEL_WORKER='provider/model'`.

Validate the launcher without making a model request: use a temporary `HOME` with a controlled `env.local` value and invoke `~/.local/bin/opencode-env --check` with a stub `opencode` that prints its environment. Confirm the selector has the configured value and `OPENCODE_CONFIG` points to the portable config. This proves only that the launcher supplies the value; it does not prove the live server or an agent has activated it.

After saving the override, invoke `/restart-opencode-env`; it launches the existing wrapper in a detached process. Check its run ID with `~/.local/bin/opencode-env-restart status <run-id>`. A started, running, cancelled, or unverified result is not success; do not blindly retry. If the turn is interrupted, check the receipt when the conversation resumes, using `status` without an ID to inspect the latest run if needed. After a succeeded receipt with exit code 0, query `~/.local/bin/opencode-env api get /api/agent` and compare the intended agent's effective model selector. Report activation only when the live configuration matches; the saved file, launcher check, healthy server, and wrapper exit alone do not prove activation. This verifies server agent configuration, not a current session's selected model or UI display, and does not guarantee an interrupted turn resumes. Preserve existing session choices. Never test by editing live settings or starting a model request.
