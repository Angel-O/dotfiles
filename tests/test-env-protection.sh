#!/usr/bin/env bash
set -euo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}

python3 - "$source_dir/dot_config/opencode/plugins/env-protection.js" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()

assert 'setup: async (context) => context.tool.hook' not in source
assert 'const registration = await context.tool.hook("execute.before", async (event) => {' in source
assert 'return () => registration.dispose()' in source
assert source.count('registration.dispose()') == 1
assert 'if (event.tool === "read" && JSON.stringify(event.input ?? "").includes(".env")) {' in source
assert 'throw new Error("Do not read .env files")' in source
PY
