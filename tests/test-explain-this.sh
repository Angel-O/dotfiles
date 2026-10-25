#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d "${TMPDIR:-/tmp}/explain-this.XXXXXX")
trap 'rm -rf "$root"' EXIT

for fixture in personal shell-only; do
  config="$source_dir/tests/fixtures/$fixture.toml"
  chezmoi execute-template --source "$source_dir" --config "$config" \
    <"$source_dir/.chezmoiexternal.toml.tmpl" >"$root/$fixture.toml"
done

python3 - "$root/personal.toml" "$root/shell-only.toml" "$source_dir/.chezmoidata.toml" <<'PY'
import sys
import tomllib

enabled, disabled, _ = [tomllib.load(open(path, "rb")) for path in sys.argv[1:]]
pin = tomllib.load(open(sys.argv[3], "rb"))["pins"]["explainThisSkill"]
paths = (
    "README.md",
    "SKILL.md",
    "scripts/build-review.mjs",
    "assets/template.html",
    "assets/mermaid.min.js",
)
base = ".config/opencode/skills/explain-this/"
expected = {
    base + path: {
        "type": "file",
        "url": f"https://raw.githubusercontent.com/abrinsmead/skills/{pin}/explain-this/{path}",
    }
    for path in paths
}
assert len(pin) == 40 and all(c in "0123456789abcdef" for c in pin)
assert {path: value for path, value in enabled.items() if path.startswith(base)} == expected
assert not any(path.startswith(base) for path in disabled)
assert len([path for path in enabled if path.startswith(base)]) == 5
PY

printf 'Explain-this declaration checks passed.\n'
