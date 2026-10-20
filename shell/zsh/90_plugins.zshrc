# Repositories are installed by mise bootstrap; shell startup never downloads.
[[ -o interactive ]] || return 0
_plugins="$HOME/.local/share/dotfiles"
[[ ! -f "$_plugins/powerlevel10k/powerlevel10k.zsh-theme" ]] || source "$_plugins/powerlevel10k/powerlevel10k.zsh-theme"
source "$HOME/.shell/p10k.zsh"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
[[ ! -f "$_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] || source "$_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ ! -f "$_plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]] || source "$_plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
unset _plugins
