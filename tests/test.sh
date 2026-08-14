#!/usr/bin/env bash
set -euo pipefail

source_dir=/src
root=/tmp/dotfiles-test
rm -rf "$root"
mkdir -p "$root"

safety_pattern='(/'"Users/|1628"'1580|Opa'"rah|8f84"'64|sk-[A-Za-z0-9]{16,})'
if grep -R -E \
  --exclude-dir=.git \
  --exclude=.git \
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

assert_warp_policy() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); keys=data["terminal"]["input"]["extra_meta_keys"]; assert keys["left_alt"] is True; assert keys["right_alt"] is False' "$file"
}

warp_dir="$root/warp-modifier"
mkdir -p "$warp_dir"

run_warp_case() {
  local name=$1
  local before="$warp_dir/$name.before"
  local after="$warp_dir/$name.after"
  local second="$warp_dir/$name.second"
  sh "$source_dir/dot_warp/modify_settings.toml" <"$before" >"$after"
  assert_warp_policy "$after"
  sh "$source_dir/dot_warp/modify_settings.toml" <"$after" >"$second"
  cmp -s "$after" "$second"
}

: >"$warp_dir/empty.before"
run_warp_case empty
cat >"$warp_dir/empty.expected" <<'EOF'
[terminal.input.extra_meta_keys]
left_alt = true
right_alt = false
EOF
cmp -s "$warp_dir/empty.expected" "$warp_dir/empty.after"

cat >"$warp_dir/unrelated.before" <<'EOF'
# Keep this comment and spacing exactly.
[appearance]
theme = "Machine-specific theme"

[privacy]
telemetry = false
EOF
run_warp_case unrelated
assert_contains "$warp_dir/unrelated.after" '# Keep this comment and spacing exactly.'
assert_contains "$warp_dir/unrelated.after" 'theme = "Machine-specific theme"'
assert_contains "$warp_dir/unrelated.after" 'telemetry = false'
python3 -c 'import sys; before=open(sys.argv[1], "rb").read(); after=open(sys.argv[2], "rb").read(); policy=b"\n[terminal.input.extra_meta_keys]\nleft_alt = true\nright_alt = false\n"; assert after == before + policy' "$warp_dir/unrelated.before" "$warp_dir/unrelated.after"

cat >"$warp_dir/opposite.before" <<'EOF'
[terminal.input.extra_meta_keys]
left_alt = false # Warp default
right_alt = true

[editor]
font_size = 14
EOF
run_warp_case opposite
assert_contains "$warp_dir/opposite.after" 'left_alt = true # Warp default'
assert_contains "$warp_dir/opposite.after" 'right_alt = false'
assert_contains "$warp_dir/opposite.after" 'font_size = 14'

cat >"$warp_dir/missing.before" <<'EOF'
[terminal.input.extra_meta_keys]
left_alt = true

[terminal]
copy_on_select = true
EOF
run_warp_case missing
test "$(grep -Fc 'left_alt = true' "$warp_dir/missing.after")" -eq 1
test "$(grep -Fc 'right_alt = false' "$warp_dir/missing.after")" -eq 1
assert_contains "$warp_dir/missing.after" 'copy_on_select = true'

assert_contains "$source_dir/scripts/backup-paths.txt" '.config/ghostty'
assert_contains "$source_dir/scripts/backup-paths.txt" 'Library/Application Support/com.mitchellh.ghostty/config'
test "$(grep -Fxc '.warp/settings.toml' "$source_dir/scripts/backup-paths.txt")" -eq 1

backup_home="$root/backup-home"
backup_destination="$root/backup-output"
mkdir -p "$backup_home/.warp"
printf '%s\n' '[privacy]' 'telemetry = false' >"$backup_home/.warp/settings.toml"
printf '%s\n' 'synthetic runtime state' >"$backup_home/.warp/runtime-state"
HOME="$backup_home" sh "$source_dir/scripts/backup-home-paths.sh" --destination "$backup_destination"
cmp -s "$backup_home/.warp/settings.toml" "$backup_destination/.warp/settings.toml"
test ! -e "$backup_destination/.warp/runtime-state"

migration_dir="$root/zshrc-migration"
mkdir -p "$migration_dir"
cat >"$migration_dir/before" <<'EOF'
ZSH_THEME="agnoster"
# >>> portable chezmoi setup >>>
source "$HOME/.config/zsh/portable.zsh"
# <<< portable chezmoi setup <<<
EOF
sh "$source_dir/modify_dot_zshrc" <"$migration_dir/before" >"$migration_dir/after"
sh "$source_dir/modify_dot_zshrc" <"$migration_dir/after" >"$migration_dir/second-apply"
cmp -s "$migration_dir/after" "$migration_dir/second-apply"
test "$(grep -Fc '# >>> portable chezmoi early setup >>>' "$migration_dir/after")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$migration_dir/after")" -eq 1
test "$(grep -Fc 'ZSH_THEME="agnoster"' "$migration_dir/after")" -eq 1

personal_home="$root/personal/home"
render_scripts personal
assert_contains "$root/personal/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/personal/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "bat"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "git-delta"'
assert_contains "$source_dir/.chezmoi.toml.tmpl" 'sourceDir = {{ .chezmoi.sourceDir | quote }}'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin herdr-zoxide "den-tanui/herdr-zoxide"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin ez-corp.space-usage "ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin robert-flo.elio "robert-flo/herdr-terminal-file-manager"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root="$HOME/workspace/source/herdr-reviewr"'
apply_fixture personal

test -f "$personal_home/.config/ghostty/config"
test -f "$personal_home/.warp/settings.toml"
assert_warp_policy "$personal_home/.warp/settings.toml"
assert_contains "$personal_home/.config/ghostty/config" 'macos-option-as-alt = true'
assert_contains "$personal_home/.config/herdr/plugins/config/herdr-zoxide/config.toml" 'preview = "eza -la --tree --level=2 --icons=always --color=always {}"'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'ram_display = "absolute"'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "herdr-zoxide.browse"'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "robert-flo.elio.open"'
assert_contains "$personal_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_not_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_contains "$personal_home/.config/zsh/starship.zsh" '[[ ${TERM_PROGRAM:-} == "WarpTerminal" ]]'
assert_contains "$personal_home/.config/zsh/starship.zsh" "TRANSIENT_PROMPT_PROMPT=''"
assert_contains "$personal_home/.config/zsh/starship.zsh" 'Keep completed prompts compact in every terminal, including Warp.'
test -f "$personal_home/.config/opencode/portable.jsonc"
test -f "$personal_home/.config/opencode/tui.jsonc"
test -L "$personal_home/.config/starship/current.toml"
test -f "$personal_home/.config/zsh/portable.zsh"
test -f "$personal_home/.config/zsh/git-worktrees.zsh"
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" "alias gwtl='git wtl'"
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'gwtco() {'
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'gwts() {'
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'cdmain() {'
test -f "$personal_home/.config/git/portable.inc"
test ! -e "$personal_home/README.md"
test ! -e "$personal_home/tests"
jq -e '.provider.openai and (.plugin | index("opencode-lmstudio@1.0.0-rc.2"))' "$personal_home/.config/opencode/portable.jsonc" >/dev/null
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$personal_home/.config/herdr/config.toml"
zsh -n "$personal_home"/.config/zsh/*.zsh

work_home="$root/work/home"
render_scripts work
assert_contains "$root/work/rendered/Brewfile" 'brew "eza"'
assert_not_contains "$root/work/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "glow"'
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin herdr-zoxide "den-tanui/herdr-zoxide"'
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin persiyanov.reviewr "persiyanov/herdr-reviewr"'
assert_not_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin robert-flo.elio'
mkdir -p "$work_home/.config/opencode" "$work_home/.warp"
cat >"$work_home/.zshrc" <<'EOF'
ZSH_THEME="agnoster"
eval "$(direnv hook zsh)"
export PRIVATE_WORK_SHELL_VALUE=present
alias zconfig='code ~/.zshrc'
alias reload='source ~/.zshrc'
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
cat >"$work_home/.warp/settings.toml" <<'EOF'
# Synthetic machine-local Warp setting.
[privacy]
telemetry = false
EOF
cp "$work_home/.warp/settings.toml" "$root/work/warp-settings.before"

apply_fixture work
assert_contains "$work_home/.zshrc" 'ZSH_THEME="agnoster"'
assert_contains "$work_home/.zshrc" 'direnv hook zsh'
assert_contains "$work_home/.zshrc" 'portable chezmoi early setup'
assert_contains "$work_home/.zshrc" 'portable chezmoi setup'
assert_contains "$work_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
assert_contains "$work_home/.config/zsh/herdr-labels.zsh" 'angel-o.labels-*/shell/hook.zsh'
assert_not_contains "$work_home/.config/zsh/herdr.zsh" 'hook.zsh'
assert_contains "$work_home/.gitconfig" 'email = work@example.invalid'
assert_contains "$work_home/.gitconfig" '.config/git/portable.inc'
assert_contains "$work_home/.config/opencode/opencode.jsonc" 'work-private-provider'
assert_contains "$work_home/.config/opencode/tui.jsonc" 'work_private_tui_setting'
cmp -s "$root/work/warp-settings.before" "$work_home/.warp/settings.toml"
assert_not_contains "$work_home/.config/opencode/portable.jsonc" '"provider"'
assert_not_contains "$work_home/.config/opencode/portable.jsonc" 'opencode-lmstudio'
assert_not_contains "$work_home/.config/herdr/config.toml" 'robert-flo.elio.open'
assert_not_contains "$work_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_contains "$work_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
jq -e '(.plugin | index("opencode-handoff@0.5.0"))' "$work_home/.config/opencode/portable.jsonc" >/dev/null
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$work_home/.config/herdr/config.toml"
zsh -n "$work_home"/.config/zsh/*.zsh
HOME="$work_home" zsh -dfc 'alias zconfig="code ~/.zshrc"; alias reload="source ~/.zshrc"; source "$HOME/.config/zsh/helpers.zsh"'

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
test "$(grep -Fc '# >>> portable chezmoi early setup >>>' "$work_home/.zshrc")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$work_home/.zshrc")" -eq 1
test "$(grep -Fc '# >>> portable chezmoi setup >>>' "$work_home/.gitconfig")" -eq 1
early_line=$(grep -nF '# >>> portable chezmoi early setup >>>' "$work_home/.zshrc" | cut -d: -f1)
work_line=$(grep -nF 'ZSH_THEME="agnoster"' "$work_home/.zshrc" | cut -d: -f1)
normal_line=$(grep -nF '# >>> portable chezmoi setup >>>' "$work_home/.zshrc" | cut -d: -f1)
test "$early_line" -lt "$work_line"
test "$work_line" -lt "$normal_line"

shell_home="$root/shell-only/home"
render_scripts shell-only
assert_contains "$root/shell-only/rendered/Brewfile" 'brew "elio"'
apply_fixture shell-only
test -f "$shell_home/.config/zsh/early.zsh"
test ! -e "$shell_home/.warp"
assert_not_contains "$shell_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
assert_not_contains "$shell_home/.config/zsh/portable.zsh" 'herdr.zsh'
test "$(grep -Fc '# >>> portable chezmoi early setup >>>' "$shell_home/.zshrc")" -eq 1

disabled_home="$root/herdr-disabled-plugins/home"
render_scripts herdr-disabled-plugins
assert_contains "$root/herdr-disabled-plugins/rendered/Brewfile" 'brew "elio"'
assert_not_contains "$root/herdr-disabled-plugins/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'Angel-O/herdr-agent-resume'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'Angel-O/herdr-labels'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'beyondlex/herdr-recent-navigator'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'jeffarese/herdr-bar'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'den-tanui/herdr-zoxide'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'robert-flo/herdr-terminal-file-manager'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'persiyanov/herdr-reviewr'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root='
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'brew install rust'
apply_fixture herdr-disabled-plugins
test ! -e "$disabled_home/.warp"
assert_not_contains "$disabled_home/.config/herdr/config.toml" 'plugin_action'
assert_not_contains "$disabled_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_not_contains "$disabled_home/.config/herdr/config.toml" '"$usage"'
assert_not_contains "$disabled_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
test ! -e "$disabled_home/.config/herdr/reviewr-toggle-tab.sh"
test ! -e "$disabled_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/herdr-bar/config.json"
test ! -e "$disabled_home/.config/herdr/plugins/config/herdr-zoxide/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml"
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$disabled_home/.config/herdr/config.toml"

ghostty_home="$root/ghostty-only/home"
render_scripts ghostty-only
assert_contains "$root/ghostty-only/rendered/Brewfile" 'brew "eza"'
ghostty_old_dir="$ghostty_home/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$ghostty_old_dir"
printf '%s\n' '# exploratory comments' 'theme = Dracula' >"$ghostty_old_dir/config"
HOME="$ghostty_home" sh "$root/ghostty-only/rendered/run_once_after_25-migrate-ghostty-config.sh.tmpl"
test ! -e "$ghostty_old_dir/config"
ghostty_archive=$(find "$ghostty_old_dir" -name 'config.pre-chezmoi-*' -type f)
assert_contains "$ghostty_archive" '# exploratory comments'
HOME="$ghostty_home" sh "$root/ghostty-only/rendered/run_once_after_25-migrate-ghostty-config.sh.tmpl"
apply_fixture ghostty-only
test -f "$ghostty_home/.config/ghostty/config"
test ! -e "$ghostty_home/.warp"
test ! -e "$ghostty_home/.config/herdr/config.toml"
test ! -e "$ghostty_home/.config/opencode/portable.jsonc"
test ! -e "$ghostty_home/.config/starship/current.toml"
test ! -e "$ghostty_home/.config/zsh/portable.zsh"
test ! -e "$ghostty_home/.config/git/portable.inc"

warp_home="$root/warp-only/home"
render_scripts warp-only
mkdir -p "$warp_home/.warp"
cat >"$warp_home/.warp/settings.toml" <<'EOF'
# Synthetic setting that the modifier must preserve.
[privacy]
telemetry = false

[terminal.input.extra_meta_keys]
left_alt = false
EOF
apply_fixture warp-only
assert_warp_policy "$warp_home/.warp/settings.toml"
assert_contains "$warp_home/.warp/settings.toml" '# Synthetic setting that the modifier must preserve.'
assert_contains "$warp_home/.warp/settings.toml" 'telemetry = false'
test ! -e "$warp_home/.config/ghostty/config"

printf 'Docker dotfiles validation passed.\n'
