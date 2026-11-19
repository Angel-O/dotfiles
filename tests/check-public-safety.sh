#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=$1
safety_pattern='(/'"Users/|1628"'1580|Opa'"rah|8f84"'64|sk-[A-Za-z0-9]{16,})'
found_match=false

if git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    if grep -E "$safety_pattern" "$source_dir/$file" >/dev/null 2>&1; then
      found_match=true
      break
    fi
  done < <(git -C "$source_dir" ls-files --cached --others --exclude-standard -z)
else
  if grep -R -E --exclude-dir=.git --exclude=.git --exclude-dir=.idea \
    --exclude='*.iml' "$safety_pattern" "$source_dir" >/dev/null; then
    found_match=true
  fi
fi

if $found_match; then
  printf 'public-safety scan found a personal path, identifier, or credential-like value.\n' >&2
  exit 1
fi
