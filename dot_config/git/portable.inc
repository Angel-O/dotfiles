[core]
	editor = code -n --wait
	excludesfile = ~/.gitignore_global
[diff]
	tool = vscode
[difftool "vscode"]
	cmd = code -n --wait --diff $LOCAL $REMOTE
[merge]
	tool = vscode
[mergetool "vscode"]
	cmd = code -n --wait $MERGED
[alias]
	wt = worktree
	wtl = worktree list
	wtp = worktree prune
	wtrm = "!f() { branch=$1; if [ -z \"$branch\" ]; then printf 'usage: git wtrm <branch>\\n' >&2; return 1; fi; path=$(git for-each-ref --format='%(worktreepath)' \"refs/heads/$branch\"); if [ -z \"$path\" ]; then printf 'wtrm: no worktree found for branch %s\\n' \"$branch\" >&2; return 1; fi; git worktree remove \"$path\"; }; f"
	wtco = "!f() { main=$(git worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }'); repo=$(basename \"$main\"); if [ \"$1\" = \"-b\" ]; then branch=$2; base=${3:-origin/main}; else branch=$1; fi; if [ -z \"$branch\" ]; then printf 'usage: git wtco [-b] <branch> [base]\\n' >&2; return 1; fi; slug=$(printf '%s' \"$branch\" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'); slug=${slug:-worktree}; path=\"$HOME/workspace/worktrees/$repo/$slug\"; mkdir -p \"$(dirname \"$path\")\" || return; if [ \"$1\" = \"-b\" ]; then git worktree add -b \"$branch\" \"$path\" \"$base\"; elif git show-ref --verify --quiet \"refs/heads/${branch}\"; then git worktree add \"$path\" \"$branch\"; elif git show-ref --verify --quiet \"refs/remotes/origin/${branch}\"; then git worktree add -b \"$branch\" \"$path\" \"origin/$branch\"; else printf 'wtco: branch %s not found locally or in refs/remotes/origin; fetch first if needed\\n' \"$branch\" >&2; return 1; fi; }; f"
