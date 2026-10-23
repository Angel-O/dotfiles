#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
cache="$root/cache"
commands_dir="$source_dir/dot_config/opencode/commands"

assert_contains() {
  grep -Fq -- "$2" "$1" || {
    printf 'expected %s to contain: %s\n' "$1" "$2" >&2
    exit 1
  }
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    printf 'expected %s not to contain: %s\n' "$1" "$2" >&2
    exit 1
  fi
}

test ! -e "$commands_dir/orchestrate.md"
test ! -e "$commands_dir/orchestrate-bead.md.tmpl"
test -f "$commands_dir/orchestrate-task.md.tmpl"
test -f "$commands_dir/orchestrate-epic.md.tmpl"
test ! -e "$source_dir/dot_config/opencode/skills/orchestration-worker-delivery/SKILL.md"
assert_contains "$commands_dir/orchestrate-task.md.tmpl" 'exactly one concrete task, bug, feature, or chore'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'For an epic, treat the epic as a coordination container and never assign its implementation directly to a worker.'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'dependency-respecting waves'
assert_not_contains "$commands_dir/orchestrate-task.md.tmpl" 'orchestration-worker-delivery'
assert_not_contains "$commands_dir/orchestrate-epic.md.tmpl" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/dot_config/opencode/agents/orchestrator.md" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/.chezmoiignore" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/.chezmoiremove.tmpl" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/README.md" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/INVENTORY.md" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/docs/opencode-agent-orchestration.md" 'orchestration-worker-delivery'
assert_not_contains "$commands_dir/orchestrate-epic.md.tmpl" 'For a task, bug, feature, or chore'
assert_not_contains "$commands_dir/orchestrate-epic.md.tmpl" 'worker tab worker <absolute-delivery-worktree-path>'
assert_not_contains "$commands_dir/orchestrate-epic.md.tmpl" 'ordinary work'
assert_not_contains "$commands_dir/orchestrate-task.md.tmpl" 'If the user selects architecture'
assert_not_contains "$commands_dir/orchestrate-task.md.tmpl" 'single-Bead flow'
assert_not_contains "$commands_dir/orchestrate-task.md.tmpl" '## Contract-First Parallelism'
assert_not_contains "$commands_dir/orchestrate-task.md.tmpl" 'dependency-respecting waves'

git show HEAD:dot_config/opencode/commands/orchestrate.md >"$root/orchestrate-baseline.md"
git show HEAD:dot_config/opencode/commands/orchestrate-bead.md.tmpl >"$root/orchestrate-bead-baseline.md.tmpl"
python3 - "$root/orchestrate-baseline.md" "$root/orchestrate-bead-baseline.md.tmpl" \
  "$commands_dir/orchestrate-task.md.tmpl" "$commands_dir/orchestrate-epic.md.tmpl" <<'PY'
import re
import sys
from pathlib import Path

ordinary, bead, task, epic = (Path(path).read_text() for path in sys.argv[1:])

def block(text, start, end=None):
    start_at = text.index(start)
    end_at = text.index(end, start_at) if end else len(text)
    return text[start_at:end_at]

def paragraph(text, start):
    start_at = text.index(start)
    end_at = text.find("\n\n", start_at)
    return text[start_at:] if end_at < 0 else text[start_at:end_at]

def require(text, fragment):
    assert fragment in text, fragment

def headings(text):
    return re.findall(r"^## .+$", text, re.MULTILINE)

ordinary_headings = headings(ordinary)
task_headings = headings(task)
assert ordinary_headings == task_headings, (ordinary_headings, task_headings)

bead_headings = headings(bead)
epic_headings = headings(epic)
assert epic_headings == bead_headings, (bead_headings, epic_headings)

# The baseline's external-OpenCode branch is retained verbatim in the epic
# destination, where the Bead coordination command remains installed.
external_start = bead.rfind("{{- if .modules.opencode }}")
external_end = bead.index("{{- end }}", external_start) + len("{{- end }}")
external_section = bead[external_start:external_end]
assert external_section in epic
epic_order = [
    epic.index("## Contract-First Parallelism"),
    epic.index("## Scope And Complexity Gate"),
    epic.index("## Worker Lifecycle"),
    epic.index("You own review and cross-Bead coordination."),
    epic.index("After all epic children are delivered"),
    epic.index("{{- if .modules.opencode }}", epic.index("After all epic children are delivered")),
    epic.index("## Delivery"),
]
assert epic_order == sorted(epic_order), epic_order

# Exact original paragraphs and section blocks are redistributed without rewriting.
require(task, paragraph(ordinary, "For ordinary work,"))
require(task, "For a private Bead argument, also load the `beads-hub` skill and follow its contract. Load `write-bead` only when creating or materially updating a Bead description.")
require(task, "For a private Bead argument, inspect the exact Bead with `wbd show <id> --json` and verify its type, status, contexts, repository placement, structured scope, acceptance criteria, and approved decisions before acting.")
task_review = paragraph(ordinary, "After worker handoff,")
task_review = task_review.replace(
    " Send accepted findings only to that worker;",
    " For an existing concrete Bead, give the reviewer the same exact concrete Bead ID as its worker and the relevant epic ID, and require it to read those authoritative records. Send accepted findings only to that worker;"
)
require(task, task_review)
require(task, paragraph(ordinary, "Treat this gate as the orchestrator"))
task_lifecycle = paragraph(ordinary, "Retain the launcher's returned metadata")
task_lifecycle = task_lifecycle.replace(" This avoids delivery gaps before handoff, review, and next-wave launch.", " This avoids delivery gaps before handoff and review.")
task_lifecycle = task_lifecycle.replace(" When the worker settles, consume its handoff and immediately advance its review, correction, integration, or dependency step in the same authorized loop.", " When the worker settles, consume its handoff and immediately advance its review, correction, or integration step in the same authorized loop.")
task_lifecycle = task_lifecycle.replace(" After delivery of a completed child or wave, recompute dependency readiness and immediately launch the next authorized ready wave.", "")
require(task, paragraph(ordinary, "Own worker startup and shutdown."))
require(task, task_lifecycle)
require(task, paragraph(bead, "From worker handoff through review/correction"))
require(epic, block(bead, "## Contract-First Parallelism", "For each concrete Bead selected for the current wave"))
require(epic, paragraph(bead, "For each concrete Bead selected for the current wave"))
require(epic, paragraph(bead, "Every fresh worker launch prompt"))
require(epic, paragraph(bead, "Each worker owns only its assigned child contract"))
require(epic, paragraph(bead, "Treat this gate as the orchestrator"))
require(epic, paragraph(bead, "You own worker startup and shutdown."))
require(epic, paragraph(bead, "You own review and cross-Bead coordination."))
require(epic, paragraph(bead, "From worker handoff through review/correction"))
require(task, "For an explicitly supplied concrete Bead, invoke `~/.local/bin/herdr-agent-launch worker worktree")
reviewer_handoff = "For an existing concrete Bead, give the reviewer the same exact concrete Bead ID as its worker and the relevant epic ID, and require it to read those authoritative records."
require(task, reviewer_handoff)
assert task.index(reviewer_handoff) < task.index("Send accepted findings only to that worker")

# Existing concrete-Bead excerpts belong to the task command; epic-only
# coordination excerpts belong to the epic command.
require(task, "inspect the exact Bead with `wbd show <id> --json` and verify its type, status, contexts, repository placement, structured scope, acceptance criteria, and approved decisions before acting.")
require(task, "Keep all private Bead IDs and `ctx:` identities out of Git-visible names, files, and reports; retain them only in private runtime prompts or ledger state.")
require(task, "When tracker tools are available for a selected private Bead, call `tracking_bead_select({ beadID })` from the root session only after the explicit existing-Bead selection/resume has succeeded and the selected Bead has passed exact validation.")
require(task, "For a selected private Bead, pass the already-validated concrete Bead ID to the worker launcher through `--tracking-bead <bead-id>` for tracker attribution; this does not select the Hub claim target. The launcher writes the exact-session descriptor before startup.")
require(task, "For an explicitly supplied concrete Bead, invoke `~/.local/bin/herdr-agent-launch worker worktree <worker-name> <dedicated-worktree-path> --tracking-bead <bead-id>`")
require(task, "Before every fresh worker launch, submit one self-contained contract.")
assert task.index("wbd claim <bead-id> --json") < task.index('herdr agent prompt <worker-name> "<contract>" --wait')
require(epic, "Before launching epic workers, read the canonical concrete children and build a dependency DAG from their genuine Hub relationships.")
require(epic, "Schedule epic children in dependency-respecting waves.")
require(epic, "After all epic children are delivered, validate the epic outcome against the epic's own acceptance criteria")
assert "For a task, bug, feature, or chore" not in epic
assert "worker tab worker <absolute-delivery-worktree-path>" not in epic
assert "Contract-First Parallelism" not in task
assert "dependency-respecting waves" not in task
assert "If the user selects architecture" not in task
assert task.count("## Fresh Worker Prompt") == 1
assert task.count("## Scope And Complexity Gate") == 1
assert task.count("## Worker Lifecycle") == 1
assert task.count("## Delivery") == 1
assert task.count("Use these labeled fields in this order:") == 1
assert task.count("After worker handoff, follow this lifecycle.") == 1
assert task.count("Own worker startup and shutdown.") == 1
assert task.count("From worker handoff through review/correction") == 1
ordinary_launch = task.index("For ordinary work,")
existing_launch = task.index("For an explicitly supplied concrete Bead,")
assert ordinary_launch < existing_launch
assert "otherwise preserve the non-Bead flow without a claim" in task[ordinary_launch:existing_launch]
assert "wbd claim <bead-id> --json" in task[existing_launch:]
task_order = [
    task.index("## Fresh Worker Prompt"),
    ordinary_launch,
    task.index("After worker handoff, follow this lifecycle."),
    task.index("## Scope And Complexity Gate"),
    task.index("## Worker Lifecycle"),
    task.index("## Delivery"),
]
assert task_order == sorted(task_order), task_order
assert "For an explicitly supplied concrete Bead" not in epic
assert "worker tab worker <absolute-delivery-worktree-path>" not in epic

# The only removed baseline wording is dependency-wave scheduling from the task
# lifecycle; it remains verbatim in the epic command.
wave = "After delivery of a completed child or wave, recompute dependency readiness and immediately launch the next authorized ready wave."
assert wave not in task
require(epic, wave)

section_map = {
    "ordinary ## Fresh Worker Prompt": "task",
    "ordinary ## Scope And Complexity Gate": "task",
    "ordinary ## Worker Lifecycle": "task",
    "ordinary ## Delivery": "task",
    "Bead ## Contract-First Parallelism": "epic",
    "Bead ## Scope And Complexity Gate": "epic",
    "Bead ## Worker Lifecycle": "epic",
    "Bead ## Delivery": "epic (shared child delivery) and task (selected concrete Bead)",
    "Bead external-OpenCode conditional section": "epic",
}
print("section map:")
for section, destination in section_map.items():
    print(f"  {section} -> /orchestrate-{destination}")
print(f"ordinary sections: {ordinary_headings} -> /orchestrate-task")
print(f"Bead sections: {bead_headings} -> /orchestrate-epic, with concrete-Bead preamble -> /orchestrate-task")
print("exact baseline wording/section mapping: PASS")
PY

apply_fixture() {
  local fixture=$1
  local home="$root/$fixture/home"
  mkdir -p "$home/.config/opencode/skills"
  chezmoi apply --source "$source_dir" --destination "$home" \
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$cache/$fixture" \
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
    --config "$source_dir/tests/fixtures/$fixture.toml" --cache "$cache/$fixture" \
    --persistent-state "$root/$fixture/state.boltdb" --exclude scripts,externals --force
  test ! -e "$home/.config/opencode/command/orchestrate-bead.md"
  test ! -e "$home/.config/opencode/commands/orchestrate-bead.md"
  test ! -e "$home/.config/opencode/skills/work-beads/SKILL.md"
  test ! -e "$home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
done
