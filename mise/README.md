# Mise migration notes

## What lives where

| Responsibility | Implementation |
| --- | --- |
| Portable tool backends, versions and platform assets | Root `mise.toml` `[tools]` |
| Shared config deployment | Root `mise.toml` `[dotfiles]` |
| Shell framework checkouts | `[bootstrap.repos]` and post-repos initialization |
| Existing data preservation and rc backups | `scripts/prepare`, `scripts/guarded-links`, `persistent.tsv` |
| Optional apt/dnf/pacman/macOS brew packages | `mise.system.toml`, selected with `-E system` |
| Host-specific install/configuration | `setup:*` tasks, existing `devbox/setup/` scripts |
| Private tools/config/tasks | Private repo `mise.toml` |
| Local version overrides | User's `~/.config/mise/config.toml` |

The guarded link helper remains because native mise treats an existing real
file/directory as a conflict. It never merges agent data or replaces Downloads.
All ordinary configuration links use native mise. Persistent data is deliberately
not declared with `mode = "track"` and is never synced by mise history.

The shell frameworks remain in use; this migration changes their installation
framework, not shell behavior. Complex installers are native mise tasks with their
existing scripts as implementation. Portable tools no longer duplicate release
lookup, extraction, checksums, platform detection or PATH edits in each installer.

## Private/inhouse example

Keep this file in the independent private repository, not in public Git:

```toml
# persistent/custom/mise.toml
[vars]
dotfiles_private_root = "{{config_source | canonicalize | dirname}}"

[tools]
"aqua:astral-sh/uv" = "0.13.1"

[dotfiles]
"~/.config/example/company.toml" = "config/company.toml"

[tasks."inhouse:setup"]
dir = "{{vars.dotfiles_private_root}}"
run = "bash devbox/setup/internal_tool"

[tasks."inhouse:check"]
dir = "{{vars.dotfiles_private_root}}"
run = "bash checks/check-env"
```

Relative dotfile sources belong to the private config root. Give private tasks an
explicit `dir` as above: when a config is loaded through both a global folder
fragment and a project, mise can otherwise resolve the default task directory to
HOME. The `config_source` anchor keeps tasks stable from any working directory.
A public install without the private repo works by itself. Private shell/setup/
snippet discovery is independent of the presence of a private `mise.toml`, so those
extensions still work without one. Public setup names win by default; for an
explicit override:

```bash
DEVBOX_SETUP_PATH="$HOME/.persistent/custom/devbox/setup:$HOME/.devbox/setup" \
  devbox setup some_tool
```

The older `persistent/mise.toml` location is also supported and takes precedence
over `persistent/custom/mise.toml`, matching the old root-level private config rule.
The normal `mise.local.toml` / `mise.*.local.toml` files are ignored for per-machine
project overrides. Do not put credentials in public `[env]` or task bodies.

Reserved global fragment slots carry a local ownership record next to
`conf.d`. The installer can replace or remove registrations it created, but
refuses unrelated symlinks or real directories in those slots. It never removes
an unrelated config registration just because this checkout has no private config.

## Convert the old private Dotbot config

Installation stops before deployment when a selected private `install.conf.yaml`
has no corresponding `mise.toml`. Portable tools can still be installed separately.
The one-time converter supports `create`, plain links, and the standard
`[ ! -e "$HOME/..." ] || [ -L "$HOME/..." ]` preservation guard:

```bash
./install --only tools
mise exec -- uv run --no-project --with PyYAML python3 \
  "$PWD/mise/scripts/migrate-private" \
  "$PWD/persistent/custom/install.conf.yaml"
```

The converter needs Python/PyYAML only for this operation. Normal bootstrap does
not. It validates the whole input before creating private `mise.toml`, a private
preparation script and a guarded-links manifest. It retains the original YAML and
refuses to overwrite generated files. Custom shell steps, nonstandard conditions,
forced links, absolute `create` paths, HOME traversal and unusual options fail
explicitly for manual migration. Relative `create` paths such as `../state`
remain relative to the private config directory. Review the
results in the private repository before rerunning the installer. This branch has
not modified the real inhouse repository for you.

## Versions and native commands

```bash
mise run setup:gdu -- --version 5.38.0
mise exec -- gdu --version
mise dot status
mise dot diff
mise bootstrap status
mise -E system bootstrap packages status
```

Per-tool `--version` writes the user's global config and installs that version.
Shared pins still take precedence while you are inside this repository, following
normal mise project rules. Run global commands from HOME when checking your global
selection. `--upgrade` follows configured pins; use `--version latest` to change a
pin. Old brew/npm/standalone copies are not deleted automatically.

Linux x64 gdu uses the static upstream asset. jless 0.9.0 has no Linux ARM64 asset,
so it is excluded there. Other missing upstream platform releases fail explicitly.
Neovim/jless and other GNU release binaries still require their upstream system
libraries. macOS and ARM paths have been checked against release metadata, but
have not been executed on hardware in this migration.

`mise run setup:tmux` retains the existing Linux source build against system
libraries; OS-package tmux in the optional basic package set is a separate choice.
NVM, pyenv and Conda remain optional explicit workflows, not automatic runtime
migrations. Existing virtual environments and initialization blocks are retained
in their original checkout; review uncommitted rc customizations before adopting
a fresh worktree's rc files.

## Inspect and roll back the experiment

This branch is intended for review before changing the live HOME. A new worktree
has its own ignored `persistent/` directory by default. Link an existing persistent
store into the new worktree only after deciding to share that state. Merely
building or testing this branch does not switch the live configuration.

If applied, remove mise-managed ordinary links with `mise dot unapply` while the
configuration is still registered; preview with `--dry-run` first. It does not
remove guarded persistent links or restore rc backups. Restore `.before-mise.*`
backups or rerun your previous checkout's installer to repoint those destinations.
Review and remove only the `50-dotfiles` / `60-dotfiles-private` symlinks when you
want to unregister this configuration; leave unrelated mise config and tool data
in place. Do not delete a shared `persistent` symlink's target.

## Checks

```bash
# An installed mise >= 2026.10.15 plus Python/PyYAML for the one-time converter test:
MISE_BIN="$(command -v mise)" uv run --no-project --with PyYAML \
  python3 mise/tests/check.py
```

The suite copies this checkout, creates disposable HOME/data/cache directories,
and invokes real mise. It covers deployment, backups/idempotence, data preservation,
dry-run isolation, private overrides, external private repos, conversion, task
forwarding, setup precedence and standalone devbox shell blocks. Tests do not run
system package installs, SSH changes, shell switching or tmux builds.
