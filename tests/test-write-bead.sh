#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
skill=$source_dir/.chezmoitemplates/write-bead.md
cache=${CHEZMOI_TEST_CACHE:-/tmp/dotfiles-write-bead-cache}

assert_contains() {
  local file=$1 text=$2
  grep -Fq -- "$text" "$file" || {
    printf 'write-bead test: expected %s to contain: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    printf 'write-bead test: expected %s not to contain: %s\n' "$1" "$2" >&2
    exit 1
  fi
}

assert_contains "$skill" 'Use ONLY when creating or materially updating a Bead description'
assert_contains "$skill" 'User stories do not replace acceptance criteria'
assert_contains "$skill" 'Todos may be contextless or contextual under the supported policy; undefined work requiring refinement is outside this structure.'
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
command=$source_dir/dot_config/opencode/commands/orchestrate-epic.md.tmpl
launcher=$source_dir/dot_local/bin/executable_opencode-env.tmpl

assert_contains "$orchestrator" 'load both `write-bead` and `beads-hub`, create the Bead with its structured canonical description'
assert_contains "$orchestrator" 'before architecture, decomposition, or implementation'
assert_contains "$architect" '    resource: "wbd show * --json"'
assert_contains "$architect" '    resource: "wbd update * --description * --json"'
assert_contains "$architect" 'Every authorized Hub operation—`wbd show` and `wbd update`—must be a direct standalone shell command matching its existing allowlisted whole-command form.'
assert_contains "$architect" 'Do not use shell composition, including chaining, pipes, redirects, command substitution, assignment or environment-prefix wrappers, or other wrapping.'
assert_contains "$planner" 'collective coverage of every epic acceptance criterion'
assert_contains "$planner" 'Creation does not authorize implementation.'
assert_contains "$planner" 'Never automatically retry, roll back, delete, claim, close, or implement.'
assert_contains "$planner" 'Every authorized Hub operation—`wbd context`, `wbd show`, `wbd scope active`, either allowlisted `wbd create` form, `wbd scope add`, or either allowlisted `wbd dep add` form—must be a direct standalone shell command matching its existing allowlisted whole-command form.'
assert_contains "$planner" 'Do not use shell composition, including chaining, pipes, redirects, command substitution, assignment or environment-prefix wrappers, or other wrapping.'
assert_contains "$planner" '    resource: "wbd context"'
assert_contains "$planner" '    resource: "wbd create * --type * --context * --description * --priority * --json"'
assert_contains "$planner" '    resource: "wbd create * --type * --priority * --context * --description * --json"'
assert_contains "$planner" '    resource: "wbd dep add * * --type parent-child --json"'
assert_contains "$planner" '    resource: "wbd show * --json"'
assert_contains "$planner" '    resource: "wbd show * --json --expand-dependencies"'
assert_contains "$planner" 'Expand dependencies only for diagnostics, debugging, or a demonstrated need for a nested field unavailable in compact output'
assert_contains "$planner" 'Inspect routine parent/child and blocker relationships with compact `wbd show <epic-id> --json` output.'
assert_contains "$worker" 'read the authoritative assigned record by its exact canonical ID'
assert_contains "$worker" 'nine-field worker prompt as operational context'
assert_contains "$reviewer" 'same exact canonical ID given to its worker'
assert_contains "$reviewer" '`met`, `unmet`, or `not verified`'
assert_contains "$command" 'Completed children alone are insufficient.'
assert_contains "$launcher" 'export PLANNOTATOR_DATA_DIR="${PLANNOTATOR_DATA_DIR:-$HOME/.local/share/plannotator}"'

# Keep the role permissions portable; local paths and plan artifacts are not configuration.
python3 - "$architect" "$planner" "$launcher" <<'PY'
import re
import sys
from pathlib import Path

architect, planner, launcher = (Path(path).read_text() for path in sys.argv[1:])
plan_resource = '$HOME/.local/share/plannotator/plans/*'

for text in (architect, planner):
    assert "/" + "Users/" not in text
    assert "/home/" not in text
    assert not re.search(r'^\s+"/[^"\n]+":\s+(?:allow|deny)\s*$', text, re.MULTILINE)
    assert not re.search(r'(?i)plan[^\n`]*\.md', text)

rules = [
    tuple(match)
    for match in re.findall(
        r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
        architect,
        re.MULTILINE,
    )
]
assert rules == [
    ('"*"', '"*"', 'deny'),
    ('shell', '"*"', 'deny'),
    ('shell', '"wbd show * --json"', 'allow'),
    ('shell', '"wbd update * --description * --json"', 'allow'),
    ('external_directory', '"*"', 'ask'),
    ('external_directory', f'"{plan_resource}"', 'allow'),
    ('question', '"*"', 'allow'),
    ('read', '"*"', 'allow'),
    ('read', f'"{plan_resource}"', 'allow'),
    ('edit', f'"{plan_resource}"', 'allow'),
    ('glob', '"*"', 'allow'),
    ('grep', '"*"', 'allow'),
    ('webfetch', '"*"', 'allow'),
    ('skill', '"*"', 'allow'),
    ('subagent', '"*"', 'deny'),
    ('subagent', 'planner', 'allow'),
], rules

planner_rules = [
    tuple(match)
    for match in re.findall(
        r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
        planner,
        re.MULTILINE,
    )
]
assert planner_rules[:3] == [
    ('"*"', '"*"', 'deny'),
    ('orchestration_tracking', '"*"', 'allow'),
    ('shell', '"*"', 'deny'),
]
assert ('shell', '"wbd context *"', 'allow') not in planner_rules
assert ('shell', '"wbd create * --context * --priority * --description * --json"', 'allow') not in planner_rules

architect_rules = [
    tuple(match)
    for match in re.findall(
        r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
        architect,
        re.MULTILINE,
    )
]

def matches(pattern, resource):
    pattern = pattern.strip('"')
    regex = re.escape(pattern).replace(r'\*', '.*').replace(r'\?', '.')
    return re.fullmatch(regex, resource) is not None

def evaluate(resource, selected_rules=planner_rules):
    effect = 'ask'
    for action, pattern, candidate in selected_rules:
        if action in {'"*"', 'shell'} and matches(pattern, resource):
            effect = candidate
    return effect

# Exercise V2's ordered, whole-value matching rather than only checking text.
assert evaluate('wbd context') == 'allow'
assert evaluate('wbd context --json') == 'deny'
assert evaluate('wbd create child --type task --priority 2 --context local --description detail --json') == 'allow'
assert evaluate('wbd create child --type task --context local --description detail --priority 2 --json') == 'allow'
assert evaluate("wbd create \"child\" --type task --context local --description 'detail with spaces' --priority 2 --json") == 'allow'
assert evaluate('wbd create child --type task --context local --priority 2 --description detail --json') == 'deny'
assert evaluate('wbd create child --type task --context local --description detail --priority 2 --json --from-todo todo') == 'deny'
assert evaluate('wbd create child --type task --context local --description detail --priority 2') == 'deny'
assert evaluate('wbd context && wbd create child --type task') == 'deny'
assert evaluate('wbd create child --type task --context local --description detail --priority 2 --json && wbd update child --status closed') == 'deny'
assert evaluate('wbd create child --type task --context local --description detail --priority 2 --json | cat') == 'deny'
assert evaluate('wbd update child --status closed --json') == 'deny'
assert evaluate('wbd create child --type task --context local --description detail --priority 2 --json > result') == 'deny'
assert evaluate('$(wbd context)') == 'deny'
assert evaluate('RESULT=ok wbd context') == 'deny'
assert evaluate('env wbd context') == 'deny'

assert evaluate('wbd show epic --json', architect_rules) == 'allow'
assert evaluate('wbd update epic --description detail --json', architect_rules) == 'allow'
assert evaluate('wbd show epic --json && wbd update epic --status closed', architect_rules) == 'deny'
assert evaluate('wbd update epic --description detail --json | cat', architect_rules) == 'deny'
assert evaluate('wbd show epic --json > result', architect_rules) == 'deny'
assert evaluate('$(wbd show epic --json)', architect_rules) == 'deny'
assert evaluate('RESULT=ok wbd show epic --json', architect_rules) == 'deny'
assert evaluate('env wbd show epic --json', architect_rules) == 'deny'
assert 'mode: subagent' in planner.split('---', 2)[1]
assert not any(action == 'subagent' and resource == 'plan' for action, resource, _ in planner_rules)
assert plan_resource in architect
assert plan_resource not in planner
assert 'plannotator' not in planner.lower()
assert 'plans/' not in planner.lower()
assert 'the only permitted file update is the approved plan artifact under `$HOME/.local/share/plannotator/plans/*`' in architect
assert 'never edit implementation files' in architect
assert launcher.index('source "$local_env"') < launcher.index('export PLANNOTATOR_DATA_DIR=')
PY

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
assert "If `## Architect notes` is absent" in architect
assert "allow any number of architecture amendments" in architect
assert "each separately requiring explicit user approval" in architect
assert "Append each approved amendment as a clearly titled level-3 subsection beneath the existing appendix" in architect
assert "preserve all existing architect-note content verbatim" in architect
assert "never add a second level-2 `## Architect notes` heading" in architect
assert "Otherwise stop." in architect
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

events = [
    "Inspect routine parent/child and blocker relationships with compact",
    "require explicit user authorization for additive publication",
    "preserve every existing child unchanged",
    "stop before mutation if any proposed slice overlaps or conflicts with one",
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
  managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$cache" --exclude externals --include files)
  printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/write-bead/SKILL.md'
done

managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" --exclude externals --include files)
! printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/write-bead/SKILL.md'

remove_list=$(chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/external-opencode-beads.toml" <"$source_dir/.chezmoiremove.tmpl")
printf '%s\n' "$remove_list" | grep -Fxq '.config/opencode/commands/materialize-epic.md'

cleanup=$(mktemp)
rendered=$(mktemp)
home=$(mktemp -d)
trap 'rm -f "$cleanup" "$rendered"; rm -rf "$home"' EXIT
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$planner" >"$rendered"
grep -Fqx '    resource: "wbd create * --type * --context * --description * --priority * --json"' "$rendered"
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
