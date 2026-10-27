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

"$helper" 'eng/[*]? weird' >/dev/null
test "$(<"$TEST_STATE")" = 'eng/[*]? weird: working on a feature'
grep -Fxq 'herdr tab rename tab-4 eng/[*]? weird' "$TEST_LOG"
grep -Fxq 'api session.get --param sessionID=ses_fixture' "$TEST_LOG"
grep -Fxq 'api session.update --param sessionID=ses_fixture --data {"title":"eng/[*]? weird: working on a feature"}' "$TEST_LOG"

"$helper" 'eng/[*]? weird' >/dev/null
test "$(<"$TEST_STATE")" = 'eng/[*]? weird: working on a feature'
test "$(grep -Fc 'herdr tab rename tab-4 eng/[*]? weird' "$TEST_LOG")" -eq 2

if HERDR_ENV=0 "$helper" 'ENG-123' >/dev/null 2>&1; then
  echo 'unmanaged Herdr context unexpectedly accepted' >&2
  exit 1
fi

integration_sources=(
  dot_config/opencode/commands/add-linear-id.md
  dot_config/opencode/skills/add-linear-id/SKILL.md
  dot_config/opencode/skills/add-linear-id/scripts/executable_add-linear-id
)
for role in work personal; do
  fixture="$repo/tests/fixtures/$role.toml"
  ignored=$(chezmoi --source "$repo" --config "$fixture" ignored --source-path)
  if [[ "$role" == work ]]; then
    ! grep -Fxq '.config/opencode/commands/add-linear-id.md' <<<"$ignored"
    ! grep -Fq '.config/opencode/skills/add-linear-id' <<<"$ignored"
  else
    grep -Fxq '.config/opencode/commands/add-linear-id.md' <<<"$ignored"
    grep -Fq '.config/opencode/skills/add-linear-id' <<<"$ignored"
  fi
  for source in "${integration_sources[@]}"; do
    target=$(chezmoi --source "$repo" --config "$fixture" target-path --source-path "$source")
    case "$source" in
      dot_config/opencode/commands/*) [[ "$target" == */.config/opencode/commands/add-linear-id.md ]] ;;
      dot_config/opencode/skills/*/SKILL.md) [[ "$target" == */.config/opencode/skills/add-linear-id/SKILL.md ]] ;;
      *) [[ "$target" == */.config/opencode/skills/add-linear-id/scripts/add-linear-id ]] ;;
    esac
  done
  ! grep -Fq '.config/herdr-labels' <<<"$ignored"
done

for disabled in opencode herdr; do
  fixture="$tmp/work-$disabled-disabled.toml"
  sed "s/^$disabled = true$/$disabled = false/" "$repo/tests/fixtures/work.toml" >"$fixture"
  ignored=$(chezmoi --source "$repo" --config "$fixture" ignored --source-path)
  grep -Fxq '.config/opencode/commands/add-linear-id.md' <<<"$ignored"
  grep -Fq '.config/opencode/skills/add-linear-id' <<<"$ignored"
done

work_home="$tmp/rendered-work"
personal_home="$tmp/rendered-personal"
for home in "$work_home" "$personal_home"; do
  mkdir -p "$home/.config/opencode/commands" "$home/.config/opencode/skills/add-linear-id/scripts" "$home/.config/herdr-labels"
done
chezmoi --source "$repo" --destination "$work_home" --config "$repo/tests/fixtures/work.toml" \
  --persistent-state "$tmp/work-state.db" --exclude scripts,externals --force --source-path apply \
  "${integration_sources[@]}" dot_config/herdr-labels/config.toml
test -f "$work_home/.config/opencode/commands/add-linear-id.md"
test -f "$work_home/.config/opencode/skills/add-linear-id/SKILL.md"
test -x "$work_home/.config/opencode/skills/add-linear-id/scripts/add-linear-id"
test -f "$work_home/.config/herdr-labels/config.toml"

chezmoi --source "$repo" --destination "$personal_home" --config "$repo/tests/fixtures/personal.toml" \
  --persistent-state "$tmp/personal-state.db" --exclude scripts,externals --force --source-path apply \
  dot_config/herdr-labels/config.toml
test ! -e "$personal_home/.config/opencode/commands/add-linear-id.md"
test ! -e "$personal_home/.config/opencode/skills/add-linear-id/SKILL.md"
test ! -e "$personal_home/.config/opencode/skills/add-linear-id/scripts/add-linear-id"
test -f "$personal_home/.config/herdr-labels/config.toml"
echo 'add-linear-id behavior checks passed'
