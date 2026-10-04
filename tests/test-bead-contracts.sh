#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
planner=$source_dir/dot_config/opencode/agents/planner.md
architect=$source_dir/dot_config/opencode/agents/architect.md
command=$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl
docs=$source_dir/docs/opencode-agent-orchestration.md
readme=$source_dir/README.md

python3 - "$planner" "$architect" "$command" "$docs" "$readme" "$source_dir" <<'PY'
import sys
from pathlib import Path

planner_path, architect_path, command_path, docs_path, readme_path, root = map(Path, sys.argv[1:])
planner = planner_path.read_text()
architect = architect_path.read_text()
command = command_path.read_text()
docs = docs_path.read_text()
readme = readme_path.read_text()
orchestrator = (root / "dot_config/opencode/agents/orchestrator.md").read_text()

headings = [
    "Problem and desired outcome",
    "User stories",
    "Scope and non-goals",
    "Approved approach / design",
    "Acceptance criteria",
    "Decisions and constraints",
    "Validation",
]
for text in (command, docs):
    positions = [text.index(heading) for heading in headings]
    assert positions == sorted(positions)
assert "who benefits, what they need, and why" in command
assert "stories complement, not replace, acceptance criteria" in command
assert "retains its existing exact-ID entrypoint" in command
assert "Todo Beads remain unchanged" in docs
assert "Todo Beads remain unchanged" in command
assert "proposed decisions" in command and "never invent" in command.lower()
assert "before architecture/decomposition" in command and "before implementation" in command
assert "schedule an authorized standalone Bead directly to a worker" in command
assert "the orchestrator creates epics and standalone" in docs.lower()
contract_reference = orchestrator.index("read `~/.config/opencode/commands/orchestrate-bead.md`")
assert "shared `Structured Bead Contract And Ownership` section" in orchestrator
assert "independent of the command's existing-ID entrypoint" in orchestrator
assert "all seven ordered sections, mandatory user stories, and stage-appropriate criteria" in orchestrator
assert "approved design/decision writeback to the existing epic and read it back before scheduling any child workers" in orchestrator
assert contract_reference < orchestrator.index("record all seven ordered sections")
assert "planner owns creation of epic child" in command
assert "The orchestrator must not recreate planner children." in command
writeback = command.index("After receiving the approved architect/planner handoff")
schedule = command.index("only the orchestrator schedules approved concrete children afterward")
assert writeback < schedule
for requirement in (
    "wbd update \"$epic_id\" --description \"$updated_description\" --json",
    "wbd show \"$epic_id\" --json",
    "Approved approach / design",
    "Decisions and constraints",
    "Resolve pending entries only when the handoff resolves them",
    "keep genuinely unresolved items explicit",
    "Preserve the agreed problem, stories, scope, and acceptance criteria",
    "stop before scheduling workers",
):
    assert requirement in command, requirement
assert "approved architecture verbatim" in architect
assert "Only after explicit approval" in architect
assert "architect-owned invocation" in command
assert "the architect invokes you only after explicit user approval" in planner.lower()
assert "If publication is not requested" in planner
assert "ordinary approved architecture task has no epic" in planner
assert "do not run Hub, setup, or scope preflight" in planner
assert "If publication is requested but any of those prerequisites are absent or ambiguous, stop" in planner
assert "Only in authorized publication mode, before any mutation" in planner
assert "same seven description headings in the same order" in planner
assert "active scope" in planner and "Never bootstrap, configure, register, create, or activate a scope." in planner
assert "complete set" in planner and "cross-child outcomes" in planner
assert "before any mutation validate the exact epic" in planner
assert "wbd create" in planner and "wbd show <child-id> --json" in planner
assert "wbd show <id> --json --expand-dependencies" in planner
assert "complete structured description, priority, and context" in planner
assert "existing active scope" in planner and "parent-child" in planner and "genuine `blocks`" in planner
assert "Never retry blindly" in planner and "start workers" in planner
assert "met, unmet, or not verified" in command
assert "completed children alone do not prove success" in command
assert "do not automatically re-review every child diff" in command.lower()
assert "post-merge only" in docs
assert "exactly one positional argument" not in command
assert "wbd comments add" not in planner

permission = planner.split("---", 2)[1].split("permission:", 1)[1]
allowed = [
    '    "*": deny',
    '    "wbd show *": allow',
    '    "wbd scope list*": allow',
    '    "wbd create *": allow',
    '    "wbd scope add *": allow',
    '    "wbd dep add *": allow',
]
positions = [permission.index(entry) for entry in allowed]
assert positions == sorted(positions)
assert '  bash:\n    "*": deny' in planner
assert "edit: allow" not in permission and "task:" not in permission

# Preflight and child mutations stay fail-stop and ordered.
events = [
    "before any mutation validate the exact epic",
    "Require Hub setup and an already active scope",
    "Validate the whole decomposition before publishing",
    "Only in authorized publication mode and after full preflight, publish children one at a time",
    "immediately read it back",
    "Add it to the existing active scope",
    "Then add its `parent-child` edge",
    "After all children are valid, scoped, and parented, add",
    "Stop at the first failure",
]
positions = [planner.index(event) for event in events]
assert positions == sorted(positions)

chezmoiremove = (root / ".chezmoiremove.tmpl").read_text()
chezmoiignore = (root / ".chezmoiignore").read_text()
retired = ".config/opencode/commands/materialize-epic.md"
assert chezmoiremove.splitlines().count(retired) == 1
assert retired not in chezmoiignore
assert not (root / "dot_config/opencode/commands/materialize-epic.md.tmpl").exists()
assert "`/materialize-epic` is retired" in readme
assert "`/materialize-epic` is retired" in docs
PY

assert_rendered() {
  local fixture=$1 expect_agent=$2 output
  output=$(chezmoi execute-template --source "$source_dir" \
    --config "$source_dir/tests/fixtures/$fixture.toml" <"$command")
  if [[ $expect_agent == managed ]]; then
    [[ $output == *"agent: orchestrator"* ]]
  else
    [[ $output != *"agent: orchestrator"* ]]
  fi
}

assert_rendered work managed
assert_rendered external-opencode-beads external

for fixture in work external-opencode-beads personal; do
  removal=$(chezmoi execute-template --source "$source_dir" \
    --config "$source_dir/tests/fixtures/$fixture.toml" <"$source_dir/.chezmoiremove.tmpl")
  test "$(printf '%s\n' "$removal" | grep -Fxc '.config/opencode/commands/materialize-epic.md')" -eq 1
done

apply_dir=$(mktemp -d)
trap 'rm -rf "$apply_dir"' EXIT
for fixture in work external-opencode-beads; do
  home="$apply_dir/$fixture/home"
  mkdir -p "$home/.config/opencode/commands" "$apply_dir/$fixture"
  printf '%s\n' 'stale retired command' >"$home/.config/opencode/commands/materialize-epic.md"
  printf '%s\n' 'unrelated user command' >"$home/.config/opencode/commands/personal.md"
  chezmoi apply --source "$source_dir" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" \
    --cache "$apply_dir/$fixture/cache" \
    --persistent-state "$apply_dir/$fixture/state.boltdb" \
    --exclude scripts,externals --force
  test ! -e "$home/.config/opencode/commands/materialize-epic.md"
  grep -Fqx 'unrelated user command' "$home/.config/opencode/commands/personal.md"
done
