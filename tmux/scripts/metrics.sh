#!/usr/bin/env bash
# Publishes the status bar's CPU/MEM/GPU/network values into @dotfiles_*
# options. tmux runs this from the status line, so there is nothing to keep
# alive, but it prints nothing and the bar renders from the options instead.
#
# The bar used to call one #() per value. tmux repaints as each job finishes,
# so it was rewritten several times per interval with a different subset of the
# values filled in, and because a job spends the format's expansion budget,
# whatever followed it in the status line went blank whenever that ran out -
# taking the clock with it. A job that prints nothing can do neither, and the
# values it publishes stay on screen until the next successful run.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL="${DOTFILES_METRICS_INTERVAL:-5}"
STAMP="${TMPDIR:-/tmp}/.dotfiles_tmux_metrics_${USER:-$(id -un)}"

# tmux re-runs status jobs on every redraw, up to once a second, and every
# attached client runs its own copy. Sampling that often costs a fork per
# redraw and leaves netspeed.sh diffing sub-second counter deltas.
if [ "${1:-}" != "--force" ]; then
  now=$(date +%s)
  last=$(cat "$STAMP" 2>/dev/null)
  [ $((now - ${last:-0})) -ge "$INTERVAL" ] || exit 0
  printf '%s\n' "$now" >"$STAMP"
fi

tmux set -g @dotfiles_cpu "$(bash "$SCRIPT_DIR/cpu.sh")" \; \
  set -g @dotfiles_mem "$(bash "$SCRIPT_DIR/mem.sh")" \; \
  set -g @dotfiles_gpu "$(bash "$SCRIPT_DIR/gpu.sh")" \; \
  set -g @dotfiles_net "$(bash "$SCRIPT_DIR/netspeed.sh")" 2>/dev/null
