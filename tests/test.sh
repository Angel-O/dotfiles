#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
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

template_suffix_error=false
while IFS= read -r source; do
  test -f "$source_dir/$source" || continue
  case "$source" in
    *.tmpl) continue ;;
  esac
  if grep -Fq '{{' "$source_dir/$source"; then
    printf 'managed source contains template directives without a .tmpl suffix: %s\n' "$source" >&2
    template_suffix_error=true
  fi
done < <(git -C "$source_dir" ls-files --cached --others --exclude-standard -- 'dot_*' 'private_*' 'encrypted_*' 'executable_*' 'symlink_*' 'run_*')
if $template_suffix_error; then
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

assert_beads_hub_external() {
  local file=$1
  local expected_url="https://raw.githubusercontent.com/Angel-O/beads_viewer/$beads_viewer_ref/skills/beads-hub/SKILL.md"
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data[".config/opencode/skills/beads-hub/SKILL.md"] == {"type": "file", "url": sys.argv[2]}' "$file" "$expected_url"
}

assert_contains "$source_dir/README.md" '`wbd` is always Hub-only'
assert_contains "$source_dir/README.md" 'atomically installs its `bv`, `wbd`, and `wbv` binaries'
assert_contains "$source_dir/README.md" '`~/.local/libexec/beads-viewer`'
assert_contains "$source_dir/README.md" '~/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh'
assert_contains "$source_dir/README.md" 'Disabling the module stops future installation and management without deleting'
python3 -c 'import json,tomllib,sys; source=sys.argv[1]; pin=tomllib.load(open(source+"/.chezmoidata.toml", "rb"))["pins"]["beadsViewer"]; managers=json.load(open(source+"/renovate.json"))["customManagers"]; assert pin["branch"] == "feature/repository-aware-correlations"; assert any(manager.get("depTypeTemplate") == "beads-viewer" and manager.get("datasourceTemplate") == "git-refs" for manager in managers)' "$source_dir"
beads_viewer_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beadsViewer"]["ref"])' "$source_dir/.chezmoidata.toml")

assert_warp_policy() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); keys=data["terminal"]["input"]["extra_meta_keys"]; assert keys["left_alt"] is True; assert keys["right_alt"] is False' "$file"
}

starship_test_dir="$root/starship-init"
mkdir -p "$starship_test_dir/bin" "$starship_test_dir/home"
cat >"$starship_test_dir/bin/starship" <<'EOF'
#!/bin/sh
test "$1 $2" = "init zsh" && printf 'STARSHIP_TEST_INITIALIZED=1\n'
EOF
chmod +x "$starship_test_dir/bin/starship"

starship_init_state() {
  HOME="$starship_test_dir/home" \
    PATH="$starship_test_dir/bin:$PATH" \
    TERM_PROGRAM=$1 \
    HERDR_ENV=$2 \
    STARSHIP_SOURCE="$source_dir/dot_config/zsh/starship.zsh" \
    zsh -dfc 'source "$STARSHIP_SOURCE"; printf "%s|%s|%s\n" "${STARSHIP_TEST_INITIALIZED:-0}" "${TRANSIENT_PROMPT_PROMPT-unset}" "${TRANSIENT_PROMPT_RPROMPT-unset}"'
}

test "$(starship_init_state WarpTerminal '')" = '0||'
test "$(starship_init_state WarpTerminal 1)" = '1|unset|unset'
test "$(starship_init_state Apple_Terminal '')" = '1|unset|unset'

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
test "$(grep -Fxc '.config/helix' "$source_dir/scripts/backup-paths.txt")" -eq 1
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

agents_modifier_dir="$root/agents-modifier"
mkdir -p "$agents_modifier_dir"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" >"$agents_modifier_dir/enabled.sh"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/ghostty-only.toml" \
  <"$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" >"$agents_modifier_dir/disabled.sh"
sh -n "$agents_modifier_dir/enabled.sh"
sh -n "$agents_modifier_dir/disabled.sh"

cat >"$agents_modifier_dir/balanced.before" <<'EOF'
# Existing guidance
<!-- portable-work-beads:start -->
replace this managed text
<!-- portable-work-beads:end -->
Preserve this trailing guidance.
EOF
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/balanced.before" >"$agents_modifier_dir/balanced.after"
assert_contains "$agents_modifier_dir/balanced.after" '# Existing guidance'
assert_contains "$agents_modifier_dir/balanced.after" 'Preserve this trailing guidance.'
assert_contains "$agents_modifier_dir/balanced.after" 'load the global `beads-hub` skill before acting'
assert_contains "$agents_modifier_dir/balanced.after" 'use only `wbd` and approved `wbv --robot-*` queries'
assert_contains "$agents_modifier_dir/balanced.after" 'never raw `bd`, `bv`, or `br`'
assert_not_contains "$agents_modifier_dir/balanced.after" 'replace this managed text'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$agents_modifier_dir/balanced.after")" -eq 1
assert_not_contains "$agents_modifier_dir/balanced.after" 'portable-work-beads:start'
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/balanced.after" >"$agents_modifier_dir/balanced.second"
cmp -s "$agents_modifier_dir/balanced.after" "$agents_modifier_dir/balanced.second"

sh "$agents_modifier_dir/disabled.sh" \
  <"$agents_modifier_dir/balanced.after" >"$agents_modifier_dir/disabled.after"
assert_contains "$agents_modifier_dir/disabled.after" '# Existing guidance'
assert_contains "$agents_modifier_dir/disabled.after" 'Preserve this trailing guidance.'
assert_not_contains "$agents_modifier_dir/disabled.after" 'portable-work-beads:start'
assert_not_contains "$agents_modifier_dir/disabled.after" 'portable-beads-hub:start'
assert_not_contains "$agents_modifier_dir/disabled.after" 'beads-hub` skill'

assert_malformed_agents() {
  local name=$1
  if sh "$agents_modifier_dir/enabled.sh" \
    <"$agents_modifier_dir/$name.before" \
    >"$agents_modifier_dir/$name.after" \
    2>"$agents_modifier_dir/$name.err"; then
    printf 'expected malformed AGENTS markers to fail: %s\n' "$name" >&2
    exit 1
  fi
  cmp -s "$agents_modifier_dir/$name.before" "$agents_modifier_dir/$name.after"
  assert_contains "$agents_modifier_dir/$name.err" 'beads-hub AGENTS modifier:'
}

cat >"$agents_modifier_dir/unmatched-start.before" <<'EOF'
Preserve before unmatched start.
<!-- portable-beads-hub:start -->
Preserve after unmatched start.
EOF
assert_malformed_agents unmatched-start
assert_contains "$agents_modifier_dir/unmatched-start.err" 'unmatched start marker'

cat >"$agents_modifier_dir/orphan-end.before" <<'EOF'
Preserve before orphan end.
<!-- portable-beads-hub:end -->
Preserve after orphan end.
EOF
assert_malformed_agents orphan-end
assert_contains "$agents_modifier_dir/orphan-end.err" 'orphan end marker'

cat >"$agents_modifier_dir/nested-start.before" <<'EOF'
<!-- portable-beads-hub:start -->
Preserve inside outer marker.
<!-- portable-beads-hub:start -->
Preserve inside nested marker.
<!-- portable-beads-hub:end -->
<!-- portable-beads-hub:end -->
EOF
assert_malformed_agents nested-start
assert_contains "$agents_modifier_dir/nested-start.err" 'nested start marker'

cat >"$agents_modifier_dir/duplicate-balanced.before" <<'EOF'
<!-- portable-beads-hub:start -->
First managed block.
<!-- portable-beads-hub:end -->
Preserve content between blocks.
<!-- portable-beads-hub:start -->
Second managed block.
<!-- portable-beads-hub:end -->
EOF
assert_malformed_agents duplicate-balanced
assert_contains "$agents_modifier_dir/duplicate-balanced.err" 'multiple managed blocks'

printf '%s\r\n' \
  'Preserve CRLF before.' \
  '<!-- portable-work-beads:start -->' \
  'Replace CRLF managed text.' \
  '<!-- portable-work-beads:end -->' \
  'Preserve CRLF after.' >"$agents_modifier_dir/crlf.before"
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/crlf.before" >"$agents_modifier_dir/crlf.after"
assert_not_contains "$agents_modifier_dir/crlf.after" 'Replace CRLF managed text.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$agents_modifier_dir/crlf.after")" -eq 1
assert_not_contains "$agents_modifier_dir/crlf.after" 'portable-work-beads:start'
python3 -c 'import sys; data=open(sys.argv[1], "rb").read(); assert b"Preserve CRLF before.\r\nPreserve CRLF after.\r\n" in data' "$agents_modifier_dir/crlf.after"
sh "$agents_modifier_dir/enabled.sh" \
  <"$agents_modifier_dir/crlf.after" >"$agents_modifier_dir/crlf.second"
cmp -s "$agents_modifier_dir/crlf.after" "$agents_modifier_dir/crlf.second"

sh "$agents_modifier_dir/disabled.sh" \
  <"$agents_modifier_dir/crlf.before" >"$agents_modifier_dir/crlf.disabled"
printf '%s\r\n' 'Preserve CRLF before.' 'Preserve CRLF after.' >"$agents_modifier_dir/crlf.expected"
cmp -s "$agents_modifier_dir/crlf.expected" "$agents_modifier_dir/crlf.disabled"

prompt_config_dir="$root/prompt-config"
mkdir -p "$prompt_config_dir"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal.toml" \
  --promptBool 'Enable the Beads module=true' \
  --promptBool 'Enable the OpenCode Beads integration=true' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/personal.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is True; assert data["integrations"]["opencodeBeads"] is True' "$prompt_config_dir/personal.toml"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$prompt_config_dir/personal.toml" \
  --promptBool 'Enable the Beads module=true' \
  --promptBool 'Enable the OpenCode Beads integration=false' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/personal-second.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is True; assert data["integrations"]["opencodeBeads"] is False' "$prompt_config_dir/personal-second.toml"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/work.toml" \
  --promptBool 'Enable the Beads module=false' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/work-disabled.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is False; assert data["integrations"]["opencodeBeads"] is False' "$prompt_config_dir/work-disabled.toml"
chezmoi execute-template --init \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/work.toml" \
  --promptBool 'Enable the Beads module=true' \
  --promptBool 'Enable the OpenCode Beads integration=false' \
  <"$source_dir/.chezmoi.toml.tmpl" >"$prompt_config_dir/work-integration-disabled.toml"
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb"))["data"]; assert data["modules"]["beads"] is True; assert data["integrations"]["opencodeBeads"] is False' "$prompt_config_dir/work-integration-disabled.toml"

personal_home="$root/personal/home"
render_scripts personal
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_contains "$root/personal/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "helix"'
assert_contains "$root/personal/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "beads"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "beads_viewer"'
assert_not_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'Angel-O/beads_viewer'
assert_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'exit 0'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "bat"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "git-delta"'
assert_contains "$source_dir/.chezmoi.toml.tmpl" 'sourceDir = {{ .chezmoi.sourceDir | quote }}'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin thomasschafer.herdr-kiosk "thomasschafer/herdr-kiosk"'
assert_not_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'den-tanui/herdr-zoxide'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin ez-corp.space-usage "ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin robert-flo.elio "robert-flo/herdr-terminal-file-manager"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root="$HOME/workspace/source/herdr-reviewr"'
assert_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" "grep '^opencode: current ' >/dev/null"
assert_not_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" "grep -q '^opencode: current '"
assert_not_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" 'codex completion'
mkdir -p "$personal_home/.config/opencode" "$personal_home/.local/bin" \
  "$personal_home/.local/libexec/beads-viewer"
printf '%s\n' preserved-wbd >"$personal_home/.local/bin/wbd"
printf '%s\n' preserved-wbv >"$personal_home/.local/bin/wbv"
printf '%s\n' preserved-migration >"$personal_home/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh"
cat >"$personal_home/.config/opencode/AGENTS.md" <<'EOF'
Keep this personal instruction.
<!-- portable-work-beads:start -->
stale managed content
<!-- portable-work-beads:end -->
EOF
apply_fixture personal

test -f "$personal_home/.config/ghostty/config"
test -f "$personal_home/.config/helix/config.toml"
assert_contains "$personal_home/.config/helix/config.toml" 'theme = "dracula_at_night"'
test -f "$personal_home/.warp/settings.toml"
assert_warp_policy "$personal_home/.warp/settings.toml"
assert_contains "$personal_home/.config/ghostty/config" 'macos-option-as-alt = true'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'ram_display = "absolute"'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "thomasschafer.herdr-kiosk.open-picker"'
assert_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+o"'
assert_not_contains "$personal_home/.config/herdr/config.toml" 'herdr-zoxide.browse'
test ! -e "$personal_home/.config/herdr/plugins/config/thomasschafer.herdr-kiosk/config.toml"
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "robert-flo.elio.open"'
assert_contains "$personal_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_not_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
assert_contains "$personal_home/.config/zsh/starship.zsh" '[[ ${TERM_PROGRAM:-} == "WarpTerminal" && ${HERDR_ENV:-} != 1 ]]'
assert_contains "$personal_home/.config/zsh/starship.zsh" "TRANSIENT_PROMPT_PROMPT=''"
assert_contains "$personal_home/.config/zsh/starship.zsh" 'Keep completed prompts compact in every terminal, including Warp.'
test -f "$personal_home/.config/opencode/portable.jsonc"
test -f "$personal_home/.config/opencode/tui.jsonc"
cmp -s "$source_dir/dot_config/opencode/plugins/plan-diagrams.js" "$personal_home/.config/opencode/plugins/plan-diagrams.js"
cmp -s "$source_dir/dot_config/opencode/skills/plan-diagrams/SKILL.md" "$personal_home/.config/opencode/skills/plan-diagrams/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$personal_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
assert_contains "$personal_home/.config/opencode/AGENTS.md" 'Keep this personal instruction.'
assert_not_contains "$personal_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
grep -Fxq preserved-wbd "$personal_home/.local/bin/wbd"
grep -Fxq preserved-wbv "$personal_home/.local/bin/wbv"
grep -Fxq preserved-migration "$personal_home/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh"
test ! -e "$personal_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$personal_home/.config/opencode/skills/beads-hub/SKILL.md"
test -L "$personal_home/.config/starship/current.toml"
test -f "$personal_home/.config/zsh/portable.zsh"
test -f "$personal_home/.config/zsh/git-worktrees.zsh"
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" "alias gwtl='git wtl'"
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'gwtco() {'
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'gwts() {'
assert_contains "$personal_home/.config/zsh/git-worktrees.zsh" 'cdmain() {'
assert_contains "$personal_home/.config/zsh/opencode.zsh" "alias warpconf='code ~/.warp/launch_configurations'"
test -f "$personal_home/.config/git/portable.inc"
test ! -e "$personal_home/README.md"
test ! -e "$personal_home/tests"
jq -e '.provider.openai and (.plugin | index("opencode-lmstudio@1.0.0-rc.2")) and (.plugin | index("opencode-mermaid-renderer@0.0.1")) and (.permission.skill == {"plan-diagrams": "deny"}) and (.agent.plan.permission.skill == {"plan-diagrams": "allow"}) and (.agent.title.model == "openai/gpt-5.4-mini")' "$personal_home/.config/opencode/portable.jsonc" >/dev/null
personal_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --include files)
printf '%s\n' "$personal_managed" | grep -Fxq '.config/opencode/skills/plan-diagrams/SKILL.md'
printf '%s\n' "$personal_managed" | grep -Fxq '.config/opencode/skills/terminal-mermaid/SKILL.md'
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$personal_home/.config/herdr/config.toml"
zsh -n "$personal_home"/.config/zsh/*.zsh
HOME="$personal_home" zsh -dfc 'source "$HOME/.config/zsh/opencode.zsh"; alias opencode >/dev/null; alias warpconf >/dev/null'

personal_beads_home="$root/personal-with-beads/home"
render_scripts personal-with-beads
assert_beads_hub_external "$root/personal-with-beads/rendered/externals.toml"
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "go"'
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'source_repo="Angel-O/beads_viewer"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "wanted_ref=\"$beads_viewer_ref\""
mkdir -p "$personal_beads_home/.config/opencode"
printf '%s\n' 'Preserve personal Beads guidance.' >"$personal_beads_home/.config/opencode/AGENTS.md"
apply_fixture personal-with-beads
test ! -e "$personal_beads_home/.local/bin/wbd"
test ! -e "$personal_beads_home/.local/bin/wbv"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$personal_beads_home/.config/opencode/skills/work-beads/SKILL.md"
assert_contains "$personal_beads_home/.config/opencode/AGENTS.md" 'Preserve personal Beads guidance.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$personal_beads_home/.config/opencode/AGENTS.md")" -eq 1
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["process_aliases"] == {"bv": "ai board", "wbv": "ai board"}' "$personal_beads_home/.config/herdr-labels/config.toml"
apply_fixture personal-with-beads
personal_beads_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$personal_beads_home" \
  --config "$source_dir/tests/fixtures/personal-with-beads.toml" \
  --cache "$root/personal-with-beads/cache" \
  --persistent-state "$root/personal-with-beads/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$personal_beads_diff"

work_home="$root/work/home"
render_scripts work
assert_beads_hub_external "$root/work/rendered/externals.toml"
assert_contains "$root/work/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/work/rendered/Brewfile" 'brew "helix"'
assert_not_contains "$root/work/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "glow"'
assert_contains "$root/work/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/work/rendered/Brewfile" 'brew "go"'
assert_contains "$root/work/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/work/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'source_repo="Angel-O/beads_viewer"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "wanted_ref=\"$beads_viewer_ref\""
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin thomasschafer.herdr-kiosk "thomasschafer/herdr-kiosk"'
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
cat >"$work_home/.config/opencode/AGENTS.md" <<'EOF'
# Existing user guidance

Preserve this private instruction exactly.
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
assert_contains "$work_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["process_aliases"] == {"bv": "ai board", "wbv": "ai board"}' "$work_home/.config/herdr-labels/config.toml"
assert_not_contains "$work_home/.config/zsh/herdr.zsh" 'hook.zsh'
assert_contains "$work_home/.gitconfig" 'email = work@example.invalid'
assert_contains "$work_home/.gitconfig" '.config/git/portable.inc'
assert_contains "$work_home/.config/opencode/opencode.jsonc" 'work-private-provider'
assert_contains "$work_home/.config/opencode/tui.jsonc" 'work_private_tui_setting'
assert_contains "$work_home/.config/opencode/AGENTS.md" 'Preserve this private instruction exactly.'
test -f "$work_home/.config/helix/config.toml"
assert_contains "$work_home/.config/helix/config.toml" 'theme = "dracula_at_night"'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$work_home/.config/opencode/AGENTS.md")" -eq 1
assert_contains "$work_home/.config/opencode/AGENTS.md" 'load the global `beads-hub` skill before acting'
assert_contains "$work_home/.config/opencode/AGENTS.md" 'never raw `bd`, `bv`, or `br`'
test ! -e "$work_home/.local/bin/wbd"
test ! -e "$work_home/.local/bin/wbv"
test ! -e "$work_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$work_home/.config/opencode/skills/work-beads/SKILL.md"
cmp -s "$root/work/warp-settings.before" "$work_home/.warp/settings.toml"
assert_not_contains "$work_home/.config/opencode/portable.jsonc" '"provider"'
assert_not_contains "$work_home/.config/opencode/portable.jsonc" 'opencode-lmstudio'
cmp -s "$source_dir/dot_config/opencode/plugins/plan-diagrams.js" "$work_home/.config/opencode/plugins/plan-diagrams.js"
cmp -s "$source_dir/dot_config/opencode/skills/plan-diagrams/SKILL.md" "$work_home/.config/opencode/skills/plan-diagrams/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$work_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
assert_not_contains "$work_home/.config/herdr/config.toml" 'robert-flo.elio.open'
assert_not_contains "$work_home/.config/herdr/config.toml" 'key = "prefix+m"'
assert_not_contains "$work_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_not_contains "$work_home/.config/zsh/opencode.zsh" '{{'
assert_not_contains "$work_home/.config/zsh/opencode.zsh" 'alias warpconf='
jq -e '(.plugin | index("opencode-handoff@0.5.0")) and (.plugin | index("opencode-mermaid-renderer@0.0.1")) and (.permission.skill == {"plan-diagrams": "deny"}) and (.agent.plan.permission.skill == {"plan-diagrams": "allow"}) and (.agent.title == null)' "$work_home/.config/opencode/portable.jsonc" >/dev/null
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$work_home/.config/herdr/config.toml"
zsh -n "$work_home"/.config/zsh/*.zsh
HOME="$work_home" zsh -dfc 'source "$HOME/.config/zsh/opencode.zsh"; alias opencode >/dev/null; ! alias warpconf >/dev/null 2>&1'
HOME="$work_home" zsh -dfc 'alias zconfig="code ~/.zshrc"; alias reload="source ~/.zshrc"; source "$HOME/.config/zsh/helpers.zsh"'

if command -v sha256sum >/dev/null 2>&1; then
  before=$(find "$work_home" -type f -exec sha256sum {} + | sort)
else
  before=$(find "$work_home" -type f -exec shasum -a 256 {} + | sort)
fi
apply_fixture work
if command -v sha256sum >/dev/null 2>&1; then
  after=$(find "$work_home" -type f -exec sha256sum {} + | sort)
else
  after=$(find "$work_home" -type f -exec shasum -a 256 {} + | sort)
fi
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
work_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" --include files)
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/portable.jsonc'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/plugins/plan-diagrams.js'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/plan-diagrams/SKILL.md'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/terminal-mermaid/SKILL.md'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/beads-hub/SKILL.md'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/work-beads/SKILL.md'

external_home="$root/external-opencode-beads/home"
render_scripts external-opencode-beads
assert_beads_hub_external "$root/external-opencode-beads/rendered/externals.toml"
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "go"'
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'source_repo="Angel-O/beads_viewer"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "wanted_ref=\"$beads_viewer_ref\""
mkdir -p "$external_home/.config/opencode/skills/existing-skill"
cat >"$external_home/.config/opencode/opencode.jsonc" <<'EOF'
{"external_opencode_setting": true}
EOF
cat >"$external_home/.config/opencode/skills/existing-skill/SKILL.md" <<'EOF'
# Existing external skill

Preserve this unmanaged skill.
EOF
cat >"$external_home/.config/opencode/AGENTS.md" <<'EOF'
# Existing external OpenCode guidance

Preserve this external instruction.
EOF
cp "$external_home/.config/opencode/opencode.jsonc" "$root/external-opencode-beads/opencode.before"
cp "$external_home/.config/opencode/skills/existing-skill/SKILL.md" "$root/external-opencode-beads/skill.before"

external_managed="$root/external-opencode-beads/managed"
chezmoi managed \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --exclude externals \
  --include files \
  | grep -E '^(\.config/opencode|\.local/bin)' >"$external_managed"
cat >"$root/external-opencode-beads/managed.expected" <<'EOF'
.config/opencode/AGENTS.md
EOF
cmp -s "$root/external-opencode-beads/managed.expected" "$external_managed"

apply_fixture external-opencode-beads
test ! -e "$external_home/.local/bin/wbd"
test ! -e "$external_home/.local/bin/wbv"
test ! -e "$external_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$external_home/.config/opencode/portable.jsonc"
test ! -e "$external_home/.config/opencode/plugins/env-protection.js"
test ! -e "$external_home/.config/opencode/plugins/plan-diagrams.js"
test ! -e "$external_home/.config/opencode/skills/plan-diagrams/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
test ! -e "$external_home/.config/opencode/commands/herdr-name.md"
test ! -e "$external_home/.local/bin/opencode-env"
cmp -s "$root/external-opencode-beads/opencode.before" "$external_home/.config/opencode/opencode.jsonc"
cmp -s "$root/external-opencode-beads/skill.before" "$external_home/.config/opencode/skills/existing-skill/SKILL.md"
assert_contains "$external_home/.config/opencode/AGENTS.md" 'Preserve this external instruction.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$external_home/.config/opencode/AGENTS.md")" -eq 1

if command -v sha256sum >/dev/null 2>&1; then
  external_before=$(find "$external_home" -type f -exec sha256sum {} + | sort)
else
  external_before=$(find "$external_home" -type f -exec shasum -a 256 {} + | sort)
fi
apply_fixture external-opencode-beads
if command -v sha256sum >/dev/null 2>&1; then
  external_after=$(find "$external_home" -type f -exec sha256sum {} + | sort)
else
  external_after=$(find "$external_home" -type f -exec shasum -a 256 {} + | sort)
fi
test "$external_before" = "$external_after"
external_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$external_home" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --cache "$root/external-opencode-beads/cache" \
  --persistent-state "$root/external-opencode-beads/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$external_diff"

integration_disabled_home="$root/beads-integration-disabled/home"
render_scripts beads-integration-disabled
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
mkdir -p "$integration_disabled_home/.config/opencode/skills/beads-hub"
printf '%s\n' 'previously installed external skill' >"$integration_disabled_home/.config/opencode/skills/beads-hub/SKILL.md"
cat >"$integration_disabled_home/.config/opencode/opencode.jsonc" <<'EOF'
{"unmanaged_setting": "preserve"}
EOF
cat >"$integration_disabled_home/.config/opencode/AGENTS.md" <<'EOF'
Preserve disabled-integration guidance.
<!-- portable-work-beads:start -->
Remove this stale managed block.
<!-- portable-work-beads:end -->
EOF
apply_fixture beads-integration-disabled
test ! -e "$integration_disabled_home/.local/bin/wbd"
test ! -e "$integration_disabled_home/.local/bin/wbv"
test ! -e "$integration_disabled_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$integration_disabled_home/.config/opencode/skills/beads-hub/SKILL.md"
test -f "$integration_disabled_home/.config/opencode/portable.jsonc"
assert_contains "$integration_disabled_home/.config/opencode/opencode.jsonc" '"unmanaged_setting": "preserve"'
assert_contains "$integration_disabled_home/.config/opencode/AGENTS.md" 'Preserve disabled-integration guidance.'
assert_not_contains "$integration_disabled_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'

# Disabling the integration removes the previously managed global skill while
# preserving unrelated global OpenCode guidance.
transition_root="$root/beads-integration-transition"
transition_home="$transition_root/home"
mkdir -p "$transition_home/.config/opencode/skills/work-beads"
printf '%s\n' 'Preserve transition guidance.' >"$transition_home/.config/opencode/AGENTS.md"
printf '%s\n' 'obsolete managed work-beads skill' >"$transition_home/.config/opencode/skills/work-beads/SKILL.md"
chezmoi apply \
  --source "$source_dir" \
  --destination "$transition_home" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --cache "$transition_root/cache" \
  --persistent-state "$transition_root/chezmoistate.boltdb" \
  --exclude scripts,externals \
  --force
test ! -e "$transition_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
assert_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-beads-hub:start'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
mkdir -p "$transition_home/.config/opencode/skills/beads-hub"
printf '%s\n' 'simulated installed external skill' >"$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
chezmoi apply \
  --source "$source_dir" \
  --destination "$transition_home" \
  --config "$source_dir/tests/fixtures/beads-integration-disabled.toml" \
  --cache "$transition_root/cache" \
  --persistent-state "$transition_root/chezmoistate.boltdb" \
  --exclude scripts,externals \
  --force
test ! -e "$transition_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$transition_home/.local/bin/wbd"
test ! -e "$transition_home/.local/bin/wbv"
assert_contains "$transition_home/.config/opencode/AGENTS.md" 'Preserve transition guidance.'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-beads-hub:start'

legacy_home="$root/legacy-beads/home"
render_scripts legacy-beads
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
mkdir -p "$legacy_home/.config/opencode"
cat >"$legacy_home/.config/opencode/AGENTS.md" <<'EOF'
Preserve legacy guidance.
<!-- portable-work-beads:start -->
Remove this legacy stale block.
<!-- portable-work-beads:end -->
EOF
apply_fixture legacy-beads
test ! -e "$legacy_home/.local/bin/wbd"
test ! -e "$legacy_home/.local/bin/wbv"
test ! -e "$legacy_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$legacy_home/.config/opencode/skills/beads-hub/SKILL.md"
assert_contains "$legacy_home/.config/opencode/AGENTS.md" 'Preserve legacy guidance.'
assert_not_contains "$legacy_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'

bash "$source_dir/tests/test-beads.sh" "$source_dir" "$root"

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
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'thomasschafer/herdr-kiosk'
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
test ! -e "$disabled_home/.config/herdr/plugins/config/thomasschafer.herdr-kiosk/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml"
test ! -e "$disabled_home/.config/herdr-labels/config.toml"
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$disabled_home/.config/herdr/config.toml"

ghostty_home="$root/ghostty-only/home"
render_scripts ghostty-only
assert_contains "$root/ghostty-only/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/ghostty-only/rendered/Brewfile" 'brew "helix"'
mkdir -p "$ghostty_home/.config/opencode"
cat >"$ghostty_home/.config/opencode/AGENTS.md" <<'EOF'
Preserve this guidance with OpenCode disabled.
<!-- portable-work-beads:start -->
remove this managed section
<!-- portable-work-beads:end -->
EOF
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
test ! -e "$ghostty_home/.config/helix"
test ! -e "$ghostty_home/.warp"
test ! -e "$ghostty_home/.config/herdr/config.toml"
test ! -e "$ghostty_home/.config/opencode/portable.jsonc"
assert_contains "$ghostty_home/.config/opencode/AGENTS.md" 'Preserve this guidance with OpenCode disabled.'
assert_not_contains "$ghostty_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
test ! -e "$ghostty_home/.config/starship/current.toml"
test ! -e "$ghostty_home/.config/zsh/portable.zsh"
test ! -e "$ghostty_home/.config/git/portable.inc"

helix_home="$root/helix-only/home"
render_scripts helix-only
mkdir -p "$helix_home/.config/helix/runtime" "$helix_home/.cache/helix"
printf '%s\n' 'preserve generated runtime data' >"$helix_home/.config/helix/runtime/generated"
printf '%s\n' 'preserve runtime log' >"$helix_home/.cache/helix/helix.log"
apply_fixture helix-only
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data == {"theme": "dracula_at_night"}' "$helix_home/.config/helix/config.toml"
grep -Fxq 'preserve generated runtime data' "$helix_home/.config/helix/runtime/generated"
grep -Fxq 'preserve runtime log' "$helix_home/.cache/helix/helix.log"
test ! -e "$helix_home/.config/ghostty/config"
helix_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/helix-only.toml" --include files | grep '^\.config/helix')
test "$helix_managed" = '.config/helix/config.toml'

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
