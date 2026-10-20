# mise manages portable tools; shims also work in noninteractive shells.
if [[ -x "$HOME/.local/bin/mise" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
if command -v mise >/dev/null 2>&1; then
    if [[ $- == *i* ]]; then
        eval "$(mise activate bash)"
    else
        eval "$(mise activate bash --shims)"
    fi
fi
