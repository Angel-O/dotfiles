#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
command=$source_dir/dot_config/opencode/commands/materialize-epic.md.tmpl

assert_contains() {
  local file=$1 text=$2
  grep -Fq "$text" "$file" || {
    printf 'materialize-epic test: expected %s to contain: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_contains "$command" 'Load the `beads-hub` skill before acting.'
assert_contains "$command" 'use only `wbd` for Hub operations.'
assert_contains "$command" 'exactly one positional argument'
assert_contains "$command" 'Do not launch, ask for, redo, infer, summarize, repair, or alter architecture or planner work.'
assert_contains "$command" 'Require a non-empty, explicit approved architecture'
assert_contains "$command" 'Require an already active scope before creating any child; never create or activate a scope.'
assert_contains "$command" 'wbd show "$1" --json'
assert_contains "$command" 'wbd comments "$1" --json'
assert_contains "$command" 'wbd show "$1" --json --expand-dependencies'
assert_contains "$command" 'Compare every existing comment body'
assert_contains "$command" 'Stop and report if a comment matches that architecture exactly, or if any direct `parent-child` child exists.'
assert_contains "$command" 'Ignore unrelated comments; they do not indicate materialization.'
assert_contains "$command" 'byte-for-byte, as one comment on the epic'
assert_contains "$command" 'wbd comments add "$1" --file "$architecture_file" --json'
assert_contains "$command" 'wbd create "$title" --type "$type" --description "$description" --priority "$priority" --context "$context" --json'
assert_contains "$command" 'wbd scope add "$child_id" --context "$context" --json'
assert_contains "$command" 'operation` equal to `add`, `matched` equal to `1`, and `changed` equal to `1`'
assert_contains "$command" 'wbd dep add "$child_id" "$1" --type parent-child --json'
assert_contains "$command" 'wbd dep add "$blocked_child_id" "$blocker_child_id" --type blocks --json'
assert_contains "$command" 'stop immediately'
assert_contains "$command" 'Do not retry, rollback, delete, claim, close, link, launch workers, or begin implementation.'

python3 - "$command" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
validation = text.index('wbd show "$child_id" --json')
scope_add = text.index('wbd scope add "$child_id" --context "$context" --json')
parent_link = text.index('wbd dep add "$child_id" "$1" --type parent-child --json')
assert validation < scope_add < parent_link
PY

assert_contains "$source_dir/.chezmoiignore" '.config/opencode/commands/materialize-epic.md'
assert_contains "$source_dir/.chezmoiremove.tmpl" '.config/opencode/commands/materialize-epic.md'
assert_contains "$source_dir/README.md" '`materialize-epic` command consumes only an already approved architecture'
assert_contains "$source_dir/.chezmoidata.toml" 'ref = "401cd5bb31bc5181c829b205af9a2ca10198ea70"'

work=$(mktemp)
external=$(mktemp)
personal=$(mktemp)
trap 'rm -f "$work" "$external" "$personal"' EXIT
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$command" >"$work"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  <"$command" >"$external"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
  <"$command" >"$personal"
assert_contains "$work" 'agent: orchestrator'
if grep -Fq 'agent: orchestrator' "$external"; then
  printf 'materialize-epic test: external rendering selected the managed orchestrator\n' >&2
  exit 1
fi
