#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
commands_dir="$source_dir/dot_config/opencode/commands"

# Keep the command interface and installation boundaries; instructional prose
# is reviewed for behavior, not frozen as source-text snapshots.
test ! -e "$commands_dir/orchestrate.md"
test ! -e "$commands_dir/orchestrate-bead.md.tmpl"
test -f "$commands_dir/orchestrate-task.md.tmpl"
test -f "$commands_dir/orchestrate-epic.md.tmpl"
test ! -e "$commands_dir/refactoring.md.tmpl"
test -f "$commands_dir/dry-code.md.tmpl"
test ! -e "$source_dir/dot_config/opencode/skills/orchestration-worker-delivery/SKILL.md"
python3 - "$commands_dir/dry-code.md.tmpl" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
frontmatter, body = text.split("---", 2)[1:]
assert not re.search(r"(?m)^agent:", frontmatter)
assert body.count("$ARGUMENTS") == 1
assert not re.search(r"/orchestrate-(?:task|epic)|\b(?:orchestrator|architect)\b", body)
PY
python3 - "$commands_dir/orchestrate-task.md.tmpl" "$commands_dir/orchestrate-epic.md.tmpl" \
  "$source_dir/dot_config/opencode/agents/worker.md" \
  "$source_dir/dot_config/opencode/agents/test-scope-reviewer.md" <<'PY'
import re
import sys
from pathlib import Path

fields = ["Work item", "Dedicated worktree and ownership", "Scope and exclusions",
          "Inputs and prerequisites", "Expected outputs or interfaces",
          "Acceptance and compatibility criteria", "Validation expected and owner",
          "Handoff contents", "Stop/report conditions"]
for path in sys.argv[1:3]:
    text = Path(path).read_text()
    positions = [text.index(f"`{field}`") for field in fields]
    assert positions == sorted(positions)

worker = Path(sys.argv[3]).read_text().split("---", 2)[1]
rules = re.findall(
    r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$', worker, re.MULTILINE
)
assert ('"*"', '"*"', 'deny') in rules
assert ('subagent', 'test-scope-reviewer', 'allow') in rules
assert not any(action == 'subagent' and effect == 'allow' and resource != 'test-scope-reviewer'
               for action, resource, effect in rules)
scope_rules = re.findall(
    r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
    Path(sys.argv[4]).read_text().split("---", 2)[1], re.MULTILINE
)
assert scope_rules == [
    ('"*"', '"*"', 'deny'),
    ('skill', 'ponytail', 'allow'),
    ('skill', 'testing-rules', 'allow'),
]
assert "mode: subagent" in Path(sys.argv[4]).read_text().split("---", 2)[1]
PY

apply_fixture() {
  local fixture=$1
  local home="$root/$fixture/home"
  mkdir -p "$home/.config/opencode/skills"
  chezmoi apply --source "$source_dir" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$root/cache/$fixture" \
    --persistent-state "$root/$fixture/state.boltdb" --exclude scripts,externals --force
}

mkdir -p "$root/personal/home/.config/opencode/agents"
printf '%s\n' 'obsolete installed planner' >"$root/personal/home/.config/opencode/agents/planner.md"
apply_fixture personal
test -f "$root/personal/home/.config/opencode/commands/orchestrate-task.md"
test -f "$root/personal/home/.config/opencode/commands/dry-code.md"
test ! -e "$root/personal/home/.config/opencode/commands/refactoring.md"
! grep -Eq '^agent:' "$root/personal/home/.config/opencode/commands/dry-code.md"
test -f "$root/personal/home/.config/opencode/agents/test-scope-reviewer.md"
test ! -e "$root/personal/home/.config/opencode/commands/orchestrate-epic.md"
test ! -e "$root/personal/home/.config/opencode/agents/planner.md"
test ! -e "$root/personal/home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/decomposition-rules/SKILL.md" \
  "$root/personal/home/.config/opencode/skills/decomposition-rules/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/testing-rules/SKILL.md" \
  "$root/personal/home/.config/opencode/skills/testing-rules/SKILL.md"

apply_fixture external-opencode-beads
test ! -e "$root/external-opencode-beads/home/.config/opencode/commands/orchestrate-task.md"
test ! -e "$root/external-opencode-beads/home/.config/opencode/commands/dry-code.md"
test ! -e "$root/external-opencode-beads/home/.config/opencode/commands/refactoring.md"
test -f "$root/external-opencode-beads/home/.config/opencode/commands/orchestrate-epic.md"
test ! -e "$root/external-opencode-beads/home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/testing-rules/SKILL.md" \
  "$root/external-opencode-beads/home/.config/opencode/skills/testing-rules/SKILL.md"

for fixture in beads-integration-disabled ghostty-only; do
  apply_fixture "$fixture"
  test ! -e "$root/$fixture/home/.config/opencode/commands/orchestrate-task.md"
  test ! -e "$root/$fixture/home/.config/opencode/commands/orchestrate-epic.md"
  if [[ $fixture == beads-integration-disabled ]]; then
    test -f "$root/$fixture/home/.config/opencode/commands/dry-code.md"
  else
    test ! -e "$root/$fixture/home/.config/opencode/commands/dry-code.md"
  fi
  test ! -e "$root/$fixture/home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
done
cmp -s "$source_dir/dot_config/opencode/skills/testing-rules/SKILL.md" \
  "$root/beads-integration-disabled/home/.config/opencode/skills/testing-rules/SKILL.md"
test ! -e "$root/ghostty-only/home/.config/opencode/skills/testing-rules/SKILL.md"

for fixture in personal-with-beads external-opencode-beads; do
  home="$root/$fixture/home"
  mkdir -p "$home/.config/opencode/command" "$home/.config/opencode/commands" \
    "$home/.config/opencode/skills/work-beads"
  printf '%s\n' legacy >"$home/.config/opencode/command/orchestrate-bead.md"
  printf '%s\n' legacy >"$home/.config/opencode/commands/orchestrate-bead.md"
  printf '%s\n' legacy >"$home/.config/opencode/skills/work-beads/SKILL.md"
  printf '%s\n' unrelated >"$home/.config/opencode/commands/unrelated.md"
  chezmoi apply --source "$source_dir" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$root/cache/$fixture" \
    --persistent-state "$root/$fixture/state.boltdb" --exclude scripts,externals --force
  test ! -e "$home/.config/opencode/command/orchestrate-bead.md"
  test ! -e "$home/.config/opencode/commands/orchestrate-bead.md"
  test ! -e "$home/.config/opencode/skills/work-beads/SKILL.md"
  if [[ $fixture == personal-with-beads ]]; then
    test -f "$home/.config/opencode/commands/dry-code.md"
  else
    test ! -e "$home/.config/opencode/commands/dry-code.md"
  fi
  test "$(cat "$home/.config/opencode/commands/unrelated.md")" = unrelated
  test ! -e "$home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
done

managed=$(chezmoi managed --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal-with-beads.toml" \
  --cache "$root/cache/managed" --exclude externals --include files)
printf '%s\n' "$managed" | grep -Fxq '.config/opencode/commands/dry-code.md'
managed=$(chezmoi managed --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal.toml" \
  --cache "$root/cache/unmanaged" --exclude externals --include files)
printf '%s\n' "$managed" | grep -Fxq '.config/opencode/commands/dry-code.md'
remove_list=$(chezmoi execute-template --source "$source_dir" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  <"$source_dir/.chezmoiremove.tmpl")
printf '%s\n' "$remove_list" | grep -Fxq '.config/opencode/commands/dry-code.md'

# Isolated stand-ins exercise the personal-only ignore gate without editing
# the separately owned approved command or skill.
adr_source="$root/adr-source"
mkdir -p "$adr_source/dot_config/opencode/commands" \
  "$adr_source/dot_config/opencode/skills/consult-adr"
cp "$source_dir/.chezmoiignore" "$adr_source/.chezmoiignore"
printf '%s\n' 'fixture command' >"$adr_source/dot_config/opencode/commands/write-adr.md"
printf '%s\n' 'fixture skill' >"$adr_source/dot_config/opencode/skills/consult-adr/SKILL.md"
for fixture in personal work beads-integration-disabled external-opencode-beads; do
  home="$root/adr-$fixture/home"
  mkdir -p "$home"
  chezmoi apply --source "$adr_source" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$root/cache/adr-$fixture" \
    --persistent-state "$root/adr-$fixture/state.boltdb" --force
  if [ "$fixture" = personal ]; then
    test -f "$home/.config/opencode/commands/write-adr.md"
    test -f "$home/.config/opencode/skills/consult-adr/SKILL.md"
  else
    test ! -e "$home/.config/opencode/commands/write-adr.md"
    test ! -e "$home/.config/opencode/skills/consult-adr/SKILL.md"
  fi
done
# Derive a personal-role config with only the OpenCode module disabled, so the
# role and module gates are exercised independently of the work profile.
personal_no_opencode="$root/personal-opencode-disabled.toml"
sed 's/^opencode = true$/opencode = false/' \
  "$source_dir/tests/fixtures/personal.toml" >"$personal_no_opencode"
home="$root/adr-personal-opencode-disabled/home"
mkdir -p "$home"
chezmoi apply --source "$adr_source" --destination "$home" \
  --config "$personal_no_opencode" --cache "$root/cache/adr-personal-opencode-disabled" \
  --persistent-state "$root/adr-personal-opencode-disabled/state.boltdb" --force
test ! -e "$home/.config/opencode/commands/write-adr.md"
test ! -e "$home/.config/opencode/skills/consult-adr/SKILL.md"
# The external-OpenCode Beads-only profile still retains its existing Beads
# command/skill behavior while excluding the personal ADR artifacts.
test -f "$root/external-opencode-beads/home/.config/opencode/commands/orchestrate-epic.md"
test -f "$root/external-opencode-beads/home/.config/opencode/skills/testing-rules/SKILL.md"

render_identity() {
  local profile=$1 identity=$2 config=$3
  chezmoi execute-template --source "$source_dir" --config "$config" \
    <"$source_dir/dot_config/opencode/agents/$identity.md.tmpl" >"$root/$profile-$identity.md"
}
for identity in orchestrator architect; do
  render_identity personal "$identity" "$source_dir/tests/fixtures/personal.toml"
  render_identity work "$identity" "$source_dir/tests/fixtures/work.toml"
  render_identity personal-opencode-disabled "$identity" "$personal_no_opencode"
  grep -Fq 'consult-adr' "$root/personal-$identity.md"
  grep -Fq 'docs/adr/index.md' "$root/personal-$identity.md"
  grep -Fq 'consult-adr' "$root/personal/home/.config/opencode/agents/$identity.md"
  ! grep -Fq 'consult-adr' "$root/work-$identity.md"
  ! grep -Fq 'consult-adr' "$root/personal-opencode-disabled-$identity.md"
done
python3 - "$root/personal-architect.md" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
permissions = text.split("---", 2)[1].split("permissions:", 1)[1]
rules = re.findall(
    r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
    permissions,
    re.MULTILINE,
)
assert ("shell", '"*"', "deny") in rules
assert ("shell", '"wbd list --json"', "allow") in rules
assert ("shell", '"wbd list --json *"', "allow") in rules
assert ("shell", '"wbd list * --json"', "allow") in rules
assert ("shell", '"wbd list * --json *"', "allow") in rules
assert ("shell", '"wbd scope show * --json"', "allow") in rules
assert ("shell", '"wbd scope show * --json *"', "allow") in rules
assert ("shell", '"wbd scope active --json"', "allow") in rules
assert ("shell", '"wbd scope add *"', "allow") in rules
PY
grep -Fq 'Act as the primary delivery controller.' "$root/personal-orchestrator.md"
grep -Fq 'Design large cross-service or cross-area initiatives without implementing them.' \
  "$root/personal-architect.md"
echo 'orchestration interfaces and installation boundaries: PASS'
