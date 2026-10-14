#!/usr/bin/env bash
set -Eeuo pipefail

# Disposable-only V2 boundary. It copies configuration and uses SQLite's
# online backup API for the live database; it never copies SQLite sidecars.

readonly VERSION=2.0.28
readonly SOURCE_COMMIT=026b106bc5d41b679ffc413264229c340871e4d3
readonly BUN_VERSION=1.4.2
readonly TMP_ROOT=${TMPDIR:-/tmp}
readonly TMP_BASE=${TMP_ROOT%/}
readonly ROOT=${OPENCODE_EVAL_ROOT:-$TMP_BASE/opencode/v2-evaluation}
readonly SOURCE_HOME=${OPENCODE_V1_HOME:-$HOME}
readonly PYTHON=${PYTHON:-python3}

die() { printf 'opencode-v2-evaluation: %s\n' "$*" >&2; exit 1; }

case "$ROOT" in
  "$TMP_BASE"/opencode/*) ;;
  *) die "OPENCODE_EVAL_ROOT must be below $TMP_BASE/opencode" ;;
esac

case "$SOURCE_HOME" in
  "$HOME"|"$HOME"/*) ;;
  "$TMP_BASE"/opencode/*) ;;
  *) die 'OPENCODE_V1_HOME must be HOME or a HOME-relative disposable fixture' ;;
esac

config_dir=$ROOT/xdg-config/opencode
data_dir=$ROOT/xdg-data/opencode
state_dir=$ROOT/xdg-state/opencode
cache_dir=$ROOT/xdg-cache/opencode
home_dir=$ROOT/home
evidence_dir=$ROOT/evidence
candidate=$ROOT/bin/opencode-$VERSION

mkdir -p "$ROOT"
test ! -L "$ROOT" || die 'evaluation root must not be a symlink'

runtime_env() {
  env \
    HOME="$home_dir" \
    XDG_CONFIG_HOME="$ROOT/xdg-config" \
    XDG_DATA_HOME="$ROOT/xdg-data" \
    XDG_STATE_HOME="$ROOT/xdg-state" \
    XDG_CACHE_HOME="$ROOT/xdg-cache" \
    OPENCODE_CONFIG="$config_dir/portable.jsonc" \
    OPENCODE_CONFIG_DIR="$config_dir" \
    TMPDIR="$ROOT/tmp" \
    "$@"
}

candidate_path() {
  test -x "$candidate" || die "candidate is not executable: $candidate"
  printf '%s\n' "$candidate"
}

assert_v2_candidate() {
  local path=$1 version major output status
  if output=$(runtime_env "$path" --version 2>&1); then
    status=0
  else
    status=$?
  fi
  "$PYTHON" - "$ROOT/candidate-version.json" "$path" "$status" "$output" <<'PY'
import json
import sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({"path": sys.argv[2], "status": int(sys.argv[3]), "output": sys.argv[4]}, indent=2) + "\n")
PY
  (( status == 0 )) || die "candidate version probe failed with status $status"
  version=$(printf '%s' "$output" | "$PYTHON" -c 'import re,sys; match=re.search(r"(?:^|\s)v?(\d+\.\d+\.\d+)(?:$|\s)", sys.stdin.read()); print(match.group(1) if match else "")')
  major=${version%%.*}
  [[ "$major" == 2 ]] || die "candidate is not OpenCode V2: ${version:-unknown}"
  [[ "$version" == "$VERSION" ]] || die "candidate version $version does not match pinned $VERSION"
}

fingerprint() {
  local output=$1
  shift
  mkdir -p "${output%/*}"
  "$PYTHON" - "$output" "$@" <<'PY'
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

output, *roots = sys.argv[1:]

def file_hash(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def one(root):
    root_path = Path(root)
    result = {"path": str(root_path), "exists": root_path.exists() or root_path.is_symlink(), "entries": []}
    if not result["exists"]:
        return result
    paths = [root_path] if root_path.is_file() or root_path.is_symlink() else sorted(root_path.rglob("*"))
    for path in paths:
        info = os.lstat(path)
        item = {"path": str(path), "mode": stat.S_IFMT(info.st_mode), "size": info.st_size, "mtime_ns": info.st_mtime_ns}
        if stat.S_ISREG(info.st_mode):
            item["sha256"] = file_hash(path)
        elif stat.S_ISLNK(info.st_mode):
            item["target"] = os.readlink(path)
        result["entries"].append(item)
    return result

Path(output).write_text(json.dumps({"roots": [one(root) for root in roots]}, indent=2, sort_keys=True) + "\n")
PY
}

copy_tree() {
  local source=$1 target=$2
  "$PYTHON" - "$source" "$target" <<'PY'
import shutil
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:])
def sqlite_artifact(path):
    return path.name.endswith(("-wal", "-shm")) or path.suffix in {".db", ".sqlite", ".sqlite3"}
if not source.exists():
    target.mkdir(parents=True, exist_ok=True)
else:
    for path in source.rglob("*"):
        if sqlite_artifact(path):
            raise SystemExit(f"refusing to copy SQLite artifact: {path}")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target, symlinks=False, dirs_exist_ok=True)
PY
}

copy_data_without_sqlite() {
  local source=$1 target=$2 selected=${3:-}
  "$PYTHON" - "$source" "$target" "$selected" <<'PY'
import shutil
import sys
from pathlib import Path

source, target, selected = map(Path, sys.argv[1:])
blocked = {selected, Path(str(selected) + "-wal"), Path(str(selected) + "-shm")} if selected else set()
def sqlite_artifact(path):
    return path.name.endswith(("-wal", "-shm")) or path.suffix in {".db", ".sqlite", ".sqlite3"}
for path in sorted(source.rglob("*")):
    relative = path.relative_to(source)
    if sqlite_artifact(path):
        if relative in blocked:
            continue
        raise SystemExit(f"refusing unsupported SQLite artifact: {path}")
    destination = target / relative
    if path.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
    elif path.is_symlink():
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(path.resolve().read_bytes())
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
PY
}

backup_sqlite() {
  local source=$1 target=$2
  "$PYTHON" - "$source" "$target" <<'PY'
import sqlite3
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:])
target.parent.mkdir(parents=True, exist_ok=True)
source_uri = f"file:{source}?mode=ro"
with sqlite3.connect(source_uri, uri=True) as source_db, sqlite3.connect(target) as target_db:
    source_db.backup(target_db)
PY
}

find_database() {
  if [[ -n "${OPENCODE_V1_DB:-}" ]]; then
    printf '%s\n' "$OPENCODE_V1_DB"
    return
  fi
  "$PYTHON" - "$SOURCE_HOME/.local/share/opencode" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
matches = sorted(path for path in root.rglob("*") if path.is_file() and path.suffix in {".db", ".sqlite", ".sqlite3"} and not path.name.endswith(("-wal", "-shm")))
if len(matches) > 1:
    raise SystemExit("multiple SQLite databases found; set OPENCODE_V1_DB explicitly")
if matches:
    print(matches[0])
PY
}

prepare() {
  local opencode
  opencode=$(candidate_path)
  assert_v2_candidate "$opencode"
  /usr/bin/pgrep -x opencode >/dev/null 2>&1 || true
  # Do not stop V1: the database backup below is the approved live-read method.
  rm -rf "$ROOT/xdg-config" "$ROOT/xdg-data" "$ROOT/xdg-state" "$ROOT/xdg-cache" "$ROOT/home" "$ROOT/evidence"
  mkdir -p "$config_dir" "$data_dir" "$state_dir" "$cache_dir" "$home_dir" "$evidence_dir" "$ROOT/tmp"

  local source_config=$SOURCE_HOME/.config/opencode
  local source_data=$SOURCE_HOME/.local/share/opencode
  local source_state=$SOURCE_HOME/.local/state/opencode
  local source_cache=$SOURCE_HOME/.cache/opencode
  local source_db db_relative target_db
  source_db=$(find_database)

  fingerprint "$evidence_dir/v1-pre.json" "$source_config" "$source_data" "$source_state" "$source_cache" "$SOURCE_HOME/.agents/skills"
  copy_tree "$source_config" "$config_dir"
  copy_tree "$SOURCE_HOME/.agents/skills" "$home_dir/.agents/skills"

  if [[ -n "$source_db" ]]; then
    case "$source_db" in
      "$source_data"/*) ;;
      *) die 'OPENCODE_V1_DB must be under the V1 OpenCode data directory' ;;
    esac
    db_relative=${source_db#"$source_data"/}
    copy_data_without_sqlite "$source_data" "$data_dir" "$db_relative"
    target_db=$data_dir/$db_relative
    backup_sqlite "$source_db" "$target_db"
    printf '%s\n' "$db_relative" >"$evidence_dir/database-relative-path"
  else
    copy_data_without_sqlite "$source_data" "$data_dir"
    : >"$evidence_dir/database-relative-path"
  fi

  copy_tree "$source_state" "$state_dir"
  copy_tree "$source_cache" "$cache_dir"
  fingerprint "$evidence_dir/v1-after-seed.json" "$source_config" "$source_data" "$source_state" "$source_cache" "$SOURCE_HOME/.agents/skills"
  cmp -s "$evidence_dir/v1-pre.json" "$evidence_dir/v1-after-seed.json" ||
    printf 'warning: V1 changed during seed; inspect fingerprints before claiming an untouched source.\n' >&2

}

install_candidate() {
  local platform architecture archive source_dir bun_archive bun_binary outdir
  platform=$(uname -s)
  architecture=$(uname -m)
  [[ "$platform" == Darwin ]] || die "pinned candidate is currently macOS-only: $platform"
  [[ "$architecture" == arm64 ]] || die "the pinned V2 source build is currently verified only for Darwin arm64"
  [[ "$VERSION" == 2.0.28 ]] || die 'only the pinned 2.0.28 candidate is authorized'
  mkdir -p "$ROOT/bin" "$ROOT/build" "$ROOT/build/home" "$ROOT/build/cache"
  for stale in "$ROOT"/bin/opencode-1.*; do
    [[ -e "$stale" ]] && rm -f "$stale"
  done
  rm -rf "$ROOT/download" "$ROOT/extract"
  if [[ -e "$candidate" ]]; then
    test -x "$candidate" || die "candidate exists but is not executable: $candidate"
  else
    archive=$ROOT/build/opencode-$SOURCE_COMMIT.tar.gz
    if [[ ! -f "$archive" ]]; then
      /usr/bin/curl --fail --location --silent --show-error --output "$archive" \
        "https://github.com/anomalyco/opencode/archive/$SOURCE_COMMIT.tar.gz"
    fi
    test "$(shasum -a 256 "$archive" | cut -d' ' -f1)" = b95af5a152120a4a458bd9e198eb415c36d407e8481d06eeef1bb5e43819b030 || die 'V2 source checksum mismatch'
    bun_archive=$ROOT/build/bun-$BUN_VERSION.zip
    if [[ ! -f "$bun_archive" ]]; then
      /usr/bin/curl --fail --location --silent --show-error --output "$bun_archive" \
        "https://github.com/oven-sh/bun/releases/download/bun-v$BUN_VERSION/bun-darwin-aarch64.zip"
    fi
    test "$(shasum -a 256 "$bun_archive" | cut -d' ' -f1)" = 90987a3a16d7db556d886ac3d551e7b6d3edf0a1cf43acaed622e8676be1d12f || die 'Bun checksum mismatch'
    rm -rf "$ROOT/build/bun" "$ROOT/build/source"
    mkdir -p "$ROOT/build/bun" "$ROOT/build/source"
    /usr/bin/unzip -q "$bun_archive" -d "$ROOT/build/bun"
    bun_binary=$(/usr/bin/find "$ROOT/build/bun" -type f -name bun -perm -111 -print -quit)
    test -n "$bun_binary" || die 'Bun archive did not contain an executable'
    /usr/bin/tar -xzf "$archive" -C "$ROOT/build/source"
    source_dir=$ROOT/build/source/opencode-$SOURCE_COMMIT
    test -f "$source_dir/package.json" || die 'V2 source archive layout changed'
    env PATH="${bun_binary%/*}:$PATH" HOME="$ROOT/build/home" XDG_CACHE_HOME="$ROOT/build/cache" BUN_INSTALL_CACHE_DIR="$ROOT/build/cache/bun" \
      "$bun_binary" install --frozen-lockfile --cwd "$source_dir"
    outdir=$ROOT/build/dist
    rm -rf "$outdir"
    env PATH="${bun_binary%/*}:$PATH" HOME="$ROOT/build/home" XDG_CACHE_HOME="$ROOT/build/cache" BUN_INSTALL_CACHE_DIR="$ROOT/build/cache/bun" OPENCODE_CHANNEL=stable OPENCODE_VERSION="$VERSION" \
      "$bun_binary" run --cwd "$source_dir/packages/cli" build --single --skip-install --skip-web-ui --outdir="$outdir"
    test -x "$outdir/cli-darwin-arm64/bin/opencode" || die 'V2 build did not produce the pinned Darwin arm64 binary'
    cp "$outdir/cli-darwin-arm64/bin/opencode" "$candidate"
    chmod 755 "$candidate"
  fi
  assert_v2_candidate "$candidate"
  printf '{"version":"%s","source_commit":"%s","path":"%s","sha256":"%s"}\n' "$VERSION" "$SOURCE_COMMIT" "$candidate" "$(shasum -a 256 "$candidate" | cut -d' ' -f1)" >"$ROOT/candidate.json"
}

convert_cli() {
  test -f "$config_dir/tui.jsonc" || die 'sandbox tui.jsonc is missing'
  test -f "$evidence_dir/automatic-cli-check.json" || die 'run the isolated V2 diagnostic before conversion'
  "$PYTHON" - "$evidence_dir/automatic-cli-check.json" <<'PY'
import json
import sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text())["after_diagnostic"] is True
PY
  test ! -e "$config_dir/cli.json" || die 'sandbox cli.json already exists; remove the disposable runtime to repeat conversion'
  "$PYTHON" - "$config_dir/tui.jsonc" "$config_dir/cli.json" "$evidence_dir/cli-conversion.json" <<'PY'
import json
import re
import sys
from pathlib import Path

source, target, evidence = map(Path, sys.argv[1:])
text = source.read_text()
clean = []
quoted = escaped = line_comment = block_comment = False
index = 0
while index < len(text):
    char = text[index]
    pair = text[index:index + 2]
    if line_comment:
        if char == "\n":
            line_comment = False
            clean.append(char)
        index += 1
        continue
    if block_comment:
        if pair == "*/":
            block_comment = False
            index += 2
        else:
            index += 1
        continue
    if quoted:
        clean.append(char)
        if escaped:
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == '"':
            quoted = False
    elif char == '"':
        quoted = True
        clean.append(char)
    elif pair == "//":
        line_comment = True
        index += 1
    elif pair == "/*":
        block_comment = True
        index += 1
    else:
        clean.append(char)
    index += 1
text = "".join(clean)
text = re.sub(r",\s*([}\]])", r"\1", text)
data = json.loads(text)
data["$schema"] = "https://opencode.ai/cli.json"
target.write_text(json.dumps(data, indent=2) + "\n")
evidence.write_text(json.dumps({"source": str(source), "target": str(target), "explicit": True, "schema": data["$schema"]}, indent=2) + "\n")
PY
}

diagnose() {
  local opencode
  opencode=$(candidate_path)
  assert_v2_candidate "$opencode"
  mkdir -p "$evidence_dir"
  runtime_env "$opencode" --version >"$evidence_dir/version.txt"
  runtime_env "$opencode" debug paths >"$evidence_dir/paths.txt"
  runtime_env "$opencode" debug config >"$evidence_dir/resolved-config.json"
  runtime_env "$opencode" debug agents >"$evidence_dir/agents.txt"
  runtime_env "$opencode" mcp list >"$evidence_dir/mcp.txt"
  test -f "$config_dir/tui.jsonc" || die 'diagnostic input tui.jsonc is missing'
  if [[ ! -e "$config_dir/cli.json" ]]; then
    "$PYTHON" - "$evidence_dir/automatic-cli-check.json" "$config_dir/tui.jsonc" "$config_dir/cli.json" <<'PY'
import json
import sys
from pathlib import Path
out, tui, cli = map(Path, sys.argv[1:])
out.write_text(json.dumps({"tui_jsonc_exists": tui.exists(), "cli_json_exists": cli.exists(), "automatic_conversion": False, "after_diagnostic": True}, indent=2) + "\n")
PY
  else
    test -f "$evidence_dir/automatic-cli-check.json" || die 'cli.json exists without a pre-conversion diagnostic'
  fi
  "$PYTHON" - "$evidence_dir/file-discovery.json" "$config_dir" "$home_dir" <<'PY'
import json
import sys
from pathlib import Path

out, root, home = map(Path, sys.argv[1:])
out.write_text(json.dumps({
    "agents": sorted(str(p.relative_to(root)) for p in (root / "agents").glob("*.md")),
    "commands": sorted(str(p.relative_to(root)) for p in (root / "commands").glob("*.md")),
    "skills": sorted(str(p.relative_to(root)).removesuffix("/SKILL.md") for p in (root / "skills").glob("*/SKILL.md")),
    "shared_skills": sorted(str(p.relative_to(home)) for p in (home / ".agents" / "skills").glob("*/SKILL.md")),
  }, indent=2) + "\n")
PY
  "$PYTHON" - "$evidence_dir/file-discovery.json" "$evidence_dir/skills.txt" <<'PY'
import json
import sys
from pathlib import Path
discovery = json.loads(Path(sys.argv[1]).read_text())
Path(sys.argv[2]).write_text("\n".join(discovery["skills"] + discovery["shared_skills"]) + "\n")
PY
}

check() {
  local opencode paths
  opencode=$(candidate_path)
  assert_v2_candidate "$opencode"
  test -f "$evidence_dir/v1-pre.json" || die 'run prepare first'
  fingerprint "$evidence_dir/v1-post.json" "$SOURCE_HOME/.config/opencode" "$SOURCE_HOME/.local/share/opencode" "$SOURCE_HOME/.local/state/opencode" "$SOURCE_HOME/.cache/opencode" "$SOURCE_HOME/.agents/skills"
  runtime_env "$opencode" debug paths >"$evidence_dir/paths-after.txt"
  paths=$evidence_dir/paths-after.txt
  "$PYTHON" - "$paths" "$ROOT" "$data_dir" "$evidence_dir/containment.json" <<'PY'
import json
import os
import sys
from pathlib import Path

paths_file, root, data, output = map(Path, sys.argv[1:])
root = root.resolve()
resolved = {}
for line in paths_file.read_text().splitlines():
    parts = line.split(None, 1)
    if len(parts) == 2:
        resolved[parts[0]] = str(Path(parts[1]).resolve())
required = {"home", "data", "cache", "config", "state", "tmp"}
missing = sorted(required - resolved.keys())
outside = {key: value for key, value in resolved.items() if not (value == str(root) or value.startswith(str(root) + os.sep))}
outside_data = []
if data.exists():
    for path in data.rglob("*"):
        if path.is_symlink() and not (path.resolve() == data or str(path.resolve()).startswith(str(data) + os.sep)):
            outside_data.append(str(path))
Path(output).write_text(json.dumps({"paths": resolved, "missing": missing, "outside_root": outside, "outside_data_symlinks": outside_data, "contained": not missing and not outside and not outside_data}, indent=2) + "\n")
if missing or outside or outside_data:
    raise SystemExit("runtime path containment failed")
PY
  "$PYTHON" - "$evidence_dir/v1-pre.json" "$evidence_dir/v1-post.json" "$evidence_dir/source-result.json" <<'PY'
import json
import sys
from pathlib import Path

pre = {item["path"]: item for item in json.loads(Path(sys.argv[1]).read_text())["roots"]}
post = {item["path"]: item for item in json.loads(Path(sys.argv[2]).read_text())["roots"]}
labels = {".config/opencode": "config", ".local/share/opencode": "data", ".local/state/opencode": "state", ".cache/opencode": "cache", ".agents/skills": "shared_skills"}
roots = {}
for path, before in pre.items():
    label = next((name for suffix, name in labels.items() if path.endswith(suffix)), path)
    roots[label] = "unchanged" if before == post.get(path) else "changed"
Path(sys.argv[3]).write_text(json.dumps({"v1_fingerprints": "unchanged" if all(value == "unchanged" for value in roots.values()) else "changed", "roots": roots}, indent=2) + "\n")
PY
}

usage() {
  cat <<'EOF'
Usage: scripts/opencode-v2-evaluation.sh <install|prepare|convert-cli|diagnose|run|check>

The wrapper only launches a candidate inside OPENCODE_EVAL_ROOT, which must be
under TMPDIR/opencode. prepare uses SQLite's online backup API for the live
OpenCode database and records hashes, not history contents.
EOF
}

command=${1:-}
shift || true
case "$command" in
  install) install_candidate ;;
  prepare) prepare ;;
  convert-cli) convert_cli ;;
  diagnose) diagnose ;;
  run)
    opencode=$(candidate_path)
    assert_v2_candidate "$opencode"
    runtime_env "$opencode" "$@"
    ;;
  check) check ;;
  *) usage; exit 2 ;;
esac
