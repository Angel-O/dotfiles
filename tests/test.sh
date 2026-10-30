#!/usr/bin/env bash
set -Eeuo pipefail

trap 'status=$?; printf "test failure at line %s: %s (status %s)\n" "$LINENO" "$BASH_COMMAND" "$status" >&2; exit "$status"' ERR

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
annotate_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["herdrPlugins"]["annotate"]["ref"])' "$source_dir/.chezmoidata.toml")
blink_source=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["herdrPlugins"]["blink"]["source"])' "$source_dir/.chezmoidata.toml")
blink_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["herdrPlugins"]["blink"]["ref"])' "$source_dir/.chezmoidata.toml")
todo_source=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["openCodePlugins"]["todo"]["source"])' "$source_dir/.chezmoidata.toml")
todo_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["openCodePlugins"]["todo"]["ref"])' "$source_dir/.chezmoidata.toml")
root=/tmp/dotfiles-test
rm -rf "$root"
mkdir -p "$root"
# Keep fixture homes and persistent state isolated; share only chezmoi's
# external/download cache so identical archives are fetched once per run.
cache="$root/chezmoi-cache"
export CHEZMOI_TEST_CACHE="$cache"

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

bash "$source_dir/tests/test-explain-this.sh"
bash "$source_dir/tests/test-agents-modifier.sh"
bash "$source_dir/tests/test-add-linear-id.sh"
[[ "${TEST_SCOPE:-}" != agents-modifier ]] || exit 0
bash "$source_dir/tests/test-env-protection.sh"
[[ "${TEST_SCOPE:-}" != env-protection ]] || exit 0
bash "$source_dir/tests/test-opencode-tracker.sh"
[[ "${TEST_SCOPE:-}" != opencode-tracker ]] || exit 0
bash "$source_dir/tests/test-opencode-orchestration.sh"
[[ "${TEST_SCOPE:-}" != opencode-orchestration ]] || exit 0
bash "$source_dir/tests/test-opencode-policy.sh"
[[ "${TEST_SCOPE:-}" != opencode-policy ]] || exit 0
bash "$source_dir/tests/test-opencode-agent-model-overrides.sh"
[[ "${TEST_SCOPE:-}" != opencode-agent-model-overrides ]] || exit 0

source_files() {
  if git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$source_dir" ls-files --cached --others --exclude-standard -- \
      'dot_*' 'private_*' 'encrypted_*' 'executable_*' 'symlink_*' 'run_*'
  else
    while IFS= read -r -d '' source; do
      printf '%s\n' "${source#"$source_dir"/}"
    done < <(find "$source_dir" -type f \( \
      -path "$source_dir/dot_*" -o -path "$source_dir/private_*" -o \
      -path "$source_dir/encrypted_*" -o -path "$source_dir/executable_*" -o \
      -path "$source_dir/symlink_*" -o -path "$source_dir/run_*" \
    \) -print0)
  fi
}

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
done < <(source_files)
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
  mkdir -p "$home/.config/opencode/skills"
  chezmoi apply \
    --source "$source_dir" \
    --destination "$home" \
    --config "$config" \
    --cache "$cache" \
    --persistent-state "$root/$name/chezmoistate.boltdb" \
    --exclude scripts,externals \
    --force
}

assert_contains() {
  local file=$1
  local text=$2
  grep -Fq -- "$text" "$file" || {
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

assert_herdr_blink() {
  local blink_dir="$root/herdr-blink"
  local config="$blink_dir/personal-config.toml"
  local disabled_config="$blink_dir/disabled-config.toml"
  local installer="$blink_dir/personal-installer.sh"
  local disabled_installer="$blink_dir/disabled-installer.sh"
  mkdir -p "$blink_dir"

  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
    <"$source_dir/dot_config/herdr/config.toml.tmpl" >"$config"
  python3 - "$config" <<'PY'
import sys
import tomllib

commands = tomllib.load(open(sys.argv[1], "rb"))["keys"]["command"]
blink = [command for command in commands if command.get("key") == "prefix+ctrl+k"]
assert blink == [{
    "key": "prefix+ctrl+k",
    "type": "plugin_action",
    "command": "dartyuhov.blink.open",
    "description": "switch agent with blink",
}]
PY

  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/herdr-disabled-plugins.toml" \
    <"$source_dir/dot_config/herdr/config.toml.tmpl" >"$disabled_config"
  assert_not_contains "$disabled_config" 'dartyuhov.blink'

  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
    <"$source_dir/run_after_30-install-herdr-plugins.sh.tmpl" >"$installer"
  sh -n "$installer"
  assert_contains "$installer" "ensure_github_plugin dartyuhov.blink \"$blink_source\" \"$blink_ref\""

  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/herdr-disabled-plugins.toml" \
    <"$source_dir/run_after_30-install-herdr-plugins.sh.tmpl" >"$disabled_installer"
  sh -n "$disabled_installer"
  assert_not_contains "$disabled_installer" 'dartyuhov.blink'

  apply_fixture personal
  assert_contains "$root/personal/home/.config/herdr/config.toml" 'key = "prefix+ctrl+k"'
  assert_contains "$root/personal/home/.config/herdr/config.toml" 'command = "dartyuhov.blink.open"'
  python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' \
    "$root/personal/home/.config/herdr/config.toml"
  managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" --include files)
  printf '%s\n' "$managed" | grep -Fxq '.config/herdr/config.toml'
}

if [[ "${TEST_SCOPE:-}" == herdr-blink ]]; then
  assert_herdr_blink
  exit 0
fi

assert_herdr_plugin_keybindings() {
  local config_dir="$root/herdr-plugin-keybindings"
  local config="$config_dir/config.toml"
  mkdir -p "$config_dir"

  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
    <"$source_dir/dot_config/herdr/config.toml.tmpl" >"$config"
  python3 - "$config" <<'PY'
import sys
import tomllib

commands = tomllib.load(open(sys.argv[1], "rb"))["keys"]["command"]
expected = {
    "persiyanov.reviewr.toggle": {
        "key": "prefix+ctrl+r",
        "type": "plugin_action",
        "command": "persiyanov.reviewr.toggle",
        "description": "toggle reviewr split",
    },
    "angel-o.hub-viewer.open": {
        "key": "prefix+ctrl+h",
        "type": "plugin_action",
        "command": "angel-o.hub-viewer.open",
        "description": "open Hub Viewer",
    },
    "annotate.last-newest": {
        "key": "prefix+ctrl+p",
        "type": "plugin_action",
        "command": "annotate.last-newest",
        "description": "review agent newest message",
    },
    "angel-o.elio.open": {
        "key": "prefix+ctrl+e",
        "type": "plugin_action",
        "command": "angel-o.elio.open",
        "description": "open Elio",
    },
}

for command, binding in expected.items():
    matches = [entry for entry in commands if entry.get("command") == command]
    assert matches == [binding], (command, matches)
    assert sum(entry.get("key") == binding["key"] for entry in commands) == 1, binding
PY
}

if [[ "${TEST_SCOPE:-}" == herdr-plugin-keybindings ]]; then
  assert_herdr_plugin_keybindings
  exit 0
fi

assert_opencode_palette() {
  local personal_cli="$root/personal/home/.config/opencode/cli.json"
  local personal_portable="$root/personal/home/.config/opencode/portable.jsonc"
  local personal_theme="$root/personal/home/.config/opencode/themes/herdr-dracula.json"
  apply_fixture personal
  python3 - "$personal_cli" "$personal_portable" "$personal_theme" <<'PY'
import json
import sys

with open(sys.argv[1]) as cli_file:
    cli = json.load(cli_file)
with open(sys.argv[2]) as portable_file:
    portable = json.load(portable_file)
with open(sys.argv[3]) as theme_file:
    theme = json.load(theme_file)

assert cli["theme"] == {"name": "tokyonight-mauve", "mode": "dark"}
assert cli["session"] == {
    "sidebar": "auto",
    "scrollbar": False,
    "thinking": "show",
    "markdown": "rendered",
    "grouping": "auto",
    "verbosity": "medium",
    "image_preview": True,
    "tps": True,
    "new_location": "launch",
    "permissions": "prompt",
}
assert cli["animations"] is True
assert "plugin" not in cli
assert cli["plugins"] == ["./herdr-opencode"]
assert cli["tabs"] == {
    "layout": "horizontal",
    "mode": "auto",
    "indicators": "status",
    "scope": "cwd",
}
assert cli["prompt"] == {"image_preview": True, "paste": "compact"}
assert cli["scroll"] == {"acceleration": False, "speed": 3}
assert cli["attention"] == {"notifications": False, "sound": False}
assert cli["terminal"] == {"copy": "select"}
assert cli["diffs"] == {
    "fullscreen": False,
    "wrap": "word",
    "tree": True,
    "single": False,
    "view": "unified",
}
assert cli["debug"] == {"devtools": True, "timing": False, "turn_tokens": True}
assert portable["default_agent"] == "orchestrator"
expected = {
    "orchestrator": {"color": "#C099FF", "model": "{env:OPENCODE_AGENT_MODEL_ORCHESTRATOR}"},
    "build": {"color": "#82AAFF", "model": "{env:OPENCODE_AGENT_MODEL_BUILD}"},
    "plan": {"color": "#FF966C", "model": "{env:OPENCODE_AGENT_MODEL_PLAN}"},
    "architect": {"color": "#C3E88D", "model": "{env:OPENCODE_AGENT_MODEL_ARCHITECT}"},
    "worker": {"color": "#FF757F", "model": "{env:OPENCODE_AGENT_MODEL_WORKER}"},
    "investigator": {"model": "{env:OPENCODE_AGENT_MODEL_INVESTIGATOR}"},
    "integration": {"model": "{env:OPENCODE_AGENT_MODEL_INTEGRATION}"},
    "reviewer": {"model": "{env:OPENCODE_AGENT_MODEL_REVIEWER}"},
    "planner": {"model": "{env:OPENCODE_AGENT_MODEL_PLANNER}"},
}
assert set(portable["agents"]) == set(expected)
for name, config in expected.items():
    assert portable["agents"][name] == config

assert set(theme) == {"$schema", "base", "dark"}
assert theme["$schema"] == "https://opencode.ai/theme.json"
assert "theme" not in theme and "defs" not in theme
assert not any(role in json.dumps(theme).lower() for role in ("orchestrator", "build", "plan", "architect", "worker"))
assert set(theme["base"]) == {
    "categorical", "text", "background", "border", "scrollbar", "diff", "syntax", "markdown", "@dialog"
}
assert set(theme["base"]["text"]) == {"base", "muted", "action", "formfield", "feedback"}
assert set(theme["base"]["text"]["action"]) == {"primary", "secondary", "destructive"}
assert set(theme["base"]["text"]["feedback"]) == {"error", "warning", "success", "info"}
assert set(theme["base"]["background"]) == {"base", "raised", "action", "formfield", "feedback"}
assert set(theme["base"]["background"]["action"]) == {"primary", "secondary", "destructive"}
assert set(theme["base"]["background"]["feedback"]) == {"error", "warning", "success", "info"}
assert set(theme["base"]["diff"]) == {"text", "background", "highlight", "lineNumber"}
assert set(theme["base"]["syntax"]) == {
    "comment", "keyword", "function", "variable", "string", "number", "type", "operator", "punctuation"
}
assert set(theme["base"]["markdown"]) == {
    "text", "heading", "link", "linkText", "code", "blockQuote", "emphasis", "strong", "horizontalRule",
    "listItem", "listEnumeration", "image", "imageText", "codeBlock"
}
hues = theme["dark"]["hue"]
assert hues["interactive"] == "$hue.purple"
assert hues["accent"] == "$hue.purple"
assert hues["neutral"] == "$hue.gray"
assert hues["purple"]["200"] == "#bd93f9"
assert set(hues) == {"orange", "green", "blue", "cyan", "yellow", "red", "purple", "gray", "accent", "interactive", "neutral"}
assert hues["blue"] == "$hue.cyan"
for name in ("orange", "green", "cyan", "yellow", "red", "purple", "gray"):
    assert set(hues[name]) == {str(step) for step in range(100, 1000, 100)}
assert theme["base"]["background"]["base"] == "#282a36"
assert theme["base"]["background"]["raised"]["high"] == "#44475a"
assert theme["base"]["text"]["base"] == "#f8f8f2"
assert theme["base"]["text"]["muted"] == "#828cb4"
assert theme["base"]["text"]["formfield"]["$focused"] == "#bd93f9"
assert theme["base"]["text"]["formfield"]["$selected"] == "#bd93f9"
assert theme["base"]["text"]["formfield"]["$hovered"] == "#bd93f9"
assert theme["base"]["text"]["formfield"]["$pressed"] == "#bd93f9"
assert theme["base"]["background"]["action"]["primary"]["$focused"] == "#bd93f9"
assert theme["base"]["border"]["base"] == "#6272a4"
PY
  apply_fixture beads-integration-disabled
  python3 - "$root/beads-integration-disabled/home/.config/opencode/cli.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as cli_file:
    cli = json.load(cli_file)

assert "plugins" not in cli
assert cli["tabs"]["layout"] == "horizontal"
PY
  assert_not_contains "$source_dir/dot_config/opencode/cli.json.tmpl" 'system-pink'
  assert_not_contains "$source_dir/dot_config/opencode/portable.jsonc.tmpl" 'system-pink'
  assert_not_contains "$source_dir/dot_config/opencode/themes/tokyonight-mauve.json" 'system-pink'
  assert_not_contains "$source_dir/dot_config/opencode/themes/tokyonight-mauve.json" 'global-'
  assert_contains "$source_dir/README.md" 'Normal composer rails follow the active agent color'
  assert_contains "$source_dir/README.md" 'Built-in `plan` and custom `planner` are distinct'
}

assert_opencode_palette
[[ "${TEST_SCOPE:-}" != opencode-palette ]] || exit 0

assert_todo_installer() {
  local file=$1
  assert_contains "$file" 'git clone --filter=blob:none --no-checkout "$url" "$path"'
  assert_contains "$file" 'exists but is not a Git checkout; refusing to overwrite it.'
  assert_contains "$file" 'has local changes; refusing to move it to pinned commit'
  assert_contains "$file" 'git -C "$path" fetch --depth 1 origin "$wanted_ref"'
  assert_contains "$file" 'resolved_ref=$(git -C "$path" rev-parse FETCH_HEAD)'
  assert_contains "$file" 'if [ "$resolved_ref" != "$wanted_ref" ]; then'
  assert_contains "$file" 'git -C "$path" checkout --detach "$resolved_ref"'
  assert_contains "$file" "  \"$todo_source\" \\"
  assert_contains "$file" '  "$HOME/.local/share/opencode/opencode-todo" \'
  assert_contains "$file" "  \"$todo_ref\""
}

assert_viewer_board_config() {
  local source_config="$source_dir/dot_config/bv/config.yaml"
  test -f "$source_config"
  assert_contains "$source_config" 'board:'
  assert_contains "$source_config" 'hide_empty_columns: true'

  for name in personal-with-beads work beads-integration-disabled external-opencode-beads legacy-beads; do
    apply_fixture "$name"
    target_config="$root/$name/home/.config/bv/config.yaml"
    test -f "$target_config"
    cmp -s "$source_config" "$target_config"
    managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$name.toml" --cache "$cache" --include files)
    printf '%s\n' "$managed" | grep -Fxq '.config/bv/config.yaml'
  done

  for name in personal ghostty-only helix-only warp-only shell-only herdr-disabled-plugins; do
    apply_fixture "$name"
    test ! -e "$root/$name/home/.config/bv/config.yaml"
    managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$name.toml" --cache "$cache" --include files)
    ! printf '%s\n' "$managed" | grep -Fxq '.config/bv/config.yaml'
  done
}

assert_reviewr_config() {
  local source_config="$source_dir/dot_config/herdr/plugins/config/persiyanov.reviewr/config.toml.tmpl"
  test -f "$source_config"
  python3 - "$source_config" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config_file:
    assert tomllib.load(config_file) == {
        "default_scope": "branch",
        "navigator_position": "left",
        "theme": "dracula",
        "toggle_placement": "split",
        "auto_open": False,
        "markdown_view": "rendered",
        "editor": "hx",
    }
PY

  for name in personal work; do
    apply_fixture "$name"
    target_config="$root/$name/home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml"
    test -f "$target_config"
    cmp -s "$source_config" "$target_config"
    managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$name.toml" --cache "$cache" --include files)
    printf '%s\n' "$managed" | grep -Fxq '.config/herdr/plugins/config/persiyanov.reviewr/config.toml'
  done
}

assert_reviewr_config
[[ "${TEST_SCOPE:-}" != reviewr-config ]] || exit 0
assert_viewer_board_config
[[ "${TEST_SCOPE:-}" != viewer-config ]] || exit 0

assert_beads_viewer_externals() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); ref=sys.argv[2]; assert data["beadsViewerSkills"] == {"type": "archive", "url": "https://github.com/Angel-O/beads_viewer/archive/" + ref + ".tar.gz", "stripComponents": 2, "include": ["*/skills/**"], "targetPath": ".config/opencode/skills"}; assert not any("beads-hub" in path for path in data if path != "beadsViewerSkills")' "$file" "$beads_viewer_ref"
}

assert_ponytail_external() {
  local file=$1
  python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); ref=sys.argv[2]; assert data[".config/opencode/skills/ponytail/SKILL.md"] == {"type": "file", "url": "https://raw.githubusercontent.com/dietrichgebert/ponytail/" + ref + "/skills/ponytail/SKILL.md"}' "$file" "$ponytail_ref"
}

assert_agent_contracts() {
  local directory=$1
  python3 - "$directory" <<'PY'
import re
import sys
from pathlib import Path

directory = Path(sys.argv[1])
contracts = {
    "orchestrator": ("primary", [
        ('"*"', '"*"', "deny"),
        ("external_directory", '"*"', "allow"),
        ("question", '"*"', "allow"),
         ("shell", '"*"', "allow"),
         ("orchestration_tracking", '"*"', "allow"),
         ("read", '"*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("subagent", '"*"', "deny"),
        ("subagent", "integration", "allow"),
        ("subagent", "investigator", "allow"),
        ("subagent", "reviewer", "allow"),
        ("webfetch", '"*"', "allow"),
        ("todowrite", '"*"', "allow"),
        ("skill", '"*"', "allow"),
        ("quota_status", '"*"', "allow"),
        ("handoff_session", '"*"', "allow"),
        ("read_session", '"*"', "allow"),
    ]),
    "integration": ("subagent", [
        ('"*"', '"*"', "deny"),
        ("shell", '"*"', "allow"),
        ("external_directory", '"*"', "allow"),
        ("read", '"*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("skill", '"*"', "allow"),
        ("skill", "terminal-mermaid", "deny"),
    ]),
    "investigator": ("subagent", [
        ('"*"', '"*"', "deny"),
        ("shell", '"*"', "allow"),
        ("external_directory", '"*"', "ask"),
        ("read", '"*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("webfetch", '"*"', "allow"),
        ("skill", '"*"', "allow"),
    ]),
    "reviewer": ("subagent", [
        ('"*"', '"*"', "deny"),
        ("shell", '"*"', "allow"),
        ("external_directory", '"*"', "allow"),
        ("read", '"*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("skill", '"*"', "allow"),
        ("skill", "terminal-mermaid", "deny"),
    ]),
    "worker": ("primary", [
        ('"*"', '"*"', "deny"),
        ("shell", '"*"', "allow"),
        ("shell", "git", "deny"),
        ("shell", '"git *"', "deny"),
        ("shell", '"git rev-parse HEAD"', "allow"),
        ("shell", '"git branch --show-current"', "allow"),
        ("shell", '"git diff"', "allow"),
        ("shell", '"git diff *"', "allow"),
        ("shell", '"git status"', "allow"),
        ("shell", '"git status *"', "allow"),
        ("shell", '"git log"', "allow"),
        ("shell", '"git log *"', "allow"),
        ("shell", '"git show"', "allow"),
        ("shell", '"git show *"', "allow"),
        ("read", '"*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("webfetch", '"*"', "allow"),
        ("todowrite", '"*"', "allow"),
        ("skill", '"*"', "allow"),
        ("edit", '"*"', "allow"),
    ]),
    "architect": ("primary", [
        ('"*"', '"*"', "deny"),
        ("shell", '"*"', "deny"),
        ("shell", '"wbd show * --json"', "allow"),
        ("shell", '"wbd update * --description * --json"', "allow"),
        ("external_directory", '"*"', "ask"),
        ("external_directory", '"$HOME/.local/share/plannotator/plans/*"', "allow"),
        ("question", '"*"', "allow"),
        ("read", '"*"', "allow"),
        ("read", '"$HOME/.local/share/plannotator/plans/*"', "allow"),
        ("edit", '"$HOME/.local/share/plannotator/plans/*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("webfetch", '"*"', "allow"),
        ("skill", '"*"', "allow"),
        ("subagent", '"*"', "deny"),
        ("subagent", "planner", "allow"),
    ]),
    "planner": ("subagent", [
        ('"*"', '"*"', "deny"),
        ("orchestration_tracking", '"*"', "allow"),
        ("shell", '"*"', "deny"),
        ("external_directory", '"*"', "deny"),
        ("external_directory", '"$HOME/workspace/source/*"', "allow"),
        ("shell", '"wbd context"', "allow"),
        ("shell", '"wbd show * --json"', "allow"),
        ("shell", '"wbd show * --json --expand-dependencies"', "allow"),
        ("shell", '"wbd scope active --json"', "allow"),
        ("shell", '"wbd create * --type * --context * --description * --priority * --json"', "allow"),
        ("shell", '"wbd create * --type * --priority * --context * --description * --json"', "allow"),
        ("shell", '"wbd scope add * --context * --json"', "allow"),
        ("shell", '"wbd dep add * * --type parent-child --json"', "allow"),
        ("shell", '"wbd dep add * * --type blocks --json"', "allow"),
        ("read", '"*"', "allow"),
        ("glob", '"*"', "allow"),
        ("grep", '"*"', "allow"),
        ("skill", '"*"', "allow"),
    ]),
}

for name, (mode, expected) in contracts.items():
    text = (directory / f"{name}.md").read_text()
    frontmatter = text.split("---", 2)[1]
    assert f"mode: {mode}" in frontmatter
    assert "model:" not in frontmatter
    assert "reasoningEffort:" not in frontmatter
    permissions = frontmatter.split("permissions:", 1)[1]
    assert "permission:" not in frontmatter
    actual = [
        match.groups()
        for match in re.finditer(
            r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
            permissions,
            re.MULTILINE,
        )
    ]
    assert actual == expected, (name, actual)
    if name in {"integration", "reviewer"}:
        assert "create or include diagrams" in text

for name, forbidden in {
    "integration": {"orchestrator", "reviewer", "worker", "planner", "architect", "orchestration", "routing", "delegate"},
    "investigator": {"orchestrator", "reviewer", "worker", "planner", "architect", "orchestration", "routing", "delegate"},
    "reviewer": {"orchestrator", "worker", "planner", "architect", "orchestration", "routing", "delegate"},
    "worker": {"orchestrator", "reviewer", "planner", "architect", "orchestration", "routing", "delegate"},
    "architect": {"orchestrator", "reviewer", "worker", "orchestration", "routing", "delegate"},
    "planner": {"orchestrator", "reviewer", "worker", "orchestration", "routing", "delegate"},
}.items():
    identity = (directory / f"{name}.md").read_text().split("---", 2)[2].lower()
    assert not forbidden.intersection(identity), (name, forbidden.intersection(identity))

orchestrator = (directory / "orchestrator.md").read_text()
assert '  - action: subagent\n    resource: "*"\n    effect: deny\n  - action: subagent\n    resource: integration\n    effect: allow\n  - action: subagent\n    resource: investigator\n    effect: allow\n  - action: subagent\n    resource: reviewer\n    effect: allow' in orchestrator
assert 'Every primary Architect launch must use `~/.local/bin/herdr-agent-launch architect sibling <architect-name>` from the current Herdr pane.' in orchestrator
assert "Do not use Herdr's raw agent-start command or a manual split-start recipe for primary Architect creation." in orchestrator
architect = (directory / "architect.md").read_text()
assert '  - action: subagent\n    resource: "*"\n    effect: deny\n  - action: subagent\n    resource: planner\n    effect: allow' in architect
assert 'architect: allow' not in orchestrator
assert 'worker: allow' not in orchestrator
for name in ("worker", "architect", "reviewer"):
    identity = (directory / f"{name}.md").read_text().split("---", 2)[2].lower()
    assert "`ponytail` skill" in identity, name
PY
  for built_in in build plan general explore scout; do
    test ! -e "$directory/$built_in.md"
  done
}

assert_herdr_agent_launcher() {
  local launcher="$source_dir/dot_local/bin/executable_herdr-agent-launch"
  local test_dir="$root/herdr-agent-launch"
  local fake_bin="$test_dir/bin"
  local canned="$test_dir/canned"
  local log="$test_dir/herdr.log"
  local worktree="$test_dir/worktree"
  local delivery_worktree="$test_dir/delivery-worktree"
  local process_repo="$test_dir/process-repo"
  local pane_repo="$test_dir/pane-repo"
  mkdir -p "$fake_bin" "$canned"
  mkdir -p "$process_repo" "$pane_repo"
  mkdir -p "$delivery_worktree"
  git -C "$process_repo" init --quiet
  git -C "$pane_repo" init --quiet
  process_repo=$(git -C "$process_repo" rev-parse --show-toplevel)

  cat >"$canned/caller.json" <<EOF
{"result":{"type":"pane_current","pane":{"pane_id":"w1:p1","terminal_id":"term1","workspace_id":"w1","tab_id":"w1:t1","focused":true,"cwd":"$pane_repo","agent_status":"working","revision":1}}}
EOF
  cat >"$canned/split.json" <<EOF
{"result":{"type":"pane_info","pane":{"pane_id":"w1:p2","terminal_id":"term2","workspace_id":"w1","tab_id":"w1:t1","focused":false,"cwd":"$pane_repo","agent_status":"idle","revision":2}}}
EOF
  cat >"$canned/rename.json" <<'EOF'
{"result":{"type":"pane_info"}}
EOF
  cat >"$canned/tab.json" <<EOF
{"result":{"type":"tab_created","tab":{"tab_id":"w1:t2","workspace_id":"w1","number":2,"label":"worker","focused":false,"pane_count":1,"agent_status":"idle"},"root_pane":{"pane_id":"w1:p3","terminal_id":"term3","workspace_id":"w1","tab_id":"w1:t2","focused":false,"cwd":"$pane_repo","agent_status":"idle","revision":3}}}
EOF
  cat >"$canned/worktree.json" <<EOF
{"result":{"type":"worktree_created","workspace":{"workspace_id":"w2","number":2,"label":"worker-agent","focused":false,"pane_count":1,"tab_count":1,"active_tab_id":"w2:t1","agent_status":"idle","worktree":{"repo_key":"process-repo","repo_name":"process-repo","repo_root":"$process_repo","checkout_path":"$worktree","is_linked_worktree":true}},"tab":{"tab_id":"w2:t1","workspace_id":"w2","number":1,"label":"worker","focused":false,"pane_count":1,"agent_status":"idle"},"root_pane":{"pane_id":"w2:p1","terminal_id":"term4","workspace_id":"w2","tab_id":"w2:t1","focused":false,"cwd":"$worktree","agent_status":"idle","revision":4},"worktree":{"path":"$worktree","branch":"worker","is_bare":false,"is_detached":false,"is_prunable":false,"is_linked_worktree":true,"open_workspace_id":"w2","label":"worker"}}}
EOF
  cat >"$canned/start.json" <<EOF
{"id":"cli:agent:start","result":{"type":"agent_started","agent":{"terminal_id":"term-agent","name":"worker-agent","agent":"opencode","agent_status":"idle","workspace_id":"w1","tab_id":"w1:t2","pane_id":"w1:p3","focused":false,"interactive_ready":true,"cwd":"$pane_repo","revision":5},"argv":["opencode","--session","ses_test"]}}
EOF
  cat >"$canned/get.json" <<EOF
{"result":{"type":"agent_info","agent":{"terminal_id":"term-agent","name":"worker-agent","agent":"opencode","agent_status":"idle","workspace_id":"w1","tab_id":"w1:t2","pane_id":"w1:p3","focused":false,"interactive_ready":true,"cwd":"$pane_repo","revision":6}}}
EOF
  cat >"$canned/plugin.json" <<'EOF'
{"result":{"type":"plugin_pane_opened","plugin_pane":{"pane":{"pane_id":"w2:p4","tab_id":"w2:t99","focused":false}}}}
EOF
  cat >"$fake_bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >>"$FAKE_HERDR_LOG"
case "$1 $2" in
  "pane current") file=caller.json ;;
  "pane split") file=split.json ;;
  "pane rename") file=rename.json ;;
  "tab create") file=tab.json ;;
  "worktree create"|"worktree open") file=worktree.json ;;
  "agent start") file=start.json ;;
  "agent get") file=get.json ;;
  "plugin pane") file=plugin.json ;;
  "tab rename") file=rename.json ;;
  *) printf '{"error":{"code":"unexpected","message":"unexpected command"}}\n'; exit 1 ;;
esac
case "${FAKE_HERDR_FAILURE:-}:$1 $2" in
  busy-once:"agent start")
    if [[ ! -e "$FAKE_HERDR_BUSY_MARKER" ]]; then
      : >"$FAKE_HERDR_BUSY_MARKER"
      printf '{"error":{"code":"agent_pane_busy","message":"pane is not ready"}}\n'
      exit 1
    fi
    ;;
  malformed:"pane current") printf 'not json\n'; exit 0 ;;
  wrong-type:"pane current") jq '.result.type = "wrong"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  missing:"pane split") jq 'del(.result.pane.cwd)' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-placement:"pane split") jq '.result.pane.workspace_id = "w9"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-focus:"tab create") jq '.result.root_pane.focused = true' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-cwd:"tab create") jq '.result.root_pane.cwd = "/wrong-cwd"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-workspace:"tab create") jq '.result.tab.workspace_id = "w9"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-worktree:"worktree create") jq '.result.worktree.path = "/wrong"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-worktree:"worktree open") jq '.result.type = "worktree_opened" | .result.worktree.path = "/wrong"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-repository:"worktree create") jq '.result.workspace.worktree.repo_root = "/wrong-repository"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-repository:"worktree open") jq '.result.type = "worktree_opened" | .result.workspace.worktree.repo_root = "/wrong-repository"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-label:"tab create") jq '.result.tab.label = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-label:"worktree create") jq '.result.workspace.label = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-label:"worktree open") jq '.result.type = "worktree_opened" | .result.workspace.label = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  wrong-argv:"agent start") jq '.result.argv = ["opencode", "--session", "ses_wrong"]' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  explicit-false:"agent start") jq '.result.agent.launch_pending = false' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  pending:"agent start") jq '.result.agent.launch_pending = true' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  malformed-pending:"agent start") jq '.result.agent.launch_pending = "false"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  not-ready:"agent start") jq '.result.agent.interactive_ready = false' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  missing-ready:"agent start") jq 'del(.result.agent.interactive_ready)' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  start-failed:"agent start") printf '{"error":{"code":"agent_start_failed","message":"TUI exited"}}\n'; exit 1 ;;
  reviewr-open:"plugin pane") printf '{"error":{"code":"reviewr_open_failed","message":"plugin unavailable"}}\n' >&2; exit 1 ;;
  reviewr-no-tab:"plugin pane") jq 'del(.result.plugin_pane.pane.tab_id)' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
  reviewr-rename:"tab rename") printf '{"error":{"code":"tab_rename_failed","message":"tab unavailable"}}\n' >&2; exit 1 ;;
  wrong-agent-cwd:"agent start"|wrong-agent-cwd:"agent get") ;;
  wrong-identity:"agent get") jq '.result.agent.name = "other-agent"' "$FAKE_HERDR_CANNED/$file" ; exit 0 ;;
esac
if [[ "$1 $2" == "worktree open" ]]; then
  output=$(jq '.result.type = "worktree_opened"' "$FAKE_HERDR_CANNED/$file")
else
  output=$(<"$FAKE_HERDR_CANNED/$file")
fi
if [[ "$1 $2" == "tab create" ]]; then
  test "$5 $6" = "--cwd $FAKE_HERDR_TAB_CWD" || { printf 'tab cwd argument mismatch\n' >&2; exit 1; }
  test "$7 $8" = "--label $FAKE_HERDR_NAME" || { printf 'tab label argument mismatch\n' >&2; exit 1; }
  if [[ "${FAKE_HERDR_FAILURE:-}" != wrong-cwd ]]; then
    output=$(printf '%s\n' "$output" | jq --arg cwd "$FAKE_HERDR_TAB_CWD" '.result.root_pane.cwd = $cwd')
  fi
  output=$(printf '%s\n' "$output" | jq --arg label "$FAKE_HERDR_NAME" '.result.tab.label = $label')
fi
if [[ "$1 $2" == "worktree create" || "$1 $2" == "worktree open" ]]; then
  # The caller workspace represents a different repository in this fixture.
  test "$3 $4" = "--cwd $FAKE_HERDR_SOURCE_REPO" || { printf 'worktree repository selector mismatch\n' >&2; exit 1; }
  if [[ "$1 $2" == "worktree create" ]]; then
    test "$5 $6" = "--branch worktree/$FAKE_HERDR_NAME" || { printf 'worktree branch argument mismatch\n' >&2; exit 1; }
    test "$9 ${10}" = "--label $FAKE_HERDR_NAME" || { printf 'worktree label argument mismatch\n' >&2; exit 1; }
  else
    test "$5 $6" = "--path $FAKE_HERDR_CWD" || { printf 'worktree open path argument mismatch\n' >&2; exit 1; }
    test "$7 $8" = "--label $FAKE_HERDR_NAME" || { printf 'worktree label argument mismatch\n' >&2; exit 1; }
    test "$9" = "--no-focus" && test "$#" -eq 9 || { printf 'worktree open arguments mismatch\n' >&2; exit 1; }
  fi
fi
if [[ "$1 $2" == "agent start" || "$1 $2" == "agent get" ]]; then
  output=$(printf '%s\n' "$output" | jq \
    --arg name "$FAKE_HERDR_NAME" --arg workspace "$FAKE_HERDR_WORKSPACE" \
    --arg tab "$FAKE_HERDR_TAB" --arg pane "$FAKE_HERDR_PANE" --arg cwd "$FAKE_HERDR_CWD" \
    '.result.agent.name = $name | .result.agent.workspace_id = $workspace |
     .result.agent.tab_id = $tab | .result.agent.pane_id = $pane |
     .result.agent.cwd = $cwd')
  if [[ "${FAKE_HERDR_FAILURE:-}" == wrong-agent-cwd ]]; then
    output=$(printf '%s\n' "$output" | jq '.result.agent.cwd = "/wrong-cwd"')
  fi
fi
printf '%s\n' "$output"
EOF
  chmod +x "$fake_bin/herdr"

  managed_opencode="$test_dir/home/.local/bin/opencode-env"
  mkdir -p "$(dirname "$managed_opencode")"
  cat >"$managed_opencode" <<'EOF'
#!/usr/bin/env bash
printf 'managed opencode-env %s\n' "$*" >>"$FAKE_HERDR_LOG"
exec opencode "$@"
EOF
  chmod +x "$managed_opencode"

  cat >"$fake_bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'opencode %s\n' "$*" >>"$FAKE_HERDR_LOG"
if [[ "$1 $2 $3" == "api session.update --param" ]]; then
  [[ $# -eq 6 && "$4" == sessionID=ses_test && "$5" == --data ]] || exit 2
  [[ "${FAKE_OPENCODE_FAILURE:-}" != metadata-update ]] || {
    printf 'metadata update unavailable\n' >&2
    exit 1
  }
  jq -e --arg session ses_test --arg bead "${FAKE_TRACKING_BEAD:-}" \
    '.metadata["orchestration-tracking.launch"] ==
      {version:1,targetSessionID:$session,beadID:$bead}' <<<"$6" >/dev/null
  exit 0
fi
[[ "$1 $2 $3" == "api session.create --data" && $# -eq 4 ]] || exit 2
case "${FAKE_OPENCODE_FAILURE:-}" in
  unavailable-role) printf 'agent not found\n' >&2; exit 1 ;;
  malformed) printf 'not json\n'; exit 0 ;;
  missing-session) jq -cn --arg role "$FAKE_HERDR_ROLE" --arg cwd "$FAKE_HERDR_CWD" '{data:{agent:$role,location:{directory:$cwd}}}'; exit 0 ;;
  wrong-role) jq -cn --arg cwd "$FAKE_HERDR_CWD" '{data:{id:"ses_test",agent:"build",location:{directory:$cwd}}}'; exit 0 ;;
  wrong-location) jq -cn --arg role "$FAKE_HERDR_ROLE" '{data:{id:"ses_test",agent:$role,location:{directory:"/wrong"}}}'; exit 0 ;;
esac
jq -e --arg role "$FAKE_HERDR_ROLE" --arg cwd "$FAKE_HERDR_CWD" \
  '. == {agent:$role,location:{directory:$cwd}}' <<<"$4" >/dev/null
jq -cn --arg role "$FAKE_HERDR_ROLE" --arg cwd "$FAKE_HERDR_CWD" \
  '{data:{id:"ses_test",agent:$role,location:{directory:$cwd}}}'
EOF
  chmod +x "$fake_bin/opencode"
  assert_not_contains "$launcher" ' --agent '

  run_launcher() {
    local role=$1 topology=$2 name=$3
    shift 3
    local launcher_path=${1:-}
    [[ -z "$launcher_path" || "$launcher_path" != --* ]] || launcher_path=
    [[ -n "$launcher_path" ]] && shift
    local tracking_bead=
    if [[ ${1:-} == --tracking-bead ]]; then
      [[ $# -eq 2 ]] || return 2
      tracking_bead=$2
      shift 2
    fi
    [[ $# -eq 0 ]] || return 2
    local -a launcher_args=("$role" "$topology" "$name")
    [[ -n "$launcher_path" ]] && launcher_args+=("$launcher_path")
    [[ -n "$tracking_bead" ]] && launcher_args+=(--tracking-bead "$tracking_bead")
    local fake_workspace=w1 fake_tab=w1:t2 fake_pane=w1:p3 fake_cwd=$pane_repo fake_tab_cwd=$pane_repo
    case "$topology" in
      sibling) fake_tab=w1:t1; fake_pane=w1:p2 ;;
      tab) [[ -z "$launcher_path" ]] || { fake_cwd=$launcher_path; fake_tab_cwd=$launcher_path; } ;;
      worktree) fake_workspace=w2; fake_tab=w2:t1; fake_pane=w2:p1; fake_cwd=$worktree ;;
    esac
    : >"$log"
    (
      CDPATH= cd -- "$process_repo"
      HOME="$test_dir/home" PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
        FAKE_HERDR_FAILURE="${FAKE_HERDR_FAILURE:-}" FAKE_OPENCODE_FAILURE="${FAKE_OPENCODE_FAILURE:-}" \
        FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE="$role" \
        FAKE_HERDR_SOURCE_REPO="$process_repo" \
        FAKE_HERDR_NAME="$name" FAKE_HERDR_WORKSPACE="$fake_workspace" \
        FAKE_HERDR_TAB="$fake_tab" FAKE_HERDR_PANE="$fake_pane" FAKE_HERDR_CWD="$fake_cwd" \
        FAKE_HERDR_TAB_CWD="$fake_tab_cwd" FAKE_HERDR_BUSY_MARKER="$test_dir/busy-marker" \
        FAKE_TRACKING_BEAD="$tracking_bead" \
        bash "$launcher" "${launcher_args[@]}"
    )
  }

  metadata=$(run_launcher architect sibling architect-agent)
  jq -e --arg cwd "$pane_repo" ' . == {role:"architect",topology:"sibling",agent_name:"architect-agent",agent_kind:"opencode",workspace_id:"w1",tab_id:"w1:t1",pane_id:"w1:p2",cwd:$cwd,session_id:"ses_test"}' <<<"$metadata" >/dev/null
  assert_contains "$log" "pane split --current --direction right --cwd $pane_repo --no-focus"
  test "$(grep -Fc 'pane rename ' "$log")" -eq 2
  grep -Fxq 'pane rename w1:p1 orchestrator' "$log"
  grep -Fxq 'pane rename w1:p2 architect' "$log"
  assert_contains "$log" "opencode api session.create --data {\"agent\":\"architect\",\"location\":{\"directory\":\"$pane_repo\"}}"
  assert_contains "$log" 'managed opencode-env api session.create'
  assert_contains "$log" 'agent start architect-agent --kind opencode --pane w1:p2 -- --session ses_test'
  assert_not_contains "$log" 'plugin pane open'

  tracking_bead=$(printf '%s%s%s' 'fixture' '-' 'bead')
  metadata=$(run_launcher worker tab worker --tracking-bead "$tracking_bead")
  jq -e --arg cwd "$pane_repo" --arg bead "$tracking_bead" \
    '. == {role:"worker",topology:"tab",agent_name:"worker",agent_kind:"opencode",workspace_id:"w1",tab_id:"w1:t2",pane_id:"w1:p3",cwd:$cwd,session_id:"ses_test"} and
     (tostring | contains($bead) | not)' <<<"$metadata" >/dev/null
  create_line=$(grep -n 'opencode api session.create ' "$log" | cut -d: -f1)
  update_line=$(grep -n 'opencode api session.update ' "$log" | cut -d: -f1)
  start_line=$(grep -n 'agent start ' "$log" | cut -d: -f1)
  test "$create_line" -lt "$update_line"
  test "$update_line" -lt "$start_line"
  assert_contains "$log" 'targetSessionID":"ses_test"'
  assert_contains "$log" "beadID\":\"$tracking_bead\""

  metadata_error="$test_dir/metadata-error"
  metadata=$(FAKE_OPENCODE_FAILURE=metadata-update run_launcher worker tab worker --tracking-bead "$tracking_bead" \
    2>"$metadata_error")
  jq -e --arg bead "$tracking_bead" '.session_id == "ses_test" and (tostring | contains($bead) | not)' \
    <<<"$metadata" >/dev/null
  assert_contains "$metadata_error" 'tracking metadata update failed; continuing launch.'
  assert_not_contains "$metadata_error" "$tracking_bead"
  assert_contains "$log" 'agent start worker --kind opencode --pane w1:p3 -- --session ses_test'

  if run_launcher worker tab worker --tracking-bead 'bad/identity' >/dev/null 2>&1; then exit 1; fi
  if run_launcher worker tab worker --tracking-bead "$tracking_bead" --tracking-bead "$tracking_bead" >/dev/null 2>&1; then exit 1; fi
  if run_launcher worker tab worker --unknown-flag >/dev/null 2>&1; then exit 1; fi

  metadata=$(run_launcher worker tab worker)
  jq -e --arg cwd "$pane_repo" ' . == {role:"worker",topology:"tab",agent_name:"worker",agent_kind:"opencode",workspace_id:"w1",tab_id:"w1:t2",pane_id:"w1:p3",cwd:$cwd,session_id:"ses_test"}' <<<"$metadata" >/dev/null
  assert_contains "$log" "tab create --workspace w1 --cwd $pane_repo --label worker --no-focus"
  assert_contains "$log" 'agent start worker --kind opencode --pane w1:p3 -- --session ses_test'
  assert_contains "$log" "plugin pane open --plugin persiyanov.reviewr --entrypoint pane --placement split --target-pane w1:p3 --cwd $pane_repo --no-focus"
  test "$(grep -Fc 'plugin pane open' "$log")" -eq 1
  assert_not_contains "$log" 'tab rename '

  metadata=$(FAKE_HERDR_FAILURE=explicit-false run_launcher worker tab worker-agent)
  jq -e --arg cwd "$pane_repo" ' .cwd == $cwd and .agent_name == "worker-agent"' <<<"$metadata" >/dev/null

  metadata=$(run_launcher worker tab worker "$delivery_worktree")
  jq -e --arg cwd "$delivery_worktree" ' . == {role:"worker",topology:"tab",agent_name:"worker",agent_kind:"opencode",workspace_id:"w1",tab_id:"w1:t2",pane_id:"w1:p3",cwd:$cwd,session_id:"ses_test"}' <<<"$metadata" >/dev/null
  assert_contains "$log" "tab create --workspace w1 --cwd $delivery_worktree --label worker --no-focus"
  assert_contains "$log" "opencode api session.create --data {\"agent\":\"worker\",\"location\":{\"directory\":\"$delivery_worktree\"}}"
  assert_contains "$log" 'agent start worker --kind opencode --pane w1:p3 -- --session ses_test'

  rm -f "$test_dir/busy-marker"
  FAKE_HERDR_FAILURE=busy-once metadata=$(run_launcher worker tab worker "$delivery_worktree")
  test "$(grep -Fc 'agent start ' "$log")" -eq 2
  test "$(grep -Fc 'plugin pane open' "$log")" -eq 1

  : >"$log"
  if FAKE_HERDR_FAILURE=wrong-label run_launcher worker tab worker >/dev/null 2>&1; then exit 1; fi
  assert_not_contains "$log" 'agent start '

  if run_launcher worker tab worker "$test_dir/missing-worktree" >/dev/null 2>&1; then exit 1; fi
  if run_launcher worker tab worker "$pane_repo" >/dev/null 2>&1; then exit 1; fi

  metadata=$(run_launcher worker worktree worker-agent "$worktree")
  jq -e --arg path "$worktree" ' . == {role:"worker",topology:"worktree",agent_name:"worker-agent",agent_kind:"opencode",workspace_id:"w2",tab_id:"w2:t1",pane_id:"w2:p1",cwd:$path,session_id:"ses_test",worktree_path:$path}' <<<"$metadata" >/dev/null
  assert_contains "$log" "worktree create --cwd $process_repo --branch worktree/worker-agent --path $worktree --label worker-agent --no-focus"
  assert_contains "$log" "opencode api session.create --data {\"agent\":\"worker\",\"location\":{\"directory\":\"$worktree\"}}"
  assert_contains "$log" 'agent start worker-agent --kind opencode --pane w2:p1 -- --session ses_test'
  assert_contains "$log" "plugin pane open --plugin persiyanov.reviewr --entrypoint pane --placement tab --workspace w2 --cwd $worktree --no-focus"
  assert_contains "$log" 'tab rename w2:t99 reviewr'
  test "$(grep -Fc 'plugin pane open' "$log")" -eq 1

  metadata=$(FAKE_HERDR_FAILURE=reviewr-no-tab run_launcher worker worktree worker-agent "$worktree")
  jq -e --arg path "$worktree" ' .cwd == $path and .agent_name == "worker-agent"' <<<"$metadata" >/dev/null
  test "$(grep -Fc 'plugin pane open' "$log")" -eq 1
  assert_not_contains "$log" 'tab rename '

  metadata=$(FAKE_HERDR_FAILURE=reviewr-rename run_launcher worker worktree worker-agent "$worktree")
  jq -e --arg path "$worktree" ' .cwd == $path and .agent_name == "worker-agent"' <<<"$metadata" >/dev/null
  assert_contains "$log" 'tab rename w2:t99 reviewr'

  reviewr_error="$test_dir/reviewr-error"
  metadata=$(FAKE_HERDR_FAILURE=reviewr-open run_launcher worker tab worker-agent 2>"$reviewr_error")
  jq -e --arg cwd "$pane_repo" ' .cwd == $cwd and .agent_name == "worker-agent"' <<<"$metadata" >/dev/null
  test "$(grep -Fc 'plugin pane open' "$log")" -eq 1
  assert_contains "$reviewr_error" 'herdr-agent-launch: Reviewr open failed:'

  : >"$log"
  if FAKE_HERDR_FAILURE=wrong-label run_launcher worker worktree worker-agent "$worktree" >/dev/null 2>&1; then exit 1; fi
  assert_not_contains "$log" 'agent start '

  mkdir -p "$worktree"
  metadata=$(run_launcher worker worktree worker-agent "$worktree")
  jq -e --arg path "$worktree" '.worktree_path == $path' <<<"$metadata" >/dev/null
  assert_contains "$log" "worktree open --cwd $process_repo --path $worktree --label worker-agent --no-focus"

  : >"$log"
  if FAKE_HERDR_FAILURE=wrong-label run_launcher worker worktree worker-agent "$worktree" >/dev/null 2>&1; then exit 1; fi
  assert_not_contains "$log" 'agent start '

  : >"$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" worker sibling bad-name 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" reviewer tab reviewer-agent 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" worker worktree worker-agent relative 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=1 FAKE_HERDR_LOG="$log" bash "$launcher" worker tab worker relative 2>/dev/null; then exit 1; fi
  test ! -s "$log"
  if PATH="$fake_bin:$PATH" HERDR_ENV=0 bash "$launcher" worker tab worker-agent 2>/dev/null; then exit 1; fi
  test ! -s "$log"

  for failure in malformed wrong-type; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
      FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w1 FAKE_HERDR_TAB=w1:t2 FAKE_HERDR_PANE=w1:p3 FAKE_HERDR_CWD="$pane_repo" \
      FAKE_HERDR_TAB_CWD="$pane_repo" \
      bash "$launcher" worker tab worker-agent 2>/dev/null; then exit 1; fi
  done
  for failure in wrong-focus wrong-cwd wrong-workspace; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
      FAKE_HERDR_NAME=worker FAKE_HERDR_WORKSPACE=w1 FAKE_HERDR_TAB=w1:t2 FAKE_HERDR_PANE=w1:p3 FAKE_HERDR_CWD="$delivery_worktree" \
      FAKE_HERDR_TAB_CWD="$delivery_worktree" bash "$launcher" worker tab worker "$delivery_worktree" 2>/dev/null; then exit 1; fi
    assert_not_contains "$log" 'agent start '
  done
  for failure in wrong-agent-cwd; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
      FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w1 FAKE_HERDR_TAB=w1:t2 FAKE_HERDR_PANE=w1:p3 FAKE_HERDR_CWD="$delivery_worktree" \
      FAKE_HERDR_TAB_CWD="$delivery_worktree" bash "$launcher" worker tab worker-agent "$delivery_worktree" 2>/dev/null; then exit 1; fi
    assert_not_contains "$log" 'agent get '
  done
  for failure in missing wrong-placement; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=architect \
      bash "$launcher" architect sibling architect-agent 2>/dev/null; then exit 1; fi
  done
  for failure in wrong-focus wrong-argv wrong-identity; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
      FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
      FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w1 FAKE_HERDR_TAB=w1:t2 FAKE_HERDR_PANE=w1:p3 FAKE_HERDR_CWD="$pane_repo" \
      FAKE_HERDR_TAB_CWD="$pane_repo" \
      bash "$launcher" worker tab worker-agent 2>/dev/null; then exit 1; fi
  done
  for failure in unavailable-role malformed missing-session wrong-role wrong-location; do
    : >"$log"
    if FAKE_OPENCODE_FAILURE=$failure run_launcher worker tab worker-agent >/dev/null 2>&1; then exit 1; fi
    assert_not_contains "$log" 'agent start '
  done
  for failure in start-failed not-ready missing-ready pending malformed-pending; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure run_launcher worker tab worker-agent >/dev/null 2>&1; then exit 1; fi
    assert_not_contains "$log" 'agent get '
  done
  for failure in wrong-worktree wrong-repository; do
    : >"$log"
    if FAKE_HERDR_FAILURE=$failure PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
    FAKE_HERDR_LOG="$log" FAKE_HERDR_CANNED="$canned" FAKE_HERDR_ROLE=worker \
    FAKE_HERDR_SOURCE_REPO="$process_repo" \
    FAKE_HERDR_NAME=worker-agent FAKE_HERDR_WORKSPACE=w2 FAKE_HERDR_TAB=w2:t1 FAKE_HERDR_PANE=w2:p1 \
    FAKE_HERDR_CWD="$worktree" bash "$launcher" worker worktree worker-agent "$worktree" 2>/dev/null; then exit 1; fi
    assert_not_contains "$log" 'agent start '
  done
}

assert_herdr_agent_launcher

elio_source="$source_dir/dot_config/herdr/plugins/local/angel-o.elio"
test -f "$elio_source/herdr-plugin.toml"
test -x "$elio_source/bin/executable_resolve-dir.sh"
test ! -e "$elio_source/README.md"
test ! -e "$elio_source/assets"
test ! -e "$elio_source/.git"
python3 -c 'from pathlib import Path; import sys; assert {str(path.relative_to(sys.argv[1])) for path in Path(sys.argv[1]).rglob("*") if path.is_file()} == {"herdr-plugin.toml", "bin/executable_resolve-dir.sh"}' "$elio_source"
assert_contains "$elio_source/herdr-plugin.toml" 'id = "angel-o.elio"'
assert_contains "$elio_source/herdr-plugin.toml" '--plugin angel-o.elio --entrypoint explorer --placement split'
assert_contains "$elio_source/herdr-plugin.toml" '--plugin angel-o.elio --entrypoint explorer --placement tab'
assert_not_contains "$elio_source/herdr-plugin.toml" 'cargo install'
assert_not_contains "$elio_source/bin/executable_resolve-dir.sh" 'node -e'
test "$(HERDR_PLUGIN_CONTEXT_JSON='{"focused_pane_cwd":"/focused","workspace_cwd":"/workspace"}' bash "$elio_source/bin/executable_resolve-dir.sh")" = /focused
test "$(HERDR_PLUGIN_CONTEXT_JSON='{"focused_pane_cwd":"","workspace_cwd":"/workspace"}' bash "$elio_source/bin/executable_resolve-dir.sh")" = /workspace
# Malformed context intentionally exercises the fallback; jq's parse warning is expected.
test "$(HERDR_PLUGIN_CONTEXT_JSON='not-json' bash -c 'cd /tmp && exec bash "$1"' _ "$elio_source/bin/executable_resolve-dir.sh" 2>/dev/null)" = /tmp

assert_hub_viewer_plugin() {
  local hub_source="$source_dir/dot_config/herdr/plugins/local/angel-o.hub-viewer"
  test -f "$hub_source/herdr-plugin.toml"
  test ! -e "$hub_source/README.md"
  test ! -e "$hub_source/assets"
  test ! -e "$hub_source/.git"
  python3 -c 'from pathlib import Path; import sys; assert {str(path.relative_to(sys.argv[1])) for path in Path(sys.argv[1]).rglob("*") if path.is_file()} == {"herdr-plugin.toml"}' "$hub_source"
  assert_contains "$hub_source/herdr-plugin.toml" 'id = "angel-o.hub-viewer"'
  assert_contains "$hub_source/herdr-plugin.toml" 'command = ["bash", "-c", "wbv --hub; exec \"${HERDR_BIN_PATH:-herdr}\" plugin pane close \"$HERDR_PANE_ID\""]'
  assert_not_contains "$hub_source/herdr-plugin.toml" 'exec wbv --hub'
  assert_contains "$hub_source/herdr-plugin.toml" 'command = ["bash", "-c", "exec \"${HERDR_BIN_PATH:-herdr}\" plugin pane open --plugin angel-o.hub-viewer --entrypoint viewer --placement split"]'
  assert_contains "$hub_source/herdr-plugin.toml" '--plugin angel-o.hub-viewer --entrypoint viewer --placement split'
  assert_contains "$hub_source/herdr-plugin.toml" '--plugin angel-o.hub-viewer --entrypoint viewer --placement tab'
  assert_contains "$hub_source/herdr-plugin.toml" 'opened=$(\"${HERDR_BIN_PATH:-herdr}\" plugin pane open --plugin angel-o.hub-viewer --entrypoint viewer --placement tab);'
  assert_contains "$hub_source/herdr-plugin.toml" 'tab=$(printf '\''%s'\'' \"$opened\" | jq -r '\''.result.plugin_pane.pane.tab_id // empty'\'')'
  assert_contains "$hub_source/herdr-plugin.toml" 'HERDR_PLUGIN_CONFIG_DIR:-'
  assert_contains "$hub_source/herdr-plugin.toml" 'dasel query --in toml --out json --compact '\''tab_label'\'''
  assert_contains "$hub_source/herdr-plugin.toml" 'jq -er '\''select(type == \"string\" and length > 0)'\'''
  assert_contains "$hub_source/herdr-plugin.toml" '\"${HERDR_BIN_PATH:-herdr}\" tab rename \"$tab\" \"$label\"'
  assert_not_contains "$hub_source/herdr-plugin.toml" 'python3'
  assert_not_contains "$hub_source/herdr-plugin.toml" 'cargo install'

  local action="$root/herdr-hub-viewer/action.sh"
  local fake_bin="$root/herdr-hub-viewer/bin"
  local log="$root/herdr-hub-viewer/herdr.log"
  local config_dir="$root/herdr-hub-viewer/config"
  mkdir -p "$fake_bin" "$config_dir"
  python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["actions"][1]["command"][2])' \
    "$hub_source/herdr-plugin.toml" >"$action"
  cat >"$fake_bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  "plugin pane")
    case "$3" in
      open) printf '%s\n' '{"result":{"plugin_pane":{"pane":{"tab_id":"w1:t99"}}}}' ;;
      close) printf '%s\n' "$*" >>"$FAKE_HERDR_LOG" ;;
      *) exit 1 ;;
    esac
    ;;
  "tab rename") printf '%s\n' "$*" >>"$FAKE_HERDR_LOG" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$fake_bin/herdr"
  cat >"$fake_bin/wbv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'wbv %s\n' "$*" >>"$FAKE_HERDR_LOG"
EOF
  chmod +x "$fake_bin/wbv"
  cat >"$fake_bin/dasel" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test "$*" = "query --in toml --out json --compact tab_label"
config=$(cat)
case "$config" in
  *'tab_label = ""'*) printf '%s\n' '""' ;;
  *'tab_label = "custom board"'*) printf '%s\n' '"custom board"' ;;
  *'tab_label = 42'*) printf '%s\n' '42' ;;
  *'malformed = true'*) printf '%s\n' 'not-json' ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$fake_bin/dasel"
  local pane_command="$root/herdr-hub-viewer/pane.sh"
  python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["panes"][0]["command"][2])' \
    "$hub_source/herdr-plugin.toml" >"$pane_command"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PANE_ID=w1:p42 \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$pane_command"
  python3 -c 'import sys; assert open(sys.argv[1]).read() == "wbv --hub\nplugin pane close w1:p42\n"' "$log"
  : >"$log"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PLUGIN_CONFIG_DIR="$config_dir/missing" \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$action"
  assert_contains "$log" 'tab rename w1:t99 hub viewer'
  : >"$log"
  printf 'other = true\n' >"$config_dir/config.toml"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PLUGIN_CONFIG_DIR="$config_dir" \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$action"
  assert_contains "$log" 'tab rename w1:t99 hub viewer'
  : >"$log"
  printf 'tab_label = ""\n' >"$config_dir/config.toml"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PLUGIN_CONFIG_DIR="$config_dir" \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$action"
  assert_contains "$log" 'tab rename w1:t99 hub viewer'
  : >"$log"
  printf 'tab_label = 42\n' >"$config_dir/config.toml"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PLUGIN_CONFIG_DIR="$config_dir" \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$action"
  assert_contains "$log" 'tab rename w1:t99 hub viewer'
  : >"$log"
  printf 'malformed = true\n' >"$config_dir/config.toml"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PLUGIN_CONFIG_DIR="$config_dir" \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$action"
  assert_contains "$log" 'tab rename w1:t99 hub viewer'
  : >"$log"
  printf 'tab_label = "custom board"\n' >"$config_dir/config.toml"
  HERDR_BIN_PATH="$fake_bin/herdr" HERDR_PLUGIN_CONFIG_DIR="$config_dir" \
    FAKE_HERDR_LOG="$log" PATH="$fake_bin:$PATH" bash "$action"
  assert_contains "$log" 'tab rename w1:t99 custom board'
}

assert_hub_viewer_plugin

if [[ "${TEST_SCOPE:-}" == herdr-hub-viewer ]]; then
  personal_brewfile="$root/herdr-hub-viewer/personal.Brewfile"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$personal_brewfile"
  assert_contains "$personal_brewfile" 'brew "dasel"'
  work_brewfile="$root/herdr-hub-viewer/work.Brewfile"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$work_brewfile"
  assert_not_contains "$work_brewfile" 'brew "dasel"'
  disabled_brewfile="$root/herdr-hub-viewer/disabled.Brewfile"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/herdr-disabled-plugins.toml" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$disabled_brewfile"
  assert_not_contains "$disabled_brewfile" 'brew "dasel"'
  herdr_disabled_preference_brewfile="$root/herdr-hub-viewer/herdr-disabled-preference.Brewfile"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/herdr-disabled-hub-viewer.toml" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$herdr_disabled_preference_brewfile"
  assert_not_contains "$herdr_disabled_preference_brewfile" 'brew "dasel"'
  hub_config="$root/herdr-hub-viewer/config.toml"
  mkdir -p "${hub_config%/*}"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
    <"$source_dir/dot_config/herdr/config.toml.tmpl" >"$hub_config"
  assert_contains "$hub_config" 'split_vertical = ["prefix+v", "alt+s"]'
   assert_contains "$hub_config" 'key = "prefix+ctrl+h"'
  assert_contains "$hub_config" 'command = "angel-o.hub-viewer.open"'
    assert_contains "$hub_config" 'key = "prefix+shift+ctrl+h"'
   assert_contains "$hub_config" 'command = "angel-o.hub-viewer.open-tab"'
    assert_contains "$hub_config" 'key = "prefix+ctrl+p"'
   assert_contains "$hub_config" 'command = "annotate.last-newest"'
  personal_installer="$root/herdr-hub-viewer/personal-installer.sh"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" \
    <"$source_dir/run_after_30-install-herdr-plugins.sh.tmpl" >"$personal_installer"
   sh -n "$personal_installer"
   assert_contains "$personal_installer" "ensure_github_plugin annotate \"plannotator/herdr-annotate\" \"$annotate_ref\""
  assert_contains "$personal_installer" 'herdr plugin link "$hub_viewer_root" --enabled'
  assert_contains "$personal_installer" 'hub_viewer_root="$HOME/.config/herdr/plugins/local/angel-o.hub-viewer"'
  disabled_installer="$root/herdr-hub-viewer/disabled-installer.sh"
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/herdr-disabled-plugins.toml" \
    <"$source_dir/run_after_30-install-herdr-plugins.sh.tmpl" >"$disabled_installer"
   sh -n "$disabled_installer"
   assert_not_contains "$disabled_installer" 'plannotator/herdr-annotate'
  assert_not_contains "$disabled_installer" 'angel-o.hub-viewer'
  apply_fixture personal
  test -f "$root/personal/home/.config/herdr/plugins/local/angel-o.hub-viewer/herdr-plugin.toml"
  test -f "$root/personal/home/.config/herdr/plugins/config/angel-o.hub-viewer/config.toml"
  python3 -c 'import sys,tomllib; assert tomllib.load(open(sys.argv[1], "rb")) == {"tab_label": "hub viewer"}' \
    "$root/personal/home/.config/herdr/plugins/config/angel-o.hub-viewer/config.toml"
  assert_contains "$root/personal/home/.config/herdr/config.toml" 'command = "angel-o.hub-viewer.open"'
  assert_contains "$root/personal/home/.config/herdr/config.toml" 'command = "angel-o.hub-viewer.open-tab"'
  apply_fixture herdr-disabled-plugins
  test ! -e "$root/herdr-disabled-plugins/home/.config/herdr/plugins/local/angel-o.hub-viewer"
  test ! -e "$root/herdr-disabled-plugins/home/.config/herdr/plugins/config/angel-o.hub-viewer"
  assert_not_contains "$root/herdr-disabled-plugins/home/.config/herdr/config.toml" 'angel-o.hub-viewer'
  exit 0
fi

bash "$source_dir/tests/test-memex.sh"
[[ "${TEST_SCOPE:-}" != memex ]] || exit 0

test ! -e "$source_dir/dot_config/opencode/skills/orchestration-worker-delivery/SKILL.md"
assert_not_contains "$source_dir/dot_config/opencode/agents/orchestrator.md" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/dot_config/opencode/commands/orchestrate-task.md.tmpl" 'orchestration-worker-delivery'
assert_not_contains "$source_dir/dot_config/opencode/commands/orchestrate-epic.md.tmpl" 'orchestration-worker-delivery'

[[ "${TEST_SCOPE:-}" != herdr-agent-launch ]] || exit 0

bash "$source_dir/tests/test-write-bead.sh"
bash "$source_dir/tests/test-opencode-alignment.sh"

assert_contains "$source_dir/README.md" '`wbd` is always Hub-only'
assert_contains "$source_dir/README.md" '`beads-hub` and `beads-hub-closeout` skills'
assert_contains "$source_dir/README.md" 'atomically installs `bd`, `bv`, `wbd`, and `wbv`'
assert_contains "$source_dir/README.md" '`~/.local/libexec/beads-viewer`'
assert_contains "$source_dir/README.md" '~/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh'
assert_contains "$source_dir/README.md" 'Disabling the module stops future installation and management without deleting'
python3 -c 'import json,tomllib,sys; source=sys.argv[1]; pins=tomllib.load(open(source+"/.chezmoidata.toml", "rb"))["pins"]; config=json.load(open(source+"/renovate.json")); managers=config["customManagers"]; assert "elio" not in pins["herdrPlugins"]; assert pins["beads"]["branch"] == "feat/bulk-history-read"; assert pins["beadsViewer"]["branch"] == "feature/repository-aware-correlations"; runtime=[manager for manager in managers if manager.get("depTypeTemplate") == "beads-runtime" and manager.get("datasourceTemplate") == "git-refs"]; assert len(runtime) == 2; assert any(rule.get("groupName") == "Beads runtime" for rule in config["packageRules"])' "$source_dir"
beads_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beads"]["ref"])' "$source_dir/.chezmoidata.toml")
beads_viewer_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beadsViewer"]["ref"])' "$source_dir/.chezmoidata.toml")
reviewr_source=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["herdrPlugins"]["reviewr"]["source"])' "$source_dir/.chezmoidata.toml")
reviewr_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["herdrPlugins"]["reviewr"]["ref"])' "$source_dir/.chezmoidata.toml")
ponytail_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["ponytailSkill"])' "$source_dir/.chezmoidata.toml")

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
assert_contains "$agents_modifier_dir/balanced.after" '## REPOSITORY ROOT'
assert_contains "$agents_modifier_dir/balanced.after" 'When locating a named local repository, look under ~/workspace/source/.'
test "$(grep -Fxc '## REPOSITORY ROOT' "$agents_modifier_dir/balanced.after")" -eq 1
test "$(grep -Fxc 'When locating a named local repository, look under ~/workspace/source/.' "$agents_modifier_dir/balanced.after")" -eq 1
assert_contains "$agents_modifier_dir/balanced.after" 'load the global `beads-hub` skill before acting'
assert_contains "$agents_modifier_dir/balanced.after" 'use only `wbd` and approved `wbv --robot-*` queries'
assert_contains "$agents_modifier_dir/balanced.after" 'never raw `bd`, `bv`, or `br`'
assert_contains "$agents_modifier_dir/balanced.after" 'Commit correlation and Bead closure must not occur during implementation, commit, push, or PR creation. Perform both only after the change is merged, through the `beads-hub-closeout` workflow.'
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
assert_contains "$agents_modifier_dir/disabled.after" '## REPOSITORY ROOT'
assert_contains "$agents_modifier_dir/disabled.after" 'When locating a named local repository, look under ~/workspace/source/.'
test "$(grep -Fxc '## REPOSITORY ROOT' "$agents_modifier_dir/disabled.after")" -eq 1
test "$(grep -Fxc 'When locating a named local repository, look under ~/workspace/source/.' "$agents_modifier_dir/disabled.after")" -eq 1
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
printf '%s\n' \
  '## REPOSITORY ROOT' \
  'When locating a named local repository, look under ~/workspace/source/.' >>"$agents_modifier_dir/crlf.expected"
python3 - "$agents_modifier_dir/crlf.disabled" "$agents_modifier_dir/crlf.disabled.preserved" <<'PY'
from pathlib import Path
import sys

output = Path(sys.argv[1]).read_bytes()
start = b'<!-- meaningful-validation:start -->\n'
end = b'<!-- meaningful-validation:end -->\n'
assert output.count(start) == output.count(end) == 1
preserved, managed = output.split(start)
_, suffix = managed.split(end)
Path(sys.argv[2]).write_bytes(preserved + suffix)
PY
cmp -s "$agents_modifier_dir/crlf.expected" "$agents_modifier_dir/crlf.disabled.preserved"

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
assert_todo_installer "$root/personal/rendered/run_before_06-install-opencode-todo.sh.tmpl"
assert_ponytail_external "$root/personal/rendered/externals.toml"
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/SKILL.md'
assert_not_contains "$root/personal/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/validate.sh'
assert_contains "$root/personal/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "helix"'
assert_contains "$root/personal/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/personal/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "beads"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "beads_viewer"'
assert_not_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'Angel-O/beads'
assert_not_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'Angel-O/beads_viewer'
assert_contains "$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'exit 0'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "bat"'
assert_not_contains "$root/personal/rendered/Brewfile" 'brew "git-delta"'
assert_contains "$source_dir/.chezmoi.toml.tmpl" 'sourceDir = {{ .chezmoi.sourceDir | quote }}'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin thomasschafer.herdr-kiosk "thomasschafer/herdr-kiosk"'
assert_not_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'den-tanui/herdr-zoxide'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin ez-corp.space-usage "ezcorp-org/herdr-pc-ram-and-cpu-usage-overlay"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'herdr plugin link "$HOME/.config/herdr/plugins/local/angel-o.elio" --enabled'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'elio_root="$HOME/.config/herdr/plugins/local/angel-o.elio"'
assert_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" "ensure_github_plugin persiyanov.reviewr \"$reviewr_source\" \"$reviewr_ref\""
assert_not_contains "$root/personal/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root='
assert_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" 'herdr integration install opencode'
assert_not_contains "$root/personal/rendered/run_after_40-install-herdr-integrations.sh.tmpl" 'herdr integration status'
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
launcher_transition_home="$root/launcher-transition/home"
mkdir -p "$launcher_transition_home"
chezmoi apply --source "$source_dir" --destination "$launcher_transition_home" \
  --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" \
  --persistent-state "$root/launcher-transition/state.boltdb" --exclude scripts,externals --force
test -x "$launcher_transition_home/.local/bin/herdr-agent-launch"
chezmoi execute-template --source "$source_dir" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  <"$source_dir/.chezmoiremove.tmpl" >"$root/launcher-transition/remove-list"
grep -Fxq '.local/bin/herdr-agent-launch' "$root/launcher-transition/remove-list"
test -f "$personal_home/.config/helix/config.toml"
assert_contains "$personal_home/.config/helix/config.toml" 'theme = "dracula_at_night"'
test -f "$personal_home/.warp/settings.toml"
assert_warp_policy "$personal_home/.warp/settings.toml"
assert_contains "$personal_home/.config/ghostty/config" 'macos-option-as-alt = true'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'interval_seconds = 30'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'window_title_totals = false'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'ram_display = "absolute"'
assert_contains "$personal_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml" 'icons = "nerdfont"'
assert_contains "$personal_home/.config/herdr/config.toml" 'window_title = "{hostname}: {workspace}"'
assert_contains "$personal_home/.config/herdr/config.toml" 'rows = [["state_icon", "workspace", { token = "agent", dim = true }], ["state_text", { token = "tab", dim = false }]]'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "thomasschafer.herdr-kiosk.open-picker"'
assert_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+o"'
assert_not_contains "$personal_home/.config/herdr/config.toml" 'herdr-zoxide.browse'
test ! -e "$personal_home/.config/herdr/plugins/config/thomasschafer.herdr-kiosk/config.toml"
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "angel-o.elio.open"'
test -f "$personal_home/.config/herdr/plugins/local/angel-o.elio/herdr-plugin.toml"
test -x "$personal_home/.config/herdr/plugins/local/angel-o.elio/bin/resolve-dir.sh"
test ! -e "$personal_home/.config/herdr/plugins/local/angel-o.elio/README.md"
test ! -e "$personal_home/.config/herdr/plugins/local/angel-o.elio/assets"
test ! -e "$personal_home/.config/herdr/plugins/local/angel-o.elio/.git"
assert_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+ctrl+h"'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "angel-o.hub-viewer.open"'
assert_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+shift+ctrl+h"'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "angel-o.hub-viewer.open-tab"'
test -f "$personal_home/.config/herdr/plugins/local/angel-o.hub-viewer/herdr-plugin.toml"
assert_contains "$personal_home/.config/ghostty/config" 'theme = dark:herdr-dracula,light:TokyoNight Day'
test -f "$personal_home/.config/ghostty/themes/herdr-dracula"
assert_contains "$personal_home/.config/ghostty/themes/herdr-dracula" 'background = #282a36'
assert_contains "$personal_home/.config/ghostty/themes/herdr-dracula" 'selection-background = #44475a'
assert_contains "$personal_home/.config/herdr/config.toml" 'key = "prefix+ctrl+p"'
assert_contains "$personal_home/.config/herdr/config.toml" 'command = "annotate.last-newest"'

assert_contains "$personal_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'markdown_view = "rendered"'
assert_not_contains "$personal_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'bd = "ai board"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'wbd = "ai board"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
assert_contains "$personal_home/.config/herdr-labels/config.toml" 'ignored_processes = ["ls", "cat", "pwd", "clear", "git", "direnv", "scutil", "starship"]'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["ignored_processes"] == ["ls", "cat", "pwd", "clear", "git", "direnv", "scutil", "starship"]; assert data["process_aliases"] == {"bd": "ai board", "bv": "ai board", "wbd": "ai board", "wbv": "ai board"}' "$personal_home/.config/herdr-labels/config.toml"
assert_contains "$personal_home/.config/zsh/starship.zsh" '[[ ${TERM_PROGRAM:-} == "WarpTerminal" && ${HERDR_ENV:-} != 1 ]]'
assert_contains "$personal_home/.config/zsh/starship.zsh" "TRANSIENT_PROMPT_PROMPT=''"
assert_contains "$personal_home/.config/zsh/starship.zsh" 'Keep completed prompts compact in every terminal, including Warp.'
test -f "$personal_home/.config/opencode/portable.jsonc"
test -f "$personal_home/.config/opencode/cli.json"
test -x "$personal_home/.local/bin/herdr-agent-launch"
assert_contains "$personal_home/.config/opencode/cli.json" '"./herdr-opencode"'
python3 - "$personal_home/.config/opencode/cli.json" <<'PY'
import json
import sys

cli = json.load(open(sys.argv[1]))
assert cli["diffs"]["fullscreen"] is False
assert cli["debug"] == {"devtools": True, "timing": False, "turn_tokens": True}
PY
assert_agent_contracts "$personal_home/.config/opencode/agents"
for agent in orchestrator integration investigator reviewer worker architect planner; do
  test -f "$personal_home/.config/opencode/agents/$agent.md"
done
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'only supplied commands that are clearly repository-wide integration validation'
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'Refuse and report a blocker for any supplied command that is outside or ambiguous'
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'may perform its own internal setup or build steps'
assert_contains "$personal_home/.config/opencode/agents/integration.md" 'Report each exact command and result, including blockers and unrelated pre-existing failures.'
assert_not_contains "$personal_home/.config/opencode/agents/integration.md" 'full test suites'
test -f "$personal_home/.config/opencode/commands/orchestrate-task.md"
test ! -e "$personal_home/.config/opencode/commands/orchestrate-epic.md"
assert_not_contains "$personal_home/.config/opencode/agents/orchestrator.md" 'orchestration-worker-delivery'
test ! -e "$personal_home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
assert_contains "$source_dir/docs/opencode-agent-orchestration.md" 'For each concurrently active worker lane, the orchestrator creates one distinct reviewer session.'
assert_contains "$personal_home/.config/opencode/agents/orchestrator.md" 'from the recorded worker worktree, not the orchestrator parent checkout'
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$personal_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
assert_contains "$personal_home/.config/opencode/AGENTS.md" 'Keep this personal instruction.'
assert_not_contains "$personal_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
grep -Fxq preserved-wbd "$personal_home/.local/bin/wbd"
grep -Fxq preserved-wbv "$personal_home/.local/bin/wbv"
grep -Fxq preserved-migration "$personal_home/.local/libexec/beads-viewer/migrate-beads-hub-prefix.sh"
test ! -e "$personal_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$personal_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$personal_home/.config/opencode/skills/write-bead/SKILL.md"
test ! -e "$personal_home/.config/opencode/commands/orchestrate-bead.md"
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
 jq -e '(.plugins == ["@slkiser/opencode-quota@5.0.2", "@plannotator/opencode@0.28.2", "../../.local/share/opencode/orchestration-tracking/src"]) and (.experimental == {"todo": true, "background_compaction": true}) and (has("plugin") | not) and .provider.openai and (.agent.title.model == "openai/gpt-5.6-luna") and (has("permission") | not) and (.agent | has("plan") | not)' "$personal_home/.config/opencode/portable.jsonc" >/dev/null
assert_not_contains "$personal_home/.config/opencode/cli.json" 'opencode-todo'
personal_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/personal.toml" --cache "$cache" --include files)
printf '%s\n' "$personal_managed" | grep -Fxq '.config/opencode/cli.json'
! printf '%s\n' "$personal_managed" | grep -Fq 'plan-diagrams'
printf '%s\n' "$personal_managed" | grep -Fxq '.config/opencode/skills/terminal-mermaid/SKILL.md'
printf '%s\n' "$personal_managed" | grep -Fxq '.local/bin/herdr-agent-launch'
printf '%s\n' "$personal_managed" | grep -Fxq '.config/herdr/plugins/local/angel-o.elio/herdr-plugin.toml'
printf '%s\n' "$personal_managed" | grep -Fxq '.config/herdr/plugins/local/angel-o.elio/bin/resolve-dir.sh'
python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1], "rb"))' "$personal_home/.config/herdr/config.toml"
zsh -n "$personal_home"/.config/zsh/*.zsh
HOME="$personal_home" zsh -dfc 'source "$HOME/.config/zsh/opencode.zsh"; alias opencode >/dev/null; alias warpconf >/dev/null'

personal_beads_home="$root/personal-with-beads/home"
render_scripts personal-with-beads
assert_beads_viewer_externals "$root/personal-with-beads/rendered/externals.toml"
assert_not_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "go"'
assert_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/personal-with-beads/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'beads_source_repo="Angel-O/beads"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "beads_wanted_ref=\"$beads_ref\""
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'viewer_source_repo="Angel-O/beads_viewer"'
assert_contains "$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "viewer_wanted_ref=\"$beads_viewer_ref\""
mkdir -p "$personal_beads_home/.config/opencode"
printf '%s\n' 'Preserve personal Beads guidance.' >"$personal_beads_home/.config/opencode/AGENTS.md"
apply_fixture personal-with-beads
test ! -e "$personal_beads_home/.local/bin/wbd"
test ! -e "$personal_beads_home/.local/bin/wbv"
test -x "$personal_beads_home/.local/bin/herdr-agent-launch"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$personal_beads_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$personal_beads_home/.config/opencode/skills/work-beads/SKILL.md"
cmp -s "$source_dir/.chezmoitemplates/write-bead.md" "$personal_beads_home/.config/opencode/skills/write-bead/SKILL.md"
for command in orchestrate-task orchestrate-epic; do
  assert_contains "$personal_beads_home/.config/opencode/commands/$command.md" 'agent: orchestrator'
done
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-task.md" 'wbd claim <bead-id> --json'
assert_contains "$personal_beads_home/.config/opencode/commands/orchestrate-epic.md" 'For an epic, treat the epic as a coordination container and never assign its implementation directly to a worker.'
test ! -e "$personal_beads_home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
assert_contains "$personal_beads_home/.config/opencode/AGENTS.md" 'Preserve personal Beads guidance.'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$personal_beads_home/.config/opencode/AGENTS.md")" -eq 1
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'bd = "ai board"'
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'wbd = "ai board"'
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
assert_contains "$personal_beads_home/.config/herdr-labels/config.toml" 'ignored_processes = ["ls", "cat", "pwd", "clear", "git", "direnv", "scutil", "starship"]'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["ignored_processes"] == ["ls", "cat", "pwd", "clear", "git", "direnv", "scutil", "starship"]; assert data["process_aliases"] == {"bd": "ai board", "bv": "ai board", "wbd": "ai board", "wbv": "ai board"}' "$personal_beads_home/.config/herdr-labels/config.toml"
apply_fixture personal-with-beads
personal_beads_diff=$(chezmoi diff \
  --source "$source_dir" \
  --destination "$personal_beads_home" \
  --config "$source_dir/tests/fixtures/personal-with-beads.toml" \
  --cache "$cache" \
  --persistent-state "$root/personal-with-beads/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$personal_beads_diff"

work_home="$root/work/home"
render_scripts work
assert_todo_installer "$root/work/rendered/run_before_06-install-opencode-todo.sh.tmpl"
assert_ponytail_external "$root/work/rendered/externals.toml"
assert_beads_viewer_externals "$root/work/rendered/externals.toml"
assert_contains "$root/work/rendered/Brewfile" 'brew "eza"'
assert_contains "$root/work/rendered/Brewfile" 'brew "helix"'
assert_not_contains "$root/work/rendered/Brewfile" 'cask "lm-studio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "elio"'
assert_contains "$root/work/rendered/Brewfile" 'brew "glow"'
assert_not_contains "$root/work/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/work/rendered/Brewfile" 'brew "go"'
assert_contains "$root/work/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/work/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'beads_source_repo="Angel-O/beads"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "beads_wanted_ref=\"$beads_ref\""
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'viewer_source_repo="Angel-O/beads_viewer"'
assert_contains "$root/work/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "viewer_wanted_ref=\"$beads_viewer_ref\""
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'ensure_github_plugin thomasschafer.herdr-kiosk "thomasschafer/herdr-kiosk"'
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" "ensure_github_plugin annotate \"plannotator/herdr-annotate\" \"$annotate_ref\""
assert_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" "ensure_github_plugin persiyanov.reviewr \"$reviewr_source\" \"$reviewr_ref\""
assert_not_contains "$root/work/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root='
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
assert_contains "$work_home/.config/herdr-labels/config.toml" 'bd = "ai board"'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'bv = "ai board"'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'wbd = "ai board"'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'wbv = "ai board"'
assert_contains "$work_home/.config/herdr-labels/config.toml" 'ignored_processes = ["ls", "cat", "pwd", "clear", "git", "direnv", "scutil", "starship"]'
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data["ignored_processes"] == ["ls", "cat", "pwd", "clear", "git", "direnv", "scutil", "starship"]; assert data["process_aliases"] == {"bd": "ai board", "bv": "ai board", "wbd": "ai board", "wbv": "ai board"}' "$work_home/.config/herdr-labels/config.toml"
assert_not_contains "$work_home/.config/zsh/herdr.zsh" 'hook.zsh'
assert_contains "$work_home/.gitconfig" 'email = work@example.invalid'
assert_contains "$work_home/.gitconfig" '.config/git/portable.inc'
assert_contains "$work_home/.config/opencode/opencode.jsonc" 'work-private-provider'
assert_contains "$work_home/.config/opencode/tui.jsonc" 'work_private_tui_setting'
test -f "$work_home/.config/opencode/cli.json"
assert_contains "$work_home/.config/opencode/cli.json" '"./herdr-opencode"'
python3 - "$work_home/.config/opencode/cli.json" <<'PY'
import json
import sys

cli = json.load(open(sys.argv[1]))
assert cli["diffs"]["fullscreen"] is False
assert cli["debug"] == {"devtools": True, "timing": False, "turn_tokens": True}
PY
assert_contains "$work_home/.config/opencode/AGENTS.md" 'Preserve this private instruction exactly.'
test -f "$work_home/.config/helix/config.toml"
assert_contains "$work_home/.config/helix/config.toml" 'theme = "dracula_at_night"'
test "$(grep -Fc '<!-- portable-beads-hub:start -->' "$work_home/.config/opencode/AGENTS.md")" -eq 1
assert_contains "$work_home/.config/opencode/AGENTS.md" 'load the global `beads-hub` skill before acting'
assert_contains "$work_home/.config/opencode/AGENTS.md" 'never raw `bd`, `bv`, or `br`'
test ! -e "$work_home/.local/bin/wbd"
test ! -e "$work_home/.local/bin/wbv"
test ! -e "$work_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$work_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$work_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$work_home/.config/opencode/skills/work-beads/SKILL.md"
cmp -s "$source_dir/.chezmoitemplates/write-bead.md" "$work_home/.config/opencode/skills/write-bead/SKILL.md"
cmp -s "$root/work/warp-settings.before" "$work_home/.warp/settings.toml"
assert_not_contains "$work_home/.config/opencode/portable.jsonc" '"provider"'
assert_not_contains "$work_home/.config/opencode/portable.jsonc" 'opencode-lmstudio'
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$work_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
assert_contains "$work_home/.config/herdr/config.toml" 'status_indicators = "symbols"'
assert_not_contains "$work_home/.config/herdr/config.toml" 'angel-o.elio.open'
assert_not_contains "$work_home/.config/herdr/config.toml" 'angel-o.hub-viewer'
assert_contains "$work_home/.config/herdr/config.toml" 'key = "prefix+ctrl+p"'
assert_contains "$work_home/.config/herdr/config.toml" 'command = "annotate.last-newest"'
assert_contains "$work_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'markdown_view = "rendered"'
assert_not_contains "$work_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" 'file_markdown_renderer = "glow -s dracula -w {width} -"'
assert_not_contains "$work_home/.config/zsh/opencode.zsh" '{{'
assert_not_contains "$work_home/.config/zsh/opencode.zsh" 'alias warpconf='
 jq -e '(.plugins == ["@slkiser/opencode-quota@5.0.2", "@plannotator/opencode@0.28.2", "../../.local/share/opencode/orchestration-tracking/src"]) and (.experimental == {"todo": true, "background_compaction": true}) and (has("plugin") | not) and (.agent.title.model == "openai/gpt-5.6-luna") and (has("permission") | not) and (.agent | has("plan") | not)' "$work_home/.config/opencode/portable.jsonc" >/dev/null
assert_not_contains "$work_home/.config/opencode/cli.json" 'opencode-todo'
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
  --cache "$cache" \
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
work_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" --cache "$cache" --include files)
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/portable.jsonc'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/cli.json'
! printf '%s\n' "$work_managed" | grep -Fq 'plan-diagrams'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/terminal-mermaid/SKILL.md'
printf '%s\n' "$work_managed" | grep -Fxq '.local/bin/herdr-agent-launch'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/commands/orchestrate-task.md'
printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/commands/orchestrate-epic.md'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/herdr/plugins/local/angel-o.elio/herdr-plugin.toml'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/herdr/plugins/local/angel-o.elio/bin/resolve-dir.sh'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/beads-hub/SKILL.md'
! printf '%s\n' "$work_managed" | grep -Fxq '.config/opencode/skills/work-beads/SKILL.md'

external_home="$root/external-opencode-beads/home"
render_scripts external-opencode-beads
assert_beads_viewer_externals "$root/external-opencode-beads/rendered/externals.toml"
assert_not_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "beads"'
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "go"'
assert_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "jq"'
assert_not_contains "$root/external-opencode-beads/rendered/Brewfile" 'brew "beads_viewer"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'beads_source_repo="Angel-O/beads"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "beads_wanted_ref=\"$beads_ref\""
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" 'viewer_source_repo="Angel-O/beads_viewer"'
assert_contains "$root/external-opencode-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl" "viewer_wanted_ref=\"$beads_viewer_ref\""
mkdir -p "$external_home/.config/opencode/command" "$external_home/.config/opencode/skills/existing-skill"
printf '%s\n' 'Legacy orchestrate command.' >"$external_home/.config/opencode/command/orchestrate-bead.md"
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
  --cache "$cache" \
  --exclude externals \
  --include files \
  | grep -E '^(\.config/opencode|\.local/bin)' >"$external_managed"
cat >"$root/external-opencode-beads/managed.expected" <<'EOF'
.config/opencode/AGENTS.md
.config/opencode/commands/orchestrate-epic.md
.config/opencode/skills/memex-quick-search/SKILL.md
.config/opencode/skills/terminal-mermaid/SKILL.md
.config/opencode/skills/update-agent-models/SKILL.md
.config/opencode/skills/write-bead/SKILL.md
EOF
cmp -s "$root/external-opencode-beads/managed.expected" "$external_managed"

apply_fixture external-opencode-beads
test ! -e "$external_home/.local/bin/wbd"
test ! -e "$external_home/.local/bin/wbv"
test ! -e "$external_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$external_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$external_home/.config/opencode/skills/work-beads/SKILL.md"
cmp -s "$source_dir/.chezmoitemplates/write-bead.md" "$external_home/.config/opencode/skills/write-bead/SKILL.md"
test ! -e "$external_home/.config/opencode/portable.jsonc"
test ! -e "$external_home/.config/opencode/plugins/env-protection.js"
test ! -e "$external_home/.config/opencode/plugins/plan-diagrams.js"
test ! -e "$external_home/.config/opencode/skills/plan-diagrams/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/memex-quick-search/SKILL.md" "$external_home/.config/opencode/skills/memex-quick-search/SKILL.md"
cmp -s "$source_dir/dot_config/opencode/skills/terminal-mermaid/SKILL.md" "$external_home/.config/opencode/skills/terminal-mermaid/SKILL.md"
test ! -e "$external_home/.config/opencode/commands/herdr-name.md"
test ! -e "$external_home/.config/opencode/command/orchestrate-bead.md"
assert_not_contains "$external_home/.config/opencode/commands/orchestrate-epic.md" 'agent: orchestrator'
assert_contains "$external_home/.config/opencode/commands/orchestrate-epic.md" 'For now, stop immediately after all workers for the first eligible wave have started successfully in their child workspaces.'
test ! -e "$external_home/.config/opencode/skills/orchestration-worker-delivery/SKILL.md"
test ! -e "$external_home/.local/bin/opencode-env"
test ! -e "$external_home/.local/bin/herdr-agent-launch"
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
  --cache "$cache" \
  --persistent-state "$root/external-opencode-beads/chezmoistate.boltdb" \
  --exclude scripts,externals)
test -z "$external_diff"

integration_disabled_home="$root/beads-integration-disabled/home"
render_scripts beads-integration-disabled
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/SKILL.md'
assert_not_contains "$root/beads-integration-disabled/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/validate.sh'
mkdir -p "$integration_disabled_home/.config/opencode/skills/beads-hub" "$integration_disabled_home/.config/opencode/skills/beads-hub-closeout"
printf '%s\n' 'previously installed external skill' >"$integration_disabled_home/.config/opencode/skills/beads-hub/SKILL.md"
printf '%s\n' 'previously installed external closeout skill' >"$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
printf '%s\n' 'previously installed external closeout validator' >"$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
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
test ! -e "$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$integration_disabled_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test ! -e "$integration_disabled_home/.config/opencode/commands/orchestrate.md"
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
  --cache "$cache" \
  --persistent-state "$transition_root/chezmoistate.boltdb" \
  --exclude scripts,externals \
  --force
test ! -e "$transition_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
cmp -s "$source_dir/.chezmoitemplates/write-bead.md" "$transition_home/.config/opencode/skills/write-bead/SKILL.md"
assert_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-beads-hub:start'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
mkdir -p "$transition_home/.config/opencode/skills/beads-hub"
printf '%s\n' 'simulated installed external skill' >"$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
mkdir -p "$transition_home/.config/opencode/skills/beads-hub-closeout"
printf '%s\n' 'simulated installed external closeout skill' >"$transition_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
printf '%s\n' 'simulated installed external closeout validator' >"$transition_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
chezmoi apply \
  --source "$source_dir" \
  --destination "$transition_home" \
  --config "$source_dir/tests/fixtures/beads-integration-disabled.toml" \
  --cache "$cache" \
  --persistent-state "$transition_root/chezmoistate.boltdb" \
  --exclude scripts,externals \
  --force
test ! -e "$transition_home/.config/opencode/skills/work-beads/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$transition_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
cleanup_script="$transition_root/remove-write-bead.sh"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/beads-integration-disabled.toml" \
  <"$source_dir/run_before_04-remove-disabled-write-bead.sh.tmpl" >"$cleanup_script"
HOME="$transition_home" sh "$cleanup_script"
test ! -e "$transition_home/.config/opencode/skills/write-bead/SKILL.md"
test ! -e "$transition_home/.local/bin/wbd"
test ! -e "$transition_home/.local/bin/wbv"
assert_contains "$transition_home/.config/opencode/AGENTS.md" 'Preserve transition guidance.'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'
assert_not_contains "$transition_home/.config/opencode/AGENTS.md" 'portable-beads-hub:start'

legacy_home="$root/legacy-beads/home"
render_scripts legacy-beads
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub/SKILL.md'
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/SKILL.md'
assert_not_contains "$root/legacy-beads/rendered/externals.toml" '.config/opencode/skills/beads-hub-closeout/validate.sh'
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
test ! -e "$legacy_home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test ! -e "$legacy_home/.config/opencode/skills/beads-hub-closeout/validate.sh"
assert_contains "$legacy_home/.config/opencode/AGENTS.md" 'Preserve legacy guidance.'
assert_not_contains "$legacy_home/.config/opencode/AGENTS.md" 'portable-work-beads:start'

bash "$source_dir/tests/test-beads.sh" "$source_dir" "$root"

shell_home="$root/shell-only/home"
render_scripts shell-only
assert_contains "$root/shell-only/rendered/Brewfile" 'brew "elio"'
assert_not_contains "$root/shell-only/rendered/run_before_06-install-opencode-todo.sh.tmpl" 'opencode-todo'
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
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'angel-o.elio'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'angel-o.hub-viewer'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'persiyanov/herdr-reviewr'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'plannotator/herdr-annotate'
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'reviewr_root='
assert_not_contains "$root/herdr-disabled-plugins/rendered/run_after_30-install-herdr-plugins.sh.tmpl" 'brew install rust'
apply_fixture herdr-disabled-plugins
test ! -e "$disabled_home/.warp"
assert_not_contains "$disabled_home/.config/herdr/config.toml" 'plugin_action'
assert_not_contains "$disabled_home/.config/herdr/config.toml" 'annotate.last-newest'
assert_not_contains "$disabled_home/.config/herdr/config.toml" '"$usage"'
assert_not_contains "$disabled_home/.config/zsh/early.zsh" 'herdr-labels.zsh'
test ! -e "$disabled_home/.config/herdr/reviewr-toggle-tab.sh"
test ! -e "$disabled_home/.config/herdr/plugins/config/ez-corp.space-usage/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/herdr-bar/config.json"
test ! -e "$disabled_home/.config/herdr/plugins/config/thomasschafer.herdr-kiosk/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/config/persiyanov.reviewr/config.toml"
test ! -e "$disabled_home/.config/herdr/plugins/local/angel-o.elio"
test ! -e "$disabled_home/.config/herdr/plugins/local/angel-o.hub-viewer"
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
test ! -e "$ghostty_home/.config/herdr/plugins/local/angel-o.elio"
test ! -e "$ghostty_home/.config/opencode/portable.jsonc"
test ! -e "$ghostty_home/.local/bin/herdr-agent-launch"
test ! -e "$ghostty_home/.config/opencode/agents"
test ! -e "$ghostty_home/.config/opencode/commands/orchestrate.md"
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
python3 -c 'import tomllib,sys; data=tomllib.load(open(sys.argv[1], "rb")); assert data == {"theme": "dracula_at_night", "editor": {"soft-wrap": {"enable": True}}}' "$helix_home/.config/helix/config.toml"
grep -Fxq 'preserve generated runtime data' "$helix_home/.config/helix/runtime/generated"
grep -Fxq 'preserve runtime log' "$helix_home/.cache/helix/helix.log"
test ! -e "$helix_home/.config/ghostty/config"
helix_managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/helix-only.toml" --cache "$cache" --include files | grep '^\.config/helix')
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
