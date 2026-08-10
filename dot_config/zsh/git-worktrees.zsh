alias gwtl='git wtl'
alias gwtp='git wtp'
alias gwtrm='git wtrm'

_gwt_main_path() {
  command git rev-parse --git-common-dir >/dev/null || return
  command git worktree list --porcelain | command awk '/^worktree / { print substr($0, 10); exit }'
}

_gwt_path_for_branch() {
  command git rev-parse --git-common-dir >/dev/null || return
  command git for-each-ref --format='%(worktreepath)' "refs/heads/$1"
}

_gwt_branch_slug() {
  local slug
  slug=$(printf '%s' "$1" | LC_ALL=C command tr '[:upper:]' '[:lower:]' | command sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  printf '%s\n' "${slug:-worktree}"
}

_gwt_default_path() {
  local main repo slug
  main=$(_gwt_main_path) || return
  repo="${main:t}"
  slug=$(_gwt_branch_slug "$1") || return
  printf '%s\n' "$HOME/workspace/worktrees/$repo/$slug"
}

cdwt() {
  local worktree_path
  worktree_path=$(_gwt_path_for_branch "$1") || return
  if [[ -z "$worktree_path" ]]; then
    printf 'cdwt: no worktree found for branch %s\n' "$1" >&2
    return 1
  fi
  cd "$worktree_path" || return
}

cdmain() {
  local main
  main=$(_gwt_main_path) || return
  cd "$main" || return
}

gwtco() {
  local branch worktree_path
  if [[ "$1" == "-b" ]]; then
    branch="$2"
  else
    branch="$1"
  fi
  if [[ -z "$branch" ]]; then
    printf 'usage: gwtco [-b] <branch> [base]\n' >&2
    return 1
  fi
  worktree_path=$(_gwt_path_for_branch "$branch") || return
  if [[ -n "$worktree_path" ]]; then
    cd "$worktree_path" || return
    return
  fi
  worktree_path=$(_gwt_default_path "$branch") || return
  command git wtco "$@" || return
  cd "$worktree_path" || return
}

gwts() {
  local selected worktree_path fzf_bin
  if command -v fzf >/dev/null 2>&1; then
    fzf_bin=$(command -v fzf)
  elif [[ -x /opt/homebrew/bin/fzf ]]; then
    fzf_bin=/opt/homebrew/bin/fzf
  else
    printf 'gwts: fzf is not installed. Install it with: brew install fzf\n' >&2
    return 1
  fi
  selected=$(
    command git worktree list --porcelain | command awk '
      /^worktree / { path = substr($0, 10) }
      /^branch / {
        branch = $2
        sub(/^refs\/heads\//, "", branch)
        printf "%s\t%s\n", branch, path
      }
      /^detached$/ { printf "(detached)\t%s\n", path }
    ' | "$fzf_bin" \
      --height=~10 \
      --reverse \
      --border \
      --prompt='Worktree> ' \
      --info='inline-right:?: toggle preview  ' \
      --no-separator \
      --bind 'pgup:preview-page-up,pgdn:preview-page-down,ctrl-u:preview-up,ctrl-d:preview-down,?:toggle-preview' \
      --delimiter=$'\t' \
      --with-nth=1 \
      --preview-window='right:60%' \
      --preview-label=' ctrl-u/d: scroll preview ' \
      --preview 'printf "Path: %s\n\n" {2}; git -C {2} status --short --branch'
  ) || return
  worktree_path="${selected#*$'\t'}"
  cd "$worktree_path" || return
}
