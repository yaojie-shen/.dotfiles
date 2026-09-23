# Fish entrypoint, reached via ~/.config/fish/config.fish.
# Mirrors source.zshrc: every shell/fish/*.fish is sourced, and the leading NN_
# number in each filename controls load order (lower loads first).
for _shell_script in "$HOME/.shell/fish/"*.fish
    source $_shell_script
end
set -e _shell_script
