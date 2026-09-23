# Fish counterpart of shell/common/00_exports.sh; keep the two in sync.

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

# nvm.fish installs node under ~/.local/share/nvm; expose the newest installed
# version so node/npm also work in non-interactive shells before `nvm use` runs.
set -l __node_bins $HOME/.local/share/nvm/v*/bin
if test (count $__node_bins) -gt 0
    set -gx PATH $__node_bins[-1] $PATH
end
