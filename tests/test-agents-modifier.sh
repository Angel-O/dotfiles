#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

line='When locating a named local repository, look under ~/workspace/source/.'
heading='## REPOSITORY ROOT'
modifier="$root/modify.sh"
disabled_modifier="$root/modify-disabled.sh"

assert_repository_section() {
  python3 - "$1" <<'PY'
import sys

lines = open(sys.argv[1]).read().splitlines()
section = [
    "## REPOSITORY ROOT",
    "When locating a named local repository, look under ~/workspace/source/.",
]
assert sum(lines[index:index + 2] == section for index in range(len(lines))) == 1
PY
}

chezmoi execute-template --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal-with-beads.toml" \
  <"$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" >"$modifier"
chezmoi execute-template --source "$source_dir" \
  --config "$source_dir/tests/fixtures/beads-integration-disabled.toml" \
  <"$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" >"$disabled_modifier"
sh -n "$modifier"
sh -n "$disabled_modifier"

cat >"$root/before" <<'EOF'
# Existing user guidance
<!-- portable-work-beads:start -->
stale managed content
<!-- portable-work-beads:end -->
Preserve this unrelated instruction.
EOF

sh "$modifier" <"$root/before" >"$root/enabled"
assert_repository_section "$root/enabled"
test "$(grep -Fxc -- "$heading" "$root/enabled")" -eq 1
test "$(grep -Fxc -- "$line" "$root/enabled")" -eq 1
grep -Fxq '# Existing user guidance' "$root/enabled"
grep -Fxq 'Preserve this unrelated instruction.' "$root/enabled"
grep -Fxq '## Private Beads Hub' "$root/enabled"
grep -Fq 'Commit correlation and Bead closure must not occur during implementation' "$root/enabled"
! grep -Fq 'stale managed content' "$root/enabled"
sh "$modifier" <"$root/enabled" >"$root/enabled-second"
cmp -s "$root/enabled" "$root/enabled-second"

sh "$disabled_modifier" <"$root/enabled" >"$root/disabled"
assert_repository_section "$root/disabled"
test "$(grep -Fxc -- "$heading" "$root/disabled")" -eq 1
test "$(grep -Fxc -- "$line" "$root/disabled")" -eq 1
! grep -Fq '<!-- portable-beads-hub:start -->' "$root/disabled"
grep -Fxq 'Preserve this unrelated instruction.' "$root/disabled"

apply_fixture() {
  local name=$1
  local home="$root/$name/home"
  mkdir -p "$home/.config/opencode/skills"
  printf '%s\n' 'Preserve this deployed instruction.' >"$home/.config/opencode/AGENTS.md"
  chezmoi apply \
    --source "$source_dir" \
    --destination "$home" \
    --config "$source_dir/tests/fixtures/$name.toml" \
    --cache "$root/$name/cache" \
    --persistent-state "$root/$name/state.boltdb" \
    --exclude scripts,externals \
    --force
  printf '%s\n' "$home"
}

enabled_home=$(apply_fixture personal-with-beads)
assert_repository_section "$enabled_home/.config/opencode/AGENTS.md"
test "$(grep -Fxc -- "$line" "$enabled_home/.config/opencode/AGENTS.md")" -eq 1
grep -Fxq 'Preserve this deployed instruction.' "$enabled_home/.config/opencode/AGENTS.md"

disabled_home=$(apply_fixture beads-integration-disabled)
assert_repository_section "$disabled_home/.config/opencode/AGENTS.md"
test "$(grep -Fxc -- "$line" "$disabled_home/.config/opencode/AGENTS.md")" -eq 1
grep -Fxq 'Preserve this deployed instruction.' "$disabled_home/.config/opencode/AGENTS.md"
