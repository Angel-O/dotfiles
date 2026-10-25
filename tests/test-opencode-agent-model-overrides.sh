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
printf 'OPENCODE_AGENT_MODEL_PLAN=%s\n' "${OPENCODE_AGENT_MODEL_PLAN-}"
printf 'OPENCODE_AGENT_MODEL_BUILD=%s\n' "${OPENCODE_AGENT_MODEL_BUILD-}"
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
grep -Fqx 'OPENCODE_AGENT_MODEL_PLAN=openai/gpt-5.6-sol#high' <<<"$defaults"
grep -Fqx 'OPENCODE_AGENT_MODEL_BUILD=openai/gpt-6.1-sol#medium' <<<"$defaults"
grep -Fqx 'args=--check' <<<"$defaults"

builtin_overrides=$(env -i HOME="$home" PATH="$fake_bin:$PATH" OPENCODE_AGENT_MODEL_PLAN=openai/independent-plan OPENCODE_AGENT_MODEL_BUILD=openai/independent-build zsh "$launcher" --check)
grep -Fqx 'OPENCODE_AGENT_MODEL_ARCHITECT=openai/gpt-5.6-sol#high' <<<"$builtin_overrides"
grep -Fqx 'OPENCODE_AGENT_MODEL_PLAN=openai/independent-plan' <<<"$builtin_overrides"
grep -Fqx 'OPENCODE_AGENT_MODEL_BUILD=openai/independent-build' <<<"$builtin_overrides"

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

# Applying the portable config installs the skill; validate its documented
# env.local path with a controlled home and the fake OpenCode executable.
skill="$target_home/.config/opencode/skills/update-agent-models/SKILL.md"
test -f "$skill"
grep -Fq 'Do not edit portable fallback definitions or generated launcher files' "$skill"
grep -Fq 'OPENCODE_AGENT_MODEL_PLANNER' "$skill"
grep -Fq 'OPENCODE_AGENT_MODEL_PLAN' "$skill"
grep -Fq 'OPENCODE_AGENT_MODEL_BUILD' "$skill"
mkdir -p "$target_home/.config/opencode"
cat >"$target_home/.config/opencode/env.local" <<'EOF'
export OPENCODE_AGENT_MODEL_WORKER='openai/controlled-model'
export OPENCODE_AGENT_MODEL_ARCHITECT='openai/local-architect#medium'
export UNRELATED_LOCAL_SETTING='preserved'
EOF
controlled=$(HOME="$target_home" PATH="$fake_bin:$PATH" zsh "$target_home/.local/bin/opencode-env" --check)
grep -Fqx 'OPENCODE_AGENT_MODEL_WORKER=openai/controlled-model' <<<"$controlled"
grep -Fqx 'OPENCODE_AGENT_MODEL_ARCHITECT=openai/local-architect#medium' <<<"$controlled"
grep -Fqx 'OPENCODE_AGENT_MODEL_PLAN=openai/gpt-5.6-sol#high' <<<"$controlled"
grep -Fqx "OPENCODE_CONFIG=$target_home/.config/opencode/portable.jsonc" <<<"$controlled"
grep -Fqx 'args=--check' <<<"$controlled"
grep -Fq "UNRELATED_LOCAL_SETTING='preserved'" "$target_home/.config/opencode/env.local"

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
    "plan": "OPENCODE_AGENT_MODEL_PLAN",
    "build": "OPENCODE_AGENT_MODEL_BUILD",
}
assert portable["agents"]["plan"]["color"] == "#FF966C"
assert portable["agents"]["build"]["color"] == "#82AAFF"
for agent, variable in expected.items():
    assert portable["agents"][agent]["model"] == "{env:" + variable + "}"
    if agent in {"plan", "build"}:
        continue
    frontmatter = (Path(sys.argv[2]) / f"{agent}.md").read_text().split("---", 2)[1]
    assert "model:" not in frontmatter
    assert "reasoningEffort:" not in frontmatter
assert portable["agent"]["title"] == {
    "model": "openai/gpt-5.6-luna",
    "options": {"reasoningEffort": "none"},
}
PY
