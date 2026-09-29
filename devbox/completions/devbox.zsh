if [[ ! -o interactive ]]; then
    return
fi

compctl -K _devbox devbox

_devbox() {
  local words completions
  read -cA words

  if [ "${#words}" -eq 2 ]; then
    completions="$(devbox commands)"
  else
    completions="$(devbox completions ${words[2,-2]})"
  fi

  reply=(${(ps:\n:)completions})
}
