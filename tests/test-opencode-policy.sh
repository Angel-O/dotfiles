#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}

python3 - "$source_dir/dot_config/opencode/agents/orchestrator.md.tmpl" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
frontmatter = text.split("---", 2)[1]
permissions = frontmatter.split("permissions:", 1)[1]
actual = [
    match.groups()
    for match in re.finditer(
        r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
        permissions,
        re.MULTILINE,
    )
]
assert actual == [
    ('"*"', '"*"', "deny"),
    ("external_directory", '"*"', "allow"),
    ("question", '"*"', "allow"),
    ("shell", '"*"', "allow"),
    ("orchestration_tracking", '"*"', "allow"),
    ("read", '"*"', "allow"),
    ("glob", '"*"', "allow"),
    ("grep", '"*"', "allow"),
    ("subagent", '"*"', "deny"),
    ("subagent", "integration", "allow"),
    ("subagent", "investigator", "allow"),
    ("subagent", "reviewer", "allow"),
    ("webfetch", '"*"', "allow"),
    ("todowrite", '"*"', "allow"),
    ("skill", '"*"', "allow"),
    ("quota_status", '"*"', "allow"),
    ("handoff_session", '"*"', "allow"),
    ("read_session", '"*"', "allow"),
]
assert text.count("  - action: orchestration_tracking\n    resource: \"*\"\n    effect: allow") == 1
assert "  - action: tool\n" not in frontmatter
PY

python3 - "$source_dir/dot_config/opencode/agents/architect.md.tmpl" <<'PY'
import re
import sys
from fnmatch import fnmatchcase
from pathlib import Path

text = Path(sys.argv[1]).read_text()
frontmatter = text.split("---", 2)[1]
permissions = [
    match.groups()
    for match in re.finditer(
        r'^  - action: (.+)\n    resource: (.+)\n    effect: (.+)$',
        frontmatter.split("permissions:", 1)[1],
        re.MULTILINE,
    )
]
rules = [
    (action.strip('"'), resource.strip('"'), effect)
    for action, resource, effect in permissions
]
assert ("*", "*", "deny") in rules
assert ("shell", "*", "deny") in rules
assert ("shell", "wbd list --json", "allow") in rules
assert ("shell", "wbd list --json *", "allow") in rules
assert ("shell", "wbd list * --json", "allow") in rules
assert ("shell", "wbd list * --json *", "allow") in rules
assert ("shell", "wbd scope show * --json", "allow") in rules
assert ("shell", "wbd scope show * --json *", "allow") in rules

shell_allows = [
    resource
    for action, resource, effect in rules
    if action == "shell" and effect == "allow"
]

def allowed(command):
    return any(fnmatchcase(command, pattern) for pattern in shell_allows)

allowed_reads = (
    "wbd list --paginate --limit 50 --sort updated_at:desc --brief --json",
    "wbd list --brief --json --paginate --limit 50 --sort updated_at:desc",
    "wbd list --paginate --limit 50 --sort updated_at:desc --cursor opaque-cursor --brief --json",
    "wbd list --json",
    "wbd list --json --paginate --limit 50 --sort updated_at:desc --brief",
    "wbd list --json --paginate --limit 50 --sort updated_at:desc --cursor opaque-cursor --brief",
    "wbd scope show active --json",
    "wbd scope show example-scope --json --paginate --limit 50",
    "wbd scope show example-scope --json --paginate --limit 50 --cursor opaque-cursor",
)
for command in allowed_reads:
    assert allowed(command), command

for command in (
    "wbd scope active --json",
    "wbd scope add bead-123 --json",
    "wbd create 'example' --type task --json",
    "wbd dep add child parent --type parent-child --json",
):
    assert allowed(command), command

for command in (
    "wbd list --paginate --limit 50 --sort updated_at:desc --brief",
    "wbd scope show active",
    "wbd scope activate viewer-harmony --json",
    "wbd scope remove bead-123 --json",
    "wbd claim bead-123 --json",
    "git status",
    "echo unrelated",
):
    assert not allowed(command), command

# Existing publication permissions remain explicit and unchanged.
assert ("shell", "wbd scope add *", "allow") in rules
assert ("shell", "wbd dep add *", "allow") in rules
PY
