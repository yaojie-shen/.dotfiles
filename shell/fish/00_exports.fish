# Fish counterpart of shell/common/00_exports.sh; keep the two in sync.

# bash/zsh get ~/.local/bin from ~/.profile, which fish never reads; starship and
# the agent CLIs install there.
if test -d "$HOME/.local/bin"; and not contains -- "$HOME/.local/bin" $PATH
    set -gx PATH "$HOME/.local/bin" $PATH
end

# Ask hydra to always show full error message including stack trace
set -gx HYDRA_FULL_ERROR 1

# Caches on the persistent folder
set -gx HF_HOME "$HOME/.persistent/cache/huggingface"
set -gx OLLAMA_MODELS "$HOME/.persistent/cache/ollama"
set -gx PIP_CACHE_DIR "$HOME/.persistent/cache/pip"
test -d "$PIP_CACHE_DIR"; or mkdir -p "$PIP_CACHE_DIR"
set -gx UV_CACHE_DIR "$HOME/.persistent/cache/uv"
set -gx CONDA_PKGS_DIRS "$HOME/.persistent/cache/conda"

# Set skills-manager home dir to persistent folder
set -gx SKILLS_HOME "$HOME/.persistent/skills"

# Node from nvm (`devbox setup nvm`, ~/.nvm), shared with bash/zsh. Put the
# default version on PATH without sourcing nvm.sh at startup (slow). `nvm` runs
# the bash nvm, then copies its PATH back, so `nvm use` / `nvm install` switch the
# node on this shell's PATH too.
set -q NVM_DIR; or set -gx NVM_DIR "$HOME/.nvm"
if test -s "$NVM_DIR/nvm.sh"
    function nvm
        set -l path_file (mktemp)
        bash -c 'source "$NVM_DIR/nvm.sh" --no-use && nvm "$@" && printf %s "$PATH" >"$0"' $path_file $argv
        set -l nvm_status $status
        if test $nvm_status -eq 0; and test -s $path_file
            set -gx PATH (string split : -- (cat $path_file))
        end
        rm -f $path_file
        return $nvm_status
    end

    # ponytail: alias/default must name a version (e.g. 22); lts/* or chained
    # aliases fall back to the newest installed node.
    set -l __default (string trim -l -c v -- (cat "$NVM_DIR/alias/default" 2>/dev/null))
    set -l __node_bins $NVM_DIR/versions/node/v$__default*/bin
    test (count $__node_bins) -gt 0; or set __node_bins $NVM_DIR/versions/node/v*/bin
    if test (count $__node_bins) -gt 0
        set -gx PATH $__node_bins[-1] $PATH
    end
end
