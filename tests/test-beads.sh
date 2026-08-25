#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
root=$2
case_root=$root/beads-installer
enabled=$root/personal-with-beads/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl
disabled=$root/personal/rendered/run_after_15-install-beads-viewer-fork.sh.tmpl
beads_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beads"]["ref"])' "$source_dir/.chezmoidata.toml")
viewer_ref=$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1], "rb"))["pins"]["beadsViewer"]["ref"])' "$source_dir/.chezmoidata.toml")
beads_short=${beads_ref:0:7}
expected_pair="Angel-O/beads@$beads_ref Angel-O/beads_viewer@$viewer_ref"

fail() {
  printf 'beads test: %s\n' "$*" >&2
  exit 1
}

for removed in \
  dot_local/bin/executable_wbd \
  dot_local/bin/executable_wbv \
  scripts/beads-hub-prefix-internal.sh \
  scripts/migrate-beads-hub-prefix.sh \
  scripts/migrate-beads-work-to-hub.sh; do
  test ! -e "$source_dir/$removed" || fail "dotfiles still owns $removed"
done

grep -Fq 'beads_source_repo="Angel-O/beads"' "$enabled"
grep -Fq "beads_wanted_ref=\"$beads_ref\"" "$enabled"
grep -Fq 'viewer_source_repo="Angel-O/beads_viewer"' "$enabled"
grep -Fq "viewer_wanted_ref=\"$viewer_ref\"" "$enabled"
grep -Fq 'if [ "$resolved_ref" != "$wanted_ref" ]' "$enabled"
grep -Fq 'CGO_ENABLED=1 go build -trimpath -tags gms_pure_go' "$enabled"
grep -Fq -- '-ldflags "-X main.Build=$beads_build" -o "$tmp/bd" ./cmd/bd' "$enabled"
for command in bv wbd wbv; do
  grep -Fq 'go build -trimpath -o "$tmp/$command" "./cmd/$command"' "$enabled"
done
for script in beads-hub-prefix-internal.sh migrate-beads-hub-prefix.sh migrate-beads-work-to-hub.sh; do
  grep -Fq 'cp "$tmp/viewer/scripts/$script" "$target_tmp"' "$enabled"
done
grep -Fq 'libexec_dir=$HOME/.local/libexec/beads-viewer' "$enabled"
grep -Fq 'mv "$target_tmp" "$bin_dir/$command"' "$enabled"
grep -Fq 'mv "$target_tmp" "$libexec_dir/$script"' "$enabled"
grep -Fq 'exit 0' "$disabled"
! grep -Fq 'Angel-O/beads_viewer' "$disabled" || fail 'disabled installer contains fork configuration'
! grep -Fq 'Angel-O/beads' "$disabled" || fail 'disabled installer contains Beads fork configuration'

# Exercise the rendered installer without a network or a real Go build.
mkdir -p "$case_root/bin" "$case_root/home" "$case_root/beads/cmd/bd" \
  "$case_root/viewer/scripts"
for command in bv wbd wbv; do
  mkdir -p "$case_root/viewer/cmd/$command"
done
for script in beads-hub-prefix-internal.sh migrate-beads-hub-prefix.sh migrate-beads-work-to-hub.sh; do
  printf '#!/bin/sh\nprintf "viewer script: %s\\n"\n' "$script" >"$case_root/viewer/scripts/$script"
done
cat >"$case_root/bin/git" <<'EOF'
#!/bin/sh
[ "${FAKE_GIT_FAIL:-0}" != 1 ] || exit 91
if [ "$1" = clone ]; then
  source=
  for argument do
    case "$argument" in
      https://github.com/Angel-O/beads.git) source=$FAKE_BEADS_SOURCE ;;
      https://github.com/Angel-O/beads_viewer.git) source=$FAKE_VIEWER_SOURCE ;;
    esac
    destination=$argument
  done
  cp -R "$source" "$destination"
elif [ "$1" = -C ] && [ "$3" = rev-parse ]; then
  case "$2" in
    */beads) ref=$FAKE_BEADS_REF ;;
    */viewer) ref=$FAKE_VIEWER_REF ;;
  esac
  if [ "${4:-}" = --short ]; then
    printf '%.7s\n' "$ref"
  else
    printf '%s\n' "$ref"
  fi
fi
EOF
cat >"$case_root/bin/go" <<'EOF'
#!/bin/sh
original_args=$*
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then
    output=$2
    break
  fi
  shift
done
printf '%s|%s|%s\n' "$PWD" "${CGO_ENABLED:-}" "$original_args" >>"$FAKE_GO_LOG"
printf '#!/bin/sh\nprintf "viewer binary: %s\\n"\n' "${output##*/}" >"$output"
chmod 0755 "$output"
EOF
chmod +x "$case_root/bin/git" "$case_root/bin/go"
HOME=$case_root/home PATH=$case_root/bin:/usr/bin:/bin \
  FAKE_BEADS_SOURCE=$case_root/beads FAKE_BEADS_REF=$beads_ref \
  FAKE_VIEWER_SOURCE=$case_root/viewer FAKE_VIEWER_REF=$viewer_ref \
  FAKE_GO_LOG=$case_root/go.log sh "$enabled"

for command in bd bv wbd wbv; do
  test -x "$case_root/home/.local/bin/$command"
  test "$("$case_root/home/.local/bin/$command")" = "viewer binary: $command"
done
grep -Fq "$case_root/beads|1|build -trimpath -tags gms_pure_go -ldflags -X main.Build=$beads_short -o" "$case_root/go.log"
for script in beads-hub-prefix-internal.sh migrate-beads-hub-prefix.sh migrate-beads-work-to-hub.sh; do
  deployed=$case_root/home/.local/libexec/beads-viewer/$script
  test -x "$deployed"
  test "$("$deployed")" = "viewer script: $script"
done
test "$(cat "$case_root/home/.local/share/beads-viewer-fork/installed-ref")" = \
  "$expected_pair"
test ! -e "$case_root/home/.local/bin/wbd.sh"
HOME=$case_root/home PATH=$case_root/bin:/usr/bin:/bin FAKE_GIT_FAIL=1 \
  FAKE_BEADS_SOURCE=$case_root/beads FAKE_BEADS_REF=$beads_ref \
  FAKE_VIEWER_SOURCE=$case_root/viewer FAKE_VIEWER_REF=$viewer_ref \
  FAKE_GO_LOG=$case_root/go.log sh "$enabled"

# Optional cross-repository contract path; the caller supplies the checkout.
if [ -n "${BEADS_SOURCE:-}" ]; then
  test -d "$BEADS_SOURCE/cmd/bd"
  mkdir -p "$case_root/contract-bin"
  source_ref=$(git -C "$BEADS_SOURCE" rev-parse --short HEAD)
  (cd "$BEADS_SOURCE" && CGO_ENABLED=1 go build -trimpath -tags gms_pure_go \
    -ldflags "-X main.Build=$source_ref" -o "$case_root/contract-bin/bd" ./cmd/bd)
  test -x "$case_root/contract-bin/bd"
  "$case_root/contract-bin/bd" --version >/dev/null
fi

if [ -n "${BEADS_VIEWER_SOURCE:-}" ]; then
  test -d "$BEADS_VIEWER_SOURCE/cmd/bv"
  test -d "$BEADS_VIEWER_SOURCE/cmd/wbd"
  test -d "$BEADS_VIEWER_SOURCE/cmd/wbv"
  for skill in beads-hub beads-hub-closeout; do
    test -f "$BEADS_VIEWER_SOURCE/skills/$skill/SKILL.md"
  done
  test -x "$BEADS_VIEWER_SOURCE/skills/beads-hub-closeout/validate.sh"
  for script in beads-hub-prefix-internal.sh migrate-beads-hub-prefix.sh migrate-beads-work-to-hub.sh; do
    test -f "$BEADS_VIEWER_SOURCE/scripts/$script"
  done
  mkdir -p "$case_root/contract-bin"
  for command in bv wbd wbv; do
    (cd "$BEADS_VIEWER_SOURCE" && go build -trimpath -o "$case_root/contract-bin/$command" "./cmd/$command")
    test -x "$case_root/contract-bin/$command"
  done
  "$case_root/contract-bin/bv" --version >/dev/null
  if "$case_root/contract-bin/wbd" >"$case_root/wbd.out" 2>&1; then
    fail 'wbd accepted an empty invocation'
  fi
  grep -Fq 'supported commands:' "$case_root/wbd.out"
  if "$case_root/contract-bin/wbv" --unsupported >"$case_root/wbv.out" 2>&1; then
    fail 'wbv accepted an unsupported invocation'
  fi
  grep -Fq 'unsupported Viewer invocation' "$case_root/wbv.out"
fi
