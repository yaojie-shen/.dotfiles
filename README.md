# Dotfiles

Personal dotfiles for setting up a consistent shell, editor, terminal, and developer-tool environment across machines. The repository uses [Dotbot](https://github.com/anishathalye/dotbot) to create symlinks and run bootstrap commands, and includes a small `devbox` command collection for common setup scripts and reusable shell snippets.

## What is included

- Zsh and Bash startup configuration
- Shared shell aliases, exports, and functions
- Tmux configuration
- Conda configuration
- Neovim configuration
- `devbox` setup scripts for tools such as Homebrew, Neovim, pyenv, and other development utilities
- `devbox` snippets for recurring command-line workflows
- A `persistent/` area for machine-local files, downloads, projects, caches, and optional private customizations

## Installation

Clone the repository, including submodules, and run the installer:

```bash
git clone --recurse-submodules git@github.com:Yaojie-Shen/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

The installer updates the Dotbot submodule, pulls the latest repository changes, and applies `install.conf.yaml`. It links files such as `~/.zshrc`, `~/.bashrc`, `~/.tmux.conf`, `~/.condarc`, `~/.config/nvim`, `~/.shell`, and `~/.devbox`.

If present, an additional private Dotbot config is also applied from either:

- `persistent/install.conf.yaml`
- `persistent/custom/install.conf.yaml`

## Usage

After installation, open a new shell or source your shell config:

```bash
source ~/.zshrc
# or
source ~/.bashrc
```

Use `devbox` to list and run setup scripts:

```bash
devbox setup --list
devbox setup <script_name>
```

Examples:

```bash
devbox setup homebrew
devbox setup neovim
devbox setup pyenv
```

To install only `devbox`, without the rest of the dotfiles, run `devbox/install.sh` from a checkout, or:

```bash
curl -fsSL https://raw.githubusercontent.com/Yaojie-Shen/.dotfiles/main/devbox/install.sh | bash
```

It clones the repository to `~/.dotfiles` if missing, links `~/.devbox` to its `devbox/` like `./install` does, and adds `devbox init` for bash, zsh and fish: a managed block in `~/.bashrc` and `~/.zshrc`, and `~/.config/fish/conf.d/devbox.fish`. Shells that already load devbox through the dotfiles `~/.shell` setup are skipped. Pass `--uninstall` to undo.

Use snippets for reusable command-line workflows:

```bash
devbox snippets --list
```

Neovim is configured under `nvim/` and is linked to `~/.config/nvim` by the installer.

### Fish

Install `fish` with `devbox setup basic_packages` (apt) or `brew install fish`. The installer installs [starship](https://starship.rs) into `~/.local/bin`, links `config.fish` and `fish_plugins` into `~/.config/fish/` and `starship.toml` (catppuccin-powerline preset) into `~/.config/`, keeps fish history in `persistent/.fish_history`, and, when fish is available, runs `fisher update` (plugins: bass, nvm.fish). Starship glyphs need a Nerd Font such as JetBrainsMono Nerd Font in the terminal.

`config.fish` sources `shell/source.fish`, which loads `shell/fish/*.fish` in `NN_` order, mirroring `shell/zsh/*.zshrc` and `shell/common/*.sh`: devbox (with fish completions), aliases, exports, and native fish ports of `shell/common/00_functions.sh`. Machine-local fish overrides go in `~/.persistent/custom.fish` or `~/.persistent/custom/shell/*.fish`.

## Customization

Machine-specific or private configuration should live under `persistent/` or `persistent/custom/` instead of being committed directly to shared dotfiles. The default shell entrypoints source shared files from `~/.shell`, while local tool-specific additions can remain in the generated shell startup files.
