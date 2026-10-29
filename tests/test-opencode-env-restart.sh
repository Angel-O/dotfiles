#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
home="$root/home"
bin="$home/.local/bin"
mkdir -p "$bin"
cp "$source_dir/dot_local/bin/executable_opencode-env-restart" "$bin/opencode-env-restart"
chmod +x "$bin/opencode-env-restart"
cat >"$bin/opencode-env" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$HOME/wrapper-args"
exit "${RESTART_TEST_EXIT:-0}"
EOF
chmod +x "$bin/opencode-env"

start_run() {
  env HOME="$home" "$bin/opencode-env-restart" start
}

wait_result() {
  local run_id=$1 output
  for _ in $(seq 1 100); do
    output=$(env HOME="$home" "$bin/opencode-env-restart" status "$run_id")
    if [[ "$output" == *'"status": "succeeded"'* || "$output" == *'"status": "failed"'* ]]; then
      printf '%s\n' "$output"
      return 0
    fi
    sleep 0.05
  done
  printf 'worker result timed out: %s\n' "$run_id" >&2
  return 1
}

started=$(start_run)
run_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["run_id"])' "$started")
[[ $(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["status"])' "$started") == started ]]
success=$(wait_result "$run_id")
python3 - "$success" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['status']=='succeeded' and d['exit_code']==0
assert d['sid']==d['pid']==d['pgid']
PY
grep -Fqx 'service restart' "$home/wrapper-args"

failed_start=$(env HOME="$home" RESTART_TEST_EXIT=17 "$bin/opencode-env-restart" start)
failed_id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["run_id"])' "$failed_start")
failed=$(wait_result "$failed_id")
python3 - "$failed" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
assert d['status']=='failed' and d['exit_code']==17
assert d['sid']==d['pid']==d['pgid']
PY
latest=$(env HOME="$home" "$bin/opencode-env-restart" status)
[[ $(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["run_id"])' "$latest") == "$failed_id" ]]
printf 'independent restart helper lifecycle and result checks passed\n'
