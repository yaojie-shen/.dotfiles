# Dotfiles

Shell, editor, terminal and developer tools for Linux and macOS. This experimental
branch uses [mise](https://mise.jdx.dev/bootstrap.html) for machine bootstrap,
dotfile deployment and portable tool installation. It no longer requires Dotbot
or Git submodules. Existing `devbox` setup/snippet commands remain available.

## Install or preview

```bash
git clone https://github.com/Yaojie-Shen/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install --dry-run
./install
```

The installer bootstraps mise **2026.10.15** if a sufficiently recent version is
not already available. Linux x86_64/ARM64 and macOS Intel/Apple Silicon downloads
are verified against pinned SHA-256 hashes. Initial requirements are Bash, curl,
Git, and `sha256sum` or `shasum`; Homebrew and Python are not bootstrap requirements.

Default installation registers this checkout as a global mise config fragment,
clones the shell frameworks, backs up managed rc files, deploys configuration and
persistent links, and installs the declared portable tools. It skips framework repositories with local changes and does not pull Git
repositories unless requested. System packages and host-specific setup are opt-in.

```bash
./install --only dotfiles        # configuration and persistent links
./install --only tools           # portable tool versions, no dotfile deployment
./install --only repos           # Oh My Zsh, zplug, Bash-it and Bash-it initialization
./install --skip repos           # omit shell frameworks
./install --update               # public/private git pull --ff-only, then bootstrap
mise run setup:basic_packages    # opt-in OS packages; may need sudo
mise run setup:tmux              # existing Linux source build using system libraries
mise run setup:shell_fallback -- --shell fish
```

`--dry-run` keeps mise downloads/trust/cache in a temporary directory and does not
write HOME or persistent data. Hooks are printed rather than executed. Native
mise may report an existing rc file as a conflict during preview: the real apply
backs it up in the preparation hook. Other configuration conflicts require review.
`--update` stops if either Git pull fails; it never merges divergent branches.

## Public and private, together

The public repo declares shared configuration. An optional independent inhouse
repo stays under `persistent/custom/`, or at an external path:

```bash
DOTFILES_CUSTOM_ROOT=/path/to/inhouse ./install
```

This creates an ignored `persistent/custom` symlink when needed; it never replaces
an existing real private directory. Subsequent runs reuse that link. Neither the
private files nor their Git history are copied into the public repository.

Global mise configuration loads in this order:

1. `~/.config/mise/conf.d/50-dotfiles/` → this public checkout
2. `~/.config/mise/conf.d/60-dotfiles-private/` → the private checkout, if it has `mise.toml`
3. Your normal `~/.config/mise/config.toml` and local configuration

Private config may add or override tools, dotfiles, environment and tasks. Use
names such as `inhouse:setup` for private tasks to keep origins clear. The installer
runs through these global fragments so private overrides apply consistently.
Project-local mise configs can still override global values inside that project.

Existing private shell files, setup scripts and snippets retain their conventions:

- `persistent/custom/shell/*.sh` / `*.fish`, in filename order
- `persistent/custom/devbox/setup/*`
- `persistent/custom/devbox/snippets/*`
- `~/.persistent/custom.sh` / `custom.fish` take precedence over the shell directory

`devbox setup` still chooses the public script first when names collide. Set
`DEVBOX_SETUP_PATH` explicitly to change this order. See [mise/README.md](mise/README.md)
for examples, old private Dotbot conversion, rollback and verification.

## Tools, setup and snippets

```bash
mise tasks ls
mise run setup -- --list         # combined public/private script discovery
mise run setup:gdu
mise run setup:gdu -- --status
mise run setup:gdu -- --version 5.38.0
mise run setup:workmux -- --setup # optional agent hooks
mise run status

# Existing commands continue to work:
devbox setup --list
devbox setup gdu
devbox snippets --list
```

Mise owns downloads, versions, verification and PATH for starship, uv, lazygit,
Neovim, jless, csvlens, gdu and workmux. Ollama is available on demand. Tool-specific
host configuration remains in explicit setup tasks: SSH, shell fallback, tmux,
Conda, NVM/pyenv, agent installation/onboarding, skills, and VS Code tunnels.
Existing environments are preserved. New runtime projects can use `mise use node`
and `mise use python` directly instead of installing another version manager.

Portable-tool wrappers accept `--version`, `--upgrade`, `--status`, `--uninstall`,
and workmux's `--setup`. Old `--install-dir`, `--url` and other installer-specific
flags are intentionally replaced by native mise configuration. Uninstall removes
mise-owned versions; it retains declarations, configuration and manually installed
copies. `--upgrade` follows the declared version; `--version latest` selects latest
locally. Existing manual binaries may still be on PATH until a new shell activates
mise. Root rc files load mise through shared `shell/` modules for Bash/Zsh/Fish.

Devbox-only installation remains available with `bash devbox/install.sh`. It
registers mise tasks/tools and installs managed shell activation, without deploying
the rest of the dotfiles. `--uninstall` removes devbox shell blocks/links; it leaves
the checkout, mise and its registrations for explicit review.

## Persistent data

`persistent/` remains ignored mutable storage for agent histories, sessions,
Downloads, Projects, Workbench and caches. It is not mise dotfile history or sync
input. Existing regular files/directories at guarded destinations are preserved;
missing or symlink destinations are linked. Managed Bash/Zsh/Fish rc files get
`.before-mise.*` backups before replacement. There is no home-wide cleanup step.

Keep your existing persistent directory when trying another checkout. In a fresh
worktree, before running the installer, you can link its missing `persistent/` to
your existing persistent directory. Review `./install --dry-run` first: applying
this branch changes the live shell/editor configuration that HOME points to.
