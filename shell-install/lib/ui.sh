#!/bin/bash

# Self-contained terminal UI for the shell installer. Pure bash and ANSI, no
# external tools, so it runs on any machine before a single dependency is
# installed. Colour is used only on an interactive terminal and honours
# NO_COLOR; otherwise everything degrades to plain text.

if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  RSI_ACCENT=$'\033[38;2;242;86;35m'   # Ryoku orange #F25623
  RSI_TAG=$'\033[38;2;174;171;148m'    # subdued foreground #aeab94
  RSI_OK=$'\033[32m'
  RSI_WARN=$'\033[33m'
  RSI_ERR=$'\033[31m'
  RSI_DIM=$'\033[2m'
  RSI_BOLD=$'\033[1m'
  RSI_OFF=$'\033[0m'
else
  RSI_ACCENT='' RSI_TAG='' RSI_OK='' RSI_WARN='' RSI_ERR='' RSI_DIM='' RSI_BOLD='' RSI_OFF=''
fi

# Branded banner: the 力 kanji block and the RYOKU wordmark in the accent
# colour, then the tagline. Matches the OS installer's boot.sh art.
rsi_banner() {
  local kanji wordmark tagline
  kanji='
                   ████████
                   ████████
                   ████████
                   ████████
     ██████████████████████████████████████████
   ██████████████████████████████████████████████
   ██████████████████████████████████████████████
                   ████████              ████████
                   ██████                ██████
                   ██████                ██████
                 ████████                ██████
                 ████████                ██████
               ████████                  ██████
             ██████████                  ██████
             ████████                  ████████
         ██████████                    ████████
       ██████████                      ██████
   ████████████              ████████████████
   ████████                  ██████████████
     ████                      ████████'
  wordmark='
 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝'
  tagline='            力と美のために  :  For the sake of power and beauty.'

  [[ -t 1 ]] && clear 2>/dev/null
  printf '%s%s\n%s%s\n' "$RSI_ACCENT" "$kanji" "$wordmark" "$RSI_OFF"
  printf '%s%s%s\n' "$RSI_TAG" "$tagline" "$RSI_OFF"
  printf '%s  Shell installer  %s(experimental)%s\n' "$RSI_ACCENT" "$RSI_DIM" "$RSI_OFF"
}

# rsi_header TITLE -> a section title with an accent bar.
rsi_header() {
  printf '\n%s▌%s %s%s%s\n' "$RSI_ACCENT" "$RSI_OFF" "$RSI_BOLD" "$*" "$RSI_OFF"
}

rsi_say()  { printf '%s\n' "$*"; }
rsi_step() { printf '  %s·%s %s\n' "$RSI_ACCENT" "$RSI_OFF" "$*"; }
rsi_ok()   { printf '  %s✓%s %s\n' "$RSI_OK" "$RSI_OFF" "$*"; }
rsi_warn() { printf '  %s!%s %s\n' "$RSI_WARN" "$RSI_OFF" "$*" >&2; }
rsi_dim()  { printf '%s%s%s\n' "$RSI_DIM" "$*" "$RSI_OFF"; }

# rsi_will / rsi_wont -> styled plan bullets.
rsi_will() { printf '    %s✓%s %s\n' "$RSI_OK" "$RSI_OFF" "$*"; }
rsi_wont() { printf '    %s✗%s %s\n' "$RSI_ERR" "$RSI_OFF" "$*"; }

rsi_die() {
  printf '\n  %s✗ %s%s\n' "$RSI_ERR" "$*" "$RSI_OFF" >&2
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
