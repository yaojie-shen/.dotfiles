#!/usr/bin/env bash
# Click dispatcher and foreground monitor runner. No installs or privilege changes.
set -uo pipefail

kind=${3:-}
case "${1:-}" in
  --run) kind=${2:-} ;;
  --open) kind=${4:-} ;;
  *) printf 'Usage: monitor.sh --run cpu|mem|gpu|net|all\n' >&2; exit 2 ;;
esac
case "$kind" in cpu|mem|gpu|net|all) ;; *) echo 'Unknown monitor type.' >&2; exit 2 ;; esac

if [[ $1 == --open ]]; then
  socket=$2 session=$3
  [[ $session =~ ^\$[0-9]+$ ]] || exit 2
  tm=(tmux -S "$socket")
  lock="dotfiles-monitor-${session}-${kind}"
  "${tm[@]}" wait-for -L "$lock" || exit 1
  trap '"${tm[@]}" wait-for -U "$lock" 2>/dev/null || true' EXIT
  trap 'exit 130' INT TERM HUP
  # Window names are user-owned. Only reuse windows we tagged for this session.
  while IFS='|' read -r id owner type dead; do
    if [[ $owner == "$session" && $type == "$kind" && $dead == 0 ]]; then
      "${tm[@]}" select-window -t "$id"
      exit $?
    fi
  done < <("${tm[@]}" list-windows -t "$session" -F '#{window_id}|#{@dotfiles_monitor_owner}|#{@dotfiles_monitor}|#{pane_dead}')
  script="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/monitor.sh"
  # Single-quote shell paths; never interpolate tool names or network devices into code.
  quoted=${script//\'/\'\\\'\'}
  id=$("${tm[@]}" new-window -d -P -F '#{window_id}' -t "$session:" -n "perf-$kind" "exec bash '$quoted' --run $kind") || exit 1
  "${tm[@]}" set-window-option -t "$id" @dotfiles_monitor "$kind" \; \
    set-window-option -t "$id" @dotfiles_monitor_owner "$session" \; \
    set-window-option -t "$id" automatic-rename off \; \
    select-window -t "$id"
  exit $?
fi

# Run tools in the foreground with their terminal and stderr intact. A failed
# launch (including nvitop with no GPU) advances; q / Ctrl-C never launches more.
trap 'exit 0' INT TERM HUP
attempts=()
try_monitor() {
  local rc
  if ! command -v "$1" >/dev/null 2>&1; then
    attempts+=("$1: not installed")
    return 1
  fi
  printf 'Starting %s\n' "$*"
  "$@"
  rc=$?
  case $rc in 0|130|143) exit 0 ;; esac
  attempts+=("$1: exit $rc (see diagnostic above)")
  printf '\n%s failed (exit %s); trying fallback.\n' "$1" "$rc"
  return 1
}

interfaces=()
network_interfaces() {
  local name rest
  # Same physical-ish interface set as netspeed.sh, excluding bridges and veths.
  case $(uname -s) in
    Linux)
      while IFS=: read -r name rest; do
        name=${name//[[:space:]]/}
        case $name in eth*|en*|wlan*|wlp*) interfaces+=("$name") ;; esac
      done < /proc/net/dev
      ;;
    Darwin)
      while IFS= read -r name; do interfaces+=("$name"); done < <(
        netstat -ibn 2>/dev/null | awk '$1 ~ /^en[0-9]+$/ && $3 ~ /^<Link#/ && !seen[$1]++ {print $1}')
      ;;
  esac
}

case "$kind" in
  all) try_monitor nvitop; try_monitor htop; try_monitor top ;;
  cpu) try_monitor htop -s PERCENT_CPU; try_monitor top ;;
  mem) try_monitor htop -s PERCENT_MEM; try_monitor top ;;
  gpu) try_monitor nvitop; try_monitor nvtop; try_monitor nvidia-smi -l 2 ;;
  net)
    network_interfaces
    if ((${#interfaces[@]})); then
      printf 'Interfaces (same selection as status bar): %s\n' "${interfaces[*]}"
      taps=()
      for interface in "${interfaces[@]}"; do taps+=(-r "$interface" -t "$interface"); done
      try_monitor speedometer "${taps[@]}"
      try_monitor nload -m "${interfaces[@]}"
    else
      attempts+=('speedometer/nload: no matching status-bar network interface')
    fi
    printf 'sar fallback displays all interfaces (not just the status-bar selection).\n'
    try_monitor sar -n DEV 1
    ;;
esac

printf '\nNo usable %s monitor.\n' "$kind"
printf '  %s\n' "${attempts[@]}"
printf 'Install one of the listed tools, or fix its driver/dependencies and retry.\n'
printf 'Press Enter to close this window.'
IFS= read -r _ || true
exit 1
