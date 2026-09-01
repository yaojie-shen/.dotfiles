#!/usr/bin/env bash
# Rebuild Catppuccin outside tmux's hook command queue. Synchronous plugin
# reloads can deadlock with programs in a display-popup that query tmux.
set -uo pipefail

PLUGIN="${HOME}/.tmux/plugins/tmux/catppuccin.tmux"
LOCK="dotfiles-catppuccin-theme"

[ -f "$PLUGIN" ] || exit 0
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

tmux set-option -g @catppuccin_flavor "$FLAVOR"
tmux set-option -g @catppuccin_reset "true"
tmux set-environment -g COLORFGBG "$COLORFGBG"
"$PLUGIN" >/dev/null 2>&1 || exit 0

# Catppuccin's reset also clears user overrides, so restore the dotfiles
# presentation before rebuilding its generated window formats once more.
tmux set-option -g @catppuccin_window_status_style "rounded"
tmux set-option -g @catppuccin_window_text ' #{?#{m/r:^(bash|zsh|fish|sh)$,#{pane_current_command}},#{?#{==:#{pane_current_path},#{@dotfiles_home}},~,#{b:pane_current_path}},#{pane_current_command} · #{=/15/…:pane_title}}'
tmux set-option -g @catppuccin_window_current_text ' #{?#{m/r:^(bash|zsh|fish|sh)$,#{pane_current_command}},#{?#{==:#{pane_current_path},#{@dotfiles_home}},~,#{b:pane_current_path}},#{pane_current_command} · #{=/15/…:pane_title}}'
tmux set-option -g @catppuccin_date_time_text "%m-%d %H:%M"
tmux set-option -g @catppuccin_status_background '#{@thm_bg}'
tmux set-option -g @catppuccin_status_session_icon_fg '#{@thm_crust}'
tmux set-option -g @catppuccin_status_session_text_fg '#{@thm_fg}'
tmux set-option -g @catppuccin_status_session_text_bg '#{@thm_surface_0}'
tmux set-option -g @catppuccin_window_current_text_color '#{@thm_overlay_0}'
tmux set-option -gu @catppuccin_window_current_left_separator
tmux set-option -gu @catppuccin_window_current_middle_separator
tmux set-option -gu @catppuccin_window_current_right_separator
"$PLUGIN" >/dev/null 2>&1 || true
