---
name: work-beads
description: Track private work tasks and todos with Beads. Use for private work planning, task tracking, dependencies, progress updates, completion, or whenever the user mentions Beads, wbd, issues, todos, blockers, or work status.
---

# Work Beads

Use `wbd`, never raw `bd`, for private work tracking. The wrapper targets one private external store at `~/.local/share/beads/work/.beads`; never run `bd init`, create a repository `.beads` directory, add Beads hooks, or write Beads files or agent guidance into a repository.

## Scope

- Run `wbd context` in the current Git repository to discover its automatic `ctx:<slug>-<hash>` label. Repository context requires an `origin` remote and equivalent common SSH/HTTPS origins produce the same stable context.
- `wbd create` and `wbd new` add the current context automatically while preserving labels supplied by the user. Do not add or duplicate the context label manually.
- `wbd list` automatically limits results to the current context. Use `wbd list --all-contexts` only when a global cross-project query is intentional.
- Discover ready work in the current context with `wbd list --ready --json`. Raw `wbd ready` is not context-filtered.
- Agent operations are limited to `create`, `new`, `list`, `show`, `update`, `dep`, `close`, and `reopen`. Stable issue IDs work directly in dependencies across repositories; use those IDs rather than project-name mappings. Do not use `wbd` for configuration, setup, hooks, maintenance, imports, exports, integrations, or repository routing.

## Agent Workflow

Use JSON output for every agent CRUD or query operation, including create, show, list, ready, update, close, reopen, and dependency commands. Prefer explicit commands such as:

```sh
wbd list --json
wbd list --ready --json
wbd list --all-contexts --json
wbd create "Task title" --description "..." --json
wbd show <id> --json
wbd update <id> --status in_progress --json
wbd dep add <issue-id> <dependency-id> --json
wbd close <id> --json
wbd reopen <id> --json
```

At the start of tracked work, inspect the current-context issues and create or update the relevant item. Record meaningful lifecycle changes as work starts, becomes blocked, changes scope, or gains dependencies. Close completed work only after verification; reopen it when completion no longer holds. For cross-project dependencies, query globally when needed and connect the stable IDs directly.

`wbv` is the human-facing global all-context viewer. Agents must not launch it; use `wbd ... --json` instead.
