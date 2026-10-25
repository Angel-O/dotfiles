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
launcher=$source_dir/dot_local/bin/executable_opencode-env.tmpl

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
assert ('external_directory', '"*"', 'deny') in planner_rules
assert ('external_directory', '"$HOME/workspace/source/*"', 'allow') in planner_rules
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
assert evaluate('wbd scope add child --context registered --json') == 'allow'
assert evaluate('wbd scope add epic --json') == 'deny'
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

external_rules = [rule for rule in planner_rules if rule[0] == 'external_directory']
def evaluate_external(resource):
    effect = 'ask'
    for _, pattern, candidate in external_rules:
        if matches(pattern, resource):
            effect = candidate
    return effect

assert evaluate_external('$HOME/workspace/source/beads_viewer') == 'allow'
assert evaluate_external('$HOME/workspace/other/beads_viewer') == 'deny'
assert evaluate_external('/tmp/beads_viewer') == 'deny'

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
assert launcher.index('source "$local_env"') < launcher.index('export PLANNOTATOR_DATA_DIR=')
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
