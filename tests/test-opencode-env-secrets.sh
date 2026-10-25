#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
root=$(mktemp -d)
trap 'chmod -R u+rwX "$root"; rm -rf "$root"' EXIT

home="$root/home"
fake_bin="$root/bin"
mkdir -p "$home/.config/opencode" "$fake_bin"
cat >"$fake_bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'launch\n' >>"$LAUNCH_LOG"
printf 'SHARED_SETTING=%s\n' "${SHARED_SETTING-}"
printf 'EXPORTED_SECRET=%s\n' "${EXPORTED_SECRET-}"
printf 'UNEXPORTED_SECRET=%s\n' "${UNEXPORTED_SECRET-}"
printf 'LOCAL_EXPORT=%s\n' "${LOCAL_EXPORT-}"
printf 'LOCAL_UNEXPORTED=%s\n' "${LOCAL_UNEXPORTED-}"
printf 'args=%s\n' "$*"
EOF
chmod +x "$fake_bin/opencode"

launcher="$root/opencode-env"
chezmoi execute-template --source "$source_dir" --config "$source_dir/tests/fixtures/work.toml" \
  <"$source_dir/dot_local/bin/executable_opencode-env.tmpl" >"$launcher"
chmod +x "$launcher"
zsh -n "$launcher"

export HOME="$home" PATH="$fake_bin:$PATH" LAUNCH_LOG="$root/launch.log"
env -i HOME="$HOME" PATH="$PATH" LAUNCH_LOG="$LAUNCH_LOG" zsh "$launcher" untouched arg
test "$(cat "$LAUNCH_LOG")" = launch

cat >"$home/.config/opencode/env.local" <<'EOF'
export SHARED_SETTING=ordinary
export LOCAL_EXPORT=from-env-local
LOCAL_UNEXPORTED=not-exported
EOF
cat >"$home/.config/opencode/secrets.env" <<'EOF'
export SHARED_SETTING=secret-wins
export EXPORTED_SECRET=dummy-secret
UNEXPORTED_SECRET=dummy-unexported
EOF
output=$(env -i HOME="$HOME" PATH="$PATH" LAUNCH_LOG="$LAUNCH_LOG" zsh "$launcher" --check)
grep -Fqx 'SHARED_SETTING=secret-wins' <<<"$output"
grep -Fqx 'EXPORTED_SECRET=dummy-secret' <<<"$output"
grep -Fqx 'UNEXPORTED_SECRET=' <<<"$output"
grep -Fqx 'LOCAL_EXPORT=from-env-local' <<<"$output"
grep -Fqx 'LOCAL_UNEXPORTED=' <<<"$output"
grep -Fqx 'args=--check' <<<"$output"

rm "$home/.config/opencode/secrets.env"
output=$(env -i HOME="$HOME" PATH="$PATH" LAUNCH_LOG="$LAUNCH_LOG" zsh "$launcher" absent)
grep -Fqx 'SHARED_SETTING=ordinary' <<<"$output"
grep -Fqx 'args=absent' <<<"$output"

printf "export EXPORTED_SECRET='dummy-unreadable-secret'\n" >"$home/.config/opencode/secrets.env"
chmod 000 "$home/.config/opencode/secrets.env"
before=$(wc -l <"$LAUNCH_LOG")
if output=$(env -i HOME="$HOME" PATH="$PATH" LAUNCH_LOG="$LAUNCH_LOG" zsh "$launcher" unreadable 2>&1); then
  echo 'unreadable secrets file unexpectedly succeeded' >&2
  exit 1
fi
grep -Fq 'opencode-env: secrets file is not readable' <<<"$output"
! grep -Fq 'dummy-unreadable-secret' <<<"$output"
test "$(wc -l <"$LAUNCH_LOG")" -eq "$before"

chmod 600 "$home/.config/opencode/secrets.env"
cat >"$home/.config/opencode/secrets.env" <<'EOF'
export EXPORTED_SECRET=dummy-failed-source-secret
print 'dummy-source-stdout-marker'
print -u2 'dummy-source-stderr-marker'
return 1
EOF
if output=$(env -i HOME="$HOME" PATH="$PATH" LAUNCH_LOG="$LAUNCH_LOG" zsh "$launcher" failed 2>&1); then
  echo 'failing secrets source unexpectedly succeeded' >&2
  exit 1
fi
grep -Fq 'opencode-env: failed to source secrets file' <<<"$output"
! grep -Fq 'dummy-failed-source-secret' <<<"$output"
! grep -Fq 'dummy-source-stdout-marker' <<<"$output"
! grep -Fq 'dummy-source-stderr-marker' <<<"$output"
test "$(wc -l <"$LAUNCH_LOG")" -eq "$before"
