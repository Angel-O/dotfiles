#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
cache=${CHEZMOI_TEST_CACHE:-/tmp/dotfiles-write-bead-cache}

python3 - "$source_dir/.chezmoitemplates/write-bead.md" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
sections = [
    "Problem and desired outcome", "User stories", "Scope and non-goals",
    "Approved approach / design", "Acceptance criteria", "Decisions and constraints",
    "Validation",
]
positions = [text.index(f"`## {section}`") for section in sections]
assert positions == sorted(positions)
assert text.count("`## Architect notes`") == 1
PY

python3 - "$source_dir/dot_config/opencode/agents/architect.md" \
  "$source_dir/dot_config/opencode/agents/planner.md" \
  "$source_dir/dot_config/opencode/skills/decomposition-rules/SKILL.md" \
  "$source_dir/dot_config/opencode/agents/worker.md" \
  "$source_dir/dot_local/bin/executable_opencode-env.tmpl" <<'PY'
from pathlib import Path
import re
import sys

architect_path, removed_planner, manifest_path, worker_path, launcher_path = map(Path, sys.argv[1:])
assert not removed_planner.exists(), "planner role must be removed"
manifest = manifest_path.read_text()
for rule in ("DEC-01", "DEC-02", "DEC-03", "DEC-04", "DEC-05"):
    assert f"| {rule} " in manifest, rule

architect = architect_path.read_text()
worker = worker_path.read_text()
launcher = launcher_path.read_text()
plan_resource = '$HOME/.local/share/plannotator/plans/*'
for text in (architect, worker):
    assert "/" + "Users/" not in text and "/" + "home/" not in text
    assert not re.search(r'^\s+"/[^"\n]+":\s+(?:allow|deny)\s*$', text, re.MULTILINE)
assert plan_resource in architect
assert '"$HOME/workspace/source/*"' in architect
frontmatter = architect.split("---", 2)[1]
rules = [
    tuple(match)
    for match in re.findall(
        r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
        frontmatter,
        re.MULTILINE,
    )
]
allowed = {
    ("shell", '"wbd context"'),
    ("shell", '"wbd show * --json"'),
    ("shell", '"wbd show * --json --expand-dependencies"'),
    ("shell", '"wbd comments * --json"'),
    ("shell", '"wbd update * --description * --json"'),
    ("shell", '"wbd scope active --json"'),
    ("shell", '"wbd create * --type * --context * --description * --priority * --json"'),
    ("shell", '"wbd create * --type * --priority * --context * --description * --json"'),
    ("shell", '"wbd scope add * --context * --json"'),
    ("shell", '"wbd dep add * * --type parent-child --json"'),
    ("shell", '"wbd dep add * * --type blocks --json"'),
}
assert all((action, resource) in allowed for action, resource, effect in rules if action == "shell" and effect == "allow")
assert allowed == {(action, resource) for action, resource, effect in rules if action == "shell" and effect == "allow"}
assert ('orchestration_tracking', '"*"', 'allow') in rules
assert not any(action == "subagent" and effect == "allow" for action, _, effect in rules)
worker_frontmatter = worker.split("---", 2)[1]
worker_rules = [tuple(match) for match in re.findall(
    r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$', worker_frontmatter, re.MULTILINE
)]
git_deny = worker_rules.index(("shell", '"git *"', "deny"))
assert worker_rules[git_deny + 1:git_deny + 3] == [
    ("shell", '"git rev-parse HEAD"', "allow"),
    ("shell", '"git branch --show-current"', "allow"),
]

def matches(pattern, resource):
    pattern = pattern.strip('"')
    return re.fullmatch(re.escape(pattern).replace(r"\*", ".*"), resource) is not None

def authorized(command):
    decision = "ask"
    for action, pattern, effect in rules:
        if action in {"*", '"*"', "shell"} and matches(pattern, command):
            decision = effect
    return decision == "allow"

for command in (
    "wbd context",
    "wbd show epic --json",
    "wbd comments epic --json",
    "wbd scope active --json",
    "wbd create child --type task --context registered --description detail --priority 2 --json",
    "wbd scope add child --context registered --json",
    "wbd dep add child epic --type parent-child --json",
    "wbd dep add child prerequisite --type blocks --json",
):
    assert authorized(command), command
for command in (
    "wbd context --json",
    "wbd comments epic",
    "wbd --json comments add epic -- text",
    "wbd --json comments edit epic 1 -- text",
    "wbd --json comments delete epic 1",
    "wbd comments epic --json | cat",
    "env wbd comments epic --json",
    "wbd create child --type task --context registered --description detail --priority 2 --json && wbd dep add child epic",
    "wbd scope add epic --json",
    "wbd dep add child epic --type relates --json",
    "wbd update epic --status closed --json",
    "wbd create child --type task --context registered --description detail --priority 2 --json | cat",
    "$(wbd context)",
    "RESULT=ok wbd context",
    "env wbd context",
):
    assert authorized(command) == False, command

assert launcher.index('source "$local_env"') < launcher.index('export PLANNOTATOR_DATA_DIR=')
PY

for fixture in work external-opencode-beads; do
  managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$cache" --exclude externals --include files)
  printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/decomposition-rules/SKILL.md'
done

managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" --exclude externals --include files)
printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/decomposition-rules/SKILL.md'

echo 'architect publication contract and managed decomposition manifest: PASS'

test ! -e "$source_dir/dot_config/opencode/commands/materialize-epic.md.tmpl"
grep -Fq '.config/opencode/commands/materialize-epic.md' "$source_dir/.chezmoiremove.tmpl"

for fixture in work external-opencode-beads; do
  managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$cache" --exclude externals --include files)
  printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/write-bead/SKILL.md'
done

managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" --exclude externals --include files)
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
cp "$source_dir/.chezmoitemplates/write-bead.md" "$home/.config/opencode/skills/write-bead/SKILL.md"
HOME=$home sh "$cleanup"
test ! -e "$home/.config/opencode/skills/write-bead/SKILL.md"
mkdir -p "$home/.config/opencode/skills/write-bead"
printf '%s\n' 'unrelated user content' >"$home/.config/opencode/skills/write-bead/SKILL.md"
HOME=$home sh "$cleanup"
grep -Fq 'unrelated user content' "$home/.config/opencode/skills/write-bead/SKILL.md"
