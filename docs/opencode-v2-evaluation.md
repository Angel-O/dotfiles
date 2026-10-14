# OpenCode V2 evaluation

This disposable workflow evaluates migration mechanics without changing the
working V1 runtime. It builds and runs the exact OpenCode V2 `2.0.28` source
candidate (commit
`026b106bc5d41b679ffc413264229c340871e4d3`) below `${TMPDIR%/}/opencode`,
using dedicated XDG roots plus `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`.

## Reproducible workflow

Use one disposable root for the complete trial:

```sh
export OPENCODE_EVAL_ROOT="${TMPDIR%/}/opencode/v2-evaluation"
wrapper="./scripts/opencode-v2-evaluation.sh"

bash "$wrapper" install
bash "$wrapper" prepare
bash "$wrapper" diagnose
bash "$wrapper" convert-cli       # explicit sandbox-only conversion
bash "$wrapper" run auth login    # authenticate in the disposable runtime
bash "$wrapper" run --standalone --format json --model openai/gpt-5.4-mini \
  'Return exactly V2_EVAL_MODEL_OK.' >"$OPENCODE_EVAL_ROOT/evidence/provider-turn.json"
bash "$wrapper" check
```

Every V2 process runs through the wrapper and fails unless the candidate
reports exactly `2.0.28`. `prepare` copies V1 configuration and file-based
artifacts into the sandbox and creates a consistent online SQLite backup of
the live session database when present; it does not copy the database or its
WAL/SHM sidecars directly. Fingerprints record that V1 configuration, data,
state, cache, database, and sidecars were not written. Evidence contains
paths, versions, warnings, and outcomes, not transcript contents or
credentials.

`diagnose` records resolved configuration and required file-based artifact
discovery. It also proves that copied `tui.jsonc` is not automatically
migrated. `convert-cli` then performs the explicit sandbox-only conversion;
its output is evidence and never authorizes a production rewrite. The
authenticated turn proves provider access and model selection in isolation.

Copied V1 plugin declarations exposed V2-contract failures. Plugin
compatibility or removal is deferred to the existing next migration child;
this evaluation does not qualify third-party plugin behavior or implement
plugin fixes.

## Evidence and rollback

`check` verifies that V2 paths and database sidecars remain below the
disposable data root and that the V1 fingerprints remain unchanged. Keep the
V1 binary, launcher, configuration, and runtime paths as the rollback path;
never start V1 against V2-migrated data. Native fork evidence, when retained
from the completed trial, represents conversational branching and not
Handoff.

Clean only the disposable evaluation after preserving any needed evidence:

```sh
rm -rf -- "$OPENCODE_EVAL_ROOT"
```

The focused wrapper contract test is:

```sh
bash tests/test-opencode-v2-evaluation.sh
```
