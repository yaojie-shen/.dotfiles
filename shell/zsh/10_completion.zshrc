[[ -o interactive ]] || return 0
autoload -Uz compinit
compinit
bindkey -e
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
