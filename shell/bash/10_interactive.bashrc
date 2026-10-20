# Shell behavior is configured directly; mise provisions tools and completions.
[[ $- == *i* ]] || return 0
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
elif [[ -f /etc/bash_completion ]]; then
    source /etc/bash_completion
fi
