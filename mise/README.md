# Native mise layout

| Responsibility | Location |
| --- | --- |
| Tool/runtime versions and platform assets | `mise.toml` `[tools]` |
| Cache paths and public commands on PATH | `mise.toml` `[env]`, `bin/` |
| Optional applications | `mise.apps.toml` |
| OS packages | `mise.system.toml` `[bootstrap.packages]` |
| Shell/tmux plugin checkouts | `mise.toml` `[bootstrap.repos]` |
| Configuration deployment | `mise.toml` `[dotfiles]` |
| Host operations | Native `[tasks]`, with scripts in `mise/operations/` |
| Mutable state protection and rc backups | `scripts/prepare`, `scripts/guarded-links`, `persistent.tsv` |
| Private customization | Separate private repo's `mise.toml` |

There is no dispatcher, installer helper library, per-tool install wrapper, old
private layout lookup, YAML conversion, or standalone installation mode. Native
backends own downloads, extraction, checksums, version selection, PATH and shims.
Tasks only perform operations that mise does not declare itself, such as
validating/authorizing an SSH public key or initializing an empty Skills Library.

## Private configuration

The root installer registers public/private repositories as global folder
fragments. They compose using mise's native merge and precedence rules, including
`[tools]`, `[env]`, `[dotfiles]`, hooks and tasks. A normal user config overrides
the fragments, while a project config can override all global defaults. No
private content is copied or committed into the public repository.

Use the example in the root README. Anchor private task directories with
`{{config_source | canonicalize | dirname}}`, and namespace tasks with `inhouse:`.
For larger private tasks use `[tasks."inhouse:name"] file = "{{vars.inhouse_root}}/operations/name"` with an
explicit `dir` and absolute, config-anchored `file`. Keep tool installation in `[tools]`, shell-independent state in
`[env]`, command scripts in a directory added with `[env]._.path`, and shell
extensions in explicit `[dotfiles]` entries. Private native file-task discovery is also supported by mise. The public
config does not change `task_config.includes`, so project and private file-task
discovery retain native defaults.

Registration ownership records are local files next to `conf.d`. Unrelated real
directories and unowned symlinks in the two reserved slots are rejected. External
private repositories with spaces or relative paths are canonicalized and reused
on subsequent installer runs. A private repo without `mise.toml` fails before
configuration deployment. It must be migrated explicitly in its own repository.
The old `persistent/mise.toml` precedence and `custom.sh`/script-directory
fallbacks are gone.

## Tool and shell choices

- Node and Python use core mise backends. No NVM or pyenv installation/init blocks.
- UV owns Python venv/dependency operations; micromamba is an opt-in native tool
  for Conda workloads. Project CUDA choices are kept out of machine bootstrap.
- Tmux uses upstream's platform builds via aqua, rather than a local Linux-only
  source-build installer. This removes custom compiler/package probing.
- Zoxide replaces autojump; Starship initializes Bash/Fish, Powerlevel10k remains
  the Zsh theme. Theme/highlighting repositories are installed before rc deployment. Bash-it
  and Oh My Zsh are replaced by direct history/completion configuration.
- Catppuccin and tmux-thumbs repositories use native bootstrap repos. The thumbs
  binary is managed by mise. The tiny tmux command script only forwards the
  existing copy/paste options to that binary; it never downloads or builds.
- Upstream thumbs publishes x86_64 binaries only, so ARM uses mise's Git cargo backend
  for tag `0.8.0` (the project is not published as a crate). This requires a Rust toolchain and build prerequisites; these are
  managed according to the cargo backend's normal rules, not a custom installer.
- Jless 0.9.0 has no Linux ARM64 binary and is excluded there. Gdu Linux x86_64
  uses a static release asset. Other upstream binaries retain their libc needs.
- The apps environment includes an explicitly versioned HTTP declaration for
  the VS Code CLI, with per-platform URLs. Login and foreground service lifecycle
  are separate tasks, rather than install/start/uninstall flags on one script.

Optional tools require `-E apps` when invoking them. For a permanent subset,
declare those tools in private/user configuration. `mise -E apps use ...` edits
an environment config in the current project; use native `--global` or `--file`
when another config is the intended destination. Native project precedence still
applies when commands run inside either repository.

The native brew manager installs formulae without requiring a Homebrew CLI.
`[env]._.path` includes its standard prefix. Its current upstream implementation
supports Apple Silicon macOS and Linux, and skips formula installs on Intel Macs;
that optional package-profile limitation does not affect mise-managed tools on
Intel Macs. There is no private fallback installer in this branch.

## Data protection and rollback

Mise cannot replace or merge an existing real data directory safely on behalf of
this repository. The pre-dotfiles hook therefore preserves it, creates only
missing storage/guarded links, and backs up managed rc files to
`.before-mise.<timestamp>.<pid>`. Ordinary `[dotfiles]` conflicts stop for review.
Persistent state is never tracked/synced as mise dotfile history.

`mise dot unapply --dry-run` previews removal of ordinary managed links. It does
not restore rc backups or undo guarded persistent links. Restore the backups or
apply the previous checkout to return to the previous configuration. Remove only
the owned `50-dotfiles`/`60-dotfiles-private` registrations when unregistering;
keep unrelated mise configuration and shared persistent data. This branch does
not automatically delete old manually installed tools or live shell settings.

## Validation

```bash
MISE_BIN="$(command -v mise)" python3 mise/tests/check.py
```

Tests use real mise, disposable HOME/config/cache/state and copied checkouts.
They cover native global task resolution, public/private and project precedence,
explicit private shell files and PATH in Bash/Zsh/Fish, external private paths,
data preservation, backup idempotence, conflict rejection, preview isolation,
native shell preference storage, SSH key validation and Skills Library safety.
No PyYAML or other Python package is required. Runtime download probes and tmux
checks can be run separately in an isolated environment. macOS/ARM execution,
privileged packages and a live inhouse conversion require their own environment;
the public branch does not run them against the active machine.
