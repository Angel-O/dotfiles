#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}

python3 - "$source_dir/dot_config/opencode/agents/orchestrator.md" <<'PY'
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
