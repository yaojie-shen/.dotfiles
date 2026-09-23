# Fish counterpart of shell/common/50_custom.sh. Machine-local overlay, not in this repo:
# ~/.persistent/custom.fish, or ~/.persistent/custom/shell/*.fish (NN_ prefix sets order).
if test -f "$HOME/.persistent/custom.fish"
    source "$HOME/.persistent/custom.fish"
else if test -d "$HOME/.persistent/custom/shell"
    for _custom_fish in "$HOME/.persistent/custom/shell/"*.fish
        source $_custom_fish
    end
    set -e _custom_fish
end
