#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
root=$2
case_root=$root/beads-wrapper
fake_bin=$case_root/bin
home=$case_root/home
store=$home/.local/share/beads/work/.beads
mkdir -p "$fake_bin" "$store"

fail() {
  printf 'beads test: %s\n' "$*" >&2
  exit 1
}

cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
if [ "${FAKE_GIT_FAIL:-0}" = 1 ]; then
  exit 1
fi
if [ "$#" -eq 1 ] && [ "$1" = rev-parse ]; then
  exit 2
fi
if [ "$#" -eq 2 ] && [ "$1" = rev-parse ] && [ "$2" = --is-inside-work-tree ]; then
  printf '%s\n' true
  exit 0
fi
if [ "$#" -eq 4 ] && [ "$1" = -C ] && [ "$3" = rev-parse ] && [ "$4" = --git-dir ]; then
  exit 1
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
  printf '%s\n' 'BEGIN_BD'
  printf 'BEADS_DIR=%s\n' "${BEADS_DIR:-}"
  printf 'BEADS_DB=%s\n' "${BEADS_DB:-}"
  printf 'BD_DB=%s\n' "${BD_DB:-}"
  printf 'BEADS_DB_SET=%s\n' "${BEADS_DB+x}"
  printf 'BD_DB_SET=%s\n' "${BD_DB+x}"
  printf 'BEADS_DOLT_DATA_DIR_SET=%s\n' "${BEADS_DOLT_DATA_DIR+x}"
  printf 'BEADS_DOLT_PROXIED_SERVER_SET=%s\n' "${BEADS_DOLT_PROXIED_SERVER+x}"
  for arg in "$@"; do printf 'arg=%s\n' "$arg"; done
  printf '%s\n' 'END_BD'
} >>"${FAKE_LOG:?}"

if [ "${1:-}" = --db ]; then
  [ "$#" -ge 3 ] || exit 90
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

if [ "${1:-}" = export ]; then
  [ "${FAKE_EXPORT_FAIL:-0}" != 1 ] || exit 42
  shift
  output=
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output) output=$2; shift 2 ;;
      *) shift ;;
    esac
  done
  printf '%s\n' '{"id":"work-test"}' >"$output"
fi
exit "${FAKE_BD_EXIT:-0}"
EOF

cat >"$fake_bin/bv" <<'EOF'
#!/bin/sh
{
  printf '%s\n' 'BEGIN_BV'
  printf 'BEADS_DIR=%s\n' "${BEADS_DIR:-}"
  printf 'BEADS_DB=%s\n' "${BEADS_DB:-}"
  printf 'BD_DB=%s\n' "${BD_DB:-}"
  printf 'BEADS_DB_SET=%s\n' "${BEADS_DB+x}"
  printf 'BD_DB_SET=%s\n' "${BD_DB+x}"
  printf 'BEADS_DOLT_DATA_DIR_SET=%s\n' "${BEADS_DOLT_DATA_DIR+x}"
  printf 'BEADS_DOLT_PROXIED_SERVER_SET=%s\n' "${BEADS_DOLT_PROXIED_SERVER+x}"
  printf 'PWD=%s\n' "$PWD"
  printf 'BV_NO_GITIGNORE=%s\n' "${BV_NO_GITIGNORE:-}"
  printf 'BV_NO_CACHE=%s\n' "${BV_NO_CACHE:-}"
  for arg in "$@"; do printf 'arg=%s\n' "$arg"; done
  printf '%s\n' 'END_BV'
} >>"${FAKE_LOG:?}"
EOF
chmod +x "$fake_bin/git" "$fake_bin/bd" "$fake_bin/bv"

wbd=$source_dir/dot_local/bin/executable_wbd
wbv=$source_dir/dot_local/bin/executable_wbv
export HOME=$home
export PATH=$fake_bin:/usr/bin:/bin
export FAKE_LOG=$case_root/calls.log

bootstrap_failure_home=$case_root/bootstrap-failure-home
bootstrap_failure_store=$bootstrap_failure_home/.local/share/beads/work/.beads
bootstrap_failure_parent=${bootstrap_failure_store%/.beads}
bootstrap_failure_log=$case_root/bootstrap-failure.log
mkdir -p "$bootstrap_failure_parent"
printf '%s\n' keep-parent >"$bootstrap_failure_parent/sentinel"
if HOME=$bootstrap_failure_home \
  FAKE_LOG=$bootstrap_failure_log \
  FAKE_CONFIG_FAIL_KEY=export.git-add \
  bash "$wbd" bootstrap >"$case_root/bootstrap-failure.out" 2>&1; then
  fail 'wbd bootstrap accepted a config failure'
else
  [ "$?" -eq 43 ] || fail 'wbd bootstrap changed config failure status'
fi
test -d "$bootstrap_failure_parent"
test ! -e "$bootstrap_failure_store"
grep -Fxq keep-parent "$bootstrap_failure_parent/sentinel"
grep -Fq 'arg=init' "$bootstrap_failure_log"
grep -Fq 'arg=metrics' "$bootstrap_failure_log"
grep -Fq 'arg=off' "$bootstrap_failure_log"
grep -Fq 'arg=export.auto' "$bootstrap_failure_log"
grep -Fq 'arg=export.git-add' "$bootstrap_failure_log"
! grep -Fq 'arg=dolt.auto-push' "$bootstrap_failure_log" || fail 'bootstrap continued after config failure'
test "$(grep -Fc 'arg=--db' "$bootstrap_failure_log")" -eq 2
test "$(grep -Fc "arg=$bootstrap_failure_store" "$bootstrap_failure_log")" -eq 2
metrics_line=$(grep -nF 'arg=metrics' "$bootstrap_failure_log" | cut -d: -f1)
init_line=$(grep -nF 'arg=init' "$bootstrap_failure_log" | cut -d: -f1)
[ "$metrics_line" -lt "$init_line" ] || fail 'bootstrap initialized before disabling metrics'

bootstrap_success_home=$case_root/bootstrap-success-home
bootstrap_success_store=$bootstrap_success_home/.local/share/beads/work/.beads
bootstrap_success_log=$case_root/bootstrap-success.log
mkdir -p "$bootstrap_success_home"
HOME=$bootstrap_success_home FAKE_LOG=$bootstrap_success_log bash "$wbd" bootstrap
test -d "$bootstrap_success_store"
test "$(grep -Fc 'BEGIN_BD' "$bootstrap_success_log")" -eq 5
grep -Fq 'arg=init' "$bootstrap_success_log"
grep -Fq 'arg=--prefix' "$bootstrap_success_log"
grep -Fq 'arg=work' "$bootstrap_success_log"
grep -Fq 'arg=metrics' "$bootstrap_success_log"
grep -Fq 'arg=off' "$bootstrap_success_log"
grep -Fq 'arg=export.auto' "$bootstrap_success_log"
grep -Fq 'arg=export.git-add' "$bootstrap_success_log"
grep -Fq 'arg=dolt.auto-push' "$bootstrap_success_log"
test "$(grep -Fc 'arg=--db' "$bootstrap_success_log")" -eq 3
test "$(grep -Fc "arg=$bootstrap_success_store" "$bootstrap_success_log")" -eq 3
metrics_line=$(grep -nF 'arg=metrics' "$bootstrap_success_log" | cut -d: -f1)
init_line=$(grep -nF 'arg=init' "$bootstrap_success_log" | cut -d: -f1)
[ "$metrics_line" -lt "$init_line" ] || fail 'successful bootstrap initialized before disabling metrics'

bootstrap_metrics_home=$case_root/bootstrap-metrics-failure-home
bootstrap_metrics_store=$bootstrap_metrics_home/.local/share/beads/work/.beads
bootstrap_metrics_parent=${bootstrap_metrics_store%/.beads}
bootstrap_metrics_log=$case_root/bootstrap-metrics-failure.log
mkdir -p "$bootstrap_metrics_parent"
printf '%s\n' keep-parent >"$bootstrap_metrics_parent/sentinel"
if HOME=$bootstrap_metrics_home \
  FAKE_LOG=$bootstrap_metrics_log \
  FAKE_METRICS_FAIL=1 \
  bash "$wbd" bootstrap >"$case_root/bootstrap-metrics-failure.out" 2>&1; then
  fail 'wbd bootstrap accepted a metrics opt-out failure'
else
  [ "$?" -eq 44 ] || fail 'wbd bootstrap changed metrics failure status'
fi
test ! -e "$bootstrap_metrics_store"
grep -Fxq keep-parent "$bootstrap_metrics_parent/sentinel"
grep -Fq 'arg=metrics' "$bootstrap_metrics_log"
grep -Fq 'arg=off' "$bootstrap_metrics_log"
test "$(grep -Fc 'BEGIN_BD' "$bootstrap_metrics_log")" -eq 1
! grep -Fq 'arg=init' "$bootstrap_metrics_log" || fail 'bootstrap initialized after metrics failure'
! grep -Fq 'arg=export.auto' "$bootstrap_metrics_log" || fail 'bootstrap continued after metrics failure'
! grep -Fq 'arg=--db' "$bootstrap_metrics_log" || fail 'metrics opt-out received a database path'

bootstrap_init_home=$case_root/bootstrap-init-failure-home
bootstrap_init_store=$bootstrap_init_home/.local/share/beads/work/.beads
bootstrap_init_parent=${bootstrap_init_store%/.beads}
bootstrap_init_log=$case_root/bootstrap-init-failure.log
mkdir -p "$bootstrap_init_parent"
printf '%s\n' keep-parent >"$bootstrap_init_parent/sentinel"
if HOME=$bootstrap_init_home \
  FAKE_LOG=$bootstrap_init_log \
  FAKE_INIT_EXIT=45 \
  bash "$wbd" bootstrap >"$case_root/bootstrap-init-failure.out" 2>&1; then
  fail 'wbd bootstrap accepted an init failure'
else
  [ "$?" -eq 45 ] || fail 'wbd bootstrap changed init failure status'
fi
test ! -e "$bootstrap_init_store"
grep -Fxq keep-parent "$bootstrap_init_parent/sentinel"
test "$(grep -Fc 'BEGIN_BD' "$bootstrap_init_log")" -eq 2
grep -Fq 'arg=metrics' "$bootstrap_init_log"
grep -Fq 'arg=init' "$bootstrap_init_log"
! grep -Fq 'arg=export.auto' "$bootstrap_init_log" || fail 'bootstrap continued after init failure'
! grep -Fq 'arg=--db' "$bootstrap_init_log" || fail 'pre-init commands received a database path'

origin_ssh=git@Example.COM:Group/Repo.git
origin_scp=Example.COM:Group/Repo.git
origin_https=https://example.com/Group/Repo.git/
context_ssh=$(FAKE_ORIGIN=$origin_ssh bash "$wbd" context)
context_scp=$(FAKE_ORIGIN=$origin_scp bash "$wbd" context)
context_https=$(FAKE_ORIGIN=$origin_https bash "$wbd" context)
[ "$context_ssh" = "$context_https" ] || fail 'equivalent origins produced different contexts'
[ "$context_scp" = "$context_https" ] || fail 'username-less SSH origin produced a different context'
case "$context_ssh" in
  ctx:repo-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) fail "unexpected context format: $context_ssh" ;;
esac

: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_ssh bash "$wbd" create 'Quoted task title' --labels 'urgent,customer request' --json
grep -Fq 'arg=create' "$FAKE_LOG"
grep -Fq "arg=$context_ssh" "$FAKE_LOG"
grep -Fq 'arg=urgent,customer request' "$FAKE_LOG"
[ "$(grep -Fc 'arg=--labels' "$FAKE_LOG")" -eq 2 ] || fail 'create did not preserve and append labels'
[ "$(grep -Fc "arg=$context_ssh" "$FAKE_LOG")" -eq 1 ] || fail 'create context label count is not one'

: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_ssh bash "$wbd" --json create 'Leading global create'
grep -Fq 'arg=--json' "$FAKE_LOG"
grep -Fq 'arg=create' "$FAKE_LOG"
grep -Fq 'arg=--labels' "$FAKE_LOG"
grep -Fq "arg=$context_ssh" "$FAKE_LOG"

: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_ssh bash "$wbd" list --status open --json
grep -Fq 'arg=list' "$FAKE_LOG"
grep -Fq 'arg=--label' "$FAKE_LOG"
grep -Fq "arg=$context_ssh" "$FAKE_LOG"
grep -Fq 'arg=--status' "$FAKE_LOG"

: >"$FAKE_LOG"
FAKE_ORIGIN=$origin_ssh bash "$wbd" --json list --status open
grep -Fq 'arg=--json' "$FAKE_LOG"
grep -Fq 'arg=list' "$FAKE_LOG"
grep -Fq 'arg=--label' "$FAKE_LOG"
grep -Fq "arg=$context_ssh" "$FAKE_LOG"

: >"$FAKE_LOG"
FAKE_GIT_FAIL=1 bash "$wbd" list --json --all-contexts --status open
grep -Fq 'arg=list' "$FAKE_LOG"
grep -Fq 'arg=--json' "$FAKE_LOG"
grep -Fq 'arg=--status' "$FAKE_LOG"
! grep -Fq 'arg=--all-contexts' "$FAKE_LOG" || fail 'custom all-contexts flag leaked to bd'
! grep -Fq 'arg=--label' "$FAKE_LOG" || fail 'global list gained a context filter'

if FAKE_BD_EXIT=37 bash "$wbd" show work-test --json; then
  fail 'wbd did not forward bd failure'
else
  [ "$?" -eq 37 ] || fail 'wbd changed bd exit status'
fi

mv "$store" "$case_root/store-away"
if bash "$wbd" list --all-contexts >"$case_root/missing-store.out" 2>&1; then
  fail 'wbd accepted a missing store'
fi
grep -Fq "run 'wbd bootstrap'" "$case_root/missing-store.out"
mv "$case_root/store-away" "$store"

if FAKE_ORIGIN_MISSING=1 FAKE_ORIGIN=unused bash "$wbd" context >"$case_root/missing-origin.out" 2>&1; then
  fail 'wbd accepted a missing origin'
fi
grep -Fq 'no origin remote' "$case_root/missing-origin.out"

if FAKE_GIT_FAIL=1 bash "$wbd" create test >"$case_root/missing-git.out" 2>&1; then
  fail 'wbd accepted a missing repository context'
fi
grep -Eq 'Git repository|origin remote' "$case_root/missing-git.out"

if bash "$wbd" init >"$case_root/direct-init.out" 2>&1; then
  fail 'wbd allowed direct init'
fi
grep -Fq "run 'wbd bootstrap'" "$case_root/direct-init.out"

assert_wbd_rejected() {
  local name=$1
  shift
  if bash "$wbd" "$@" >"$case_root/$name.out" 2>&1; then
    fail "wbd allowed routing override: $name"
  fi
}

assert_wbd_rejected db-split --db /tmp/not-the-work-store list
assert_wbd_rejected db-equals --db=/tmp/not-the-work-store list
assert_wbd_rejected database-split --database other list
assert_wbd_rejected database-equals --database=other list
assert_wbd_rejected global --global list
assert_wbd_rejected global-equals --global=true list
assert_wbd_rejected repo-split create test --repo elsewhere
assert_wbd_rejected repo-equals create test --repo=elsewhere
assert_wbd_rejected short-directory-split -C /tmp list
assert_wbd_rejected short-directory-joined -C/tmp list
assert_wbd_rejected directory-split --directory /tmp list
assert_wbd_rejected directory-equals --directory=/tmp list

if bash "$wbd" --json init >"$case_root/leading-init.out" 2>&1; then
  fail 'wbd allowed init after a global flag'
fi
grep -Fq "run 'wbd bootstrap'" "$case_root/leading-init.out"

: >"$FAKE_LOG"
BEADS_DB=/tmp/stale-beads-db \
  BD_DB=/tmp/stale-bd-db \
  BEADS_DOLT_DATA_DIR=/tmp/stale-dolt-data \
  BEADS_DOLT_PROXIED_SERVER=1 \
  bash "$wbd" show work-test --json
grep -Fq "BEADS_DIR=$store" "$FAKE_LOG"
grep -Fxq 'BEADS_DB=' "$FAKE_LOG"
grep -Fxq 'BD_DB=' "$FAKE_LOG"
grep -Fxq 'BEADS_DB_SET=' "$FAKE_LOG"
grep -Fxq 'BD_DB_SET=' "$FAKE_LOG"
grep -Fxq 'BEADS_DOLT_DATA_DIR_SET=' "$FAKE_LOG"
grep -Fxq 'BEADS_DOLT_PROXIED_SERVER_SET=' "$FAKE_LOG"
grep -Fq 'arg=--db' "$FAKE_LOG"
grep -Fq "arg=$store" "$FAKE_LOG"

assert_wbd_command_rejected() {
  local command=$1
  : >"$FAKE_LOG"
  if bash "$wbd" "$command" >"$case_root/unsupported-$command.out" 2>&1; then
    fail "wbd allowed unsupported command: $command"
  fi
  grep -Fq 'supported commands:' "$case_root/unsupported-$command.out"
  test ! -s "$FAKE_LOG"
}

assert_wbd_command_rejected config
assert_wbd_command_rejected setup
assert_wbd_command_rejected hooks
assert_wbd_command_rejected doctor
assert_wbd_command_rejected sync
assert_wbd_command_rejected admin
assert_wbd_command_rejected repo
assert_wbd_command_rejected worktree
assert_wbd_command_rejected edit
assert_wbd_command_rejected import
assert_wbd_command_rejected export

: >"$FAKE_LOG"
if bash "$wbd" >"$case_root/unsupported-missing.out" 2>&1; then
  fail 'wbd allowed a missing command'
fi
grep -Fq 'supported commands:' "$case_root/unsupported-missing.out"
test ! -s "$FAKE_LOG"

no_bd=$case_root/no-bd
mkdir -p "$no_bd"
cp "$fake_bin/git" "$no_bd/git"
if PATH=$no_bd /bin/bash "$wbd" show work-test >"$case_root/missing-bd.out" 2>&1; then
  fail 'wbd accepted a missing bd command'
fi
grep -Fq 'required command not found: bd' "$case_root/missing-bd.out"

: >"$FAKE_LOG"
BEADS_DB=/tmp/stale-beads-db \
  BD_DB=/tmp/stale-bd-db \
  BEADS_DOLT_DATA_DIR=/tmp/stale-dolt-data \
  BEADS_DOLT_PROXIED_SERVER=1 \
  FAKE_ORIGIN=$origin_ssh \
  sh "$wbv" --theme compact
grep -Fq 'arg=export' "$FAKE_LOG"
grep -Fq 'arg=--output' "$FAKE_LOG"
grep -Fq 'BEGIN_BV' "$FAKE_LOG"
grep -Fq "BEADS_DIR=$store" "$FAKE_LOG"
grep -Fq 'BV_NO_GITIGNORE=1' "$FAKE_LOG"
grep -Fq 'BV_NO_CACHE=1' "$FAKE_LOG"
grep -Fxq "PWD=${store%/.beads}" "$FAKE_LOG"
test "$(grep -Fxc 'BEADS_DB=' "$FAKE_LOG")" -eq 2
test "$(grep -Fxc 'BD_DB=' "$FAKE_LOG")" -eq 2
test "$(grep -Fxc 'BEADS_DB_SET=' "$FAKE_LOG")" -eq 2
test "$(grep -Fxc 'BD_DB_SET=' "$FAKE_LOG")" -eq 2
test "$(grep -Fxc 'BEADS_DOLT_DATA_DIR_SET=' "$FAKE_LOG")" -eq 2
test "$(grep -Fxc 'BEADS_DOLT_PROXIED_SERVER_SET=' "$FAKE_LOG")" -eq 2
grep -Fq 'arg=--db' "$FAKE_LOG"
grep -Fq "arg=$store" "$FAKE_LOG"
test "$(grep -Fxc 'arg=--db' "$FAKE_LOG")" -eq 2
test "$(grep -Fxc "arg=$store" "$FAKE_LOG")" -eq 2
grep -Fq 'arg=--theme' "$FAKE_LOG"
grep -Fq '"id":"work-test"' "$store/issues.jsonl"
export_line=$(grep -nF 'arg=export' "$FAKE_LOG" | cut -d: -f1)
viewer_line=$(grep -nF 'BEGIN_BV' "$FAKE_LOG" | cut -d: -f1)
[ "$export_line" -lt "$viewer_line" ] || fail 'viewer launched before export'

: >"$FAKE_LOG"
if sh "$wbv" --db /tmp/not-the-work-store >"$case_root/viewer-db-split.out" 2>&1; then
  fail 'wbv allowed a split database override'
fi
grep -Fq 'Viewer database override flags are disabled' "$case_root/viewer-db-split.out"
test ! -s "$FAKE_LOG"

if sh "$wbv" --db=/tmp/not-the-work-store >"$case_root/viewer-db-equals.out" 2>&1; then
  fail 'wbv allowed an equals database override'
fi
grep -Fq 'Viewer database override flags are disabled' "$case_root/viewer-db-equals.out"
test ! -s "$FAKE_LOG"

if sh "$wbv" -db=/tmp/not-the-work-store >"$case_root/viewer-db-single-dash.out" 2>&1; then
  fail 'wbv allowed a single-dash database override'
fi
grep -Fq 'Viewer database override flags are disabled' "$case_root/viewer-db-single-dash.out"
test ! -s "$FAKE_LOG"

assert_wbv_agents_rejected() {
  local name=$1
  local flag=$2
  if sh "$wbv" "$flag" >"$case_root/$name.out" 2>&1; then
    fail "wbv allowed repository agent-file mutation: $flag"
  fi
  grep -Fq 'Viewer repository agent-file mutation flags are disabled' "$case_root/$name.out"
  test ! -s "$FAKE_LOG"
}

assert_wbv_agents_rejected viewer-agents-add --agents-add
assert_wbv_agents_rejected viewer-agents-add-equals --agents-add=true
assert_wbv_agents_rejected viewer-agents-remove --agents-remove
assert_wbv_agents_rejected viewer-agents-remove-equals --agents-remove=true
assert_wbv_agents_rejected viewer-agents-update --agents-update
assert_wbv_agents_rejected viewer-agents-update-equals --agents-update=true

printf '%s\n' original >"$store/issues.jsonl"
: >"$FAKE_LOG"
if FAKE_EXPORT_FAIL=1 sh "$wbv" >"$case_root/export-failure.out" 2>&1; then
  fail 'wbv accepted export failure'
else
  [ "$?" -eq 42 ] || fail 'wbv changed export failure status'
fi
grep -Fxq original "$store/issues.jsonl"
! grep -Fq 'BEGIN_BV' "$FAKE_LOG" || fail 'viewer launched after export failure'

no_bv=$case_root/no-bv
mkdir -p "$no_bv"
cp "$fake_bin/bd" "$no_bv/bd"
if PATH=$no_bv /bin/sh "$wbv" >"$case_root/missing-bv.out" 2>&1; then
  fail 'wbv accepted a missing bv command'
fi
grep -Fq 'required command not found: bv' "$case_root/missing-bv.out"

# Bootstrap runs only against fake commands and temporary homes; static checks pin its flags.
grep -Fq 'cd "$parent"' "$wbd"
grep -Fq 'git -C "$parent" rev-parse --git-dir' "$wbd"
grep -Fq -- '--non-interactive' "$wbd"
grep -Fq -- '--skip-hooks' "$wbd"
grep -Fq -- '--skip-agents' "$wbd"
grep -Fq 'run_bd_bootstrap metrics off' "$wbd"
grep -Fq 'run_bd_bootstrap init' "$wbd"
grep -Fq 'run_bd config set export.auto false' "$wbd"
grep -Fq 'run_bd config set export.git-add false' "$wbd"
grep -Fq 'run_bd config set dolt.auto-push false' "$wbd"
! grep -Fq 'no-git-ops' "$wbd" || fail 'unsupported no-git-ops setting was added'
