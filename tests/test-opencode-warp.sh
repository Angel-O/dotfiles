#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

for profile in personal work; do
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$profile.toml" \
    <"$source_dir/dot_config/opencode/portable.jsonc.tmpl" >"$root/$profile.json"
done

python3 - "$source_dir/.chezmoidata.toml" "$root/personal.json" "$root/work.json" <<'PY'
import json
import sys
import tomllib

pins = tomllib.load(open(sys.argv[1], "rb"))["pins"]["openCodePlugins"]
personal, work = (json.load(open(path)) for path in sys.argv[2:])
plugin = f"@warp-dot-dev/opencode-warp@{pins['warp']}"
baseline = [
    f"@slkiser/opencode-quota@{pins['quota']}",
    {
        "package": f"@plannotator/opencode@{pins['plannotator']}",
        "options": {"planningAgents": ["plan", "architect"]},
    },
    f"opencode-handoff@{pins['handoff']}",
    "../../.local/share/opencode/orchestration-tracking/src",
]

assert personal["plugins"] == baseline[:-1] + [plugin, baseline[-1]]
assert work["plugins"] == baseline
assert all("plugin" not in config for config in (personal, work))
PY
