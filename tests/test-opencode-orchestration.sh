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
test ! -e "$source_dir/dot_config/opencode/skills/orchestration-worker-delivery/SKILL.md"
python3 - "$commands_dir/orchestrate-task.md.tmpl" "$commands_dir/orchestrate-epic.md.tmpl" <<'PY'
import re
import sys
from pathlib import Path

fields = ["Work item", "Dedicated worktree and ownership", "Scope and exclusions",
          "Inputs and prerequisites", "Expected outputs or interfaces",
          "Acceptance and compatibility criteria", "Validation expected and owner",
          "Handoff contents", "Stop/report conditions"]
for path in sys.argv[1:]:
    text = Path(path).read_text()
    positions = [text.index(f"`{field}`") for field in fields]
    assert positions == sorted(positions)
PY

apply_fixture() {
  local fixture=$1
  local home="$root/$fixture/home"
  mkdir -p "$home/.config/opencode/skills"
  chezmoi apply --source "$source_dir" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$root/cache/$fixture" \
    --persistent-state "$root/$fixture/state.boltdb" --exclude scripts,externals --force
}

apply_fixture personal
test -f "$root/personal/home/.config/opencode/commands/orchestrate-task.md"
test ! -e "$root/personal/home/.config/opencode/commands/orchestrate-epic.md"
test ! -e "$root/personal/home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"

apply_fixture external-opencode-beads
test ! -e "$root/external-opencode-beads/home/.config/opencode/commands/orchestrate-task.md"
test -f "$root/external-opencode-beads/home/.config/opencode/commands/orchestrate-epic.md"
test ! -e "$root/external-opencode-beads/home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"

for fixture in beads-integration-disabled ghostty-only; do
  apply_fixture "$fixture"
  test ! -e "$root/$fixture/home/.config/opencode/commands/orchestrate-task.md"
  test ! -e "$root/$fixture/home/.config/opencode/commands/orchestrate-epic.md"
  test ! -e "$root/$fixture/home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
done

for fixture in personal-with-beads external-opencode-beads; do
  home="$root/$fixture/home"
  mkdir -p "$home/.config/opencode/command" "$home/.config/opencode/commands" \
    "$home/.config/opencode/skills/work-beads"
  printf '%s\n' legacy >"$home/.config/opencode/command/orchestrate-bead.md"
  printf '%s\n' legacy >"$home/.config/opencode/commands/orchestrate-bead.md"
  printf '%s\n' legacy >"$home/.config/opencode/skills/work-beads/SKILL.md"
  chezmoi apply --source "$source_dir" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$root/cache/$fixture" \
    --persistent-state "$root/$fixture/state.boltdb" --exclude scripts,externals --force
  test ! -e "$home/.config/opencode/command/orchestrate-bead.md"
  test ! -e "$home/.config/opencode/commands/orchestrate-bead.md"
  test ! -e "$home/.config/opencode/skills/work-beads/SKILL.md"
  test ! -e "$home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
done
echo 'orchestration interfaces and installation boundaries: PASS'
