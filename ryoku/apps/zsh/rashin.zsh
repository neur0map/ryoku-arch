(( $+commands[ryoku-rashin] )) || return

autoload -Uz add-zsh-hook

__rashin_set_buffer() {
  BUFFER=$1
  CURSOR=${#BUFFER}
  __rashin_proposed=${1//$'\n'/ && }
}

rashin() {
  local payload
  payload=$(RASHIN_LAST_CMD=${__rashin_last_cmd:-} RASHIN_LAST_STATUS=${__rashin_last_status:-0} \
    command ryoku-rashin term --buffer -- "$@") || return
  [[ -n $payload ]] || return
  __rashin_pending=$payload
  __rashin_proposed=${payload//$'\n'/ && }
  __rashin_skip_postexec=1
}

__rashin_line_init() {
  if [[ -n ${__rashin_pending:-} ]]; then
    BUFFER=$__rashin_pending
    CURSOR=${#BUFFER}
    unset __rashin_pending
  fi
}
zle -N __rashin_line_init
add-zle-hook-widget line-init __rashin_line_init

__rashin_transmute() {
  [[ -n $BUFFER ]] || return
  local payload
  payload=$(command ryoku-rashin term --buffer -- "$BUFFER" 2>/dev/null) || return
  [[ -n $payload ]] && __rashin_set_buffer "$payload"
}
zle -N __rashin_transmute
bindkey '\er' __rashin_transmute

__rashin_preexec() {
  __rashin_running=$1
}

__rashin_precmd() {
  local st=$?
  if [[ ${__rashin_skip_postexec:-0} == 1 ]]; then
    unset __rashin_skip_postexec
  elif [[ -n ${__rashin_proposed:-} ]]; then
    command ryoku-rashin term --report "$__rashin_proposed" "${__rashin_running:-}" "$st" >/dev/null 2>&1 &!
    unset __rashin_proposed
  fi
  __rashin_last_cmd=${__rashin_running:-}
  __rashin_last_status=$st
}
add-zsh-hook preexec __rashin_preexec
add-zsh-hook precmd __rashin_precmd

_ryoku_recipes=${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/rashin-recipes.zsh
[[ -r $_ryoku_recipes ]] && source "$_ryoku_recipes"
unset _ryoku_recipes
