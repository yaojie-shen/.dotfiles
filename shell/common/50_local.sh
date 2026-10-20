# The private mise.toml may deploy explicit Bash/Zsh startup files here.
if [[ -n "${BASH_VERSION:-}" && -f "$HOME/.config/dotfiles/bash.sh" ]]; then
    source "$HOME/.config/dotfiles/bash.sh"
elif [[ -n "${ZSH_VERSION:-}" && -f "$HOME/.config/dotfiles/zsh.zsh" ]]; then
    source "$HOME/.config/dotfiles/zsh.zsh"
fi
