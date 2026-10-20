# mise env owns the preference. Only replace a terminal's top-level Bash.
if [[ $- == *i* && -t 0 && -t 1 && -z "${DOTFILES_SHELL_ACTIVE:-}" &&
      -z "${BASH_EXECUTION_STRING:-}" && -z "${SSH_ORIGINAL_COMMAND:-}" &&
      -n "${DOTFILES_LOGIN_SHELL:-}" && -x "$DOTFILES_LOGIN_SHELL" &&
      ! "$DOTFILES_LOGIN_SHELL" -ef "$BASH" ]]; then
    _fallback_execfail=0
    shopt -q execfail && _fallback_execfail=1
    shopt -s execfail
    export DOTFILES_SHELL_ACTIVE=1
    if ! exec "$DOTFILES_LOGIN_SHELL" -i; then unset DOTFILES_SHELL_ACTIVE; fi
    [[ $_fallback_execfail == 1 ]] || shopt -u execfail
    unset _fallback_execfail
fi
