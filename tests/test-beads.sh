#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
root=$2
case_root=$root/beads-wrapper
fake_bin=$case_root/bin
home=$case_root/home
store=$home/.local/share/beads/hub/.beads
hub_config=$home/.config/bv/hub.yaml
ledger=$home/.local/share/beads/hub/correlations.jsonl
repo_a=$case_root/repos/repo-a
repo_b=$case_root/repos/repo-b
mkdir -p "$fake_bin" "$store" "$repo_a" "$repo_b"

fail() {
  printf 'beads test: %s\n' "$*" >&2
  exit 1
}

jq_path=$(command -v jq) || fail 'jq is required to run wrapper tests'
ln -s "$jq_path" "$fake_bin/jq"

cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
if [ "${FAKE_GIT_FAIL:-0}" = 1 ]; then
  exit 1
fi
if [ "$#" -eq 4 ] && [ "$1" = -C ] && [ "$3" = rev-parse ] && [ "$4" = --git-dir ]; then
  exit 1
fi
if [ "$#" -eq 2 ] && [ "$1" = rev-parse ] && [ "$2" = --is-inside-work-tree ]; then
  printf '%s\n' true
  exit 0
fi
if [ "$#" -eq 2 ] && [ "$1" = rev-parse ] && [ "$2" = --show-toplevel ]; then
  printf '%s\n' "${FAKE_GIT_ROOT:?}"
  exit 0
fi
if [ "$#" -eq 3 ] && [ "$1" = config ] && [ "$2" = --get ] && [ "$3" = remote.origin.url ]; then
  [ "${FAKE_ORIGIN_MISSING:-0}" != 1 ] || exit 1
  printf '%s\n' "${FAKE_ORIGIN:?}"
  exit 0
fi
exit 2
EOF

cat >"$fake_bin/bd" <<'EOF'
#!/bin/sh
{
  printf '%s\n' BEGIN_BD
  printf 'BEADS_DIR=%s\n' "${BEADS_DIR:-}"
  printf 'BEADS_DB_SET=%s\n' "${BEADS_DB+x}"
  printf 'BD_DB_SET=%s\n' "${BD_DB+x}"
  printf 'BD_GLOBAL_SET=%s\n' "${BD_GLOBAL+x}"
  printf 'BEADS_DOLT_DATA_DIR_SET=%s\n' "${BEADS_DOLT_DATA_DIR+x}"
  printf 'BEADS_DOLT_PORT_SET=%s\n' "${BEADS_DOLT_PORT+x}"
  printf 'BEADS_DOLT_PROXIED_SERVER_SET=%s\n' "${BEADS_DOLT_PROXIED_SERVER+x}"
  printf 'BEADS_DOLT_SERVER_DATABASE_SET=%s\n' "${BEADS_DOLT_SERVER_DATABASE+x}"
  printf 'BEADS_DOLT_SERVER_HOST_SET=%s\n' "${BEADS_DOLT_SERVER_HOST+x}"
  printf 'BEADS_DOLT_SERVER_MODE_SET=%s\n' "${BEADS_DOLT_SERVER_MODE+x}"
  printf 'BEADS_DOLT_SERVER_PORT_SET=%s\n' "${BEADS_DOLT_SERVER_PORT+x}"
  printf 'BEADS_DOLT_SERVER_SOCKET_SET=%s\n' "${BEADS_DOLT_SERVER_SOCKET+x}"
  printf 'BEADS_DOLT_SHARED_SERVER_SET=%s\n' "${BEADS_DOLT_SHARED_SERVER+x}"
  for arg in "$@"; do printf 'arg=%s\n' "$arg"; done
  printf '%s\n' END_BD
} >>"${FAKE_LOG:?}"

if [ "${1:-}" = --db ]; then
  shift 2
fi
if [ "${1:-}" = --json ]; then
  shift
fi
if [ "${1:-}" = config ] && [ "${2:-}" = get ] && [ "${3:-}" = issue_prefix ] && [ -n "${FAKE_MIGRATION_HOME:-}" ]; then
  count=0
  if [ -f "$FAKE_MIGRATION_HOME/prefix-read-count" ]; then
    IFS= read -r count <"$FAKE_MIGRATION_HOME/prefix-read-count"
  fi
  count=$((count + 1))
  printf '%s\n' "$count" >"$FAKE_MIGRATION_HOME/prefix-read-count"
  IFS= read -r prefix <"$FAKE_MIGRATION_HOME/current-prefix"
  if [ -n "${FAKE_PREFIX_CHANGE_AT:-}" ] && [ "$count" -ge "$FAKE_PREFIX_CHANGE_AT" ]; then
    prefix=${FAKE_CHANGED_PREFIX:?}
  fi
  printf '{"key":"issue_prefix","schema_version":%s,"value":"%s"}\n' "${FAKE_SCHEMA_VERSION:-1}" "$prefix"
  exit 0
fi
if [ "${1:-}" = rename-prefix ] && [ -n "${FAKE_MIGRATION_HOME:-}" ]; then
  if [ -d "$FAKE_MIGRATION_HOME/.local/share/beads/work/.beads" ]; then
    old_parent=$FAKE_MIGRATION_HOME/.local/share/beads/work
    backup_found=false
    for candidate in "$FAKE_MIGRATION_HOME"/.local/share/beads/work-to-hub-backup-*; do
      if [ -d "$candidate/work/.beads" ] && [ -f "$candidate/work-beads.yaml" ]; then
        backup_found=true
      fi
    done
  else
    old_parent=$FAKE_MIGRATION_HOME/.local/share/beads/hub
    backup_found=false
    for candidate in "$FAKE_MIGRATION_HOME"/.local/share/beads/hub-prefix-backup-*; do
      if [ -d "$candidate/hub/.beads" ] && [ -f "$candidate/hub.yaml" ]; then
        backup_found=true
      fi
    done
  fi
  $backup_found || exit 46
  if [ "$old_parent" = "$FAKE_MIGRATION_HOME/.local/share/beads/work" ]; then
    [ -d "$old_parent/.beads" ] && [ ! -e "$FAKE_MIGRATION_HOME/.local/share/beads/hub" ] || exit 47
  else
    [ -d "$old_parent/.beads" ] || exit 47
  fi
  printf '%s\n' MIGRATION_BACKUP_BEFORE_RENAME >>"${FAKE_LOG:?}"
  : >"$FAKE_MIGRATION_HOME/rename-complete"
  printf '%s\n' "${2:?}" >"$FAKE_MIGRATION_HOME/rename-prefix"
  printf '%s\n' "${2:?}" >"$FAKE_MIGRATION_HOME/current-prefix"
fi
if [ "${1:-}" = export ] && [ -n "${FAKE_MIGRATION_HOME:-}" ]; then
  [ -f "$FAKE_MIGRATION_HOME/rename-complete" ] || exit 48
  [ "${2:-}" = -o ] && [ -n "${3:-}" ] || exit 49
  IFS= read -r prefix <"$FAKE_MIGRATION_HOME/rename-prefix"
  printf '{"id":"%s-1gj","title":"Renamed export"}\n' "$prefix" >"$3"
  printf '{"id":"%s-8au","title":"Second renamed export"}\n' "$prefix" >>"$3"
fi
if [ "${1:-}" = init ]; then
  mkdir -p "${BEADS_DIR:?}"
  exit "${FAKE_INIT_EXIT:-0}"
fi
if [ "${1:-}" = config ] && [ "${2:-}" = set ] && [ "${3:-}" = "${FAKE_CONFIG_FAIL_KEY:-__never__}" ]; then
  exit 43
fi
if [ "${1:-}" = metrics ] && [ "${FAKE_METRICS_FAIL:-0}" = 1 ]; then
  exit 44
fi
exit "${FAKE_BD_EXIT:-0}"
EOF

cat >"$fake_bin/bv" <<'EOF'
#!/bin/sh
{
  printf '%s\n' BEGIN_BV
  printf 'BEADS_DIR=%s\n' "${BEADS_DIR:-}"
  printf 'BEADS_DB_SET=%s\n' "${BEADS_DB+x}"
  printf 'BD_DB_SET=%s\n' "${BD_DB+x}"
  printf 'BD_GLOBAL_SET=%s\n' "${BD_GLOBAL+x}"
  printf 'BEADS_DOLT_DATA_DIR_SET=%s\n' "${BEADS_DOLT_DATA_DIR+x}"
  printf 'BEADS_DOLT_PORT_SET=%s\n' "${BEADS_DOLT_PORT+x}"
  printf 'BEADS_DOLT_PROXIED_SERVER_SET=%s\n' "${BEADS_DOLT_PROXIED_SERVER+x}"
  printf 'BEADS_DOLT_SERVER_DATABASE_SET=%s\n' "${BEADS_DOLT_SERVER_DATABASE+x}"
  printf 'BEADS_DOLT_SERVER_HOST_SET=%s\n' "${BEADS_DOLT_SERVER_HOST+x}"
  printf 'BEADS_DOLT_SERVER_MODE_SET=%s\n' "${BEADS_DOLT_SERVER_MODE+x}"
  printf 'BEADS_DOLT_SERVER_PORT_SET=%s\n' "${BEADS_DOLT_SERVER_PORT+x}"
  printf 'BEADS_DOLT_SERVER_SOCKET_SET=%s\n' "${BEADS_DOLT_SERVER_SOCKET+x}"
  printf 'BEADS_DOLT_SHARED_SERVER_SET=%s\n' "${BEADS_DOLT_SHARED_SERVER+x}"
  printf 'PWD=%s\n' "$PWD"
  printf 'BV_NO_GITIGNORE=%s\n' "${BV_NO_GITIGNORE:-}"
  printf 'BV_NO_CACHE=%s\n' "${BV_NO_CACHE:-}"
  printf 'BV_OUTPUT_FORMAT_SET=%s\n' "${BV_OUTPUT_FORMAT+x}"
  printf 'TOON_DEFAULT_FORMAT_SET=%s\n' "${TOON_DEFAULT_FORMAT+x}"
  printf 'TOON_STATS_SET=%s\n' "${TOON_STATS+x}"
  printf 'BV_PRETTY_JSON_SET=%s\n' "${BV_PRETTY_JSON+x}"
  for arg in "$@"; do printf 'arg=%s\n' "$arg"; done
  printf '%s\n' END_BV
} >>"${FAKE_LOG:?}"
exit "${FAKE_BV_EXIT:-0}"
EOF
chmod +x "$fake_bin/git" "$fake_bin/bd" "$fake_bin/bv"

wbd=$source_dir/dot_local/bin/executable_wbd
wbv=$source_dir/dot_local/bin/executable_wbv
cat >"$fake_bin/wbd" <<'EOF'
#!/bin/sh
exec /bin/bash "${WBD_SOURCE:?}" "$@"
EOF
chmod +x "$fake_bin/wbd"
export HOME=$home
export PATH=$fake_bin:/usr/bin:/bin
export FAKE_LOG=$case_root/calls.log
export WBD_SOURCE=$wbd
export FAKE_ORIGIN=git@example.com:Group/Repo-A.git
export FAKE_GIT_ROOT=$repo_a
: >"$FAKE_LOG"

assert_config() {
  jq -e \
    --arg store "$store" \
    --arg ledger "$ledger" \
    '.version == 1 and .store == $store and .ledger == $ledger and (.repositories | type == "object")' \
    "$hub_config" >/dev/null || fail 'hub config contents are invalid'
}

assert_last_args() {
  local command=$1
  shift
  python3 - "$FAKE_LOG" "$command" "$@" <<'PY'
import sys

path, command, *expected = sys.argv[1:]
begin, end = f"BEGIN_{command}", f"END_{command}"
blocks, current = [], None
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if line == begin:
        current = []
    elif line == end and current is not None:
        blocks.append(current)
        current = None
    elif current is not None and line.startswith("arg="):
        current.append(line[4:])
assert blocks, f"no {command} invocation in {path}"
assert blocks[-1] == expected, (blocks[-1], expected)
PY
}

assert_migration_bd_calls() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys

path, store, prefix = sys.argv[1:]
blocks, current = [], None
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if line == "BEGIN_BD":
        current = []
    elif line == "END_BD" and current is not None:
        blocks.append(current)
        current = None
    elif current is not None and line.startswith("arg="):
        current.append(line[4:])
assert blocks == [
    ["--db", store, "--json", "config", "get", "issue_prefix"],
    ["--db", store, "--json", "config", "get", "issue_prefix"],
    ["--db", store, "--json", "config", "get", "issue_prefix"],
    ["--db", store, "rename-prefix", prefix],
    ["--db", store, "export", "-o", f"{store}/issues.jsonl"],
], blocks
PY
}

assert_hub_prefix_calls() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys

path, store, target = sys.argv[1:]
blocks, current = [], None
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if line == "BEGIN_BD":
        current = []
    elif line == "END_BD" and current is not None:
        blocks.append(current)
        current = None
    elif current is not None and line.startswith("arg="):
        current.append(line[4:])
assert blocks == [
    ["--db", store, "--json", "config", "get", "issue_prefix"],
    ["--db", store, "--json", "config", "get", "issue_prefix"],
    ["--db", store, "--json", "config", "get", "issue_prefix"],
    ["--db", store, "rename-prefix", target],
    ["--db", store, "export", "-o", f"{store}/issues.jsonl"],
], blocks
PY
}

assert_prefix_reads_only() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys

path, store, count = sys.argv[1:]
expected = ["--db", store, "--json", "config", "get", "issue_prefix"]
blocks, current = [], None
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if line == "BEGIN_BD":
        current = []
    elif line == "END_BD" and current is not None:
        blocks.append(current)
        current = None
    elif current is not None and line.startswith("arg="):
        current.append(line[4:])
assert blocks == [expected] * int(count), blocks
PY
}

assert_hub_prefix_detection_only() {
  python3 - "$1" "$2" <<'PY'
import sys

path, store = sys.argv[1:]
blocks, current = [], None
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if line == "BEGIN_BD":
        current = []
    elif line == "END_BD" and current is not None:
        blocks.append(current)
        current = None
    elif current is not None and line.startswith("arg="):
        current.append(line[4:])
assert blocks == [["--db", store, "--json", "config", "get", "issue_prefix"]], blocks
PY
}

setup_hub_prefix_fixture() {
  local fixture_home=$1 prefix=$2
  local parent=$fixture_home/.local/share/beads/hub
  local store=$parent/.beads
  local config=$fixture_home/.config/bv/hub.yaml
  mkdir -p "$store/nested" "${config%/*}" "$fixture_home/project/.beads"
  printf '%s\n' "$prefix" >"$fixture_home/current-prefix"
  printf '%s\n' complete >"$store/nested/payload"
  printf '%s\n' project-local >"$fixture_home/project/.beads/sentinel"
  printf '{"id":"%s-1gj","title":"Current export"}\n' "$prefix" >"$store/issues.jsonl"
  printf '{"issue_id":"%s-1gj","nested":{"issue_id":"%s-8au"},"text":"mention %s-8au"}\n' \
    "$prefix" "$prefix" "$prefix" >"$store/interactions.jsonl"
  printf '%s-1gj\n' "$prefix" >"$store/last-touched"
  printf '{"bead_id":"%s-1gj","nested":{"bead_id":"%s-8au"},"text":"mention %s-8au"}\n' \
    "$prefix" "$prefix" "$prefix" >"$parent/correlations.jsonl"
  cat >"$config" <<EOF
{"version":1,"store":"$store","ledger":"$parent/correlations.jsonl","repositories":{"ctx:repo-1234567890":{"path":"$repo_a"}}}
EOF
}

# Bootstrap creates the hub with the default bead prefix.
bootstrap_home=$case_root/bootstrap-home
bootstrap_store=$bootstrap_home/.local/share/beads/hub/.beads
bootstrap_config=$bootstrap_home/.config/bv/hub.yaml
mkdir -p "$bootstrap_home"
HOME=$bootstrap_home FAKE_LOG=$case_root/bootstrap.log bash "$wbd" bootstrap
test -d "$bootstrap_store"
jq -e --arg store "$bootstrap_store" \
  '.version == 1 and .store == $store and .repositories == {}' "$bootstrap_config" >/dev/null
test "$(grep -Fc BEGIN_BD "$case_root/bootstrap.log")" -eq 5
grep -Fq 'arg=metrics' "$case_root/bootstrap.log"
grep -Fq 'arg=--skip-hooks' "$case_root/bootstrap.log"
grep -Fq 'arg=--skip-agents' "$case_root/bootstrap.log"
grep -Fq 'arg=bead' "$case_root/bootstrap.log"

# A caller may select another valid prefix.
custom_home=$case_root/bootstrap-custom-home
custom_store=$custom_home/.local/share/beads/hub/.beads
mkdir -p "$custom_home"
HOME=$custom_home FAKE_LOG=$case_root/bootstrap-custom.log bash "$wbd" bootstrap --prefix custom-prefix
test -d "$custom_store"
grep -Fq 'arg=custom-prefix' "$case_root/bootstrap-custom.log"

# Invalid prefixes are rejected before creating paths or invoking bd.
for prefix in '' Work work_1 1work work- work--item 'work space' 'abcdefghijklmnopqrstuvwxyzabcdefg'; do
  invalid_home=$case_root/bootstrap-invalid-${prefix//[^a-zA-Z0-9]/x}
  invalid_log=$invalid_home.log
  mkdir -p "$invalid_home"
  : >"$invalid_log"
  if HOME=$invalid_home FAKE_LOG=$invalid_log bash "$wbd" bootstrap --prefix "$prefix" \
    >"$invalid_home.out" 2>&1; then
    fail "bootstrap accepted invalid prefix: $prefix"
  fi
  test ! -s "$invalid_log"
  test ! -e "$invalid_home/.local/share/beads/hub"
  test ! -e "$invalid_home/.config/bv/hub.yaml"
done

for invocation in '--prefix' '--prefix bead extra' '--prefix bead --prefix other' '--prefix=bead' '--unknown bead'; do
  invalid_home=$case_root/bootstrap-invalid-syntax-${invocation//[^a-zA-Z0-9]/x}
  invalid_log=$invalid_home.log
  mkdir -p "$invalid_home"
  : >"$invalid_log"
  read -r -a args <<<"$invocation"
  if HOME=$invalid_home FAKE_LOG=$invalid_log bash "$wbd" bootstrap "${args[@]}" \
    >"$invalid_home.out" 2>&1; then
    fail "bootstrap accepted invalid syntax: $invocation"
  fi
  test ! -s "$invalid_log"
  test ! -e "$invalid_home/.local/share/beads/hub"
  test ! -e "$invalid_home/.config/bv/hub.yaml"
done

# Bootstrap failures propagate and remove only the partially created store.
failure_home=$case_root/bootstrap-failure-home
failure_store=$failure_home/.local/share/beads/hub/.beads
failure_parent=${failure_store%/.beads}
mkdir -p "$failure_parent"
printf '%s\n' keep >"$failure_parent/sentinel"
if HOME=$failure_home FAKE_LOG=$case_root/bootstrap-failure.log \
  FAKE_CONFIG_FAIL_KEY=export.git-add bash "$wbd" bootstrap; then
  fail 'bootstrap accepted a configuration failure'
else
  test "$?" -eq 43
fi
test ! -e "$failure_store"
grep -Fxq keep "$failure_parent/sentinel"
! grep -Fq 'arg=dolt.auto-push' "$case_root/bootstrap-failure.log" || fail 'bootstrap continued after failure'

# Metrics failure stops before init and preserves the store parent.
metrics_home=$case_root/bootstrap-metrics-home
metrics_store=$metrics_home/.local/share/beads/hub/.beads
metrics_parent=${metrics_store%/.beads}
metrics_log=$case_root/bootstrap-metrics.log
mkdir -p "$metrics_parent"
printf '%s\n' keep >"$metrics_parent/sentinel"
if HOME=$metrics_home FAKE_LOG=$metrics_log FAKE_METRICS_FAIL=1 bash "$wbd" bootstrap; then
  fail 'bootstrap accepted a metrics failure'
else
  test "$?" -eq 44
fi
test ! -e "$metrics_store"
grep -Fxq keep "$metrics_parent/sentinel"
test "$(grep -Fc BEGIN_BD "$metrics_log")" -eq 1
grep -Fq 'arg=metrics' "$metrics_log"
! grep -Fq 'arg=init' "$metrics_log" || fail 'bootstrap initialized after metrics failure'
! grep -Fq 'arg=export.auto' "$metrics_log" || fail 'bootstrap configured after metrics failure'

# Init failure stops before config writes and preserves the store parent.
init_home=$case_root/bootstrap-init-home
init_store=$init_home/.local/share/beads/hub/.beads
init_parent=${init_store%/.beads}
init_log=$case_root/bootstrap-init.log
mkdir -p "$init_parent"
printf '%s\n' keep >"$init_parent/sentinel"
if HOME=$init_home FAKE_LOG=$init_log FAKE_INIT_EXIT=45 bash "$wbd" bootstrap; then
  fail 'bootstrap accepted an init failure'
else
  test "$?" -eq 45
fi
test ! -e "$init_store"
grep -Fxq keep "$init_parent/sentinel"
test "$(grep -Fc BEGIN_BD "$init_log")" -eq 2
grep -Fq 'arg=metrics' "$init_log"
grep -Fq 'arg=init' "$init_log"
! grep -Fq 'arg=export.auto' "$init_log" || fail 'bootstrap configured after init failure'

# Configure is idempotent and creates JSON-valid YAML with private permissions.
config_path=$(bash "$wbd" configure)
test "$config_path" = "$hub_config"
assert_config
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$hub_config"
cp "$hub_config" "$case_root/config.before"
bash "$wbd" configure >/dev/null
cmp -s "$case_root/config.before" "$hub_config"
chmod 0644 "$hub_config"
bash "$wbd" configure >/dev/null
cmp -s "$case_root/config.before" "$hub_config"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$hub_config"

# Equivalent origins have one stable context.
context_ssh=$(FAKE_ORIGIN=git@Example.COM:Group/Repo-A.git bash "$wbd" context)
context_scp=$(FAKE_ORIGIN=Example.COM:Group/Repo-A.git bash "$wbd" context)
context_https=$(FAKE_ORIGIN=https://example.com/Group/Repo-A.git/ bash "$wbd" context)
test "$context_ssh" = "$context_scp"
test "$context_ssh" = "$context_https"
case "$context_ssh" in
  ctx:repo-a-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) fail "unexpected context: $context_ssh" ;;
esac

# Registration is deterministic regardless of insertion order.
origin_a=git@example.com:Group/Repo-A.git
origin_b=https://example.com/Group/Repo-B.git
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" register >"$case_root/register-a.out"
context_a=$(cut -f1 "$case_root/register-a.out")
FAKE_ORIGIN=$origin_b FAKE_GIT_ROOT=$repo_b bash "$wbd" register >"$case_root/register-b.out"
context_b=$(cut -f1 "$case_root/register-b.out")
jq -e --arg a "$context_a" --arg ap "$repo_a" --arg b "$context_b" --arg bp "$repo_b" \
  '.repositories == {($a): {path: $ap}, ($b): {path: $bp}}' "$hub_config" >/dev/null
cp "$hub_config" "$case_root/config-a-then-b"
jq '.repositories = {}' "$hub_config" >"$case_root/empty-config"
mv "$case_root/empty-config" "$hub_config"
FAKE_ORIGIN=$origin_b FAKE_GIT_ROOT=$repo_b bash "$wbd" register >/dev/null
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" register >/dev/null
cmp -s "$case_root/config-a-then-b" "$hub_config" || fail 'registration order changed serialized config'

# Failed context discovery neither registers nor rewrites the config.
cp "$hub_config" "$case_root/config-before-missing-origin"
if FAKE_ORIGIN_MISSING=1 bash "$wbd" register >"$case_root/missing-origin.out" 2>&1; then
  fail 'register accepted a repository without origin'
fi
cmp -s "$case_root/config-before-missing-origin" "$hub_config"

# Create and scoped list register the checkout before forwarding to bd.
jq '.repositories = {}' "$hub_config" >"$case_root/empty-config"
mv "$case_root/empty-config" "$hub_config"
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" create 'Quoted task' --labels 'urgent,customer request' --json
assert_last_args BD --db "$store" --json create --labels "$context_a" 'Quoted task' --labels 'urgent,customer request'
jq -e --arg context "$context_a" --arg path "$repo_a" '.repositories[$context].path == $path' "$hub_config" >/dev/null

jq '.repositories = {}' "$hub_config" >"$case_root/empty-config"
mv "$case_root/empty-config" "$hub_config"
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" --json list --status open
assert_last_args BD --db "$store" --json list --label "$context_a" --status open
jq -e --arg context "$context_a" '.repositories | has($context)' "$hub_config" >/dev/null

# Global list does not require or register a repository.
: >"$FAKE_LOG"
FAKE_GIT_FAIL=1 bash "$wbd" list --all-contexts --json
assert_last_args BD --db "$store" --json list

# Every documented CRUD/query family is normalized through the positive parser.
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" new 'New task' \
  --description 'Details' --type task --priority P1 --labels urgent --json
assert_last_args BD --db "$store" --json new --labels "$context_a" 'New task' \
  --description Details --type task --priority P1 --labels urgent

: >"$FAKE_LOG"
bash "$wbd" show work-123 --json
assert_last_args BD --db "$store" --json show work-123

: >"$FAKE_LOG"
bash "$wbd" update work-123 --title 'Updated task' --description 'New details' \
  --type bug --priority 0 --status blocked --add-label urgent --json
assert_last_args BD --db "$store" --json update work-123 \
  --title 'Updated task' --description 'New details' --type bug --priority 0 \
  --status blocked --add-label urgent

: >"$FAKE_LOG"
bash "$wbd" dep add work-123 work-456 --type discovered-from --json
assert_last_args BD --db "$store" --json dep add work-123 work-456 --type discovered-from

: >"$FAKE_LOG"
bash "$wbd" dep remove work-123 work-456 --json
assert_last_args BD --db "$store" --json dep remove work-123 work-456

: >"$FAKE_LOG"
bash "$wbd" close work-123 --reason verified --json
assert_last_args BD --db "$store" --json close work-123 --reason verified

: >"$FAKE_LOG"
bash "$wbd" reopen work-123 --reason regressed --json
assert_last_args BD --db "$store" --json reopen work-123 --reason regressed

: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" list --ready \
  --status open,in_progress --type task --priority 2 --label urgent --limit 25 --json
assert_last_args BD --db "$store" --json list --label "$context_a" --ready \
  --status open,in_progress --type task --priority 2 --label urgent --limit 25

# Link registers and forwards the exact correlate CLI, leaving ref resolution to bv.
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" link work-123
assert_last_args BV correlate add --bead work-123 --repo "$context_a" --commit HEAD --hub-config "$hub_config"
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" link work-123 refs/tags/release-1
assert_last_args BV correlate add --bead work-123 --repo "$context_a" --commit refs/tags/release-1 --hub-config "$hub_config"
if FAKE_BV_EXIT=38 FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" link work-123; then
  fail 'link accepted a bv failure'
else
  test "$?" -eq 38
fi

# Unknown options, implicit IDs, context-label tampering, and unsafe globals
# are rejected before either wrapped tool or private config is touched.
for invocation in \
  'create' \
  'create one two' \
  'create task --body-file /tmp/input' \
  'create task --metadata @private.json' \
  'create task --labels ctx:other' \
  'create task --json=true' \
  'list unexpected' \
  'list --status open --status closed' \
  'list --status custom' \
  'list --label' \
  'show' \
  'show work-1 work-2' \
  'show --current' \
  'update' \
  'update work-1' \
  'update work-1 --json' \
  'update work-1 --status closed' \
  'update work-1 --set-labels urgent' \
  'update work-1 --remove-label obsolete' \
  'update work-1 --add-label ctx:other' \
  'update work-1 --body-file /tmp/input' \
  'dep' \
  'dep list work-1' \
  'dep add work-1' \
  'dep add work-1 work-2 extra' \
  'dep add work-1 --blocked-by work-2' \
  'dep add --file /tmp/deps' \
  'dep add work-1 work-2 --no-cycle-check' \
  'dep remove work-1' \
  'dep remove work-1 work-2 --type blocks' \
  'close' \
  'close work-1 work-2' \
  'close work-1 --reason-file /tmp/reason' \
  'close work-1 --force' \
  'reopen' \
  'reopen work-1 work-2' \
  'link' \
  'link work-1 HEAD extra' \
  'link work-1 --json' \
  '--actor someone show work-1' \
  '--readonly list' \
  '-json list'; do
  : >"$FAKE_LOG"
  cp "$hub_config" "$case_root/config-before-rejection"
  read -r -a args <<<"$invocation"
  if bash "$wbd" "${args[@]}" >"$case_root/strict-rejected.out" 2>&1; then
    fail "wbd allowed unsupported invocation: $invocation"
  fi
  test ! -s "$FAKE_LOG"
  cmp -s "$case_root/config-before-rejection" "$hub_config"
done
: >"$FAKE_LOG"
if bash "$wbd" create task --labels 'urgent, ctx:other' >"$case_root/context-label-rejected.out" 2>&1; then
  fail 'wbd allowed a whitespace-prefixed context label'
fi
test ! -s "$FAKE_LOG"
for invocation in \
  'create task --labels "ctx:other"' \
  'update work-1 --add-label "ctx:other"'; do
  : >"$FAKE_LOG"
  read -r -a args <<<"$invocation"
  if bash "$wbd" "${args[@]}" >"$case_root/quoted-context-label-rejected.out" 2>&1; then
    fail "wbd allowed a CSV-quoted context label: $invocation"
  fi
  test ! -s "$FAKE_LOG"
done

# Stale routing variables are removed for both wrapped tools.
: >"$FAKE_LOG"
BEADS_DB=x BD_DB=x BD_GLOBAL=x BEADS_DOLT_DATA_DIR=x BEADS_DOLT_PORT=x \
  BEADS_DOLT_PROXIED_SERVER=x BEADS_DOLT_SERVER_DATABASE=x BEADS_DOLT_SERVER_HOST=x \
  BEADS_DOLT_SERVER_MODE=x BEADS_DOLT_SERVER_PORT=x BEADS_DOLT_SERVER_SOCKET=x \
  BEADS_DOLT_SHARED_SERVER=x bash "$wbd" show work-123 --json
assert_last_args BD --db "$store" --json show work-123
for variable in BEADS_DB BD_DB BD_GLOBAL BEADS_DOLT_DATA_DIR BEADS_DOLT_PORT BEADS_DOLT_PROXIED_SERVER BEADS_DOLT_SERVER_DATABASE BEADS_DOLT_SERVER_HOST BEADS_DOLT_SERVER_MODE BEADS_DOLT_SERVER_PORT BEADS_DOLT_SERVER_SOCKET BEADS_DOLT_SHARED_SERVER; do
  grep -Fxq "${variable}_SET=" "$FAKE_LOG"
done
if FAKE_BD_EXIT=37 bash "$wbd" show work-123; then
  fail 'wbd accepted a bd failure'
else
  test "$?" -eq 37
fi

# A missing global store fails with bootstrap guidance before dispatch.
mv "$store" "$case_root/store-away"
: >"$FAKE_LOG"
if bash "$wbd" list --all-contexts >"$case_root/missing-store.out" 2>&1; then
  fail 'wbd accepted a missing global store'
fi
grep -Fq "run 'wbd bootstrap'" "$case_root/missing-store.out"
test ! -s "$FAKE_LOG"
mv "$case_root/store-away" "$store"

# Required command checks fail before dispatch.
no_bd=$case_root/no-bd
mkdir -p "$no_bd"
cp "$fake_bin/git" "$fake_bin/bv" "$fake_bin/jq" "$no_bd/"
: >"$FAKE_LOG"
if PATH=$no_bd:/usr/bin:/bin /bin/bash "$wbd" show work-123 >"$case_root/missing-bd.out" 2>&1; then
  fail 'wbd accepted a missing bd command'
fi
grep -Fq 'required command not found: bd' "$case_root/missing-bd.out"
test ! -s "$FAKE_LOG"

no_bv_link=$case_root/no-bv-link
mkdir -p "$no_bv_link"
cp "$fake_bin/git" "$fake_bin/bd" "$fake_bin/jq" "$no_bv_link/"
: >"$FAKE_LOG"
if PATH=$no_bv_link:/usr/bin:/bin /bin/bash "$wbd" link work-123 >"$case_root/missing-link-bv.out" 2>&1; then
  fail 'wbd link accepted a missing bv command'
fi
grep -Fq 'required command not found: bv' "$case_root/missing-link-bv.out"
test ! -s "$FAKE_LOG"

# Malformed and symlinked configs are rejected without replacement.
cp "$hub_config" "$case_root/valid-config"
printf '%s\n' '{"version":1,"repositories":[]}' >"$hub_config"
cp "$hub_config" "$case_root/malformed-before"
if bash "$wbd" configure >"$case_root/malformed.out" 2>&1; then
  fail 'configure accepted malformed config'
fi
cmp -s "$case_root/malformed-before" "$hub_config"
rm "$hub_config"
ln -s "$case_root/valid-config" "$hub_config"
if bash "$wbd" configure >"$case_root/symlink.out" 2>&1; then
  fail 'configure accepted a symlink config'
fi
test -L "$hub_config"
rm "$hub_config"
cp "$case_root/valid-config" "$hub_config"

# Direct init remains blocked, including after a leading global flag.
: >"$FAKE_LOG"
if bash "$wbd" init >"$case_root/direct-init.out" 2>&1; then
  fail 'wbd allowed direct init'
fi
grep -Fq "run 'wbd bootstrap'" "$case_root/direct-init.out"
test ! -s "$FAKE_LOG"
if bash "$wbd" --json init >"$case_root/leading-init.out" 2>&1; then
  fail 'wbd allowed direct init after a leading global flag'
fi
grep -Fq "run 'wbd bootstrap'" "$case_root/leading-init.out"
test ! -s "$FAKE_LOG"

# Every database, directory, and create-routing override form remains blocked.
for invocation in \
  '--db /tmp/other list' \
  '--db=/tmp/other list' \
  '--database /tmp/other list' \
  '--database=/tmp/other list' \
  '--global list' \
  '--global=true list' \
  '-C /tmp list' \
  '-C/tmp list' \
  '--directory /tmp list' \
  '--directory=/tmp list' \
  'create task --repo elsewhere' \
  'create task --repo=elsewhere'; do
  : >"$FAKE_LOG"
  read -r -a args <<<"$invocation"
  if bash "$wbd" "${args[@]}" >"$case_root/rejected.out" 2>&1; then
    fail "wbd allowed routing override: $invocation"
  fi
  test ! -s "$FAKE_LOG"
done

# Unsupported and missing commands never dispatch to bd or bv.
for command in config setup hooks doctor sync admin repo worktree edit import export; do
  : >"$FAKE_LOG"
  if bash "$wbd" "$command" >"$case_root/unsupported.out" 2>&1; then
    fail "wbd allowed unsupported command: $command"
  fi
  grep -Fq 'supported commands:' "$case_root/unsupported.out"
  test ! -s "$FAKE_LOG"
done
: >"$FAKE_LOG"
if bash "$wbd" >"$case_root/missing-command.out" 2>&1; then
  fail 'wbd allowed a missing command'
fi
grep -Fq 'supported commands:' "$case_root/missing-command.out"
test ! -s "$FAKE_LOG"

# Bare wbv is human-only and requires a real input/output TTY.
viewer_cwd=$case_root/viewer-cwd
mkdir -p "$viewer_cwd"
rm -f "$hub_config"
: >"$FAKE_LOG"
if bash "$wbv" >"$case_root/viewer-nontty.out" 2>&1; then
  fail 'wbv allowed a bare non-interactive invocation'
fi
grep -Fq 'requires an interactive terminal' "$case_root/viewer-nontty.out"
test ! -s "$FAKE_LOG"
test ! -e "$hub_config"

(cd "$viewer_cwd" && \
  BEADS_DB=x BD_DB=x BD_GLOBAL=x BEADS_DOLT_DATA_DIR=x BEADS_DOLT_PORT=x \
  BEADS_DOLT_PROXIED_SERVER=x BEADS_DOLT_SERVER_DATABASE=x BEADS_DOLT_SERVER_HOST=x \
  BEADS_DOLT_SERVER_MODE=x BEADS_DOLT_SERVER_PORT=x BEADS_DOLT_SERVER_SOCKET=x \
  BEADS_DOLT_SHARED_SERVER=x python3 - "$wbv" <<'PY'
import os
import pty
import subprocess
import sys

master, slave = pty.openpty()
try:
    result = subprocess.run(
        ["/bin/bash", sys.argv[1]],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=os.environ,
        check=False,
    )
finally:
    os.close(slave)
    os.close(master)
if result.returncode != 0:
    raise SystemExit(result.returncode)
PY
)
assert_config
assert_last_args BV --history-mode external --hub-config "$hub_config"
grep -Fxq "PWD=$viewer_cwd" "$FAKE_LOG"
grep -Fxq 'BV_NO_GITIGNORE=1' "$FAKE_LOG"
grep -Fxq 'BV_NO_CACHE=1' "$FAKE_LOG"
! grep -Fq BEGIN_BD "$FAKE_LOG" || fail 'wbv manually invoked bd/export'
for variable in BEADS_DB BD_DB BD_GLOBAL BEADS_DOLT_DATA_DIR BEADS_DOLT_PORT BEADS_DOLT_PROXIED_SERVER BEADS_DOLT_SERVER_DATABASE BEADS_DOLT_SERVER_HOST BEADS_DOLT_SERVER_MODE BEADS_DOLT_SERVER_PORT BEADS_DOLT_SERVER_SOCKET BEADS_DOLT_SHARED_SERVER; do
  grep -Fxq "${variable}_SET=" "$FAKE_LOG"
done

# Every approved robot primary is forwarded with deterministic JSON.
assert_robot() {
  : >"$FAKE_LOG"
  BV_OUTPUT_FORMAT=toon TOON_DEFAULT_FORMAT=toon TOON_STATS=1 BV_PRETTY_JSON=1 \
    bash "$wbv" "$@"
  assert_last_args BV --history-mode external --hub-config "$hub_config" "$@" --format json
  grep -Fxq 'BV_OUTPUT_FORMAT_SET=' "$FAKE_LOG"
  grep -Fxq 'TOON_DEFAULT_FORMAT_SET=' "$FAKE_LOG"
  grep -Fxq 'TOON_STATS_SET=' "$FAKE_LOG"
  grep -Fxq 'BV_PRETTY_JSON_SET=' "$FAKE_LOG"
}

assert_robot --robot-plan --label "$context_a"
assert_robot --robot-priority --label backend --robot-min-confidence 0.5 \
  --robot-max-results 20 --robot-by-label urgent --robot-by-assignee agent
assert_robot --robot-insights --label "$context_a"
assert_robot --robot-graph --graph-format mermaid \
  --graph-root work-123 --graph-depth 3
assert_robot --robot-label-health
assert_robot --robot-label-flow
assert_robot --robot-label-attention --attention-limit 5
assert_robot --robot-blocker-chain work-123
assert_robot --robot-sprint-list
assert_robot --robot-sprint-show sprint-1
assert_robot --robot-forecast all --forecast-label backend --forecast-sprint sprint-1 \
  --forecast-agents 4
assert_robot --robot-capacity --agents 4 --capacity-label backend
assert_robot --robot-triage --brief --robot-not-ready-labels waiting

if FAKE_BV_EXIT=39 bash "$wbv" --robot-plan >"$case_root/viewer-failure.out" 2>&1; then
  fail 'wbv accepted a bv failure'
else
  test "$?" -eq 39
fi

# The standalone fixed-Hub migration detects the persisted prefix and a blank
# selection is a true no-op with no backup or runtime mutation.
hub_prefix_script=$source_dir/scripts/migrate-beads-hub-prefix.sh
hub_noop_home=$case_root/hub-prefix-noop-home
hub_noop_store=$hub_noop_home/.local/share/beads/hub/.beads
setup_hub_prefix_fixture "$hub_noop_home" bead
cp "$hub_noop_store/last-touched" "$case_root/hub-prefix-noop.before"
: >"$case_root/hub-prefix-noop.log"
printf '\n' | HOME=$hub_noop_home FAKE_LOG=$case_root/hub-prefix-noop.log \
  FAKE_MIGRATION_HOME=$hub_noop_home PATH=$fake_bin:/usr/bin:/bin \
  bash "$hub_prefix_script" >"$case_root/hub-prefix-noop.out" 2>"$case_root/hub-prefix-noop.err"
assert_hub_prefix_detection_only "$case_root/hub-prefix-noop.log" "$hub_noop_store"
grep -Fq 'Hub prefix is already bead; no changes made.' "$case_root/hub-prefix-noop.out"
grep -Fq 'You can change this prefix later by running migrate-beads-hub-prefix.sh.' "$case_root/hub-prefix-noop.err"
cmp -s "$case_root/hub-prefix-noop.before" "$hub_noop_store/last-touched"
hub_noop_backups=("$hub_noop_home"/.local/share/beads/hub-prefix-backup-*)
test "${hub_noop_backups[0]}" = "$hub_noop_home/.local/share/beads/hub-prefix-backup-*"

# Invalid selections retry, then every current top-level runtime ID follows a
# custom prefix while nested and prose references remain unchanged.
hub_custom_home=$case_root/hub-prefix-custom-home
hub_custom_parent=$hub_custom_home/.local/share/beads/hub
hub_custom_store=$hub_custom_parent/.beads
hub_custom_config=$hub_custom_home/.config/bv/hub.yaml
setup_hub_prefix_fixture "$hub_custom_home" bead
cp "$hub_custom_config" "$case_root/hub-prefix-config.before"
: >"$case_root/hub-prefix-custom.log"
printf '%s\n' Work work_1 1work work- work--item 'work space' \
  abcdefghijklmnopqrstuvwxyzabcdefg team-core | \
  HOME=$hub_custom_home FAKE_LOG=$case_root/hub-prefix-custom.log \
  FAKE_MIGRATION_HOME=$hub_custom_home \
  BEADS_DB=x BD_DB=x BD_GLOBAL=x BEADS_DOLT_DATA_DIR=x BEADS_DOLT_PORT=x \
  BEADS_DOLT_PROXIED_SERVER=x BEADS_DOLT_SERVER_DATABASE=x BEADS_DOLT_SERVER_HOST=x \
  BEADS_DOLT_SERVER_MODE=x BEADS_DOLT_SERVER_PORT=x BEADS_DOLT_SERVER_SOCKET=x \
  BEADS_DOLT_SHARED_SERVER=x PATH=$fake_bin:/usr/bin:/bin \
  bash "$hub_prefix_script" >"$case_root/hub-prefix-custom.out" 2>"$case_root/hub-prefix-custom.err"
test "$(grep -Fc 'Invalid prefix:' "$case_root/hub-prefix-custom.err")" -eq 7
grep -Fq 'You can change this prefix later by running migrate-beads-hub-prefix.sh.' "$case_root/hub-prefix-custom.err"
assert_hub_prefix_calls "$case_root/hub-prefix-custom.log" "$hub_custom_store" team-core
grep -Fxq '{"id":"team-core-1gj","title":"Renamed export"}' "$hub_custom_store/issues.jsonl"
grep -Fxq '{"id":"team-core-8au","title":"Second renamed export"}' "$hub_custom_store/issues.jsonl"
grep -Fxq '{"issue_id":"team-core-1gj","nested":{"issue_id":"bead-8au"},"text":"mention bead-8au"}' "$hub_custom_store/interactions.jsonl"
grep -Fxq '{"bead_id":"team-core-1gj","nested":{"bead_id":"bead-8au"},"text":"mention bead-8au"}' "$hub_custom_parent/correlations.jsonl"
grep -Fxq team-core-1gj "$hub_custom_store/last-touched"
grep -Fxq project-local "$hub_custom_home/project/.beads/sentinel"
cmp -s "$case_root/hub-prefix-config.before" "$hub_custom_config"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$hub_custom_parent/correlations.jsonl"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$hub_custom_store/interactions.jsonl"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$hub_custom_store/last-touched"
jq -e '(.bead_id | startswith("bead-") | not)' "$hub_custom_parent/correlations.jsonl" >/dev/null
jq -e '(.issue_id | startswith("bead-") | not)' "$hub_custom_store/interactions.jsonl" >/dev/null
for variable in BEADS_DB BD_DB BD_GLOBAL BEADS_DOLT_DATA_DIR BEADS_DOLT_PORT BEADS_DOLT_PROXIED_SERVER BEADS_DOLT_SERVER_DATABASE BEADS_DOLT_SERVER_HOST BEADS_DOLT_SERVER_MODE BEADS_DOLT_SERVER_PORT BEADS_DOLT_SERVER_SOCKET BEADS_DOLT_SHARED_SERVER; do
  grep -Fxq "${variable}_SET=" "$case_root/hub-prefix-custom.log"
done
! grep -Eq '_SET=.+' "$case_root/hub-prefix-custom.log"
grep -Fq 'Run migrate-beads-hub-prefix.sh again to change the Hub prefix later.' "$case_root/hub-prefix-custom.out"
hub_custom_backups=("$hub_custom_home"/.local/share/beads/hub-prefix-backup-*)
test "${#hub_custom_backups[@]}" -eq 1
grep -Fxq bead-1gj "${hub_custom_backups[0]}/hub/.beads/last-touched"
cmp -s "$case_root/hub-prefix-config.before" "${hub_custom_backups[0]}/hub.yaml"
test -f "${hub_custom_backups[0]}/hub/.beads/nested/payload"

# A second invocation detects a hyphenated current prefix and creates a
# collision-safe second backup before applying another rename.
: >"$case_root/hub-prefix-repeat.log"
printf '%s\n' final-prefix | HOME=$hub_custom_home FAKE_LOG=$case_root/hub-prefix-repeat.log \
  FAKE_MIGRATION_HOME=$hub_custom_home PATH=$fake_bin:/usr/bin:/bin \
  bash "$hub_prefix_script" >"$case_root/hub-prefix-repeat.out" 2>"$case_root/hub-prefix-repeat.err"
assert_hub_prefix_calls "$case_root/hub-prefix-repeat.log" "$hub_custom_store" final-prefix
grep -Fxq final-prefix-1gj "$hub_custom_store/last-touched"
grep -Fxq '{"issue_id":"final-prefix-1gj","nested":{"issue_id":"bead-8au"},"text":"mention bead-8au"}' "$hub_custom_store/interactions.jsonl"
grep -Fxq '{"bead_id":"final-prefix-1gj","nested":{"bead_id":"bead-8au"},"text":"mention bead-8au"}' "$hub_custom_parent/correlations.jsonl"
hub_repeat_backups=("$hub_custom_home"/.local/share/beads/hub-prefix-backup-*)
test "${#hub_repeat_backups[@]}" -eq 2

# EOF and invalid fixed state fail before backup or mutation. Prefix detection
# is read-only and may be the sole bd call before an EOF failure.
hub_eof_home=$case_root/hub-prefix-eof-home
hub_eof_store=$hub_eof_home/.local/share/beads/hub/.beads
setup_hub_prefix_fixture "$hub_eof_home" bead
cp "$hub_eof_store/last-touched" "$case_root/hub-prefix-eof.before"
: >"$case_root/hub-prefix-eof.log"
if HOME=$hub_eof_home FAKE_LOG=$case_root/hub-prefix-eof.log FAKE_MIGRATION_HOME=$hub_eof_home \
  PATH=$fake_bin:/usr/bin:/bin bash "$hub_prefix_script" </dev/null \
  >"$case_root/hub-prefix-eof.out" 2>"$case_root/hub-prefix-eof.err"; then
  fail 'standalone Hub prefix migration accepted EOF'
fi
assert_hub_prefix_detection_only "$case_root/hub-prefix-eof.log" "$hub_eof_store"
grep -Fq 'end of input while reading target prefix' "$case_root/hub-prefix-eof.err"
cmp -s "$case_root/hub-prefix-eof.before" "$hub_eof_store/last-touched"
hub_eof_backups=("$hub_eof_home"/.local/share/beads/hub-prefix-backup-*)
test "${hub_eof_backups[0]}" = "$hub_eof_home/.local/share/beads/hub-prefix-backup-*"

# A source-prefix change at the engine's final check preserves the backed-up
# pre-migration state and never reaches native rename or export.
hub_engine_mismatch_home=$case_root/hub-prefix-engine-mismatch-home
hub_engine_mismatch_store=$hub_engine_mismatch_home/.local/share/beads/hub/.beads
setup_hub_prefix_fixture "$hub_engine_mismatch_home" bead
cp "$hub_engine_mismatch_store/last-touched" "$case_root/hub-prefix-engine-mismatch.before"
: >"$case_root/hub-prefix-engine-mismatch.log"
if printf '%s\n' task | HOME=$hub_engine_mismatch_home \
  FAKE_LOG=$case_root/hub-prefix-engine-mismatch.log \
  FAKE_MIGRATION_HOME=$hub_engine_mismatch_home \
  FAKE_PREFIX_CHANGE_AT=3 FAKE_CHANGED_PREFIX=other \
  PATH=$fake_bin:/usr/bin:/bin bash "$hub_prefix_script" \
  >"$case_root/hub-prefix-engine-mismatch.out" 2>"$case_root/hub-prefix-engine-mismatch.err"; then
  fail 'shared prefix engine accepted a changed persisted source prefix'
fi
assert_prefix_reads_only "$case_root/hub-prefix-engine-mismatch.log" "$hub_engine_mismatch_store" 3
cmp -s "$case_root/hub-prefix-engine-mismatch.before" "$hub_engine_mismatch_store/last-touched"
grep -Fxq bead "$hub_engine_mismatch_home/current-prefix"
test ! -e "$hub_engine_mismatch_home/rename-complete"
hub_engine_mismatch_backups=("$hub_engine_mismatch_home"/.local/share/beads/hub-prefix-backup-*)
test "${#hub_engine_mismatch_backups[@]}" -eq 1
grep -Fxq bead-1gj "${hub_engine_mismatch_backups[0]}/hub/.beads/last-touched"

hub_missing_home=$case_root/hub-prefix-missing-home
mkdir -p "$hub_missing_home"
: >"$case_root/hub-prefix-missing.log"
if HOME=$hub_missing_home FAKE_LOG=$case_root/hub-prefix-missing.log FAKE_MIGRATION_HOME=$hub_missing_home \
  PATH=$fake_bin:/usr/bin:/bin bash "$hub_prefix_script" </dev/null \
  >"$case_root/hub-prefix-missing.out" 2>&1; then
  fail 'standalone Hub prefix migration accepted a missing store'
fi
test ! -s "$case_root/hub-prefix-missing.log"

hub_invalid_home=$case_root/hub-prefix-invalid-home
setup_hub_prefix_fixture "$hub_invalid_home" bead
printf '%s\n' '{"version":1,"repositories":{}}' >"$hub_invalid_home/.config/bv/hub.yaml"
: >"$case_root/hub-prefix-invalid.log"
if HOME=$hub_invalid_home FAKE_LOG=$case_root/hub-prefix-invalid.log FAKE_MIGRATION_HOME=$hub_invalid_home \
  PATH=$fake_bin:/usr/bin:/bin bash "$hub_prefix_script" </dev/null \
  >"$case_root/hub-prefix-invalid.out" 2>&1; then
  fail 'standalone Hub prefix migration accepted an invalid config'
fi
test ! -s "$case_root/hub-prefix-invalid.log"

hub_bad_prefix_home=$case_root/hub-prefix-bad-detection-home
hub_bad_prefix_store=$hub_bad_prefix_home/.local/share/beads/hub/.beads
setup_hub_prefix_fixture "$hub_bad_prefix_home" bead
printf '%s\n' Bad_Prefix >"$hub_bad_prefix_home/current-prefix"
: >"$case_root/hub-prefix-bad-detection.log"
if HOME=$hub_bad_prefix_home FAKE_LOG=$case_root/hub-prefix-bad-detection.log \
  FAKE_MIGRATION_HOME=$hub_bad_prefix_home PATH=$fake_bin:/usr/bin:/bin \
  bash "$hub_prefix_script" </dev/null >"$case_root/hub-prefix-bad-detection.out" 2>&1; then
  fail 'standalone Hub prefix migration accepted invalid persisted prefix output'
fi
assert_hub_prefix_detection_only "$case_root/hub-prefix-bad-detection.log" "$hub_bad_prefix_store"
hub_bad_prefix_backups=("$hub_bad_prefix_home"/.local/share/beads/hub-prefix-backup-*)
test "${hub_bad_prefix_backups[0]}" = "$hub_bad_prefix_home/.local/share/beads/hub-prefix-backup-*"

hub_bad_schema_home=$case_root/hub-prefix-bad-schema-home
hub_bad_schema_store=$hub_bad_schema_home/.local/share/beads/hub/.beads
setup_hub_prefix_fixture "$hub_bad_schema_home" bead
: >"$case_root/hub-prefix-bad-schema.log"
if HOME=$hub_bad_schema_home FAKE_LOG=$case_root/hub-prefix-bad-schema.log \
  FAKE_MIGRATION_HOME=$hub_bad_schema_home FAKE_SCHEMA_VERSION=2 \
  PATH=$fake_bin:/usr/bin:/bin bash "$hub_prefix_script" </dev/null \
  >"$case_root/hub-prefix-bad-schema.out" 2>&1; then
  fail 'standalone Hub prefix migration accepted an unsupported prefix schema'
fi
assert_hub_prefix_detection_only "$case_root/hub-prefix-bad-schema.log" "$hub_bad_schema_store"
hub_bad_schema_backups=("$hub_bad_schema_home"/.local/share/beads/hub-prefix-backup-*)
test "${hub_bad_schema_backups[0]}" = "$hub_bad_schema_home/.local/share/beads/hub-prefix-backup-*"

hub_symlink_home=$case_root/hub-prefix-symlink-home
setup_hub_prefix_fixture "$hub_symlink_home" bead
mv "$hub_symlink_home/.local/share/beads/hub/.beads/interactions.jsonl" "$case_root/hub-prefix-interactions-target"
ln -s "$case_root/hub-prefix-interactions-target" "$hub_symlink_home/.local/share/beads/hub/.beads/interactions.jsonl"
: >"$case_root/hub-prefix-symlink.log"
if HOME=$hub_symlink_home FAKE_LOG=$case_root/hub-prefix-symlink.log \
  FAKE_MIGRATION_HOME=$hub_symlink_home PATH=$fake_bin:/usr/bin:/bin \
  bash "$hub_prefix_script" </dev/null >"$case_root/hub-prefix-symlink.out" 2>&1; then
  fail 'standalone Hub prefix migration accepted a symlinked runtime file'
fi
test ! -s "$case_root/hub-prefix-symlink.log"

# The repository-only migration uses a synthetic home and fake bd. It backs up
# before renaming, narrowly rewrites top-level IDs, then moves the whole parent.
migration_home=$case_root/migration-home
migration_old_parent=$migration_home/.local/share/beads/work
migration_old_store=$migration_old_parent/.beads
migration_old_config=$migration_home/.config/bv/work-beads.yaml
migration_new_parent=$migration_home/.local/share/beads/hub
migration_new_store=$migration_new_parent/.beads
migration_new_config=$migration_home/.config/bv/hub.yaml
migration_log=$case_root/migration.log
mkdir -p "$migration_old_store/nested" "${migration_old_config%/*}"
printf '%s\n' work >"$migration_home/current-prefix"
printf '%s\n' 'complete parent payload' >"$migration_old_store/nested/payload"
printf '%s\n' 'parent sibling payload' >"$migration_old_parent/sibling"
printf '%s\n' '{"id":"work-1gj","title":"Stale export"}' >"$migration_old_store/issues.jsonl"
cat >"$migration_old_store/interactions.jsonl" <<'EOF'
{"issue_id":"work-1gj","kind":"view","nested":{"issue_id":"work-8au"},"text":"mention work-8au"}
{"issue_id":"other-1","kind":"view","nested":{"issue_id":"work-1gj"}}
EOF
printf '%s\n' work-1gj >"$migration_old_store/last-touched"
cat >"$migration_old_parent/correlations.jsonl" <<'EOF'
{"bead_id":"work-1","nested":{"bead_id":"work-2"},"text":"mention work-3"}
{"bead_id":"other-1","nested":{"bead_id":"work-4"},"text":"work-5"}
{"bead_id":"work-work-6","items":["work-7",{"bead_id":"work-8"}]}
EOF
cat >"$migration_old_config" <<EOF
{"version":1,"store":"$migration_old_store","ledger":"$migration_old_parent/correlations.jsonl","repositories":{"ctx:repo-1234567890":{"path":"$repo_a"}}}
EOF
cp "$migration_old_parent/correlations.jsonl" "$case_root/migration-ledger.before"
cp "$migration_old_config" "$case_root/migration-config.before"
: >"$migration_log"
printf '\n' | HOME=$migration_home FAKE_LOG=$migration_log FAKE_MIGRATION_HOME=$migration_home \
  BEADS_DB=x BD_DB=x BD_GLOBAL=x BEADS_DOLT_DATA_DIR=x BEADS_DOLT_PORT=x \
  BEADS_DOLT_PROXIED_SERVER=x BEADS_DOLT_SERVER_DATABASE=x BEADS_DOLT_SERVER_HOST=x \
  BEADS_DOLT_SERVER_MODE=x BEADS_DOLT_SERVER_PORT=x BEADS_DOLT_SERVER_SOCKET=x \
  BEADS_DOLT_SHARED_SERVER=x \
  PATH=$fake_bin:/usr/bin:/bin bash "$source_dir/scripts/migrate-beads-work-to-hub.sh" \
  >"$case_root/migration.out" 2>"$case_root/migration.err"
assert_migration_bd_calls "$migration_log" "$migration_old_store" bead
grep -Fq 'store-wide prefix for every Beads ID in the Hub' "$case_root/migration.err"
grep -Fq 'You can change this prefix later by running migrate-beads-hub-prefix.sh.' "$case_root/migration.err"
grep -Fq "Migrated work-* to bead-* in $migration_new_store" "$case_root/migration.out"
test "$(grep -Fc "BEADS_DIR=$migration_old_store" "$migration_log")" -eq 2
grep -Fxq MIGRATION_BACKUP_BEFORE_RENAME "$migration_log"
test -f "$migration_new_store/nested/payload"
test -f "$migration_new_parent/sibling"
test ! -e "$migration_old_parent"
test ! -e "$migration_old_config"
jq -e --arg store "$migration_new_store" --arg ledger "$migration_new_parent/correlations.jsonl" \
  --arg context ctx:repo-1234567890 --arg path "$repo_a" \
  '.store == $store and .ledger == $ledger and .repositories[$context].path == $path' \
  "$migration_new_config" >/dev/null
cat >"$case_root/migration-ledger.expected" <<'EOF'
{"bead_id":"bead-1","nested":{"bead_id":"work-2"},"text":"mention work-3"}
{"bead_id":"other-1","nested":{"bead_id":"work-4"},"text":"work-5"}
{"bead_id":"bead-work-6","items":["work-7",{"bead_id":"work-8"}]}
EOF
cmp -s "$case_root/migration-ledger.expected" "$migration_new_parent/correlations.jsonl"
cat >"$case_root/migration-interactions.expected" <<'EOF'
{"issue_id":"bead-1gj","kind":"view","nested":{"issue_id":"work-8au"},"text":"mention work-8au"}
{"issue_id":"other-1","kind":"view","nested":{"issue_id":"work-1gj"}}
EOF
cmp -s "$case_root/migration-interactions.expected" "$migration_new_store/interactions.jsonl"
grep -Fxq '{"id":"bead-1gj","title":"Renamed export"}' "$migration_new_store/issues.jsonl"
grep -Fxq '{"id":"bead-8au","title":"Second renamed export"}' "$migration_new_store/issues.jsonl"
grep -Fxq bead-1gj "$migration_new_store/last-touched"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$migration_new_parent/correlations.jsonl"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$migration_new_store/interactions.jsonl"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$migration_new_store/last-touched"
for variable in BEADS_DB BD_DB BD_GLOBAL BEADS_DOLT_DATA_DIR BEADS_DOLT_PORT BEADS_DOLT_PROXIED_SERVER BEADS_DOLT_SERVER_DATABASE BEADS_DOLT_SERVER_HOST BEADS_DOLT_SERVER_MODE BEADS_DOLT_SERVER_PORT BEADS_DOLT_SERVER_SOCKET BEADS_DOLT_SHARED_SERVER; do
  grep -Fxq "${variable}_SET=" "$migration_log"
done
! grep -Eq '_SET=.+' "$migration_log"
migration_backups=("$migration_home"/.local/share/beads/work-to-hub-backup-*)
test "${#migration_backups[@]}" -eq 1
migration_backup=${migration_backups[0]}
cmp -s "$case_root/migration-ledger.before" "$migration_backup/work/correlations.jsonl"
cmp -s "$case_root/migration-config.before" "$migration_backup/work-beads.yaml"
test -f "$migration_backup/work/.beads/nested/payload"
test -f "$migration_backup/work/sibling"
grep -Fxq '{"id":"work-1gj","title":"Stale export"}' "$migration_backup/work/.beads/issues.jsonl"
grep -Fq '"issue_id":"work-1gj"' "$migration_backup/work/.beads/interactions.jsonl"
grep -Fxq work-1gj "$migration_backup/work/.beads/last-touched"
test "$(find "$migration_backup/work" -name '*.tmp.*' | wc -l | tr -d ' ')" -eq 0

# A legacy deployment without a ledger still migrates and does not create one.
no_ledger_home=$case_root/migration-no-ledger-home
no_ledger_old_parent=$no_ledger_home/.local/share/beads/work
no_ledger_old_store=$no_ledger_old_parent/.beads
no_ledger_old_config=$no_ledger_home/.config/bv/work-beads.yaml
no_ledger_new_parent=$no_ledger_home/.local/share/beads/hub
no_ledger_new_config=$no_ledger_home/.config/bv/hub.yaml
mkdir -p "$no_ledger_old_store" "${no_ledger_old_config%/*}"
printf '%s\n' work >"$no_ledger_home/current-prefix"
printf '%s\n' 'store without ledger' >"$no_ledger_old_store/payload"
cat >"$no_ledger_old_config" <<EOF
{"version":1,"store":"$no_ledger_old_store","ledger":"$no_ledger_old_parent/correlations.jsonl","repositories":{"ctx:repo-1234567890":{"path":"$repo_a"}}}
EOF
: >"$case_root/migration-no-ledger.log"
printf '\n' | HOME=$no_ledger_home FAKE_LOG=$case_root/migration-no-ledger.log FAKE_MIGRATION_HOME=$no_ledger_home \
  PATH=$fake_bin:/usr/bin:/bin bash "$source_dir/scripts/migrate-beads-work-to-hub.sh" \
  >"$case_root/migration-no-ledger.out" 2>"$case_root/migration-no-ledger.err"
test -f "$no_ledger_new_parent/.beads/payload"
grep -Fxq '{"id":"bead-1gj","title":"Renamed export"}' "$no_ledger_new_parent/.beads/issues.jsonl"
test ! -e "$no_ledger_new_parent/correlations.jsonl"
test ! -e "$no_ledger_old_parent"
test ! -e "$no_ledger_old_config"
jq -e --arg store "$no_ledger_new_parent/.beads" --arg ledger "$no_ledger_new_parent/correlations.jsonl" \
  --arg context ctx:repo-1234567890 --arg path "$repo_a" \
  '.store == $store and .ledger == $ledger and .repositories[$context].path == $path' \
  "$no_ledger_new_config" >/dev/null
no_ledger_backups=("$no_ledger_home"/.local/share/beads/work-to-hub-backup-*)
test "${#no_ledger_backups[@]}" -eq 1
test ! -e "${no_ledger_backups[0]}/work/correlations.jsonl"

# Invalid input retries, and a custom prefix reaches every migrated ID surface.
custom_migration_home=$case_root/migration-custom-home
custom_old_parent=$custom_migration_home/.local/share/beads/work
custom_old_store=$custom_old_parent/.beads
custom_old_config=$custom_migration_home/.config/bv/work-beads.yaml
custom_new_parent=$custom_migration_home/.local/share/beads/hub
custom_new_store=$custom_new_parent/.beads
custom_log=$case_root/migration-custom.log
mkdir -p "$custom_old_store" "${custom_old_config%/*}"
printf '%s\n' work >"$custom_migration_home/current-prefix"
printf '%s\n' '{"id":"work-1gj","title":"Stale export"}' >"$custom_old_store/issues.jsonl"
cat >"$custom_old_store/interactions.jsonl" <<'EOF'
{"issue_id":"work-1gj","nested":{"issue_id":"work-8au"},"text":"work-8au"}
EOF
printf '%s\n' work-1gj >"$custom_old_store/last-touched"
cat >"$custom_old_parent/correlations.jsonl" <<'EOF'
{"bead_id":"work-1gj","nested":{"bead_id":"work-8au"},"text":"work-8au"}
EOF
cat >"$custom_old_config" <<EOF
{"version":1,"store":"$custom_old_store","ledger":"$custom_old_parent/correlations.jsonl","repositories":{"ctx:repo-1234567890":{"path":"$repo_a"}}}
EOF
: >"$custom_log"
printf '%s\n' Work work_1 1work work- work--item 'work space' \
  abcdefghijklmnopqrstuvwxyzabcdefg custom-prefix | \
  HOME=$custom_migration_home FAKE_LOG=$custom_log FAKE_MIGRATION_HOME=$custom_migration_home \
  PATH=$fake_bin:/usr/bin:/bin bash "$source_dir/scripts/migrate-beads-work-to-hub.sh" \
  >"$case_root/migration-custom.out" 2>"$case_root/migration-custom.err"
test "$(grep -Fc 'Invalid prefix:' "$case_root/migration-custom.err")" -eq 7
assert_migration_bd_calls "$custom_log" "$custom_old_store" custom-prefix
grep -Fxq '{"id":"custom-prefix-1gj","title":"Renamed export"}' "$custom_new_store/issues.jsonl"
grep -Fxq '{"id":"custom-prefix-8au","title":"Second renamed export"}' "$custom_new_store/issues.jsonl"
grep -Fxq '{"issue_id":"custom-prefix-1gj","nested":{"issue_id":"work-8au"},"text":"work-8au"}' "$custom_new_store/interactions.jsonl"
grep -Fxq '{"bead_id":"custom-prefix-1gj","nested":{"bead_id":"work-8au"},"text":"work-8au"}' "$custom_new_parent/correlations.jsonl"
grep -Fxq custom-prefix-1gj "$custom_new_store/last-touched"
grep -Fq "Migrated work-* to custom-prefix-* in $custom_new_store" "$case_root/migration-custom.out"
custom_backups=("$custom_migration_home"/.local/share/beads/work-to-hub-backup-*)
test "${#custom_backups[@]}" -eq 1
grep -Fxq work-1gj "${custom_backups[0]}/work/.beads/last-touched"

# EOF fails cleanly after one read-only prefix query and before backup,
# destination creation, or source mutation.
eof_home=$case_root/migration-eof-home
eof_old_parent=$eof_home/.local/share/beads/work
eof_old_store=$eof_old_parent/.beads
eof_old_config=$eof_home/.config/bv/work-beads.yaml
mkdir -p "$eof_old_store" "${eof_old_config%/*}"
printf '%s\n' work >"$eof_home/current-prefix"
printf '%s\n' source >"$eof_old_store/payload"
cat >"$eof_old_config" <<EOF
{"version":1,"store":"$eof_old_store","ledger":"$eof_old_parent/correlations.jsonl","repositories":{}}
EOF
cp "$eof_old_config" "$case_root/migration-eof-config.before"
: >"$case_root/migration-eof.log"
if HOME=$eof_home FAKE_LOG=$case_root/migration-eof.log FAKE_MIGRATION_HOME=$eof_home \
  PATH=$fake_bin:/usr/bin:/bin bash "$source_dir/scripts/migrate-beads-work-to-hub.sh" \
  </dev/null >"$case_root/migration-eof.out" 2>"$case_root/migration-eof.err"; then
  fail 'migration accepted EOF while reading the target prefix'
fi
grep -Fq 'end of input while reading target prefix' "$case_root/migration-eof.err"
assert_hub_prefix_detection_only "$case_root/migration-eof.log" "$eof_old_store"
grep -Fxq source "$eof_old_store/payload"
cmp -s "$case_root/migration-eof-config.before" "$eof_old_config"
test ! -e "$eof_home/.local/share/beads/hub"
test ! -e "$eof_home/.config/bv/hub.yaml"
eof_backups=("$eof_home"/.local/share/beads/work-to-hub-backup-*)
test "${eof_backups[0]}" = "$eof_home/.local/share/beads/work-to-hub-backup-*"

# The one-time migration requires the persisted source prefix to be exactly
# work before prompting, backing up, or changing any source/destination state.
legacy_mismatch_home=$case_root/migration-source-mismatch-home
legacy_mismatch_parent=$legacy_mismatch_home/.local/share/beads/work
legacy_mismatch_store=$legacy_mismatch_parent/.beads
legacy_mismatch_config=$legacy_mismatch_home/.config/bv/work-beads.yaml
mkdir -p "$legacy_mismatch_store" "${legacy_mismatch_config%/*}"
printf '%s\n' task >"$legacy_mismatch_home/current-prefix"
printf '%s\n' source >"$legacy_mismatch_store/payload"
cat >"$legacy_mismatch_config" <<EOF
{"version":1,"store":"$legacy_mismatch_store","ledger":"$legacy_mismatch_parent/correlations.jsonl","repositories":{}}
EOF
cp "$legacy_mismatch_config" "$case_root/migration-source-mismatch-config.before"
: >"$case_root/migration-source-mismatch.log"
if HOME=$legacy_mismatch_home FAKE_LOG=$case_root/migration-source-mismatch.log \
  FAKE_MIGRATION_HOME=$legacy_mismatch_home PATH=$fake_bin:/usr/bin:/bin \
  bash "$source_dir/scripts/migrate-beads-work-to-hub.sh" </dev/null \
  >"$case_root/migration-source-mismatch.out" 2>"$case_root/migration-source-mismatch.err"; then
  fail 'legacy migration accepted a persisted prefix other than work'
fi
assert_hub_prefix_detection_only "$case_root/migration-source-mismatch.log" "$legacy_mismatch_store"
grep -Fq 'legacy store prefix must be work, found: task' "$case_root/migration-source-mismatch.err"
! grep -Fq 'Choose the store-wide prefix' "$case_root/migration-source-mismatch.err"
grep -Fxq source "$legacy_mismatch_store/payload"
cmp -s "$case_root/migration-source-mismatch-config.before" "$legacy_mismatch_config"
test ! -e "$legacy_mismatch_home/.local/share/beads/hub"
test ! -e "$legacy_mismatch_home/.config/bv/hub.yaml"
legacy_mismatch_backups=("$legacy_mismatch_home"/.local/share/beads/work-to-hub-backup-*)
test "${legacy_mismatch_backups[0]}" = "$legacy_mismatch_home/.local/share/beads/work-to-hub-backup-*"

# Existing destination state rejects migration before backup, bd, or source mutation.
precondition_home=$case_root/migration-precondition-home
precondition_parent=$precondition_home/.local/share/beads/work
precondition_store=$precondition_parent/.beads
precondition_config=$precondition_home/.config/bv/work-beads.yaml
mkdir -p "$precondition_store" "$precondition_home/.local/share/beads/hub" "${precondition_config%/*}"
printf '%s\n' source >"$precondition_store/payload"
printf '%s\n' '{"bead_id":"work-1"}' >"$precondition_parent/correlations.jsonl"
printf '%s\n' '{"version":1,"repositories":{}}' >"$precondition_config"
: >"$case_root/migration-precondition.log"
if HOME=$precondition_home FAKE_LOG=$case_root/migration-precondition.log \
  FAKE_MIGRATION_HOME=$precondition_home PATH=$fake_bin:/usr/bin:/bin \
  bash "$source_dir/scripts/migrate-beads-work-to-hub.sh" \
  >"$case_root/migration-precondition.out" 2>&1; then
  fail 'migration accepted an existing hub destination'
fi
grep -Fq 'hub destination already exists' "$case_root/migration-precondition.out"
test ! -s "$case_root/migration-precondition.log"
grep -Fxq source "$precondition_store/payload"
test ! -e "$precondition_home/.config/bv/hub.yaml"
precondition_backups=("$precondition_home"/.local/share/beads/work-to-hub-backup-*)
test "${precondition_backups[0]}" = "$precondition_home/.local/share/beads/work-to-hub-backup-*"

# Unknown, mutating, noncanonical, and mode-inapplicable Viewer syntax never
# reaches config initialization or Viewer.
for invocation in \
  '--theme dark' \
  '--robot-triage' \
  '--robot-triage --brief --robot-triage-by-track' \
  '--robot-plan --robot-insights' \
  '--robot-plan --label backend --label frontend' \
  '--robot-plan --graph-depth 2' \
  '--robot-label-health --label backend' \
  '--robot-graph --label backend' \
  '--robot-triage --brief --label backend' \
  '--robot-graph --graph-format html' \
  '--robot-graph --graph-depth 101' \
  '--robot-priority --robot-min-confidence 1.1' \
  '--robot-capacity --agents 0' \
  '--robot-new-safe-mode' \
  '--robot-next' \
  '--robot-suggest' \
  '--robot-search' \
  '--robot-history' \
  '--robot-confirm-correlation ctx@sha:id' \
  '--robot-reject-correlation ctx@sha:id' \
  '--robot-plan --format json' \
  '--robot-plan --format=json' \
  '--robot-plan --label=backend' \
  '--robot-plan=true' \
  '-robot-plan' \
  '-work-config /tmp/other' \
  '-history-mode git' \
  '-workspace other' \
  '-as-of HEAD~1' \
  '-agents-add' \
  '-f json' \
  '-l backend' \
  '--' \
  '--db /tmp/other' \
  '--db=/tmp/other' \
  '-db /tmp/other' \
  '-db=/tmp/other' \
  '--hub-config /tmp/other' \
  '--hub-config=/tmp/other' \
  '--work-config /tmp/other' \
  '--work-config=/tmp/other' \
  '--history-mode git' \
  '--history-mode=git' \
  '--workspace other' \
  '--workspace=other' \
  '--as-of HEAD~1' \
  '--as-of=HEAD~1' \
  '--update' \
  '--rollback' \
  '--export-md report.md' \
  '--pages' \
  '--cpu-profile profile.out' \
  '--agents-add' \
  '--feedback-accept work-1' \
  'correlate add'; do
  : >"$FAKE_LOG"
  cp "$hub_config" "$case_root/viewer-config-before-rejection"
  read -r -a args <<<"$invocation"
  if bash "$wbv" "${args[@]}" >"$case_root/viewer-rejected.out" 2>&1; then
    fail "wbv allowed unsupported invocation: $invocation"
  fi
  test ! -s "$FAKE_LOG"
  cmp -s "$case_root/viewer-config-before-rejection" "$hub_config"
done

# Missing Viewer or wrapper commands fail before launch.
no_wbv_bv=$case_root/no-wbv-bv
mkdir -p "$no_wbv_bv"
cp "$fake_bin/bd" "$fake_bin/wbd" "$no_wbv_bv/"
: >"$FAKE_LOG"
if PATH=$no_wbv_bv:/usr/bin:/bin /bin/sh "$wbv" >"$case_root/viewer-missing-bv.out" 2>&1; then
  fail 'wbv accepted a missing bv command'
fi
grep -Fq 'required command not found: bv' "$case_root/viewer-missing-bv.out"
test ! -s "$FAKE_LOG"

no_wbv_wbd=$case_root/no-wbv-wbd
mkdir -p "$no_wbv_wbd"
cp "$fake_bin/bd" "$fake_bin/bv" "$no_wbv_wbd/"
: >"$FAKE_LOG"
if PATH=$no_wbv_wbd:/usr/bin:/bin /bin/sh "$wbv" >"$case_root/viewer-missing-wbd.out" 2>&1; then
  fail 'wbv accepted a missing wbd command'
fi
grep -Fq 'required command not found: wbd' "$case_root/viewer-missing-wbd.out"
test ! -s "$FAKE_LOG"

# Config initialization failure prevents Viewer launch.
printf '%s\n' not-json >"$hub_config"
: >"$FAKE_LOG"
if bash "$wbv" --robot-plan >"$case_root/viewer-config-failure.out" 2>&1; then
  fail 'wbv accepted config initialization failure'
fi
! grep -Fq BEGIN_BV "$FAKE_LOG" || fail 'viewer launched after config failure'

# Static guards ensure the rejected shadow export/chdir workaround stays absent.
! grep -Fq 'bd --db "$store" export' "$wbv" || fail 'wbv contains a manual export'
! grep -Fq 'cd "$parent"' "$wbv" || fail 'wbv changes to the store parent'
grep -Fq -- '--history-mode external --hub-config "$hub_config"' "$wbv"
grep -Fq 'run_bd_bootstrap metrics off' "$wbd"
grep -Fq -- '--skip-hooks' "$wbd"
grep -Fq -- '--skip-agents' "$wbd"
! grep -Fq 'no-git-ops' "$wbd" || fail 'unsupported no-git-ops setting was added'
grep -Fq '. "$script_dir/beads-hub-prefix-internal.sh"' "$source_dir/scripts/migrate-beads-work-to-hub.sh"
grep -Fq '. "$script_dir/beads-hub-prefix-internal.sh"' "$source_dir/scripts/migrate-beads-hub-prefix.sh"
grep -Fq 'hub_prefix_migrate' "$source_dir/scripts/migrate-beads-work-to-hub.sh"
grep -Fq 'hub_prefix_migrate' "$source_dir/scripts/migrate-beads-hub-prefix.sh"
! grep -Fq 'jq -c' "$source_dir/scripts/migrate-beads-work-to-hub.sh"
! grep -Fq 'jq -c' "$source_dir/scripts/migrate-beads-hub-prefix.sh"
