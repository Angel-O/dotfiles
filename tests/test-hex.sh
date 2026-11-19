#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

for role in personal work; do
  chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/$role.toml" \
    <"$source_dir/.chezmoitemplates/Brewfile.tmpl" >"$root/$role.Brewfile"
done

grep -Fxq 'cask "anomalyco/tap/hex"' "$root/personal.Brewfile"
grep -Fxq 'cask "anomalyco/tap/hex"' "$root/work.Brewfile"
grep -Fxq 'cask "lm-studio"' "$root/personal.Brewfile"
! grep -Fxq 'cask "lm-studio"' "$root/work.Brewfile"
grep -Fxq 'brew "go"' "$root/work.Brewfile"
! grep -Fxq 'brew "go"' "$root/personal.Brewfile"

renovate_fixture="$root/renovate-fixture"
mkdir -p "$renovate_fixture"
github_token=${RENOVATE_GITHUB_COM_TOKEN:-${GITHUB_COM_TOKEN:-}}
if [[ -z "$github_token" ]] && command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1; then
  github_token=$(gh auth token)
fi
if [[ -z "$github_token" ]]; then
  printf 'Hex Renovate lookup requires a GitHub token; set RENOVATE_GITHUB_COM_TOKEN or authenticate gh.\n' >&2
  exit 1
fi
export RENOVATE_GITHUB_COM_TOKEN="$github_token"
python3 - "$source_dir/.chezmoidata.toml" "$source_dir/renovate.json" "$renovate_fixture" <<'PY'
import json
import os
import re
import sys
import tomllib
import urllib.request
from pathlib import Path

data_path, renovate_path, fixture_dir = map(Path, sys.argv[1:])
pin_text = data_path.read_text()
hex_pin = tomllib.loads(pin_text)["pins"]["hex"]
assert hex_pin["source"] == "anomalyco/hex"
assert re.fullmatch(r"\d+\.\d+\.\d+", hex_pin["version"])

renovate = json.loads(renovate_path.read_text())
managers = [
    manager for manager in renovate["customManagers"]
    if manager.get("description") == "Track Hex releases"
]
assert len(managers) == 1, managers
manager = managers[0]
assert manager["datasourceTemplate"] == "github-releases"
assert manager["versioningTemplate"] == "semver"
assert manager["managerFilePatterns"] == [r"/^\.chezmoidata\.toml$/"]
request = urllib.request.Request(
    "https://api.github.com/repos/anomalyco/hex/releases?per_page=100",
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "hex-renovate-validation",
        **(
            {"Authorization": f"Bearer {os.environ['RENOVATE_GITHUB_COM_TOKEN']}"}
            if os.environ.get("RENOVATE_GITHUB_COM_TOKEN")
            else {}
        ),
    },
)
releases = json.load(urllib.request.urlopen(request, timeout=30))
versions = sorted(
    {
        tuple(map(int, match.groups()))
        for release in releases
        if not release["draft"] and not release["prerelease"]
        if (match := re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", release["tag_name"]))
    },
    reverse=True,
)
assert len(versions) >= 2, "Hex upstream needs two stable releases for update recognition"
fixture_current = ".".join(map(str, versions[1]))
fixture_text, replacements = re.subn(
    r'(?m)(^\[pins\.hex\]\nsource = "anomalyco/hex"\nversion = ")[^"]+("$)',
    rf"\g<1>{fixture_current}\2",
    pin_text,
)
assert replacements == 1
(fixture_dir / ".chezmoidata.toml").write_text(fixture_text)
(fixture_dir / "renovate.json").write_text(json.dumps({
    "enabledManagers": ["custom.regex"],
    "customManagers": [manager],
}))
PY

if ! (
  cd "$renovate_fixture"
  RENOVATE_GITHUB_COM_TOKEN="$github_token" \
    RENOVATE_BASE_DIR="$root/renovate-cache" \
    LOG_LEVEL=debug \
    npx --yes --package=node@24.13.0 --package=renovate@44.254.1 \
      -c 'renovate --platform=local --dry-run=lookup'
) >"$root/renovate.log" 2>&1; then
  cat "$root/renovate.log" >&2
  exit 1
fi

python3 - "$renovate_fixture/.chezmoidata.toml" "$root/renovate.log" <<'PY'
import re
import sys
import tomllib
from pathlib import Path

current = tomllib.loads(Path(sys.argv[1]).read_text())["pins"]["hex"]["version"]
log = Path(sys.argv[2]).read_text()
assert "1 flattened updates found: anomalyco/hex" in log, log
position = log.rfind('"depName": "anomalyco/hex"')
updates = log.find('"updates": [', position)
match = re.search(r'"newValue": "([^"]+)"', log[updates:])
assert position >= 0 and updates > position and match, log

def semver(value):
    match = re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", value)
    return tuple(map(int, match.groups())) if match else None

assert semver(match.group(1)) > semver(current), (current, match.group(1))
print(f"Renovate recognized Hex update: {current} -> {match.group(1)}")
PY
