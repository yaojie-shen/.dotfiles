[[ $- == *i* ]] || return 0
if command -v zoxide >/dev/null 2>&1; then eval "$(zoxide init bash)"; fi
if command -v starship >/dev/null 2>&1; then eval "$(starship init bash)"; fi
