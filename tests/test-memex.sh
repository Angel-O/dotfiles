#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=/tmp/dotfiles-memex-test
rm -rf "$root"
mkdir -p "$root/bin" "$root/home"

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
assert_contains "$root/personal/herdr.sh" 'ensure_github_plugin nicosuave.memex "nicosuave/memex" "v0.28.0"'
assert_contains "$root/personal/herdr.toml" 'key = "prefix+ctrl+m"'
assert_contains "$root/personal/herdr.toml" 'command = "nicosuave.memex.palette"'
jq -e '(.plugin | all(.[]; contains("history") | not)) and (has("mcp") | not) and (has("mcpServers") | not) and (.permission | tostring | contains("memex_") | not)' \
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
assert_not_contains "$root/missing-memex/Brewfile" 'brew "memex"'
assert_not_contains "$root/missing-memex/herdr.sh" 'nicosuave.memex'
assert_not_contains "$root/missing-memex/herdr.toml" 'nicosuave.memex'

printf 'Memex focused contract tests passed.\n'
