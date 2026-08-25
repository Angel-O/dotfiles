#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
image=portable-dotfiles-test

docker build --tag "$image" --file "$repo/tests/Dockerfile" "$repo"
docker run --rm --volume "$repo:/src:ro" \
  --env GIT_CONFIG_COUNT=1 \
  --env GIT_CONFIG_KEY_0=safe.directory \
  --env GIT_CONFIG_VALUE_0=/src \
  "$image"
