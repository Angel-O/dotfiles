#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

config="$root/config-home/.config/opencode/portable.jsonc"
mkdir -p "$(dirname "$config")"
installer="$root/installer.sh"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_config/opencode/portable.jsonc.tmpl" >"$config"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/run_before_07-install-opencode-tracker.sh.tmpl" >"$installer"
sh -n "$installer"

python3 - "$config" "$source_dir/.chezmoidata.toml" "$source_dir/renovate.json" <<'PY'
import json
import re
import sys
import tomllib
from pathlib import Path

portable = json.load(open(sys.argv[1]))
pin_text = Path(sys.argv[2]).read_text()
pins = tomllib.loads(pin_text)["pins"]["openCodeTracker"]
renovate = json.load(open(sys.argv[3]))
assert "plugin" not in portable
assert portable["experimental"] == {"todo": True}
plugins = portable["plugins"]
assert "../../.local/share/opencode/opencode-todo/src" not in plugins
tracker = [entry for entry in plugins if "orchestration-tracking" in str(entry)]
assert len(tracker) == 1, plugins
assert plugins[-1] is tracker[0], plugins
assert tracker[0] == "../../.local/share/opencode/orchestration-tracking/src"
assert isinstance(tracker[0], str), tracker
assert plugins.count(tracker[0]) == 1, plugins
assert tracker[0] != "../../.local/share/opencode/orchestration-tracking"
assert all("qa" not in str(entry).lower() for entry in plugins)
assert all(not (isinstance(entry, dict) and "orchestration-tracking" in str(entry)) for entry in plugins)
assert plugins == [
    "@slkiser/opencode-quota@5.0.2",
    "@plannotator/opencode@0.28.2",
    "../../.local/share/opencode/orchestration-tracking/src",
]
assert plugins.count("@plannotator/opencode@0.28.2") == 1
config_dir = Path(sys.argv[1]).parent
managed_src = config_dir.parent.parent / ".local/share/opencode/orchestration-tracking/src"
managed_src.mkdir(parents=True)
(managed_src / "index.ts").write_text("export default {};\n")
assert (config_dir / tracker[0]).resolve() == managed_src.resolve()
assert (config_dir / tracker[0] / "index.ts").is_file()
assert set(pins) == {"source", "tag", "archiveSha256"}
assert pins["source"] == "Angel-O/orchestration-tracking"
assert pins["tag"] == "v0.2.1"
assert pins["archiveSha256"] == "dfece5623582a6121c86f121fbe4a0945bfed776b52312df59126500d012b2ef"
assert re.fullmatch(r"v\d+\.\d+\.\d+", pins["tag"])
assert re.fullmatch(r"[0-9a-f]{64}", pins["archiveSha256"])
managers = [manager for manager in renovate["customManagers"] if manager.get("depTypeTemplate") == "opencode-tracker"]
assert len(managers) == 1, managers
manager = managers[0]
assert manager["datasourceTemplate"] == "github-release-attachments"
assert manager["versioningTemplate"] == "semver-coerced"
assert manager["managerFilePatterns"] == [r"/^\.chezmoidata\.toml$/"]
pattern = manager["matchStrings"][0].replace("(?<", "(?P<")
match = re.search(pattern, pin_text)
assert match and match.groupdict() == {
    "depName": pins["source"],
    "currentValue": pins["tag"],
    "currentDigest": pins["archiveSha256"],
}
PY

launcher="$source_dir/dot_local/bin/executable_herdr-agent-launch"
grep -Fq -- '--arg session "$session_id"' "$launcher"
grep -Fq 'session_id:$session' "$launcher"
grep -Fq 'orchestration-tracking.launch' "$launcher"
grep -Fq 'tracking_bead_select({ beadID })' "$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl"
if grep -Fq 'tracking_run_start' "$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl"; then
  printf 'managed orchestration must not use the removed run-start call.\n' >&2
  exit 1
fi
if grep -R -Fq 'tracking_lane_attach' "$source_dir/dot_config/opencode" "$source_dir/docs" "$source_dir/README.md"; then
  printf 'managed guidance must not use the removed lane-attach call.\n' >&2
  exit 1
fi
grep -Fq -- '--tracking-bead <bead-id>' "$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl"
grep -Fq -- 'architect sibling <architect-name> --tracking-bead <bead-id>' "$source_dir/dot_config/opencode/commands/orchestrate.md"
if grep -Fq 'After each primary architect or worker launch' "$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl"; then
  printf 'normal orchestration must not require post-launch lane attachment.\n' >&2
  exit 1
fi
grep -Fq 'tracking_report' "$source_dir/dot_config/opencode/commands/tracking-report.md"
grep -Fq 'tracking_report({ bead?, sessions?, from?, to? })' "$source_dir/dot_config/opencode/commands/tracking-report.md"
grep -Fq 'tracking_closeout({ beadID })' "$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl"
grep -Fq 'tracking_closeout' "$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl"

python3 - "$source_dir/dot_config/opencode/agents/orchestrator.md" \
  "$source_dir/dot_config/opencode/agents/planner.md" \
  "$source_dir/dot_config/opencode/commands/orchestrate-bead.md.tmpl" \
  "$source_dir/dot_config/opencode/commands/orchestrate.md" \
  "$source_dir/dot_config/opencode/commands/tracking-report.md" \
  "$source_dir/dot_config/opencode/modify_AGENTS.md.tmpl" <<'PY'
from pathlib import Path
import sys

orchestrator, planner, command, ordinary_command, report, agents = (
    Path(path).read_text() for path in sys.argv[1:]
)
assert "tracking_bead_created({ beadID })" in orchestrator
assert "successful top-level `wbd create`" in orchestrator
assert "exact `wbd show` validation" in orchestrator
assert "active-scope membership confirmation" in orchestrator
assert "tracking_bead_created({ beadID })" in planner
assert planner.index("parent-linking succeeds") < planner.index("tracking_bead_created({ beadID })")
assert "planner's epic attribution" in planner
assert "creating child scoping" in planner
assert command.index("tracking_bead_select({ beadID })") < command.index("--tracking-bead <bead-id>")
assert "tracking_run_start" not in command
assert "tracking_lane_attach" not in command
assert "newly created epic from normal discussion" in ordinary_command
assert "already-validated epic ID" in ordinary_command
assert ordinary_command.index("newly created epic") < ordinary_command.index("architect sibling <architect-name> --tracking-bead <bead-id>")
assert "omit that option for non-Bead architecture" in ordinary_command
assert "tracking_report({ bead?, sessions?, from?, to? })" in report
assert "default run" not in report
assert agents.index("closeout complete") < agents.index("tracking_closeout({ beadID })")
PY

managed=$(chezmoi managed --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal.toml" --cache "$root/cache" \
  --exclude externals --include files)
printf '%s\n' "$managed" | grep -Fxq '.config/opencode/commands/tracking-report.md'
disabled_managed=$(chezmoi managed --source "$source_dir" \
  --config "$source_dir/tests/fixtures/helix-only.toml" --cache "$root/disabled-cache" \
  --exclude externals --include files)
if printf '%s\n' "$disabled_managed" | grep -Fxq '.config/opencode/commands/tracking-report.md'; then
  printf 'tracking-report must not be managed when OpenCode is disabled.\n' >&2
  exit 1
fi

grep -Fq 'https://github.com/$repo/releases/download/$wanted_tag/$wanted_archive' "$installer"
grep -Fq 'curl -fsSL' "$installer"
grep -Fq 'mv -Tf "$link_tmp" "$current"' "$installer"
grep -Fq 'os.replace(sys.argv[1], sys.argv[2])' "$installer"
if grep -Fq '/archive/' "$installer"; then
  printf 'tracker installer must use the verified release asset, not a source archive.\n' >&2
  exit 1
fi
if grep -Eq '(^|[[:space:]])(gh|wget)([[:space:]]|$)' "$installer"; then
  printf 'tracker installer must use the public archive URL, not GitHub CLI or wget.\n' >&2
  exit 1
fi

archive_root="$root/archive/orchestration-tracking-fixture"
mkdir -p "$archive_root/src"
printf '%s\n' 'export default {};' >"$archive_root/src/plugin.ts"
printf '%s\n' '{"name":"orchestration-tracking"}' >"$archive_root/package.json"
tar -czf "$root/tracker.tar.gz" -C "$root/archive" orchestration-tracking-fixture
if command -v sha256sum >/dev/null 2>&1; then
  archive_sha=$(sha256sum "$root/tracker.tar.gz" | awk '{print $1}')
else
  archive_sha=$(shasum -a 256 "$root/tracker.tar.gz" | awk '{print $1}')
fi
read -r tracker_source tracker_tag tracker_sha < <(python3 - "$source_dir/.chezmoidata.toml" <<'PY'
import sys
import tomllib

pins = tomllib.load(open(sys.argv[1], "rb"))["pins"]["openCodeTracker"]
print(pins["source"], pins["tag"], pins["archiveSha256"])
PY
)
tracker_archive="orchestration-tracking-${tracker_tag#v}.tar.gz"
python3 - "$installer" "$tracker_sha" "$archive_sha" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace(sys.argv[2], sys.argv[3]))
PY

fake_bin="$root/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=
url=
while (($#)); do
  case $1 in
    --output|-o) output=$2; shift 2 ;;
    --retry) shift 2 ;;
    --) shift; url=$1; shift ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
printf '%s\n' "$url" >"$FAKE_CURL_URL"
cat "$FAKE_CURL_ARCHIVE" >"$output"
EOF
chmod +x "$fake_bin/curl"

home="$root/home"
mkdir -p "$home"
HOME="$home" PATH="$fake_bin:$PATH" FAKE_CURL_ARCHIVE="$root/tracker.tar.gz" \
  FAKE_CURL_URL="$root/curl.url" \
  sh "$installer"
current="$home/.local/share/opencode/orchestration-tracking"
test -L "$current"
test "$(readlink "$current")" = "orchestration-tracking-$archive_sha"
test -f "$current/src/plugin.ts"
grep -Fxq "https://github.com/$tracker_source/releases/download/$tracker_tag/$tracker_archive" "$root/curl.url"

old_ref=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
mkdir -p "$home/.local/share/opencode/orchestration-tracking-$old_ref/src"
printf '%s\n' 'old managed release' >"$home/.local/share/opencode/orchestration-tracking-$old_ref/src/plugin.ts"
rm "$current"
rm -rf "$home/.local/share/opencode/orchestration-tracking-$archive_sha"
ln -s "orchestration-tracking-$old_ref" "$current"
HOME="$home" PATH="$fake_bin:$PATH" FAKE_CURL_ARCHIVE="$root/tracker.tar.gz" \
  FAKE_CURL_URL="$root/curl.url" \
  sh "$installer"
test "$(readlink "$current")" = "orchestration-tracking-$archive_sha"
test -f "$home/.local/share/opencode/orchestration-tracking-$old_ref/src/plugin.ts"

HOME="$home" PATH="$fake_bin:$PATH" FAKE_CURL_ARCHIVE="$root/tracker.tar.gz" \
  FAKE_CURL_URL="$root/curl.url" \
  sh "$installer"
test -f "$current/src/plugin.ts"

rm "$current"
ln -s unmanaged-target "$current"
if HOME="$home" PATH="$fake_bin:$PATH" FAKE_CURL_ARCHIVE="$root/tracker.tar.gz" \
  FAKE_CURL_URL="$root/curl.url" sh "$installer" 2>"$root/unmanaged.error"; then
  printf 'tracker installer unexpectedly replaced an unmanaged symlink.\n' >&2
  exit 1
fi
grep -Fq 'not the managed tracker symlink' "$root/unmanaged.error"

if HOME="$root/no-curl-home" PATH="$root/empty-bin" FAKE_CURL_ARCHIVE="$root/tracker.tar.gz" \
  FAKE_CURL_URL="$root/curl.url" /bin/sh "$installer" 2>"$root/no-curl.error"; then
  printf 'tracker installer unexpectedly succeeded without curl.\n' >&2
  exit 1
fi
grep -Fq 'requires curl' "$root/no-curl.error"
