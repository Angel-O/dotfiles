#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
root=$2
case_root=$root/beads-wrapper
fake_bin=$case_root/bin
home=$case_root/home
store=$home/.local/share/beads/work/.beads
work_config=$home/.config/bv/work-beads.yaml
ledger=$home/.local/share/beads/work/correlations.jsonl
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
    "$work_config" >/dev/null || fail 'work config contents are invalid'
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

# Bootstrap creates the store and a valid empty private work config.
bootstrap_home=$case_root/bootstrap-home
bootstrap_store=$bootstrap_home/.local/share/beads/work/.beads
bootstrap_config=$bootstrap_home/.config/bv/work-beads.yaml
mkdir -p "$bootstrap_home"
HOME=$bootstrap_home FAKE_LOG=$case_root/bootstrap.log bash "$wbd" bootstrap
test -d "$bootstrap_store"
jq -e --arg store "$bootstrap_store" \
  '.version == 1 and .store == $store and .repositories == {}' "$bootstrap_config" >/dev/null
test "$(grep -Fc BEGIN_BD "$case_root/bootstrap.log")" -eq 5
grep -Fq 'arg=metrics' "$case_root/bootstrap.log"
grep -Fq 'arg=--skip-hooks' "$case_root/bootstrap.log"
grep -Fq 'arg=--skip-agents' "$case_root/bootstrap.log"

# Bootstrap failures propagate and remove only the partially created store.
failure_home=$case_root/bootstrap-failure-home
failure_store=$failure_home/.local/share/beads/work/.beads
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
metrics_store=$metrics_home/.local/share/beads/work/.beads
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
init_store=$init_home/.local/share/beads/work/.beads
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
test "$config_path" = "$work_config"
assert_config
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$work_config"
cp "$work_config" "$case_root/config.before"
bash "$wbd" configure >/dev/null
cmp -s "$case_root/config.before" "$work_config"
chmod 0644 "$work_config"
bash "$wbd" configure >/dev/null
cmp -s "$case_root/config.before" "$work_config"
python3 -c 'import os,stat,sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o600' "$work_config"

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
  '.repositories == {($a): {path: $ap}, ($b): {path: $bp}}' "$work_config" >/dev/null
cp "$work_config" "$case_root/config-a-then-b"
jq '.repositories = {}' "$work_config" >"$case_root/empty-config"
mv "$case_root/empty-config" "$work_config"
FAKE_ORIGIN=$origin_b FAKE_GIT_ROOT=$repo_b bash "$wbd" register >/dev/null
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" register >/dev/null
cmp -s "$case_root/config-a-then-b" "$work_config" || fail 'registration order changed serialized config'

# Failed context discovery neither registers nor rewrites the config.
cp "$work_config" "$case_root/config-before-missing-origin"
if FAKE_ORIGIN_MISSING=1 bash "$wbd" register >"$case_root/missing-origin.out" 2>&1; then
  fail 'register accepted a repository without origin'
fi
cmp -s "$case_root/config-before-missing-origin" "$work_config"

# Create and scoped list register the checkout before forwarding to bd.
jq '.repositories = {}' "$work_config" >"$case_root/empty-config"
mv "$case_root/empty-config" "$work_config"
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" create 'Quoted task' --labels 'urgent,customer request' --json
assert_last_args BD --db "$store" --json create --labels "$context_a" 'Quoted task' --labels 'urgent,customer request'
jq -e --arg context "$context_a" --arg path "$repo_a" '.repositories[$context].path == $path' "$work_config" >/dev/null

jq '.repositories = {}' "$work_config" >"$case_root/empty-config"
mv "$case_root/empty-config" "$work_config"
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" --json list --status open
assert_last_args BD --db "$store" --json list --label "$context_a" --status open
jq -e --arg context "$context_a" '.repositories | has($context)' "$work_config" >/dev/null

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
assert_last_args BV correlate add --bead work-123 --repo "$context_a" --commit HEAD --work-config "$work_config"
: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_a FAKE_GIT_ROOT=$repo_a bash "$wbd" link work-123 refs/tags/release-1
assert_last_args BV correlate add --bead work-123 --repo "$context_a" --commit refs/tags/release-1 --work-config "$work_config"
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
  cp "$work_config" "$case_root/config-before-rejection"
  read -r -a args <<<"$invocation"
  if bash "$wbd" "${args[@]}" >"$case_root/strict-rejected.out" 2>&1; then
    fail "wbd allowed unsupported invocation: $invocation"
  fi
  test ! -s "$FAKE_LOG"
  cmp -s "$case_root/config-before-rejection" "$work_config"
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
cp "$work_config" "$case_root/valid-config"
printf '%s\n' '{"version":1,"repositories":[]}' >"$work_config"
cp "$work_config" "$case_root/malformed-before"
if bash "$wbd" configure >"$case_root/malformed.out" 2>&1; then
  fail 'configure accepted malformed config'
fi
cmp -s "$case_root/malformed-before" "$work_config"
rm "$work_config"
ln -s "$case_root/valid-config" "$work_config"
if bash "$wbd" configure >"$case_root/symlink.out" 2>&1; then
  fail 'configure accepted a symlink config'
fi
test -L "$work_config"
rm "$work_config"
cp "$case_root/valid-config" "$work_config"

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
rm -f "$work_config"
: >"$FAKE_LOG"
if bash "$wbv" >"$case_root/viewer-nontty.out" 2>&1; then
  fail 'wbv allowed a bare non-interactive invocation'
fi
grep -Fq 'requires an interactive terminal' "$case_root/viewer-nontty.out"
test ! -s "$FAKE_LOG"
test ! -e "$work_config"

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
assert_last_args BV --history-mode external --work-config "$work_config"
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
  assert_last_args BV --history-mode external --work-config "$work_config" "$@" --format json
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
  cp "$work_config" "$case_root/viewer-config-before-rejection"
  read -r -a args <<<"$invocation"
  if bash "$wbv" "${args[@]}" >"$case_root/viewer-rejected.out" 2>&1; then
    fail "wbv allowed unsupported invocation: $invocation"
  fi
  test ! -s "$FAKE_LOG"
  cmp -s "$case_root/viewer-config-before-rejection" "$work_config"
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
printf '%s\n' not-json >"$work_config"
: >"$FAKE_LOG"
if bash "$wbv" --robot-plan >"$case_root/viewer-config-failure.out" 2>&1; then
  fail 'wbv accepted config initialization failure'
fi
! grep -Fq BEGIN_BV "$FAKE_LOG" || fail 'viewer launched after config failure'

# Static guards ensure the rejected shadow export/chdir workaround stays absent.
! grep -Fq 'bd --db "$store" export' "$wbv" || fail 'wbv contains a manual export'
! grep -Fq 'cd "$parent"' "$wbv" || fail 'wbv changes to the store parent'
grep -Fq -- '--history-mode external --work-config "$work_config"' "$wbv"
grep -Fq 'run_bd_bootstrap metrics off' "$wbd"
grep -Fq -- '--skip-hooks' "$wbd"
grep -Fq -- '--skip-agents' "$wbd"
! grep -Fq 'no-git-ops' "$wbd" || fail 'unsupported no-git-ops setting was added'
