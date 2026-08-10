# Herdr Labels shell integration.
for _herdr_labels_hook in "$HOME"/.config/herdr/plugins/github/angel-o.labels-*/shell/hook.zsh(N); do
  source "$_herdr_labels_hook"
  break
done
unset _herdr_labels_hook

alias h='herdr'
