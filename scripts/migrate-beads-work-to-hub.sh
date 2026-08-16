#!/bin/bash
set -euo pipefail

old_parent=$HOME/.local/share/beads/work
old_store=$old_parent/.beads
old_ledger=$old_parent/correlations.jsonl
issues_export=$old_store/issues.jsonl
interactions=$old_store/interactions.jsonl
last_touched=$old_store/last-touched
old_config=$HOME/.config/bv/work-beads.yaml
new_parent=$HOME/.local/share/beads/hub
new_store=$new_parent/.beads
new_ledger=$new_parent/correlations.jsonl
new_config=$HOME/.config/bv/hub.yaml
backup=$HOME/.local/share/beads/work-to-hub-backup-$(date +%Y%m%d%H%M%S)

die() {
  printf 'migrate-beads-work-to-hub: %s\n' "$*" >&2
  exit 1
}

valid_prefix() {
  local prefix=$1
  case "$prefix" in *--*) return 1 ;; esac
  [ "${#prefix}" -le 32 ] && [[ $prefix =~ ^[a-z]([a-z0-9-]{0,30}[a-z0-9])?$ ]]
}

command -v bd >/dev/null 2>&1 || die 'required command not found: bd'
command -v jq >/dev/null 2>&1 || die 'required command not found: jq'
[ -d "$old_store" ] && [ ! -L "$old_parent" ] || die "legacy store is missing or invalid: $old_store"
[ -f "$old_config" ] && [ ! -L "$old_config" ] || die "legacy config is missing or invalid: $old_config"
if [ -e "$issues_export" ] || [ -L "$issues_export" ]; then
  [ -f "$issues_export" ] && [ ! -L "$issues_export" ] || die "legacy issues export is invalid: $issues_export"
fi
ledger_exists=false
if [ -e "$old_ledger" ] || [ -L "$old_ledger" ]; then
  [ -f "$old_ledger" ] && [ ! -L "$old_ledger" ] || die "legacy ledger is invalid: $old_ledger"
  ledger_exists=true
fi
interactions_exists=false
if [ -e "$interactions" ] || [ -L "$interactions" ]; then
  [ -f "$interactions" ] && [ ! -L "$interactions" ] || die "legacy interactions file is invalid: $interactions"
  interactions_exists=true
fi
last_touched_rewrite=false
if [ -e "$last_touched" ] || [ -L "$last_touched" ]; then
  [ -f "$last_touched" ] && [ ! -L "$last_touched" ] || die "legacy last-touched file is invalid: $last_touched"
  last_touched_value=$(<"$last_touched")
  if [[ $last_touched_value =~ ^work-[^[:space:]]+$ ]]; then
    last_touched_rewrite=true
  fi
fi
[ ! -e "$new_parent" ] && [ ! -L "$new_parent" ] || die "hub destination already exists: $new_parent"
[ ! -e "$new_config" ] && [ ! -L "$new_config" ] || die "hub config already exists: $new_config"
[ ! -e "$backup" ] || die "backup destination already exists: $backup"

printf '%s\n' \
  'Choose the store-wide prefix for every Beads ID in the Hub. Changing it later requires another migration.' >&2
while true; do
  printf 'Target Beads prefix [bead]: ' >&2
  if ! IFS= read -r target_prefix; then
    printf '\n' >&2
    die 'end of input while reading target prefix'
  fi
  target_prefix=${target_prefix:-bead}
  if valid_prefix "$target_prefix"; then
    break
  fi
  printf '%s\n' \
    'Invalid prefix: use 1-32 lowercase ASCII letters, digits, or hyphens; start with a letter, end with a letter or digit, and do not use consecutive hyphens.' >&2
done

umask 077
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/migrate-beads-work-to-hub.XXXXXX")
config_tmp=$tmp_dir/hub.yaml
ledger_tmp=$tmp_dir/correlations.jsonl
interactions_tmp=$tmp_dir/interactions.jsonl
last_touched_tmp=$tmp_dir/last-touched
trap 'rm -rf "$tmp_dir"' EXIT

jq -e \
  --arg old_store "$old_store" \
  --arg old_ledger "$old_ledger" \
  --arg store "$new_store" \
  --arg ledger "$new_ledger" '
  if type != "object" or .version != 1 or
     .store != $old_store or .ledger != $old_ledger or
     (.repositories | type) != "object" then
    error("invalid legacy config")
  else
    .store = $store | .ledger = $ledger
  end
' "$old_config" >"$config_tmp" || die "cannot rewrite legacy config: $old_config"

if $ledger_exists; then
  jq -c --arg target_prefix "$target_prefix-" '
    if (.bead_id | type) == "string" and (.bead_id | startswith("work-")) then
      .bead_id = ($target_prefix + (.bead_id | ltrimstr("work-")))
    else
      .
    end
  ' "$old_ledger" >"$ledger_tmp" || die "cannot rewrite legacy ledger: $old_ledger"
  chmod 0600 "$ledger_tmp"
fi

if $interactions_exists; then
  jq -c --arg target_prefix "$target_prefix-" '
    if (.issue_id | type) == "string" and (.issue_id | startswith("work-")) then
      .issue_id = ($target_prefix + (.issue_id | ltrimstr("work-")))
    else
      .
    end
  ' "$interactions" >"$interactions_tmp" || die "cannot rewrite legacy interactions: $interactions"
  chmod 0600 "$interactions_tmp"
fi

if $last_touched_rewrite; then
  printf '%s-%s\n' "$target_prefix" "${last_touched_value#work-}" >"$last_touched_tmp"
  chmod 0600 "$last_touched_tmp"
fi

mkdir "$backup"
cp -R "$old_parent" "$backup/work"
cp "$old_config" "$backup/work-beads.yaml"

env \
  -u BD_DB \
  -u BEADS_DB \
  -u BD_GLOBAL \
  -u BEADS_DOLT_DATA_DIR \
  -u BEADS_DOLT_PORT \
  -u BEADS_DOLT_PROXIED_SERVER \
  -u BEADS_DOLT_SERVER_DATABASE \
  -u BEADS_DOLT_SERVER_HOST \
  -u BEADS_DOLT_SERVER_MODE \
  -u BEADS_DOLT_SERVER_PORT \
  -u BEADS_DOLT_SERVER_SOCKET \
  -u BEADS_DOLT_SHARED_SERVER \
  BEADS_DIR="$old_store" \
  bd --db "$old_store" rename-prefix "$target_prefix"
env \
  -u BD_DB \
  -u BEADS_DB \
  -u BD_GLOBAL \
  -u BEADS_DOLT_DATA_DIR \
  -u BEADS_DOLT_PORT \
  -u BEADS_DOLT_PROXIED_SERVER \
  -u BEADS_DOLT_SERVER_DATABASE \
  -u BEADS_DOLT_SERVER_HOST \
  -u BEADS_DOLT_SERVER_MODE \
  -u BEADS_DOLT_SERVER_PORT \
  -u BEADS_DOLT_SERVER_SOCKET \
  -u BEADS_DOLT_SHARED_SERVER \
  BEADS_DIR="$old_store" \
  bd --db "$old_store" export -o "$issues_export"
if $ledger_exists; then
  mv "$ledger_tmp" "$old_ledger"
fi
if $interactions_exists; then
  mv "$interactions_tmp" "$interactions"
fi
if $last_touched_rewrite; then
  mv "$last_touched_tmp" "$last_touched"
fi
mv "$old_parent" "$new_parent"
chmod 0600 "$config_tmp"
mv "$config_tmp" "$new_config"
rm "$old_config"

printf 'Migrated work-* to %s-* in %s\n' "$target_prefix" "$new_store"
printf 'Hub config: %s\n' "$new_config"
printf 'Backup: %s\n' "$backup"
