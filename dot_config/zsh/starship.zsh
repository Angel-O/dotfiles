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

# Keep this terminal-specific behavior aligned with the user-facing policy in
# ~/.config/starship/README.md under "Warp Prompt Behavior."
if [[ ${TERM_PROGRAM:-} == "WarpTerminal" ]]; then
  TRANSIENT_PROMPT_PROMPT=''
  TRANSIENT_PROMPT_RPROMPT=''
elif command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Keep completed prompts compact in every terminal, including Warp. This
# marker is independent of the full Starship prompt used in other terminals.
TRANSIENT_PROMPT_TRANSIENT_PROMPT='%F{#BD93F9}❯%f '
if [[ -r "$HOME/.oh-my-zsh/custom/plugins/zsh-transient-prompt/transient-prompt.plugin.zsh" ]]; then
  source "$HOME/.oh-my-zsh/custom/plugins/zsh-transient-prompt/transient-prompt.plugin.zsh"
fi
