[[ ${__RYOKU_ZSH_LOADED:-0} == 1 ]] && return
__RYOKU_ZSH_LOADED=1

_ryoku_env=${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-terminal/env.sh
[[ -r $_ryoku_env ]] || _ryoku_env=${${(%):-%N}:A:h}/../terminal-shell/env.sh
[[ -r $_ryoku_env ]] && source "$_ryoku_env"
unset _ryoku_env

[[ -o interactive ]] || return

command -v ryoku-fastfetch >/dev/null 2>&1 && ryoku-fastfetch
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"

autoload -Uz compinit
_cache=${XDG_CACHE_HOME:-$HOME/.cache}/zsh
mkdir -p "$_cache"
compinit -d "$_cache/zcompdump"
unset _cache

[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]] &&
  source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#949699'
ZSH_HIGHLIGHT_STYLES[default]='fg=#F1F3E4'
ZSH_HIGHLIGHT_STYLES[command]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[function]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#e2342a'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#e83b30'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#e83b30'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#e83b30'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#CCD0CF'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#CCD0CF'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#A3C293'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#A3C293'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#A3C293'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#8AA9CC'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#8AA9CC'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#8AA9CC'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#93D4E0'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#93D4E0'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#949699'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF6B6B'

if (( $+functions[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey '^P' history-substring-search-up
  bindkey '^N' history-substring-search-down
fi

if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

_ryoku_cfg=${XDG_CONFIG_HOME:-$HOME/.config}
[[ -r $_ryoku_cfg/zsh/rashin.zsh ]] && source "$_ryoku_cfg/zsh/rashin.zsh"
[[ -r $_ryoku_cfg/zsh/user.zsh ]] && source "$_ryoku_cfg/zsh/user.zsh"
unset _ryoku_cfg
