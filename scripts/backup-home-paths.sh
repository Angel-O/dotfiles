#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
paths_file="$script_dir/backup-paths.txt"
destination="$HOME/chezmoi-backup-$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage: backup-home-paths.sh [--paths-file FILE] [--destination DIRECTORY]

Back up existing paths listed one per line, relative to $HOME. Blank lines and
lines beginning with # are ignored.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --paths-file)
      [ "$#" -ge 2 ] || { printf '%s\n' '--paths-file requires a value.' >&2; exit 2; }
      paths_file=$2
      shift 2
      ;;
    --destination)
      [ "$#" -ge 2 ] || { printf '%s\n' '--destination requires a value.' >&2; exit 2; }
      destination=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -f "$paths_file" ] || { printf 'Path list not found: %s\n' "$paths_file" >&2; exit 1; }
[ ! -e "$destination" ] || { printf 'Destination already exists: %s\n' "$destination" >&2; exit 1; }

mkdir -p "$destination"
copied=0

while IFS= read -r path || [ -n "$path" ]; do
  case "$path" in
    ''|'#'*) continue ;;
    /*|..|../*|*/..|*/../*)
      printf 'Path must be relative to HOME and cannot contain ..: %s\n' "$path" >&2
      exit 1
      ;;
  esac

  source_path="$HOME/$path"
  if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
    continue
  fi

  target_path="$destination/$path"
  mkdir -p "$(dirname -- "$target_path")"
  cp -a "$source_path" "$target_path"
  printf 'Backed up %s\n' "$source_path"
  copied=$((copied + 1))
done <"$paths_file"

printf 'Backup complete: %s path(s) copied to %s\n' "$copied" "$destination"
