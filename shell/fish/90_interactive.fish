# Interactive-session setup: silence the greeting, start the starship prompt.
# Loads after the custom overlay so PATH additions there (e.g. starship) are visible.
if status is-interactive
    if command -q zoxide
        zoxide init fish | source
    end
    set fish_greeting ""
    if command -q starship
        # Emit the full script directly, avoiding a second process and psub file.
        starship init fish --print-full-init | source
    end
end
