#!/bin/bash

# Self-contained terminal UI for the shell installer. No dependency on the
# OS installer's helpers, so the shell layer stays decoupled. Colours match
# the Ryoku accent (#F25623 -> 208) with a subdued foreground for detail.

RSI_C_ACCENT=$'\e[38;5;208m'
RSI_C_OK=$'\e[32m'
RSI_C_WARN=$'\e[33m'
RSI_C_ERR=$'\e[31m'
RSI_C_DIM=$'\e[2m'
RSI_C_OFF=$'\e[0m'

rsi_say()  { printf '%s\n' "$*"; }
rsi_step() { printf '%s::%s %s\n' "$RSI_C_ACCENT" "$RSI_C_OFF" "$*"; }
rsi_ok()   { printf '%s ok %s %s\n' "$RSI_C_OK" "$RSI_C_OFF" "$*"; }
rsi_warn() { printf '%swarn%s %s\n' "$RSI_C_WARN" "$RSI_C_OFF" "$*" >&2; }
rsi_dim()  { printf '%s%s%s\n' "$RSI_C_DIM" "$*" "$RSI_C_OFF"; }

rsi_die() {
  printf '%serror%s %s\n' "$RSI_C_ERR" "$RSI_C_OFF" "$*" >&2
  exit 1
}

# rsi_confirm PROMPT -> 0 if the user affirms. Honours --yes. Reads from the
# controlling terminal so it works even when stdin is a pipe (curl | bash).
rsi_confirm() {
  local prompt="$1" answer=""
  if [[ ${RSI_ASSUME_YES:-0} == 1 ]]; then
    return 0
  fi
  if { exec 9</dev/tty; } 2>/dev/null; then
    read -r -p "$prompt [y/N] " answer <&9 || answer=""
    exec 9<&-
  else
    read -r -p "$prompt [y/N] " answer || answer=""
  fi
  [[ $answer == [yY]* ]]
}

# rsi_dry -> 0 when running in dry-run mode (changes nothing).
rsi_dry() { [[ ${RSI_DRY_RUN:-0} == 1 ]]; }

rsi_banner() {
  printf '%s\n' "${RSI_C_ACCENT}力${RSI_C_OFF}  Ryoku Shell installer  ${RSI_C_DIM}(experimental)${RSI_C_OFF}"
}
