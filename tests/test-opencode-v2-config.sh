#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
tmp_root=${TMPDIR:?TMPDIR must point to the disposable test root}
root="${tmp_root%/}/opencode/v2-config-test"
config="$root/config"
rm -rf "$root"
mkdir -p "$config/plugins"

cat >"$config/opencode.jsonc" <<'EOF'
{"plugin":["v1-only-plugin"],"permission":{"skill":{"plan-diagrams":"deny"}}}
EOF
cat >"$config/plugins/plan-diagrams.js" <<'EOF'
export default () => ({})
EOF
cat >"$config/plugins/env-protection.js" <<'EOF'
export const V1Only = async () => ({})
EOF
cat >"$config/plugins/herdr-agent-state.js" <<'EOF'
export default { id: "retained.herdr" }
EOF

OPENCODE_V2_CONFIG_DIR="$config" OPENCODE_V2_ROLE=work SOURCE_DIR="$source_dir" \
  bash "$source_dir/scripts/opencode-v2-config.sh"

python3 - "$config" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
def load_jsonc(path):
    return json.loads("\n".join(line for line in path.read_text().splitlines() if not line.lstrip().startswith("//")))

portable = load_jsonc(root / "portable.jsonc")
tui = load_jsonc(root / "tui.jsonc")
assert portable["plugin"] == [
    "@slkiser/opencode-quota@5.0.2",
    "@plannotator/opencode@0.28.2",
]
assert tui["plugin"] == ["./herdr-tui-session.js"]
assert not root.joinpath("opencode.jsonc").exists()
assert not root.joinpath("plugins/plan-diagrams.js").exists()
assert root.joinpath("plugins/herdr-agent-state.js").exists()
PY

for fixture in work personal; do
  managed=$(chezmoi managed --source "$source_dir" --config "$source_dir/tests/fixtures/$fixture.toml" --include files)
  for target in .config/opencode/portable-v2.jsonc .config/opencode/tui-v2.jsonc .config/opencode/plugins-v2/env-protection.js; do
    if printf '%s\n' "$managed" | grep -Fxq -- "$target"; then
      printf 'V2 evaluation asset is managed for %s: %s\n' "$fixture" "$target" >&2
      exit 1
    fi
  done
done

if grep -Eiq 'mermaid|codex|lmstudio|warp|handoff|plan-diagrams|3\.11\.2|v1-only' \
  "$config/portable.jsonc" "$config/tui.jsonc" "$config/plugins"/*; then
  printf 'obsolete V1 declaration survived V2 generation\n' >&2
  exit 1
fi

node --input-type=module - "$config/plugins/env-protection.js" <<'NODE'
import { readFile } from "node:fs/promises";
import process from "node:process";

const source = await readFile(process.argv[2], "utf8");
const plugin = await import(`data:text/javascript,${encodeURIComponent(source)}`);
let before;
await plugin.default.setup({
  tool: {
    hook(name, callback) {
      if (name !== "execute.before") throw new Error(`unexpected hook: ${name}`);
      before = callback;
      return () => {};
    },
  },
});
await before({ tool: "read", input: { filePath: "project/README.md" } });
for (const filePath of ["project/.env", "project/.env.local"]) {
  await before({ tool: "read", input: { filePath } }).then(
    () => { throw new Error(`protected path was allowed: ${filePath}`); },
    (error) => { if (!error.message.includes("Do not read .env files")) throw error; },
  );
}
NODE

printf 'OpenCode V2 configuration tests passed.\n'
