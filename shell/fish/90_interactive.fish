# Interactive-session setup: silence the greeting, start the starship prompt.
# Loads after the custom overlay so PATH additions there (e.g. starship) are visible.
if status is-interactive
    set fish_greeting ""
    if command -q starship
        starship init fish | source
    end
end
