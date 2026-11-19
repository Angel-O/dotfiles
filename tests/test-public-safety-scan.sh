#!/usr/bin/env bash
set -Eeuo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
scanner="$repo/tests/check-public-safety.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fixture=$tmp/fixture
mkdir -p "$fixture"
git -C "$fixture" init -q
git -C "$fixture" config user.name test
git -C "$fixture" config user.email test@example.invalid
: >"$tmp/empty-config"

run_scanner() {
  local global_config=$1
  (
    unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
    GIT_CONFIG_GLOBAL="$global_config" bash "$scanner" "$fixture"
  )
}

match='/Us'"ers"'/synthetic'
mkdir -p "$fixture/cache"
printf '%s\n' "$match" >"$fixture/cache/symbols"
printf '%s\n' 'cache/' '*.iml' >"$fixture/.gitignore"
if run_scanner "$tmp/empty-config"; then
  :
else
  printf 'ignored cache unexpectedly failed the public-safety scan\n' >&2
  exit 1
fi

printf '%s\n' '*.iml' >"$fixture/.gitignore"
printf '%s\n' 'cache/' >"$tmp/global-ignore"
git config --file "$tmp/gitconfig" core.excludesFile "$tmp/global-ignore"
if run_scanner "$tmp/gitconfig"; then
  :
else
  printf 'globally ignored cache unexpectedly failed the public-safety scan\n' >&2
  exit 1
fi

printf '%s\n' 'cache/' '*.iml' >"$fixture/.gitignore"
mkdir -p "$fixture/.idea"
printf '%s\n' "$match" >"$fixture/.idea/secret.iml"
git -C "$fixture" add -f .idea/secret.iml
if run_scanner "$tmp/empty-config"; then
  printf 'tracked ignored IDE file unexpectedly passed the public-safety scan\n' >&2
  exit 1
fi

git -C "$fixture" rm --cached -q .idea/secret.iml
rm "$fixture/.idea/secret.iml"
printf '%s\n' "$match" >"$fixture/candidate.txt"
if run_scanner "$tmp/empty-config"; then
  printf 'non-ignored untracked file unexpectedly passed the public-safety scan\n' >&2
  exit 1
fi

printf 'public-safety scan fixtures passed\n'
