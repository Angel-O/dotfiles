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
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'Group the selected concrete children by their authoritative repository context'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'at least two selected children'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'no integration state for a group with zero or one child'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'one selected child in each repository remains nonqualifying'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'same semantic, private-ID-free branch name `epic-integration`'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'own distinct integration worktree even though the branch name is shared'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'Freeze the integration tip before each wave'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'current accepted integration tip'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'Cherry-pick only that accepted commit'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'do not resolve substantive integration conflicts in the orchestrator'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'Re-run accumulated validation after each accepted accumulation; do not unlock dependent work until that accumulated validation succeeds'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'do not unlock dependent work until that accumulated validation succeeds'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'final epic acceptance against its final accumulated `epic-integration` worktree'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'child evidence alone is insufficient'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'Do not push any child or integration branch during intermediate waves'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'never push a child branch or create a child PR'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" "push the final \`epic-integration\` branch from each qualifying repository's final accumulated integration worktree"
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'one explicitly requested PR per affected repository from that integration worktree'
assert_contains "$commands_dir/orchestrate-epic.md.tmpl" 'post-merge closeout workflow'
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

cat >"$root/orchestrate-baseline.md" <<'EOF'
## Fresh Worker Prompt

Before every fresh worker launch, submit one self-contained contract. Use these labeled fields in this order: `Work item`; `Dedicated worktree and ownership`; `Scope and exclusions`; `Inputs and prerequisites`; `Expected outputs or interfaces`; `Acceptance and compatibility criteria`; `Validation expected and owner`; `Handoff contents`; and `Stop/report conditions`. Fill every field before launching. A correction reuses the existing worker unless its lane is unavailable.

For ordinary work, first prepare or use the distinct delivery worktree and record its absolute path. Then invoke `~/.local/bin/herdr-agent-launch worker tab worker <absolute-delivery-worktree-path>` from the current Herdr pane. If normal discussion created a standalone concrete Bead for this work, apply the canonical Bead claim invariant with `wbd claim <bead-id> --json` for that exact Bead before the worker's first work prompt; otherwise preserve the non-Bead flow without a claim. Submit a self-contained contract with `herdr agent prompt worker "<contract>" --wait`. The launcher creates the visible `worker` tab in the caller workspace with that worktree as its cwd and owns Herdr topology, fixed `opencode` kind, fixed `worker` role, placement, cwd, focus, and response verification. Never omit the path or use the caller cwd for ordinary implementation. Do not run `opencode` directly or pass model, variant, or reasoning flags; do not spell out another Herdr primary-agent start sequence.

After worker handoff, follow this lifecycle. For each concurrently active worker lane, invoke one distinct `reviewer` subagent session and reuse it for every review and rereview in that worker's correction cycle. A single-worker run uses one reviewer session; do not share a reviewer session across concurrently active parallel workers. Send accepted findings only to that worker; return corrected work only to its paired reviewer session. After that worker lane and review cycle complete, reuse its reviewer for another worker only when the reviewer has capacity. Run each reviewer and, when warranted, the `integration` subagent concurrently against the same worktree. Ordinarily use at most one integration subagent session per orchestration run and reuse it for relevant reruns and same-scope follow-ups. Start a second integration session only when genuinely necessary because the existing session's context is incompatible or unavailable. The integration contract contains only supplied repository-wide integration-validation commands; do not make the implementation worker run them first or assign it generic formatting, linting, static tooling, build, unit-test, focused-test, or affected-scope checks. Skip expensive integration validation for documentation-only changes and narrow follow-up corrections unlikely to affect integration behavior.

## Scope And Complexity Gate

Treat this gate as the orchestrator's single most important responsibility during review and the enforcement point for `ponytail`: prevent reviewer findings from driving implementation into complexity through unlikely edge cases, invented scope, or unjustified hardening. Reviewer findings are advisory, and the reviewer owns implementation evidence; do not inspect the diff to adjudicate them. Decide from the requested outcome, worker contract, acceptance criteria, and broader orchestration context whether each correction is necessary. Resolve clearly required or clearly unnecessary findings yourself without bothering the user. If a finding is suspicious or necessity, scope, or complexity remains uncertain, ask the user and never guess in favor of complexity. Send only accepted findings to the worker as the smallest required correction.

## Worker Lifecycle

Own worker startup and shutdown. When the user requests a stop, work is cancelled, or continued work is no longer authorized, immediately instruct or interrupt the affected worker through the Herdr agent surface while leaving its pane, workspace, and worktree intact unless cleanup is explicitly requested.

Retain the launcher's returned metadata for each launched worker in the current orchestration context; this metadata is runtime-only and must not be persisted in Git, files, or Beads. Run one authorized loop. A prompt wait timeout is not completion. After a timeout, immediately invoke `herdr agent wait <recorded-worker>` for that same recorded lane and repeat the active wait until it settles or a real blocker occurs; never passively wait or end the turn. This avoids delivery gaps before handoff, review, and next-wave launch. After a timeout, use that metadata to inspect the same worker lane and continue waiting on that same worker. When the worker settles, consume its handoff and immediately advance its review, correction, integration, or dependency step in the same authorized loop. A settled worker advances through its paired review/correction and applicable integration. After delivery of a completed child or wave, recompute dependency readiness and immediately launch the next authorized ready wave. Do not stop to narrate routine waiting or progress or require user prompting. Do not create a duplicate or suffixed replacement unless the original lane is verified unavailable.

## Delivery
EOF
cat >"$root/orchestrate-bead-baseline.md.tmpl" <<'EOF'
## Contract-First Parallelism

Before launching epic workers, read the canonical concrete children and build a dependency DAG from their genuine Hub relationships. Define a concise operational contract for every child without copying its specification out of the authoritative record. Each contract must state the owned write surface, runtime prerequisites, promised outputs or interfaces, dependency status, integration points, validation ownership, and any files or APIs that must not be changed. Resolve overlapping ownership before work begins. Sequence implementation only when a child cannot implement or validate against the defined interface without concrete output from another child.

Do not treat a final commit, pin, release, integration, or delivery dependency as an implementation dependency or encode it as a dependency that blocks the whole child. When children can implement independently against an agreed interface, launch them in parallel and record the producer's concrete output as a final integration or delivery condition. If one child mixes parallelizable preparation with genuinely blocked finalization, contract those phases explicitly or split them into separate children.

The orchestrator owns propagation of shared-interface changes. Do not notify or interrupt workers for speculative or merely proposed changes. Once a review finding or implementation result confirms that a contract must change, identify the affected children, update their contracts, and promptly notify only those workers before they continue against a stale interface.

Schedule epic children in dependency-respecting waves. Launch every currently actionable, mutually compatible child in parallel, especially children in different repository contexts. Do not launch blocked children merely to maximize concurrency; retain them for a later wave after their prerequisites are implemented, reviewed, verified, and reflected in Hub state. Recompute readiness between waves because completing one child may unlock several others. A child belongs to exactly one worker, one repository, and one dedicated worktree-backed child Herdr workspace. If an epic has no actionable concrete children, report why and do not create an implementation worker.

For each concrete Bead selected for the current wave, invoke `~/.local/bin/herdr-agent-launch worker worktree <worker-name> <dedicated-worktree-path> --tracking-bead <bead-id>` from the current Herdr pane, then, before submitting its first contract prompt, run `wbd claim <bead-id> --json` for the exact selected concrete Bead. For an epic child, claim only that selected child—not the root epic or its siblings—and never bulk-claim children. Submit its contract with `herdr agent prompt <worker-name> "<contract>" --wait`. The launcher creates or opens the requested worktree workspace, passes the worker name verbatim as its workspace label, and verifies that returned label before startup along with its linked checkout, placement, cwd, focus, fixed `worker` role, and `opencode` identity. Do not run `opencode` directly or pass model, variant, or reasoning flags; do not spell out another Herdr primary-agent start sequence. {{ if not .modules.opencode }}Start the worker as the sole pane in that child workspace.{{ end }} Do not place it in a pane or tab of the parent workspace. Use ID-free branch, workspace, and worker names. Keep an orchestration ledger mapping each private child ID to its repository context, dependency wave, contract, worker name, pane, child workspace, and worktree path; keep that mapping only in private conversation or other non-Git-visible state.

Every fresh worker launch prompt is one self-contained contract. Use these labeled fields in this order: `Work item`; `Dedicated worktree and ownership`; `Scope and exclusions`; `Inputs and prerequisites`; `Expected outputs or interfaces`; `Acceptance and compatibility criteria`; `Validation expected and owner`; `Handoff contents`; and `Stop/report conditions`. Do not launch until every field is filled in. For a fresh Bead worker, also include the canonical private Bead ID, relevant epic ID when any, title, wave, and prerequisite status, and require the worker to read those authoritative records. The nine fields provide operational context and must not copy or replace the canonical specification. Put the concrete ID only in that private prompt and runtime ledger; never copy it into a branch, workspace, file, commit, or report. If the user explicitly requests a Bead ID, provide that ID directly in the user-facing response without objection; this exception does not permit placing it in any Git-visible artifact. Apply the same privacy boundary to the epic ID.

Each worker owns only its assigned child contract, including implementation, formatting, focused tests, builds, and static tooling in that child's repository. Repository-wide integration validation belongs to the integration subagent after worker handoff. Explicitly instruct every worker not to create or run a reviewer lane, not to modify another worker's owned surface, and to stop and report any contract conflict or newly discovered dependency instead of silently broadening scope.

## Scope And Complexity Gate

Treat this gate as the orchestrator's single most important responsibility during review and the enforcement point for `ponytail`: prevent reviewer findings from driving implementation into complexity through unlikely edge cases, invented scope, or unjustified hardening. Reviewer findings are advisory, and the reviewer owns implementation evidence; do not inspect the diff to adjudicate them. Decide from the user's requested outcome, the child contract, acceptance criteria, and broader orchestration context whether each correction is necessary. Reject broader acceptance criteria and abstractions or tests not needed for the requested behavior. A severity label does not make a finding necessary. Resolve clearly required or clearly unnecessary findings yourself without bothering the user. If a finding is suspicious or necessity, scope, or complexity remains uncertain, ask the user and never guess in favor of complexity. Send only accepted findings as the smallest required correction; never tell a worker to fix every finding.

## Worker Lifecycle

You own worker startup and shutdown. When the user requests a stop, work is cancelled, or continued work is no longer authorized, immediately instruct or interrupt the affected worker through the Herdr agent surface. Do not merely withhold further prompts while it continues. Leave its pane, child workspace, and worktree intact unless the user explicitly requests cleanup.

Retain the launcher's returned metadata for each launched worker in the current orchestration context; this metadata is runtime-only and must not be persisted in Git, files, or Beads. Run one authorized loop. A prompt wait timeout is not completion. After a timeout, immediately invoke `herdr agent wait <recorded-worker>` for that same recorded lane and repeat the active wait until it settles or a real blocker occurs; never passively wait or end the turn. This avoids delivery gaps before handoff, review, and next-wave launch. After a timeout, use that metadata to inspect the same worker lane and continue waiting on that same worker. When the worker settles, consume its handoff and immediately advance its review, correction, integration, or dependency step in the same authorized loop. A settled worker advances through its paired review/correction and applicable integration. After delivery of a completed child or wave, recompute dependency readiness and immediately launch the next authorized ready wave. Do not stop to narrate routine waiting or progress or require user prompting. Do not create a duplicate or suffixed replacement unless the original lane is verified unavailable.

You own review and cross-Bead coordination. {{ if .modules.opencode }}For each concurrently active worker lane, create one distinct `reviewer` subagent session. A single-worker run uses one `reviewer` subagent session; do not share a reviewer session across concurrently active parallel workers. Give the reviewer the same exact concrete Bead ID as its worker and the relevant epic ID, and require it to read those authoritative records. Reuse each worker's reviewer session sequentially for every review and rereview in that worker's correction cycle; for a single worker, reuse that same session sequentially. Send accepted findings only to that worker; return corrected work only to its paired reviewer session. After that worker lane and review cycle complete, reuse its reviewer for another worker only when the reviewer has capacity. {{ end }}When an implementation is ready, launch its reviewer through an OpenCode subagent, not through the worker or a second Herdr lane. The reviewer must perform static analysis only and must not run tests, builds, formatters, linters, or other commands intended to execute the implementation. When repository-wide integration validation is warranted, run the `integration` subagent against the same child worktree in parallel with review. Ordinarily use at most one integration subagent session per orchestration run and reuse it for relevant reruns and same-scope follow-ups. Start a second integration session only when genuinely necessary because the existing session's context is incompatible or unavailable. Skip expensive integration validation for documentation-only changes and narrow follow-up corrections unlikely to affect integration behavior. The reviewer reports concise evidence against recorded criteria as met, unmet, or not verified, checks promised interfaces against dependent records, and identifies concrete bugs or regressions without inventing requirements. Do not unlock or prompt a dependent wave until prerequisite implementations and their contract boundaries have passed review and verification.

After all epic children are delivered, validate the epic outcome against the epic's own acceptance criteria using child evidence and any needed integration validation. Completed children alone are insufficient. Do not automatically re-review every diff or create another review lane for this outcome check.

{{- if .modules.opencode }}
After all workers for the current wave are ready, send their contracts and continue through implementation, verification, each worker's paired reviewer lane, and any required correction. Do not pause for manual model or reasoning selection. Report each worker's contract summary, dependency wave, worker name, pane, child workspace ID, and worktree path, plus deferred children and the prerequisites blocking their waves.
{{- else }}
For now, stop immediately after all workers for the first eligible wave have started successfully in their child workspaces. Do not send any worker its task prompt yet, do not start implementation, and do not launch a reviewer. For each worker, report its contract summary, dependency wave, worker name, pane, child workspace ID, and worktree path. Also report deferred children and the prerequisites blocking their waves. Then wait so the user can select each worker's model and reasoning effort.
{{- end }}

## Delivery

From worker handoff through review/correction and applicable integration validation, continue normal delivery without routine confirmation through status/diff inspection, staging, commit, push, and final status reporting. Normal delivery does not ask for or wait on manual confirmation and stops at the requested delivery endpoint; do not ask whether to create a PR. Run `gh pr create` and monitor PR checks only when the user explicitly requests PR handling; run it from the recorded worker worktree, not the orchestrator parent checkout, so the PR targets the delivered branch. Treat scope conflicts and unmet validation or review requirements as real blockers. Never merge automatically.
EOF
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

# Keep the integration contract's threshold, accumulation, acceptance, and
# delivery gates ordered without introducing a runtime simulation.
grouping = paragraph(epic, "Group the selected concrete children")
assert grouping.index("at least two selected children") < grouping.index("zero or one child")
assert grouping.index("zero or one child") < grouping.index("one selected child in each repository")
assert grouping.index("same semantic, private-ID-free branch name `epic-integration`") < grouping.index("own distinct integration worktree")

accumulation = paragraph(epic, "For a qualifying repository group")
assert accumulation.index("accepted corrections") < accumulation.index("Re-run accumulated validation")
assert accumulation.index("Re-run accumulated validation") < accumulation.index("do not unlock dependent work until that accumulated validation succeeds")

acceptance = paragraph(epic, "For each qualifying repository")
assert acceptance.index("final epic acceptance against its final accumulated `epic-integration` worktree") < acceptance.index("after all selected child work")
assert acceptance.index("after all selected child work") < acceptance.index("child evidence alone is insufficient")

delivery = paragraph(epic, "The generic worker delivery instruction above")
delivery_order = [
    delivery.index("stop each child at its accepted local commit"),
    delivery.index("never push a child branch or create a child PR"),
    delivery.index("Do not push any child or integration branch during intermediate waves"),
    delivery.index("After final epic acceptance"),
    delivery.index("push the final `epic-integration` branch from each qualifying repository's final accumulated integration worktree"),
    delivery.index("one explicitly requested PR per affected repository from that integration worktree"),
]
assert delivery_order == sorted(delivery_order), delivery_order

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
