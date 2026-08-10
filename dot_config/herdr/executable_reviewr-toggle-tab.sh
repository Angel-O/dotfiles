#!/bin/sh
set -eu

herdr=${HERDR_BIN_PATH:-herdr}
workspace=${HERDR_ACTIVE_WORKSPACE_ID:?}
cwd=${HERDR_ACTIVE_PANE_CWD:?}

panes=$("$herdr" pane list --workspace "$workspace")
existing=$(printf '%s' "$panes" | jq -r '[.result.panes[] | select(.label == "reviewr") | .pane_id][0] // empty')
if [ -n "$existing" ]; then
  "$herdr" pane close "$existing" >/dev/null
  exit 0
fi

opened=$("$herdr" plugin pane open \
  --plugin persiyanov.reviewr \
  --entrypoint pane \
  --placement tab \
  --workspace "$workspace" \
  --cwd "$cwd" \
  --focus)
tab=$(printf '%s' "$opened" | jq -r '.result.plugin_pane.pane.tab_id // empty')
[ -n "$tab" ] && "$herdr" tab rename "$tab" reviewr >/dev/null
