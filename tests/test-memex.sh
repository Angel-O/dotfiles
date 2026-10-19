#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=/tmp/dotfiles-memex-test
rm -rf "$root"
mkdir -p "$root/bin" "$root/home"
cache=${CHEZMOI_TEST_CACHE:-$root/cache}

assert_contains() {
  local file=$1 text=$2
  grep -Fq -- "$text" "$file" || {
    printf 'expected %s to contain: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_not_contains() {
  local file=$1 text=$2
  if grep -Fq -- "$text" "$file"; then
    printf 'expected %s not to contain: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

render() {
  local fixture=$1 output=$2
  mkdir -p "$output"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" \
    <"$source_dir/run_before_10-install-packages.sh.tmpl" >"$output/packages.sh"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" \
    <"$source_dir/run_after_20-install-memex-skill.sh.tmpl" >"$output/skill.sh"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$output/Brewfile"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" \
    <"$source_dir/dot_config/opencode/portable.jsonc.tmpl" >"$output/portable.json"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" \
    <"$source_dir/dot_config/herdr/config.toml.tmpl" >"$output/herdr.toml"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" \
    <"$source_dir/run_after_30-install-herdr-plugins.sh.tmpl" >"$output/herdr.sh"
  sh -n "$output/packages.sh" "$output/skill.sh" "$output/herdr.sh"
  python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$output/herdr.toml"
  jq empty "$output/portable.json"
}

render personal "$root/personal"
skill="$source_dir/dot_config/opencode/skills/memex-quick-search/SKILL.md"
test -f "$skill"
assert_contains "$skill" 'name: memex-quick-search'
assert_contains "$skill" 'allowed-tools: Bash(memex:*)'
assert_contains "$skill" 'memex search "<one query>" --unique-session --limit 1 --fields session_id,ts,role,snippet --format toon --non-interactive'
assert_contains "$skill" 'memex search "<one query>" --unique-session --limit 1 --fields session_id,ts,role,snippet,record_id,machine --format toon --non-interactive'
assert_not_contains "$skill" '--cwd .'
assert_contains "$skill" 'Only when verification or surrounding context is needed'
assert_contains "$skill" 'query with identifiers included:'
assert_contains "$skill" 'Use the returned `record_id` and `machine` for bounded follow-up.'
assert_contains "$skill" 'Stop when the result is direct and unambiguous.'
assert_contains "$skill" 'memex show --record-id <record_id> --machine <machine_id> --non-interactive'
assert_contains "$skill" 'memex context --record-id <record_id> --machine <machine_id> --before 1 --after 1 --max-chars 4000 --non-interactive'
assert_contains "$skill" 'Do not use `memex session` for ordinary lookup or read a full session.'
assert_contains "$skill" 'ambiguous discovery'
assert_contains "$skill" 'multi-session synthesis'
assert_contains "$skill" 'transcript reconstruction'
assert_contains "$skill" 'analogous-work'
assert_contains "$skill" 'investigation'
managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" --exclude externals --include files)
printf '%s\n' "$managed" | grep -Fxq '.config/opencode/skills/memex-quick-search/SKILL.md'

coexist_home="$root/coexist-home"
mkdir -p "$coexist_home/.agents/skills/memex-search"
printf '%s\n' 'release-managed upstream skill' >"$coexist_home/.agents/skills/memex-search/SKILL.md"
chezmoi apply --source "$source_dir" --destination "$coexist_home" \
  --config "$source_dir/tests/fixtures/personal.toml" \
  --cache "$cache" --persistent-state "$root/coexist-state.boltdb" \
  --exclude scripts,externals --force
test -f "$coexist_home/.agents/skills/memex-search/SKILL.md"
assert_contains "$coexist_home/.agents/skills/memex-search/SKILL.md" 'release-managed upstream skill'
cmp -s "$skill" "$coexist_home/.config/opencode/skills/memex-quick-search/SKILL.md"

assert_contains "$root/personal/Brewfile" 'brew "memex"'
assert_not_contains "$root/personal/Brewfile" 'version:'
assert_contains "$root/personal/packages.sh" 'brew bundle check'
assert_contains "$root/personal/packages.sh" 'brew bundle install'
assert_contains "$root/personal/packages.sh" 'HOMEBREW_BUNDLE_NO_UPGRADE=1'
assert_contains "$root/personal/skill.sh" 'memex skill status --target shared'
assert_contains "$root/personal/skill.sh" 'memex skill install --target shared'
assert_contains "$root/personal/skill.sh" 'memex skill update --target shared'
assert_not_contains "$root/personal/skill.sh" 'minimum_version'
assert_not_contains "$root/personal/skill.sh" 'memex --version'
grep -Eq '^ensure_github_plugin nicosuave\.memex "nicosuave/memex" "v0\.[0-9]+\.[0-9]+"$' "$root/personal/herdr.sh"
assert_contains "$root/personal/herdr.toml" 'key = "prefix+ctrl+m"'
assert_contains "$root/personal/herdr.toml" 'command = "nicosuave.memex.palette"'
jq -e '(.plugins | all(.[]; (if type == "string" then contains("history") | not else true end))) and (has("mcp") | not) and (has("mcpServers") | not) and (.permission | tostring | contains("memex_") | not)' \
  "$root/personal/portable.json" >/dev/null

mkdir -p "$root/fake-home/.agents/skills/memex-search" "$root/fake-bin"
cat >"$root/fake-bin/memex" <<'EOF'
#!/bin/sh
if [ "$1" = skill ] && [ "$2" = status ]; then
  printf 'shared: %s (/fake-home/.agents/skills/memex-search/SKILL.md)\n' "${MEMEX_SKILL_STATUS:-not installed}"
  exit 0
fi
printf '%s\n' "$*" >>"$MEMEX_LOG"
EOF
chmod +x "$root/fake-bin/memex"
MEMEX_LOG="$root/missing.log" HOME="$root/fake-home" PATH="$root/fake-bin:$PATH" \
  sh "$root/personal/skill.sh"
grep -Fxq 'skill install --target shared' "$root/missing.log"
printf '%s\n' installed >"$root/fake-home/.agents/skills/memex-search/SKILL.md"
MEMEX_SKILL_STATUS='current' MEMEX_LOG="$root/current.log" HOME="$root/fake-home" PATH="$root/fake-bin:$PATH" \
  sh "$root/personal/skill.sh"
test ! -s "$root/current.log"
MEMEX_SKILL_STATUS='outdated or locally modified' MEMEX_LOG="$root/stale.log" HOME="$root/fake-home" PATH="$root/fake-bin:$PATH" \
  sh "$root/personal/skill.sh"
grep -Fxq 'skill update --target shared' "$root/stale.log"

render herdr-disabled-plugins "$root/disabled"
assert_not_contains "$root/disabled/Brewfile" 'brew "memex"'
assert_not_contains "$root/disabled/herdr.toml" 'nicosuave.memex'
grep -Fxq 'exit 0' "$root/disabled/skill.sh"

render herdr-missing-memex "$root/missing-memex"
assert_contains "$root/missing-memex/Brewfile" 'brew "memex"'
assert_contains "$root/missing-memex/herdr.sh" 'nicosuave.memex'
assert_contains "$root/missing-memex/herdr.toml" 'command = "nicosuave.memex.palette"'

printf 'Memex focused contract tests passed.\n'
