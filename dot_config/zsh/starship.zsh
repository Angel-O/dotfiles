export STARSHIP_CONFIG="$HOME/.config/starship/current.toml"

stheme() {
  local theme_dir="$HOME/.config/starship/themes"
  local current="$HOME/.config/starship/current.toml"
  local theme="${1:-}"
  local config name active marker

  if [[ -z "$theme" || "$theme" == "--list" ]]; then
    active=$(readlink "$current" 2>/dev/null)
    active="${${active:t}%.toml}"
    printf 'Installed themes (* active):\n'
    for config in "$theme_dir"/*.toml(N); do
      name="${${config:t}%.toml}"
      marker=' '
      [[ "$name" == "$active" ]] && marker='*'
      printf '  %s %s\n' "$marker" "$name"
    done
    printf '\nBundled Starship presets (generated on first use):\n'
    command starship preset --list
    return
  fi

  if [[ "$theme" == "--refresh" ]]; then
    theme="${2:-}"
    if [[ -z "$theme" ]]; then
      printf 'usage: stheme --refresh <bundled-preset>\n' >&2
      return 2
    fi
    command starship preset "$theme" -o "$theme_dir/$theme.toml" || return
  elif [[ ! -f "$theme_dir/$theme.toml" ]]; then
    command starship preset "$theme" -o "$theme_dir/$theme.toml" || return
  fi

  ln -sfn "$theme_dir/$theme.toml" "$current" || return
  printf 'Starship theme: %s\n' "$theme"
}

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
  TRANSIENT_PROMPT_TRANSIENT_PROMPT='%F{#BD93F9}❯%f '
  if [[ -r "$HOME/.oh-my-zsh/custom/plugins/zsh-transient-prompt/transient-prompt.plugin.zsh" ]]; then
    source "$HOME/.oh-my-zsh/custom/plugins/zsh-transient-prompt/transient-prompt.plugin.zsh"
  fi
fi
