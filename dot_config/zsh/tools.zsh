if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if [[ -x /opt/homebrew/bin/fzf ]]; then
  source <(/opt/homebrew/bin/fzf --zsh)
elif command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
