#!/usr/bin/env bash
set -euo pipefail

source_dir=/src
root=/tmp/dotfiles-test
rm -rf "$root"
mkdir -p "$root"

safety_pattern='(/'"Users/|1628"'1580|Opa'"rah|8f84"'64|sk-[A-Za-z0-9]{16,})'
if grep -R -E \
  --exclude-dir=.git \
  --exclude-dir=.idea \
  --exclude='*.iml' \
  "$safety_pattern" \
  "$source_dir" >/dev/null; then
  printf 'public-safety scan found a personal path, identifier, or credential-like value.\n' >&2
  exit 1
fi

render_scripts() {
  local name=$1
  local config="$source_dir/tests/fixtures/$name.toml"
  local rendered="$root/$name/rendered"
  mkdir -p "$rendered"
  for template in "$source_dir"/run_*.tmpl; do
    output="$rendered/${template##*/}"
    chezmoi execute-template --source "$source_dir" --config "$config" <"$template" >"$output"
    sh -n "$output"
  done
  chezmoi execute-template --source "$source_dir" --config "$config" \
    <"$source_dir/.chezmoiexternal.toml.tmpl" >"$rendered/externals.toml"
  python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$rendered/externals.toml"
  chezmoi execute-template --source "$source_dir" --config "$config" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$rendered/Brewfile"
}

apply_fixture() {
  local name=$1
  local home="$root/$name/home"
  local config="$source_dir/tests/fixtures/$name.toml"
  mkdir -p "$home"
  chezmoi apply \
    --source "$source_dir" \
    --destination "$home" \
    --config "$config" \
    --cache "$root/$name/cache" \
    --persistent-state "$root/$name/chezmoistate.boltdb" \
    --exclude scripts,externals \
    --force
}

assert_contains() {
  local file=$1
  local text=$2
  grep -Fq "$text" "$file" || {
    printf 'expected %s to contain: %s\n' "$file" "$text" >&2
    exit 1
  }
}

assert_not_contains() {
  local file=$1
  local text=$2
  if grep -Fq "$text" "$file"; then
    printf 'expected %s not to contain: %s\n' "$file" "$text" >&2
    exit 1
  fi
}

personal_home="$root/personal/home"
render_scripts personal
assert_contains "$root/personal/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "elio"'
apply_fixture personal

test -f "$personal_home/Library/Application Support/com.mitchellh.ghostty/config"
test -f "$personal_home/.config/herdr/plugins/config/herdr-file-viewer/config.toml"
test -f "$personal_home/.config/opencode/portable.jsonc"
test -f "$personal_home/.config/opencode/tui.jsonc"
test -L "$personal_home/.config/starship/current.toml"
test -f "$personal_home/.config/zsh/portable.zsh"
test -f "$personal_home/.config/git/portable.inc"
test ! -e "$personal_home/README.md"
test ! -e "$personal_home/tests"
jq -e '.provider.openai and (.plugin | index("opencode-lmstudio@1.0.0-rc.2"))' "$personal_home/.config/opencode/portable.jsonc" >/dev/null
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$personal_home/.config/herdr/config.toml"
zsh -n "$personal_home"/.config/zsh/*.zsh

work_home="$root/work/home"
render_scripts work
assert_not_contains "$root/work/rendered/Brewfile" 'cask "lm-studio"'
assert_not_contains "$root/work/rendered/Brewfile" 'brew "elio"'
mkdir -p "$work_home/.config/opencode"
cat >"$work_home/.zshrc" <<'EOF'
ZSH_THEME="agnoster"
eval "$(direnv hook zsh)"
export PRIVATE_WORK_SHELL_VALUE=present
EOF
cat >"$work_home/.gitconfig" <<'EOF'
[user]
	name = Work User
	email = work@example.invalid
EOF
cat >"$work_home/.config/opencode/opencode.jsonc" <<'EOF'
{
  "provider": {
    "work-private-provider": {
      "models": {"private-model": {}}
    }
  },
  "work_private_setting": true
}
EOF
cat >"$work_home/.config/opencode/tui.jsonc" <<'EOF'
{"work_private_tui_setting": true}
EOF

apply_fixture work
assert_contains "$work_home/.zshrc" 'ZSH_THEME="agnoster"'
assert_contains "$work_home/.zshrc" 'direnv hook zsh'
assert_contains "$work_home/.zshrc" 'portable chezmoi setup'
assert_contains "$work_home/.gitconfig" 'email = work@example.invalid'
assert_contains "$work_home/.gitconfig" '.config/git/portable.inc'
assert_contains "$work_home/.config/opencode/opencode.jsonc" 'work-private-provider'
assert_contains "$work_home/.config/opencode/tui.jsonc" 'work_private_tui_setting'
assert_not_contains "$work_home/.config/opencode/portable.jsonc" '"provider"'
assert_not_contains "$work_home/.config/opencode/portable.jsonc" 'opencode-lmstudio'
assert_not_contains "$work_home/.config/herdr/config.toml" 'herdr-logbook'
test ! -e "$work_home/.config/herdr/plugins/config/herdr-file-viewer/config.toml"
jq -e '(.plugin | index("opencode-handoff@0.5.0"))' "$work_home/.config/opencode/portable.jsonc" >/dev/null
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$work_home/.config/herdr/config.toml"
zsh -n "$work_home"/.config/zsh/*.zsh

before=$(find "$work_home" -type f -exec sha256sum {} + | sort)
apply_fixture work
after=$(find "$work_home" -type f -exec sha256sum {} + | sort)
test "$before" = "$after"
remaining_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$work_home" \
  --config "$source_dir/tests/fixtures/work.toml" \
  --cache "$root/work/cache" \
  --persistent-state "$root/work/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$remaining_diff"
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$work_home/.zshrc")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$work_home/.gitconfig")" -eq 1

ghostty_home="$root/ghostty-only/home"
render_scripts ghostty-only
apply_fixture ghostty-only
test -f "$ghostty_home/Library/Application Support/com.mitchellh.ghostty/config"
test ! -e "$ghostty_home/.config/herdr/config.toml"
test ! -e "$ghostty_home/.config/opencode/portable.jsonc"
test ! -e "$ghostty_home/.config/starship/current.toml"
test ! -e "$ghostty_home/.config/zsh/portable.zsh"
test ! -e "$ghostty_home/.config/git/portable.inc"

printf 'Docker dotfiles validation passed.\n'
