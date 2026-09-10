#!/usr/bin/env bash
set -euo pipefail

if [ -n "${1:-}" ]; then
  printf '%s\n' "$1"
  exit 0
fi
if [ -n "${HERDR_EXPLORER_DIR:-}" ]; then
  printf '%s\n' "$HERDR_EXPLORER_DIR"
  exit 0
fi
if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
  DIR="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '
    def nonempty($value):
      if ($value | type) == "string" then
        if ($value | length) > 0 then $value else empty end
      else empty
      end;
    try (first(nonempty(.focused_pane_cwd), nonempty(.workspace_cwd)) // empty) catch empty
  ' || :)"
  if [ -n "$DIR" ]; then
    printf '%s\n' "$DIR"
    exit 0
  fi
fi
pwd
