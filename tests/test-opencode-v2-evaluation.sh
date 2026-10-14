#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=/tmp/opencode/v2-evaluation-test
rm -rf "$root"
mkdir -p "$root/source/.config/opencode/agents" "$root/source/.config/opencode/commands" \
  "$root/source/.config/opencode/skills/demo" "$root/source/.agents/skills/shared" "$root/source/.local/share/opencode" \
  "$root/source/.local/state/opencode" "$root/source/.cache/opencode" "$root/tmp"

cat >"$root/source/.config/opencode/portable.jsonc" <<'EOF'
{"agent":{"demo":{"permission":{"read":"allow"}}}}
EOF
cat >"$root/source/.config/opencode/tui.jsonc" <<'EOF'
{
  // conversion is explicit, not automatic
  "$schema": "https://opencode.ai/tui.json",
  "plugin": ["sandbox-plugin",],
}
EOF
printf '# demo\n' >"$root/source/.config/opencode/agents/demo.md"
printf '# command\n' >"$root/source/.config/opencode/commands/demo.md"
printf '# skill\n' >"$root/source/.config/opencode/skills/demo/SKILL.md"
printf '# shared skill\n' >"$root/source/.agents/skills/shared/SKILL.md"

python3 - "$root/source/.local/share/opencode/opencode.db" <<'PY'
import sqlite3
import sys
from pathlib import Path
path = Path(sys.argv[1])
with sqlite3.connect(path) as db:
    db.execute("create table marker (value text)")
    db.execute("insert into marker values ('migrated-v1-marker')")
PY
printf 'state\n' >"$root/source/.local/state/opencode/state"
printf 'cache\n' >"$root/source/.cache/opencode/cache"

eval_root="$root/tmp/opencode/eval"
candidate="$eval_root/bin/opencode-2.0.28"
mkdir -p "${candidate%/*}"
cat >"$candidate" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$*" in
  "--version") test "${OPENCODE_CONFIG_DIR:?}" = "${OPENCODE_CONFIG%/*}"; printf '%s\n' "${FAKE_VERSION:-2.0.28}"; [[ "${FAIL_VERSION:-0}" != 1 ]] || exit 7 ;;
  "debug paths")
    test "${OPENCODE_CONFIG_DIR:?}" = "${OPENCODE_CONFIG%/*}"
    printf 'home %s\ndata %s\ncache %s\nconfig %s\nstate %s\ntmp %s\n' "$HOME" "$XDG_DATA_HOME/opencode" "$XDG_CACHE_HOME/opencode" "$OPENCODE_CONFIG_DIR" "$XDG_STATE_HOME/opencode" "$TMPDIR"
    ;;
  "debug config") printf '{"ok":true}\n' ;;
  "debug agents") printf 'demo\n' ;;
  "mcp list") printf 'No MCP servers configured\n' ;;
  *) touch "$XDG_DATA_HOME/opencode/native-v2.db" ;;
esac
EOF
chmod +x "$candidate"

wrapper="$source_dir/scripts/opencode-v2-evaluation.sh"
if env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  FAKE_VERSION=1.19.0 bash "$wrapper" prepare >/dev/null 2>&1; then
  printf 'V1 candidate was accepted\n' >&2
  exit 1
fi
if env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  FAIL_VERSION=1 bash "$wrapper" prepare >/dev/null 2>&1; then
  printf 'failed version probe was accepted\n' >&2
  exit 1
fi
grep -Fq '"status": 7' "$eval_root/candidate-version.json"
env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" prepare
test ! -e "$eval_root/xdg-config/opencode/cli.json"
test ! -e "$eval_root/evidence/automatic-cli-check.json"
env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  SOURCE_DIR="$source_dir" bash "$wrapper" configure-v2
env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" diagnose
grep -Fq '"after_diagnostic": true' "$eval_root/evidence/automatic-cli-check.json"
grep -Fq '.agents/skills/shared/SKILL.md' "$eval_root/evidence/file-discovery.json"
env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" convert-cli
test -f "$eval_root/xdg-config/opencode/cli.json"
test -f "$eval_root/home/.agents/skills/shared/SKILL.md"
env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" run synthetic
env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" check

grep -Fq '"contained": true' "$eval_root/evidence/containment.json"
grep -Fq '"v1_fingerprints": "unchanged"' "$eval_root/evidence/source-result.json"
grep -Fq '"explicit": true' "$eval_root/evidence/cli-conversion.json"
python3 - "$eval_root/xdg-data/opencode/opencode.db" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as db:
    assert db.execute("select value from marker").fetchone() == ("migrated-v1-marker",)
PY
test ! -e "$eval_root/xdg-data/opencode/opencode.db-wal"
test ! -e "$eval_root/xdg-data/opencode/opencode.db-shm"

printf 'unsupported SQLite artifact\n' >"$root/source/.cache/opencode/cache.db"
if env TMPDIR=/tmp OPENCODE_EVAL_ROOT="$eval_root" OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" prepare >/dev/null 2>&1; then
  printf 'unsupported SQLite artifact was copied\n' >&2
  exit 1
fi

if env TMPDIR=/tmp OPENCODE_EVAL_ROOT=/tmp/not-allowed OPENCODE_V1_HOME="$root/source" \
  bash "$wrapper" check >/dev/null 2>&1; then
  printf 'unsafe evaluation root was accepted\n' >&2
  exit 1
fi

printf 'OpenCode V2 evaluation wrapper tests passed.\n'
