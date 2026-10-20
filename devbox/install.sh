#!/usr/bin/env bash
#
# One-step standalone installer for devbox, without the rest of the dotfiles.
#
#   bash devbox/install.sh                      # from a checkout
#   curl -fsSL <raw url>/devbox/install.sh | bash
#
# Paths match the dotfiles installer: ~/.devbox links to <repo>/devbox, and a
# curl run clones the repository to ~/.dotfiles (reused as-is if present, so a
# later full ./install works from the same checkout). `devbox init` is added for
# bash, zsh and fish alike, except where the dotfiles shell setup already runs it.

set -Eeuo pipefail

DEVBOX_ROOT="${DEVBOX_ROOT:-$HOME/.devbox}"
DEVBOX_REPO="${DEVBOX_REPO:-https://github.com/Yaojie-Shen/.dotfiles.git}"
DEVBOX_REF="${DEVBOX_REF:-main}"
DEVBOX_SRC="${DEVBOX_SRC:-$HOME/.dotfiles}"
START_MARKER="# >>> devbox initialize >>>"
END_MARKER="# <<< devbox initialize <<<"
FISH_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/devbox.fish"

ACTION="install"

usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  -h, --help            Show this help message
  -u, --uninstall       Remove the shell init and the ~/.devbox link

Environment:
  DEVBOX_ROOT   Link location (default: ~/.devbox)
  DEVBOX_REPO   Repository cloned when not run from a checkout
  DEVBOX_REF    Branch to clone (default: main)
  DEVBOX_SRC    Clone location (default: ~/.dotfiles)
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

configure_rc_block() {
  local rc_file="${1:-}"
  local start_marker="${2:-}"
  local end_marker="${3:-}"
  local content="${4:-}"
  local warning="# !! Contents within this block are managed by devbox/install.sh"
  local start_count end_count content_file output_file

  if [[ -z "$rc_file" || -z "$start_marker" || -z "$end_marker" || -z "$content" ]]; then
    echo "Error: configure_rc_block: missing required arguments" >&2
    return 1
  fi

  mkdir -p "$(dirname "$rc_file")"
  [[ -e "$rc_file" || -L "$rc_file" ]] || touch "$rc_file"

  start_count="$(awk -v marker="$start_marker" '$0 == marker { count++ } END { print count + 0 }' "$rc_file")"
  end_count="$(awk -v marker="$end_marker" '$0 == marker { count++ } END { print count + 0 }' "$rc_file")"

  if [[ "$start_count" -eq 0 && "$end_count" -eq 0 ]]; then
    {
      printf '\n%s\n' "$start_marker"
      printf '%s\n' "$warning"
      printf '%s\n' "$content"
      printf '%s\n\n' "$end_marker"
    } >>"$rc_file"
    return 0
  fi

  if [[ "$start_count" -ne 1 || "$end_count" -ne 1 ]]; then
    echo "Error: malformed devbox block in $rc_file" >&2
    return 1
  fi

  content_file="$(mktemp "${TMPDIR:-/tmp}/devbox-content.XXXXXX")" || return 1
  output_file="$(mktemp "${TMPDIR:-/tmp}/devbox-rc.XXXXXX")" || {
    rm -f "$content_file"
    return 1
  }
  printf '%s\n' "$content" >"$content_file"

  if ! awk -v start="$start_marker" -v end="$end_marker" -v warning="$warning" -v content_file="$content_file" '
    $0 == start {
      if (inside || seen_start) exit 2
      seen_start = 1
      inside = 1
      print start
      print warning
      while ((getline line < content_file) > 0) print line
      close(content_file)
      next
    }
    $0 == end {
      if (!inside || seen_end) exit 2
      seen_end = 1
      inside = 0
      print end
      next
    }
    !inside { print }
    END {
      if (!seen_start || !seen_end || inside) exit 2
    }
  ' "$rc_file" >"$output_file"; then
    echo "Error: malformed devbox block in $rc_file" >&2
    rm -f "$content_file" "$output_file"
    return 1
  fi

  if ! cat "$output_file" >"$rc_file"; then
    rm -f "$content_file" "$output_file"
    return 1
  fi
  rm -f "$content_file" "$output_file"
}

# Directory holding libexec/devbox: this checkout, an existing ~/.dotfiles, or a
# fresh clone. An existing checkout is not pulled; it may be on a work branch.
resolve_source() {
  local here=""
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  fi

  if [[ -n "$here" && -x "$here/libexec/devbox" ]]; then
    printf '%s\n' "$here"
    return
  fi

  if [[ -e "$DEVBOX_SRC" ]]; then
    echo "==> Using existing $DEVBOX_SRC (update it with git pull)" >&2
  else
    command -v git >/dev/null 2>&1 || die "git is required to download devbox"
    echo "==> Cloning $DEVBOX_REPO ($DEVBOX_REF) into $DEVBOX_SRC" >&2
    git clone --quiet --depth 1 --branch "$DEVBOX_REF" "$DEVBOX_REPO" "$DEVBOX_SRC" >&2
  fi
  [[ -x "$DEVBOX_SRC/devbox/libexec/devbox" ]] || die "no devbox/ in $DEVBOX_SRC"
  printf '%s\n' "$DEVBOX_SRC/devbox"
}

# The dotfiles shell setup already runs `devbox init`; a second one is redundant.
loaded_by_dotfiles() {
  case "$1" in
  bash) [[ -f "$HOME/.shell/bash/00_devbox.bashrc" ]] ;;
  zsh) [[ -f "$HOME/.shell/zsh/00_devbox.zshrc" ]] ;;
  fish) [[ -f "$HOME/.shell/fish/00_devbox.fish" ]] ;;
  esac
}

install_devbox() {
  local src shell rc mise_executable
  src="$(resolve_source)"
  # Tool/setup tasks are now backed by mise; the rest of dotfiles is not applied.
  source "$src/../mise/scripts/ensure-mise"
  ensure_mise
  mise_executable="$(cd "$(dirname "$MISE_BIN")" && pwd -P)/${MISE_BIN##*/}"
  bash "$src/../mise/scripts/register"

  if [[ -L "$DEVBOX_ROOT" || ! -e "$DEVBOX_ROOT" ]]; then
    ln -sfn "$src" "$DEVBOX_ROOT"
    echo "==> Linked $DEVBOX_ROOT -> $src"
  elif [[ "$(cd "$DEVBOX_ROOT" && pwd -P)" != "$src" ]]; then
    die "$DEVBOX_ROOT exists and is not a symlink; move it aside first"
  fi

  for shell in bash zsh; do
    rc="$HOME/.bashrc"
    [[ "$shell" == zsh ]] && rc="${ZDOTDIR:-$HOME}/.zshrc"
    if loaded_by_dotfiles "$shell"; then
      echo "==> $shell already loads devbox via ~/.shell (dotfiles); leaving $rc untouched"
      continue
    fi
    configure_rc_block "$rc" "$START_MARKER" "$END_MARKER" "export DEVBOX_ROOT=\"$DEVBOX_ROOT\"
export PATH=\"\$HOME/.local/bin:\$DEVBOX_ROOT/libexec:\$PATH\"
eval \"\$(devbox init - $shell)\"
eval \"\$(\"$mise_executable\" activate $shell)\""
    echo "==> Configured $rc"
  done

  if loaded_by_dotfiles fish; then
    echo "==> fish already loads devbox via ~/.shell (dotfiles); leaving $FISH_CONF untouched"
  else
    mkdir -p "$(dirname "$FISH_CONF")"
    printf '%s\n' \
      "# Managed by devbox/install.sh" \
      "set -gx DEVBOX_ROOT \"$DEVBOX_ROOT\"" \
      'set -gx PATH "$HOME/.local/bin" "$DEVBOX_ROOT/libexec" $PATH' \
      'devbox init - fish | source' \
      "\"$mise_executable\" activate fish | source" >"$FISH_CONF"
    echo "==> Wrote $FISH_CONF"
  fi

  echo "==> Done. Open a new shell, then run: devbox setup --list"
}

uninstall_devbox() {
  local rc
  for rc in "$HOME/.bashrc" "${ZDOTDIR:-$HOME}/.zshrc"; do
    if [[ -f "$rc" ]] && grep -qF "$START_MARKER" "$rc"; then
      sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$rc" && rm -f "$rc.bak"
      echo "==> Removed devbox block from $rc"
    fi
  done
  if [[ -f "$FISH_CONF" ]] && grep -qF "Managed by devbox/install.sh" "$FISH_CONF"; then
    rm -f "$FISH_CONF"
    echo "==> Removed $FISH_CONF"
  fi
  if [[ -L "$DEVBOX_ROOT" ]]; then
    rm -f "$DEVBOX_ROOT"
    echo "==> Removed link $DEVBOX_ROOT"
  fi
  [[ -d "$DEVBOX_SRC" ]] && echo "==> Checkout left in place: $DEVBOX_SRC"
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  -u | --uninstall)
    ACTION="uninstall"
    shift
    ;;
  *)
    usage >&2
    die "unknown option: $1"
    ;;
  esac
done

"${ACTION}_devbox"
