#!/usr/bin/env bash

# Set DEVBOX_ROOT to directory of this script
export DEVBOX_ROOT=${DEVBOX_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/devbox"}
[[ -d "$DEVBOX_ROOT/libexec" ]] && export PATH="$DEVBOX_ROOT/libexec:$PATH"
eval "$(devbox init - bash)"
source "$DEVBOX_ROOT/completions/devbox.bash"

# NOTE: wrap with double quotes to preserve undesired word splitting
devbox "$@"
