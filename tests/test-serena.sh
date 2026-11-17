#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

render() {
  local config=$1 input=$2
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$config.toml" \
    <"$source_dir/$input" >"$root/$config-$(basename "$input" .tmpl)"
}

render serena-enabled dot_config/opencode/portable.jsonc.tmpl
render work dot_config/opencode/portable.jsonc.tmpl
render serena-opencode-disabled dot_config/opencode/portable.jsonc.tmpl
render serena-enabled dot_config/opencode/agents/worker.md.tmpl
render work dot_config/opencode/agents/worker.md.tmpl
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/serena-enabled.toml" \
  <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$root/Brewfile"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$root/Brewfile-disabled"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/serena-enabled.toml" \
  <"$source_dir/run_after_25-install-serena.sh.tmpl" >"$root/install.sh"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/run_after_25-install-serena.sh.tmpl" >"$root/install-disabled.sh"
sh -n "$root/install.sh"
sh -n "$root/install-disabled.sh"

if command -v opencode >/dev/null 2>&1; then
  opencode_bin=$(command -v opencode)
  mkdir -p "$root/runtime-home/.config/opencode/agents"
  chezmoi execute-template --source "$source_dir" \
    --config "$source_dir/tests/fixtures/serena-enabled.toml" \
    <"$source_dir/dot_config/opencode/agents/worker.md.tmpl" \
    >"$root/runtime-home/.config/opencode/agents/worker.md"
  HOME="$root/runtime-home" XDG_CONFIG_HOME="$root/runtime-home/.config" \
    OPENCODE_CONFIG="$root/serena-enabled-portable.jsonc" PATH=/usr/bin:/bin \
    "$opencode_bin" --standalone debug config >"$root/opencode-config.json"
  HOME="$root/runtime-home" XDG_CONFIG_HOME="$root/runtime-home/.config" \
    OPENCODE_CONFIG="$root/serena-enabled-portable.jsonc" PATH=/usr/bin:/bin \
    "$opencode_bin" --standalone debug agents >"$root/opencode-agents.json"
  python3 - "$root/runtime-home" "$root/opencode-config.json" "$root/opencode-agents.json" <<'PY'
import fnmatch
import json
import sys
from pathlib import Path

home = sys.argv[1]
documents = json.load(open(sys.argv[2]))
config = next(item["info"] for item in documents if item["type"] == "document")
server = config["mcp"]["servers"]["serena"]
assert server["command"][0] == f"{home}/.local/bin/serena"
assert server["codemode"] is False

agents = json.load(open(sys.argv[3]))
expected = {
    "serena_activate_project", "serena_initial_instructions",
    "serena_get_symbols_overview", "serena_find_symbol",
    "serena_find_referencing_symbols", "serena_replace_symbol_body",
    "serena_insert_before_symbol", "serena_insert_after_symbol",
    "serena_replace_content",
}
probes = expected | {"serena_repl", "serena_unlisted_probe"}

def allowed(agent, tool):
    effect = "ask"
    for rule in agent["permissions"]:
        if fnmatch.fnmatchcase(tool, rule["action"]) and fnmatch.fnmatchcase("*", rule["resource"]):
            effect = rule["effect"]
    return effect == "allow"

worker = [agent for agent in agents if agent["id"] == "worker"]
assert len(worker) == 1
assert {tool for tool in probes if allowed(worker[0], tool)} == expected
for agent in agents:
    if agent["id"] != "worker":
        assert not any(allowed(agent, tool) for tool in probes), agent["id"]
print("OpenCode runtime config and effective Serena policy: PASS")
PY
fi

python3 - "$source_dir" "$root" <<'PY'
import json
import re
import sys
import tomllib
from pathlib import Path

source, root = map(Path, sys.argv[1:])
pin_text = (source / ".chezmoidata.toml").read_text()
pin = tomllib.loads(pin_text)["pins"]["serena"]
assert pin == "2.1.0"
config = json.loads((root / "serena-enabled-portable.jsonc").read_text())
assert config["mcp"]["servers"]["serena"]["codemode"] is False
assert config["mcp"]["servers"]["serena"]["command"] == [
    "{env:HOME}/.local/bin/serena", "start-mcp-server", "--transport", "stdio",
    "--agent-interface", "tools", "--enable-web-dashboard", "false",
]
expected = {
    "serena_activate_project", "serena_initial_instructions",
    "serena_get_symbols_overview", "serena_find_symbol",
    "serena_find_referencing_symbols", "serena_replace_symbol_body",
    "serena_insert_before_symbol", "serena_insert_after_symbol",
    "serena_replace_content",
}
assert config["permissions"] == [
    {"action": "serena_*", "resource": "*", "effect": "deny"}
]
rules = config["agents"]["worker"]["permissions"]
assert {rule["action"] for rule in rules} == expected
assert all(rule["resource"] == "*" and rule["effect"] == "allow" for rule in rules)
baseline = json.loads((root / "work-portable.jsonc").read_text())
for key in ("default_agent", "experimental", "plugins", "agent"):
    assert config[key] == baseline[key]
assert {
    name: agent for name, agent in config["agents"].items() if name != "worker"
} == {
    name: agent for name, agent in baseline["agents"].items() if name != "worker"
}
assert config["agents"]["worker"]["color"] == baseline["agents"]["worker"]["color"]
assert config["agents"]["worker"]["model"] == baseline["agents"]["worker"]["model"]
for disabled in ("work", "serena-opencode-disabled"):
    rendered = json.loads((root / f"{disabled}-portable.jsonc").read_text())
    assert "mcp" not in rendered and "permissions" not in rendered
worker_enabled = (root / "serena-enabled-worker.md").read_text()
worker_disabled = (root / "work-worker.md").read_text()
expected_guidance = (
    "For coding work, first call `serena_initial_instructions` and activate the supplied target "
    "project or worktree with `serena_activate_project` using its absolute path. You must use "
    "Serena's symbolic search tools (`serena_get_symbols_overview`, `serena_find_symbol`, and "
    "`serena_find_referencing_symbols`) and editing tools (`serena_replace_symbol_body`, "
    "`serena_insert_before_symbol`, `serena_insert_after_symbol`, and `serena_replace_content`) "
    "whenever they support the operation. Use native read/search/edit tools or shell-based "
    "equivalents only when Serena cannot perform the needed operation, the file/language is "
    "unsupported, or Serena is unavailable or fails; briefly report the reason for falling back. "
    "Do not bypass Serena merely for convenience. Keep all operations within the supplied scope "
    "and existing validation requirements."
)
assert expected_guidance in worker_enabled
assert "## Serena tools\n\n" + expected_guidance in worker_enabled
assert "serena_activate_project" not in worker_disabled
assert 'brew "uv"' in (root / "Brewfile").read_text()
assert 'brew "uv"' not in (root / "Brewfile-disabled").read_text()
installer = (root / "install.sh").read_text()
assert "UV_TOOL_BIN_DIR=\"$HOME/.local/bin\" uv tool install --python 3.12 --upgrade \"serena-agent==2.1.0\"" in installer
renovate = json.loads((source / "renovate.json").read_text())
managers = [
    item for item in renovate["customManagers"]
    if item.get("packageNameTemplate") == "serena-agent"
]
assert len(managers) == 1
manager = managers[0]
assert manager["datasourceTemplate"] == "pypi"
assert manager["versioningTemplate"] == "semver"
assert manager["managerFilePatterns"] == [r"/^\.chezmoidata\.toml$/"]
pattern = manager["matchStrings"][0].replace("(?<", "(?P<")
match = re.search(pattern, pin_text)
assert match and match.group("currentValue") == "2.1.0"
assert re.search(pattern, pin_text.replace('serena = "2.1.0"', 'serena = "2.1.1"')).group("currentValue") == "2.1.1"
PY

mkdir -p "$root/bin" "$root/home/.local/share/uv/tools/serena-agent" "$root/home/.cache/uv"
cat >"$root/bin/uv" <<'EOF'
#!/bin/sh
printf 'UV_TOOL_BIN_DIR=%s %s\n' "$UV_TOOL_BIN_DIR" "$*" >>"$UV_CALLS"
EOF
chmod +x "$root/bin/uv"
HOME="$root/home" PATH="$root/bin:$PATH" UV_CALLS="$root/calls" sh "$root/install.sh"
HOME="$root/home" PATH="$root/bin:$PATH" UV_CALLS="$root/calls" sh "$root/install.sh"
HOME="$root/home" PATH="$root/bin:$PATH" UV_CALLS="$root/calls" sh "$root/install-disabled.sh"
test "$(wc -l <"$root/calls" | tr -d ' ')" = 2
grep -Fqx "UV_TOOL_BIN_DIR=$root/home/.local/bin tool install --python 3.12 --upgrade serena-agent==2.1.0" "$root/calls"
test -d "$root/home/.local/share/uv/tools/serena-agent"
test -d "$root/home/.cache/uv"
! grep -Eq 'uv (tool uninstall|cache clean)' "$root/install.sh"
