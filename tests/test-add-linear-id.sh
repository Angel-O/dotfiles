#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
helper="$repo/dot_config/opencode/skills/add-linear-id/scripts/executable_add-linear-id"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
mkdir -p "$bin"
export TEST_STATE="$tmp/state" TEST_LOG="$tmp/log"
printf '%s\n' 'working on a feature' >"$TEST_STATE"

cat >"$bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'herdr %s\n' "$*" >>"$TEST_LOG"
case "$*" in
  'agent get pane-7') printf '%s\n' '{"result":{"type":"agent_info","agent":{"agent":"opencode","pane_id":"pane-7","tab_id":"tab-4","workspace_id":"workspace-2","focused":false,"agent_session":{"agent":"opencode","kind":"id","source":"herdr:opencode","value":"ses_fixture"}}}}' ;;
  'tab rename tab-4 '*) ;;
  *) exit 9 ;;
esac
EOF
cat >"$bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_LOG"
case "$1 $2" in
  'api session.get')
    [[ "$3 $4" == '--param sessionID=ses_fixture' ]] || exit 3
    jq -cn --arg title "$(<"$TEST_STATE")" '{data:{id:"ses_fixture",title:$title}}'
    ;;
  'api session.update')
    [[ "$3 $4" == '--param sessionID=ses_fixture' && "$5" == --data ]] || exit 4
    jq -er '.title' <<<"$6" >"$TEST_STATE"
    ;;
  *) exit 5 ;;
esac
EOF
chmod +x "$bin/herdr" "$bin/opencode"
export PATH="$bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=pane-7 HERDR_TAB_ID=tab-4 HERDR_WORKSPACE_ID=workspace-2

if "$helper" '' >/dev/null 2>&1; then
  echo 'empty ID unexpectedly accepted' >&2
  exit 1
fi
test ! -e "$TEST_LOG"

"$helper" 'eng/123 weird' >/dev/null
test "$(<"$TEST_STATE")" = 'eng/123 weird: working on a feature'
grep -Fxq 'herdr tab rename tab-4 eng/123 weird' "$TEST_LOG"
grep -Fxq 'api session.get --param sessionID=ses_fixture' "$TEST_LOG"
grep -Fxq 'api session.update --param sessionID=ses_fixture --data {"title":"eng/123 weird: working on a feature"}' "$TEST_LOG"

"$helper" 'eng/123 weird' >/dev/null
test "$(<"$TEST_STATE")" = 'eng/123 weird: eng/123 weird: working on a feature'
test "$(grep -Fc 'herdr tab rename tab-4 eng/123 weird' "$TEST_LOG")" -eq 2

if HERDR_ENV=0 "$helper" 'ENG-123' >/dev/null 2>&1; then
  echo 'unmanaged Herdr context unexpectedly accepted' >&2
  exit 1
fi

for role in personal work; do
  fixture="$repo/tests/fixtures/$role.toml"
  ignored=$(chezmoi --source "$repo" --config "$fixture" ignored --source-path)
  ! grep -Fxq 'dot_config/opencode/commands/add-linear-id.md' <<<"$ignored"
  ! grep -Fxq 'dot_config/opencode/skills/add-linear-id' <<<"$ignored"
  target=$(chezmoi --source "$repo" --config "$fixture" target-path --source-path dot_config/opencode/commands/add-linear-id.md)
  [[ "$target" == */.config/opencode/commands/add-linear-id.md ]]
  target=$(chezmoi --source "$repo" --config "$fixture" target-path --source-path dot_config/opencode/skills/add-linear-id/SKILL.md)
  [[ "$target" == */.config/opencode/skills/add-linear-id/SKILL.md ]]
  target=$(chezmoi --source "$repo" --config "$fixture" target-path --source-path dot_config/opencode/skills/add-linear-id/scripts/executable_add-linear-id)
  [[ "$target" == */.config/opencode/skills/add-linear-id/scripts/add-linear-id ]]
done
echo 'add-linear-id behavior checks passed'
