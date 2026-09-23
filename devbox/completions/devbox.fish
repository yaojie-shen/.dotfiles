# Fish completions for devbox, modeled on pyenv's completions/pyenv.fish and
# sourced by `devbox init - fish` like devbox.bash / devbox.zsh. Unlike pyenv it
# registers one lazy rule for subcommand args instead of running `devbox commands`
# at every shell start.

function __fish_devbox_needs_command
    test (count (commandline -opc)) -eq 1
end

complete -f -c devbox -n __fish_devbox_needs_command -a '(devbox commands)'
complete -f -c devbox -n 'not __fish_devbox_needs_command' -a '(devbox completions (commandline -opc)[2..-1])'
