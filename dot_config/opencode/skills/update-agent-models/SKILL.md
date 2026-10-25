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

An explicit `PLAN` or `BUILD` value overrides its default independently. These settings provide model preferences in the portable configuration; they do not promise automatic session-model or UI agent-switch changes.

Keep existing local settings and add or edit only the desired exports, for example `export OPENCODE_AGENT_MODEL_WORKER='provider/model'`.

Validate without making a model request: use a temporary `HOME` with a controlled `env.local` value and invoke `~/.local/bin/opencode-env --check` with a stub `opencode` that prints its environment. Confirm the selector has the configured value and `OPENCODE_CONFIG` points to the portable config. Never test by editing live settings or starting a real model request.
