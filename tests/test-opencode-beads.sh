#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
fixture="$source_dir/tests/fixtures/personal-with-beads.toml"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

rendered="$root/externals.toml"
chezmoi execute-template --source "$source_dir" --config "$fixture" \
  <"$source_dir/.chezmoiexternal.toml.tmpl" >"$rendered"

python3 - "$rendered" "$source_dir/.chezmoidata.toml" <<'PY'
import sys
import tomllib

externals = tomllib.load(open(sys.argv[1], "rb"))
pins = tomllib.load(open(sys.argv[2], "rb"))["pins"]["beadsViewer"]
source = pins["source"]
ref = pins["ref"]
skills = externals["beadsViewerSkills"]

assert skills == {
    "type": "archive",
    "url": f"https://github.com/{source}/archive/{ref}.tar.gz",
    "stripComponents": 2,
    "include": ["*/skills/**"],
    "targetPath": ".config/opencode/skills",
}
assert not any("beads-hub" in path for path in externals if path != "beadsViewerSkills")
PY

home="$root/home"
mkdir -p "$home"
chezmoi apply \
  --source "$source_dir" \
  --destination "$home" \
  --config "$fixture" \
  --cache "$root/cache" \
  --persistent-state "$root/state.boltdb" \
  --exclude scripts \
  --force

test -f "$home/.config/opencode/skills/beads-hub/SKILL.md"
test -f "$home/.config/opencode/skills/beads-hub-closeout/SKILL.md"
test -x "$home/.config/opencode/skills/beads-hub-closeout/validate.sh"
test -x "$home/.config/opencode/skills/beads-hub-closeout/closeout.sh"
test -f "$home/.config/opencode/skills/beads-hub-closeout/validate_test.go"
test -f "$home/.config/opencode/skills/terminal-mermaid/SKILL.md"
test -f "$home/.config/opencode/skills/write-bead/SKILL.md"

external_only_home="$root/external-only-home"
mkdir -p "$external_only_home"
chezmoi apply \
  --source "$source_dir" \
  --destination "$external_only_home" \
  --config "$source_dir/tests/fixtures/external-opencode-beads.toml" \
  --cache "$root/external-only-cache" \
  --persistent-state "$root/external-only-state.boltdb" \
  --exclude scripts \
  --force
test -f "$external_only_home/.config/opencode/skills/beads-hub/SKILL.md"
test -f "$external_only_home/.config/opencode/skills/beads-hub-closeout/validate_test.go"
