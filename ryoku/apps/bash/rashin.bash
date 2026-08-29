# shellcheck disable=SC1090
command -v ryoku-rashin >/dev/null 2>&1 || return

__rashin_apply_buffer() {
  local payload=$1
  __rashin_proposed=${payload//$'\n'/ && }
  if declare -F ble-edit/content/reset >/dev/null; then
    ble-edit/content/reset "$payload"
  else
    READLINE_LINE=$payload
    READLINE_POINT=${#READLINE_LINE}
  fi
}

rashin() {
  local payload
  payload=$(RASHIN_LAST_CMD=${__rashin_last_cmd:-} RASHIN_LAST_STATUS=${__rashin_last_status:-0} \
    command ryoku-rashin term --buffer -- "$@") || return
  [[ -n $payload ]] || return
  __rashin_skip_postexec=1
  __rashin_apply_buffer "$payload"
}

__rashin_transmute() {
  [[ -n ${READLINE_LINE:-} ]] || return
  local payload
  payload=$(command ryoku-rashin term --buffer -- "$READLINE_LINE" 2>/dev/null) || return
  [[ -n $payload ]] && __rashin_apply_buffer "$payload"
}
bind -x '"\er":__rashin_transmute'

__rashin_postexec() {
  local st=$? ran
  ran=$(HISTTIMEFORMAT='' history 1)
  ran=${ran#*[0-9]  }
  if [[ ${__rashin_skip_postexec:-0} == 1 ]]; then
    unset __rashin_skip_postexec
  elif [[ -n ${__rashin_proposed:-} ]]; then
    command ryoku-rashin term --report "$__rashin_proposed" "$ran" "$st" >/dev/null 2>&1 &
    unset __rashin_proposed
  fi
  __rashin_last_cmd=$ran
  __rashin_last_status=$st
}

if declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare -a'; then
  PROMPT_COMMAND+=(__rashin_postexec)
elif [[ -n ${PROMPT_COMMAND:-} ]]; then
  PROMPT_COMMAND="__rashin_postexec; $PROMPT_COMMAND"
else
  PROMPT_COMMAND=__rashin_postexec
fi

_ryoku_recipes=${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/rashin-recipes.bash
[[ -r $_ryoku_recipes ]] && . "$_ryoku_recipes"
unset _ryoku_recipes
