# Dotfiles with mise

This experimental branch uses mise for tool versions, runtime environments,
commands, machine bootstrap and dotfile deployment. There is one framework:
`mise.toml`. The former devbox dispatcher, per-tool setup scripts, Dotbot config,
NVM/pyenv installers, private-script discovery and standalone devbox installer
have been removed.

## Start a new machine

Install Git and curl, then clone the repository and bootstrap:

```bash
git clone https://github.com/yaojie-shen/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./install --dry-run
./install
```

`./install` only ensures a checksum-verified mise binary, registers the public and
optional private configuration, and invokes native `mise bootstrap`. It requires
mise >= 2026.10.15 and supports Linux/macOS on x86_64/ARM64. Afterwards use mise
commands directly:

```bash
mise install                       # declared tools and runtimes
mise dot apply                     # config deployment, with data protection hook
mise dot status
mise bootstrap                     # tools + plugin repos + config
mise bootstrap repos update        # update unpinned shell/plugin repositories
mise tasks ls
mise run status
mise run update                    # ff-only public/private pulls, then bootstrap
```

The bootstrap installs Node LTS, Python 3.13, uv, tmux, starship, zoxide, lazygit,
Neovim, jless, csvlens, gdu, workmux and tmux-thumbs through native mise backends.
Bash history/completion and Zsh completion are configured directly in `shell/`.
Zsh theme/highlighting repositories are declared in `[bootstrap.repos]`. Bash-it,
Oh My Zsh, Zplug and TPM are removed. Tmux starts
without fetching tools or plugin repositories; use `mise bootstrap` to provision
them first.

Optional applications and OS packages are separate native environments:

```bash
mise -E apps install               # Claude, Codex, Ollama, chatgpt, snipkit,
                                  # Skills Manager, micromamba, VS Code CLI
mise -E apps exec -- codex
mise -E apps run vscode:login
mise -E apps run vscode:serve       # foreground; Ctrl-C stops the tunnel
mise -E apps run skills:init
mise -E system bootstrap --only packages  # apt/dnf/pacman/brew; may need sudo
```

`-E apps` activates the application declarations for that command. To make a tool
available in every shell, declare it in your private `mise.toml` or add it to the
normal mise global config. There are no `setup:gdu` or `devbox setup` wrappers:

```bash
cd ~                              # outside the public repo's project overrides
mise use --global github:dundee/gdu@5.38.0
mise upgrade github:dundee/gdu
mise exec -- gdu --version
mise uninstall github:dundee/gdu@5.38.0          # remove an installed version
mise unuse --global github:dundee/gdu            # remove your global declaration
```

## Compose public and private repositories

The inhouse repository stays independent. It contains its own `mise.toml`:

```bash
DOTFILES_CUSTOM_ROOT=/path/to/inhouse ./install
```

Without that variable the initial default is `persistent/custom/`. Explicitly
registered external paths are remembered by the mise registration; no alias or
copy is created inside the public repository. A private directory must have
`mise.toml`; there is no YAML converter or fallback discovery of old scripts.

Mise loads the global fragments in order:

1. `~/.config/mise/conf.d/50-dotfiles/` → public repo
2. `~/.config/mise/conf.d/60-dotfiles-private/` → optional private repo
3. `~/.config/mise/config.toml` → personal overrides

Project config retains mise's normal precedence over global configuration.
Both repositories use the same native schema:

```toml
# Private repo: mise.toml
[vars]
inhouse_root = "{{config_source | canonicalize | dirname}}"

[tools]
"aqua:openai/codex" = "latest"

[env]
COMPANY_ENV = "development"
_.path = ["{{vars.inhouse_root}}/bin"]

[dotfiles]
"~/.config/company/tool.toml" = "config/tool.toml"
"~/.config/dotfiles/bash.sh" = "shell/bash.sh"
"~/.config/dotfiles/zsh.zsh" = "shell/zsh.zsh"
"~/.config/dotfiles/fish.fish" = "shell/fish.fish"

[tasks."inhouse:setup"]
dir = "{{vars.inhouse_root}}"
file = "{{vars.inhouse_root}}/operations/setup"
```

Declare only files that actually exist. Environment variables and command paths
belong in `[env]`; the optional shell extension files above are for shell
functions, aliases or integrations that require sourcing. Relative task paths
and working directories should be anchored explicitly, since the same config can
be loaded globally and as a project. Use `inhouse:*` task names to make private
operations easy to identify. See [mise/README.md](mise/README.md).

## Runtimes and commands

Mise replaces separate NVM/pyenv installation and initialization. Python project
environments and dependency selection belong in the project:

```bash
cd ~/Projects/example
mise use node@lts python@3.13
uv venv
uv pip install --python .venv/bin/python torch torchvision torchaudio
# Choose CPU/CUDA indexes in the project's dependency config when needed.
```

Conda workloads can use the mise-managed micromamba without a second installer
or shell `conda init`: `mise -E apps exec -- micromamba run -n ENV COMMAND`.
Existing Conda environments are not converted or deleted. There is no hardcoded
interactive table of old PyTorch/CUDA versions.

Useful scripts live in `bin/`, on PATH through mise `[env]._.path`:

```bash
catpick --help
file_growth --help
ssh_manager --help
mise run ssh:authorize 'ssh-ed25519 AAAA... comment'
mise run ssh:serve 2222             # foreground OpenSSH server; host sshd required
mise run shell:fallback fish        # persist preference in the mise user config
mise run shell:fallback off
mise run workmux:configure
```

Zoxide replaces autojump. Shell fallback is a static Bash startup integration
controlled by `DOTFILES_LOGIN_SHELL` in native mise config. It does not patch rc
files. Fish/Zsh themselves remain host packages in the optional system profile.

## Mutable data and trying this branch

`persistent/` is ignored storage for histories, sessions, Downloads, Projects,
Workbench and caches. Mise `[env]` supplies cache paths consistently to all
shells and tasks. Normal configuration links use `[dotfiles]`; a small
`pre-dotfiles` hook preserves real data directories and backs up managed rc files
before deploying them. This protection is needed even with a fully native mise
configuration. It is not a second setup framework.

Review `./install --dry-run` before applying to a live account. A dry run isolates
mise writes in a temporary directory; native mise can report conflicts with
existing rc files because it does not execute the real backup hook in a preview.
A worktree has its own persistent store unless you explicitly share one. Applying
this branch changes shell/editor configuration. Merely checking out, testing or
committing it does not switch the active environment.

Run isolated checks with a preinstalled mise binary:

```bash
MISE_BIN="$(command -v mise)" python3 mise/tests/check.py
```
