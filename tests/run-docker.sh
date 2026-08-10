#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
image=portable-dotfiles-test

docker build --tag "$image" --file "$repo/tests/Dockerfile" "$repo"
docker run --rm --volume "$repo:/src:ro" "$image"
