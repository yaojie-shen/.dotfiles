#!/usr/bin/env bash
# Rebuild Catppuccin outside tmux's hook command queue. Synchronous plugin
# reloads can deadlock with programs in a display-popup that query tmux.
set -uo pipefail

PLUGIN_DIR="${HOME}/.tmux/plugins/tmux"
OPTIONS="${PLUGIN_DIR}/catppuccin_options_tmux.conf"
THEME="${PLUGIN_DIR}/catppuccin_tmux.conf"
LOCK="dotfiles-catppuccin-theme"
PALETTE_OPTIONS=(
  @thm_bg @thm_fg @thm_rosewater @thm_flamingo @thm_pink @thm_mauve
  @thm_red @thm_maroon @thm_peach @thm_yellow @thm_green @thm_teal
  @thm_sky @thm_sapphire @thm_blue @thm_lavender @thm_subtext_1
  @thm_subtext_0 @thm_overlay_2 @thm_overlay_1 @thm_overlay_0
  @thm_surface_2 @thm_surface_1 @thm_surface_0 @thm_mantle @thm_crust
)

[ -f "$OPTIONS" ] && [ -f "$THEME" ] || exit 0
tmux wait-for -L "$LOCK" >/dev/null 2>&1 || exit 0
trap 'tmux wait-for -U "$LOCK" >/dev/null 2>&1 || true' EXIT

# Read the desired flavor after taking the lock. If light/dark events arrive
# quickly, queued workers converge on the newest value instead of racing.
FLAVOR=$(tmux show-option -gqv @dotfiles_catppuccin_flavor)
case "$FLAVOR" in
  latte)
    COLORFGBG="0;15"
    ;;
  mocha)
    COLORFGBG="15;0"
    ;;
  *)
    exit 0
    ;;
esac

# Repeated terminal theme notifications are common. Avoid rebuilding when a
# queued worker has already converged on the newest requested flavor.
if [ "$(tmux show-option -gqv @catppuccin_flavor)" = "$FLAVOR" ]; then
  exit 0
fi

# Catppuccin's palette files use "set -o", so remove only the old palette
# before loading the new one. Keep all presentation options in place: using
# @catppuccin_reset would temporarily replace the custom window layout with
# Catppuccin defaults and then require a second visible rebuild.
tmux_command=(tmux set-option -g @catppuccin_flavor "$FLAVOR")
for option in "${PALETTE_OPTIONS[@]}"; do
  tmux_command+=(\; set-option -gu "$option")
done
tmux_command+=(\; set-environment -g COLORFGBG "$COLORFGBG"
  \; source-file "$OPTIONS"
  \; source-file "$THEME"
  \; set-option -gF message-style 'fg=#{@thm_mauve},bg=#{@thm_mantle},fill=#{@thm_mantle},bold,align=left'
  \; set-option -gF message-command-style 'fg=#{@thm_mauve},bg=#{@thm_mantle},fill=#{@thm_mantle},bold,align=left'
  \; set-option -g window-status-separator ''
  \; set-option -g window-status-activity-style default
  \; set-option -g window-status-bell-style default)
"${tmux_command[@]}" >/dev/null 2>&1 || exit 0
