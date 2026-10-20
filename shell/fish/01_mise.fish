if test -x "$HOME/.local/bin/mise"
    fish_add_path --prepend "$HOME/.local/bin"
end
if command -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
end
