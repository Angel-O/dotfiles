# Portable shell baseline.
if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"

fpath=("$HOME/.zsh/completions" $fpath)

export ZSH="$HOME/.oh-my-zsh"
if [[ -r "$ZSH/oh-my-zsh.sh" && -z ${ZSH_CACHE_DIR:-} ]]; then
  plugins=(git macos)
  source "$ZSH/oh-my-zsh.sh"
fi
