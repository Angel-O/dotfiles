#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
image=portable-dotfiles-test

docker build --tag "$image" --file "$repo/tests/Dockerfile" "$repo"
global_excludes=$(git config --global --path --get core.excludesFile 2>/dev/null || true)
if [ -z "$global_excludes" ]; then
  global_excludes=${XDG_CONFIG_HOME:-"$HOME/.config"}/git/ignore
fi
case "$global_excludes" in
  /*) ;;
  *) global_excludes=$repo/$global_excludes ;;
esac

global_ignore=/dev/null
set -- --rm --volume "$repo:/src:ro"
if [ -f "$repo/.git" ]; then
  git_dir=$(git -C "$repo" rev-parse --absolute-git-dir)
  common_dir=$(git -C "$repo" rev-parse --git-common-dir)
  case "$common_dir" in
    /*) ;;
    *) common_dir=$repo/$common_dir ;;
  esac
  common_dir=$(CDPATH= cd -- "$common_dir" && pwd)
  set -- "$@" --volume "$git_dir:$git_dir:ro" --volume "$common_dir:$common_dir:ro"
fi
if [ -f "$global_excludes" ]; then
  global_ignore=/host-global-ignore
  set -- "$@" --volume "$global_excludes:$global_ignore:ro"
fi
set -- "$@" \
  --env GIT_CONFIG_COUNT=2 \
  --env GIT_CONFIG_KEY_0=safe.directory \
  --env GIT_CONFIG_VALUE_0=/src \
  --env GIT_CONFIG_KEY_1=core.excludesFile \
  --env "GIT_CONFIG_VALUE_1=$global_ignore" \
  "$image"
docker run "$@"
