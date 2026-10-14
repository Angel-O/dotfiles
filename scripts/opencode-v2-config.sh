#!/usr/bin/env bash
set -Eeuo pipefail

# Render only inside the disposable V2 runtime. The existing portable.jsonc,
# tui.jsonc, and local plugins remain the V1 source of truth.

readonly SOURCE_DIR=${SOURCE_DIR:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}
readonly TMP_ROOT=${TMPDIR:-/tmp}
readonly TMP_BASE=${TMP_ROOT%/}
readonly OUTPUT_DIR=${OPENCODE_V2_CONFIG_DIR:?OPENCODE_V2_CONFIG_DIR is required}
readonly ROLE=${OPENCODE_V2_ROLE:-work}

die() { printf 'opencode-v2-config: %s\n' "$*" >&2; exit 1; }

case "$OUTPUT_DIR" in
  "$TMP_BASE"/opencode/*) ;;
  *) die 'OPENCODE_V2_CONFIG_DIR must be below TMPDIR/opencode' ;;
esac
case "$ROLE" in
  personal|work) ;;
  *) die 'OPENCODE_V2_ROLE must be personal or work' ;;
esac

fixture="$SOURCE_DIR/tests/fixtures/$ROLE.toml"
test -f "$fixture" || die "missing fixture: $fixture"
command -v chezmoi >/dev/null 2>&1 || die 'chezmoi is required to render V2 configuration'

mkdir -p "$OUTPUT_DIR/plugins"
chezmoi execute-template --source "$SOURCE_DIR" --config "$fixture" \
  <"$SOURCE_DIR/dot_config/opencode/portable-v2.jsonc.tmpl" \
  >"$OUTPUT_DIR/portable.jsonc"
chezmoi execute-template --source "$SOURCE_DIR" --config "$fixture" \
  <"$SOURCE_DIR/dot_config/opencode/tui-v2.jsonc.tmpl" \
  >"$OUTPUT_DIR/tui.jsonc"

# The copied global/V1 config and V1-only local Plan plugin must not participate
# in this runtime. Herdr's generated plugin is intentionally retained.
rm -f "$OUTPUT_DIR/opencode.jsonc" "$OUTPUT_DIR/plugins/plan-diagrams.js"
cp "$SOURCE_DIR/dot_config/opencode/plugins-v2/env-protection.js" \
  "$OUTPUT_DIR/plugins/env-protection.js"
