# Activate before prompt/plugin setup; keep project version switching.
[[ ! -x "$HOME/.local/bin/mise" ]] || export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    if [[ -o interactive ]]; then
        eval "$(mise activate zsh)"
    else
        eval "$(mise activate zsh --shims)"
    fi
fi
