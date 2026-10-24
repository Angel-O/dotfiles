#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
command_file=$source_dir/.opencode/commands/align-portable-config.md

test -f "$command_file"
grep -Fxq 'agent: orchestrator' <(sed -n '1,5p' "$command_file")

python3 - "$command_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
required = [
    "dot_config/opencode/portable.jsonc.tmpl",
    "dot_config/opencode/cli.json.tmpl",
    "~/.config/opencode/portable.jsonc",
    "~/.config/opencode/cli.json",
    "exactly, including formatting, comments, key ordering",
    "Exclude only secrets, authentication, and provider-local content",
    "managed content, live content",
    "numbered Markdown table",
    "question` tool call containing exactly these two questions",
    "`all`, `none`, `inclusions`, or `exclusions`",
    "same questionnaire",
    "separate explicit confirmation question",
    "~/.local/bin/herdr-agent-launch worker tab <worker-name> <absolute-delivery-worktree-path>",
    "herdr agent prompt <worker-name>",
    "semantic name unique among live agents (including retained completed lanes)",
    "Record the exact name and use it for every subsequent prompt, wait, or correction",
    "retain a suitable same-scope lane",
    "only the selected eligible live content",
    "never edit live configuration",
    "modify no file outside the two matching managed config templates",
    "do not reject a selected discrepancy in those templates merely because its setting concerns an agent or plugin",
    "no alignment was selected and launch no worker",
]
for phrase in required:
    assert phrase in text, phrase

assert text.index("separate explicit confirmation question") < text.index("herdr-agent-launch worker")
assert "Do not open, compare, or reconcile unmanaged `~/.config/opencode/opencode.jsonc`." in text
assert "Ignore formatting" not in text
assert "generated/local state" not in text
assert "semantic discrepancy" not in text
assert text.count("`all`") >= 2
assert text.count("`none`") >= 2
assert text.count("`inclusions`") >= 2
assert text.count("`exclusions`") >= 2
PY

grep -Fqx '.opencode' "$source_dir/.chezmoiignore"
grep -Fqx '.opencode/**' "$source_dir/.chezmoiignore"

cache=${CHEZMOI_TEST_CACHE:-${TMPDIR:-/tmp}/dotfiles-opencode-alignment-cache}
managed=$(chezmoi managed \
  --source "$source_dir" \
  --config "$source_dir/tests/fixtures/personal.toml" \
  --cache "$cache" \
  --exclude externals \
  --include files)
if printf '%s\n' "$managed" | grep -Fq '.opencode/commands/align-portable-config.md'; then
  printf 'project-local command must not be managed by chezmoi\n' >&2
  exit 1
fi
