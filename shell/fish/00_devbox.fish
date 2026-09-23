# Import devbox (fish counterpart of shell/zsh/00_devbox.zshrc)
set -q DEVBOX_ROOT; or set -gx DEVBOX_ROOT "$HOME/.devbox"
test -d $DEVBOX_ROOT/libexec; and set -gx PATH $DEVBOX_ROOT/libexec $PATH
devbox init - fish | source
