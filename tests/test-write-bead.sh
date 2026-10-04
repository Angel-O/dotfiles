#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
skill=$source_dir/.chezmoitemplates/write-bead.md

assert_contains() {
  local file=$1 text=$2
  grep -Fq -- "$text" "$file" || {
    printf 'write-bead test: expected %s to contain: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_contains "$skill" 'Use ONLY when creating or materially updating a Bead description'
assert_contains "$skill" 'User stories do not replace acceptance criteria'
assert_contains "$skill" 'Todos are unscoped, undefined work requiring refinement and are outside this structure.'
assert_contains "$skill" 'Pending information may be explicit only when it is not required for the next stage; required missing information blocks that stage.'
assert_contains "$skill" 'Distinguish proposed decisions from approved decisions.'
assert_contains "$skill" '`Acceptance criteria` states what must be true. `Validation` states how those truths will be established.'
assert_contains "$skill" 'enough task-specific problem, scope, approach, criteria, constraints, and validation detail for implementation and review'
assert_contains "$skill" '`## Architect notes` is the exact epic-only appendix heading'

python3 - "$skill" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
sections = [
    "Problem and desired outcome",
    "User stories",
    "Scope and non-goals",
    "Approved approach / design",
    "Acceptance criteria",
    "Decisions and constraints",
    "Validation",
]
positions = [text.index(f"`## {section}`") for section in sections]
assert positions == sorted(positions)
assert text.count("`## Architect notes`") == 1
PY

orchestrator=$source_dir/dot_config/opencode/agents/orchestrator.md
architect=$source_dir/dot_config/opencode/agents/architect.md
planner=$source_dir/dot_config/opencode/agents/planner.md
worker=$source_dir/dot_config/opencode/agents/worker.md
reviewer=$source_dir/dot_config/opencode/agents/reviewer.md
command=$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl

assert_contains "$orchestrator" 'load both `write-bead` and `beads-hub`, create the Bead with its structured canonical description'
assert_contains "$orchestrator" 'before architecture, decomposition, or implementation'
assert_contains "$architect" '"wbd show * --json": allow'
assert_contains "$architect" '"wbd update * --description * --json": allow'
assert_contains "$planner" 'collective coverage of every epic acceptance criterion'
assert_contains "$planner" 'Creation does not authorize implementation.'
assert_contains "$planner" 'Never automatically retry, roll back, delete, claim, close, or implement.'
assert_contains "$planner" '"wbd create * --type * --description * --priority * --context * --json": allow'
assert_contains "$planner" '"wbd dep add * * --type parent-child --json": allow'
assert_contains "$planner" '"wbd show * --json --expand-dependencies": allow'
assert_contains "$worker" 'read the authoritative assigned record by its exact canonical ID'
assert_contains "$worker" 'nine-field worker prompt as operational context'
assert_contains "$reviewer" 'same exact canonical ID given to its worker'
assert_contains "$reviewer" '`met`, `unmet`, or `not verified`'
assert_contains "$command" 'The nine fields provide operational context and must not copy or replace the canonical specification.'
assert_contains "$command" 'Completed children alone are insufficient.'
assert_contains "$command" 'Do not automatically re-review every diff or create another review lane'

python3 - "$orchestrator" "$architect" "$planner" <<'PY'
from pathlib import Path
import sys

orchestrator, architect, planner = (Path(path).read_text() for path in sys.argv[1:])

sequence = next(line for line in orchestrator.splitlines() if line.startswith("When architecture is selected"))
bead = sequence.index("For a Bead-backed architecture run")
normal = sequence.index("For a normal non-Bead architecture run")
assert bead < normal
assert "persists the approved architecture to the canonical epic" in sequence[bead:normal]
assert "passes the complete approved architecture verbatim to the planner" in sequence[normal:]

assert architect.count("wbd show <epic-id> --json") == 2
assert "use that current description as the base" in architect
assert "Stop if `## Architect notes` already exists" in architect
assert "Do not perform a post-update read or full-description comparison." in architect
assert "then read it again" not in architect
assert "`## Architect notes`" in architect
bead = architect.index("For a Bead-backed run")
normal = architect.index("For a normal non-Bead run")
bead_handoff = architect[bead:normal]
normal_handoff = architect[normal:]
assert "report the canonical epic and created-child results or accurate partial-publication status using runtime IDs" in bead_handoff
assert "do not reproduce a combined specification" in bead_handoff
assert "combined handoff" not in bead_handoff
assert "complete approved architecture verbatim" in normal_handoff
assert "emit one combined handoff" in normal_handoff

assert "relevant epic ID when any" in orchestrator
assert "The nine fields provide operational context and must not copy or replace the canonical specification." in orchestrator

events = [
    "Inspect existing direct relationships",
    "stop before mutation if any direct `parent-child` child already exists",
    "completely preflight distinct concrete slices, valid slice references",
    "create each structured concrete child",
    "required create-then-show flow",
    "add it to the active scope",
    "add a genuine `parent-child` relationship",
    "Only after every created child is validated, scoped, and parent-linked",
    "add `blocks` relationships",
]
positions = [planner.index(event) for event in events]
assert positions == sorted(positions)
assert "Missing, duplicate, self-referential, unknown, or conflicting inputs block all publication." in planner
assert "without adding post-mutation verification beyond the `beads-hub` contract" in planner
PY

test ! -e "$source_dir/dot_config/opencode/commands/materialize-epic.md.tmpl"
assert_contains "$source_dir/.chezmoiremove.tmpl" '.config/opencode/commands/materialize-epic.md'

for fixture in work external-opencode-beads; do
  managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" --exclude externals --include files)
  printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/write-bead/SKILL.md'
done

managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --exclude externals --include files)
! printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/write-bead/SKILL.md'

remove_list=$(chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/external-opencode-beads.toml" <"$source_dir/.chezmoiremove.tmpl")
printf '%s\n' "$remove_list" | grep -Fxq '.config/opencode/commands/materialize-epic.md'

cleanup=$(mktemp)
home=$(mktemp -d)
trap 'rm -f "$cleanup"; rm -rf "$home"' EXIT
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/beads-integration-disabled.toml" \
  <"$source_dir/run_before_04-remove-disabled-write-bead.sh.tmpl" >"$cleanup"
sh -n "$cleanup"
mkdir -p "$home/.config/opencode/skills/write-bead"
cp "$skill" "$home/.config/opencode/skills/write-bead/SKILL.md"
HOME=$home sh "$cleanup"
test ! -e "$home/.config/opencode/skills/write-bead/SKILL.md"
mkdir -p "$home/.config/opencode/skills/write-bead"
printf '%s\n' 'unrelated user content' >"$home/.config/opencode/skills/write-bead/SKILL.md"
HOME=$home sh "$cleanup"
assert_contains "$home/.config/opencode/skills/write-bead/SKILL.md" 'unrelated user content'
