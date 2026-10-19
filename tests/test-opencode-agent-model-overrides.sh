#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

home="$root/home"
fake_bin="$root/bin"
mkdir -p "$home" "$fake_bin"

cat >"$fake_bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'OPENCODE_CONFIG=%s\n' "${OPENCODE_CONFIG-}"
printf 'OPENCODE_AGENT_MODEL_ORCHESTRATOR=%s\n' "${OPENCODE_AGENT_MODEL_ORCHESTRATOR-}"
printf 'OPENCODE_AGENT_MODEL_INTEGRATION=%s\n' "${OPENCODE_AGENT_MODEL_INTEGRATION-}"
printf 'OPENCODE_AGENT_MODEL_INVESTIGATOR=%s\n' "${OPENCODE_AGENT_MODEL_INVESTIGATOR-}"
printf 'OPENCODE_AGENT_MODEL_REVIEWER=%s\n' "${OPENCODE_AGENT_MODEL_REVIEWER-}"
printf 'OPENCODE_AGENT_MODEL_WORKER=%s\n' "${OPENCODE_AGENT_MODEL_WORKER-}"
printf 'OPENCODE_AGENT_MODEL_ARCHITECT=%s\n' "${OPENCODE_AGENT_MODEL_ARCHITECT-}"
printf 'OPENCODE_AGENT_MODEL_PLANNER=%s\n' "${OPENCODE_AGENT_MODEL_PLANNER-}"
printf 'args=%s\n' "$*"
EOF
chmod +x "$fake_bin/opencode"

launcher="$root/opencode-env"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_local/bin/executable_opencode-env.tmpl" >"$launcher"
chmod +x "$launcher"
zsh -n "$launcher"

defaults=$(env -i HOME="$home" PATH="$fake_bin:$PATH" zsh "$launcher" --check)
grep -Fqx "OPENCODE_CONFIG=$home/.config/opencode/portable.jsonc" <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_ORCHESTRATOR=openai/gpt-5.6-terra#high' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_INTEGRATION=openai/gpt-5.6-luna#medium' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_INVESTIGATOR=openai/gpt-5.6-sol#medium' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_REVIEWER=openai/gpt-6-astra#medium' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_WORKER=openai/gpt-5.6-luna#high' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_ARCHITECT=openai/gpt-5.6-sol#high' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_PLANNER=openai/gpt-5.6-terra#medium' <<<"$defaults"
grep -Fqx 'args=--check' <<<"$defaults"

empty_worker=$(env -i HOME="$home" PATH="$fake_bin:$PATH" OPENCODE_AGENT_MODEL_WORKER= zsh "$launcher" --check)
grep -Fqx 'OPENCODE_AGENT_MODEL_WORKER=' <<<"$empty_worker"

target_launcher="$root/target-opencode"
cat >"$target_launcher" <<EOF
#!/usr/bin/env zsh
export OPENCODE_AGENT_MODEL_WORKER='anthropic/claude-sonnet#fast'
exec '$launcher' "\$@"
EOF
chmod +x "$target_launcher"
overridden=$(HOME="$home" PATH="$fake_bin:$PATH" zsh "$target_launcher" run)
grep -Fqx 'OPENCODE_AGENT_MODEL_WORKER=anthropic/claude-sonnet#fast' <<<"$overridden"
grep -Fqx 'OPENCODE_AGENT_MODEL_ORCHESTRATOR=openai/gpt-5.6-terra#high' <<<"$overridden"
grep -Fqx 'args=run' <<<"$overridden"

target_home="$root/target-home"
target_override="$target_home/bin/opencode-target"
mkdir -p "$(dirname "$target_override")" "$target_home/.config/opencode/skills"
cat >"$target_override" <<'EOF'
#!/usr/bin/env zsh
export OPENCODE_AGENT_MODEL_WORKER='anthropic/claude-sonnet#fast'
exec "$HOME/.local/bin/opencode-env" "$@"
EOF
chmod +x "$target_override"
chezmoi apply --source "$source_dir" --destination "$target_home" \
  --config "$source_dir/tests/fixtures/work.toml" --cache "$root/cache" \
  --persistent-state "$root/chezmoistate.boltdb" --exclude scripts,externals --force
cp "$target_override" "$root/target-opencode.before-apply"
chezmoi apply --source "$source_dir" --destination "$target_home" \
  --config "$source_dir/tests/fixtures/work.toml" --cache "$root/cache" \
  --persistent-state "$root/chezmoistate.boltdb" --exclude scripts,externals --force
cmp -s "$target_override" "$root/target-opencode.before-apply"
durable=$(HOME="$target_home" PATH="$fake_bin:$PATH" zsh "$target_override" run)
grep -Fqx 'OPENCODE_AGENT_MODEL_WORKER=anthropic/claude-sonnet#fast' <<<"$durable"
grep -Fqx "OPENCODE_CONFIG=$target_home/.config/opencode/portable.jsonc" <<<"$durable"

config="$root/portable.json"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_config/opencode/portable.jsonc.tmpl" >"$config"
python3 - "$config" "$source_dir/dot_config/opencode/agents" <<'PY'
import json
import sys
from pathlib import Path

portable = json.load(open(sys.argv[1]))
expected = {
    "orchestrator": "OPENCODE_AGENT_MODEL_ORCHESTRATOR",
    "integration": "OPENCODE_AGENT_MODEL_INTEGRATION",
    "investigator": "OPENCODE_AGENT_MODEL_INVESTIGATOR",
    "reviewer": "OPENCODE_AGENT_MODEL_REVIEWER",
    "worker": "OPENCODE_AGENT_MODEL_WORKER",
    "architect": "OPENCODE_AGENT_MODEL_ARCHITECT",
    "planner": "OPENCODE_AGENT_MODEL_PLANNER",
}
for agent, variable in expected.items():
    assert portable["agents"][agent]["model"] == "{env:" + variable + "}"
    frontmatter = (Path(sys.argv[2]) / f"{agent}.md").read_text().split("---", 2)[1]
    assert "model:" not in frontmatter
    assert "reasoningEffort:" not in frontmatter
assert portable["agent"]["title"] == {
    "model": "openai/gpt-5.6-luna",
    "options": {"reasoningEffort": "none"},
}
PY
