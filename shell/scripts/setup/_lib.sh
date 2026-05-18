#!/bin/bash
# Shared helpers for Ryoku setup recipes invoked from GlobalActions.

_setup_load_distro() {
  DISTRO_ID="unknown"
  DISTRO_LIKE=""

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
  fi
}

setup_cmd_present() {
  if command -v ryoku-cmd-present >/dev/null 2>&1; then
    ryoku-cmd-present "$1"
    return $?
  fi

  command -v "$1" >/dev/null 2>&1
}

is_arch_like() {
  case " $DISTRO_ID $DISTRO_LIKE " in
    *" arch "*|*" archlinux "*|*" endeavouros "*|*" cachyos "*|*" manjaro "*|*" garuda "*|*" artix "*)
      return 0
      ;;
  esac

  return 1
}

setup_notify() {
  local body="$1"
  local icon="${2:-download}"

  [[ -z ${SETUP_TAG:-} ]] && return 0
  setup_cmd_present notify-send || return 0

  notify-send \
    -a "Setup" \
    -i "$icon" \
    -h "string:x-canonical-private-synchronous:${SETUP_TAG}" \
    -- "$SETUP_TITLE" "$body" 2>/dev/null || true
}

setup_progress() {
  local step="$1"
  local total="$2"
  local message="$3"

  printf '\n[%s/%s] %s\n' "$step" "$total" "$message"
  setup_notify "[$step/$total] $message" "download"
}

setup_done() {
  local message="${1:-Done}"

  printf '\nOK: %s\n' "$message"
  setup_notify "$message" "emblem-ok-symbolic"
}

setup_fail() {
  local message="${1:-Setup failed}"

  printf '\nFAIL: %s\n' "$message" >&2
  setup_notify "$message" "dialog-error"
}

setup_init() {
  SETUP_TAG="setup-$1"
  SETUP_TITLE="$2"

  trap 'setup_fail "$SETUP_TITLE failed at line $LINENO"' ERR
  setup_notify "Starting..." "download"
  printf '%s (distro: %s)\n' "$SETUP_TITLE" "$DISTRO_ID"
}

ensure_aur_helper() {
  local helper=""
  local tmp=""

  if setup_cmd_present yay; then
    echo "yay"
    return 0
  fi

  if setup_cmd_present paru; then
    echo "paru"
    return 0
  fi

  setup_notify "Bootstrapping yay AUR helper..." "download"
  sudo pacman -S --needed --noconfirm git base-devel >&2
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" >&2
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm) >&2
  rm -rf "$tmp"

  helper="yay"
  echo "$helper"
}

install_arch() {
  local repo=()
  local aur=()
  local all=()
  local seen_split=0
  local arg
  local helper

  for arg in "$@"; do
    if [[ $arg == "--" ]]; then
      seen_split=1
      continue
    fi

    all+=("$arg")
    if (( seen_split )); then
      aur+=("$arg")
    else
      repo+=("$arg")
    fi
  done

  if setup_cmd_present ryoku-pkg-add; then
    ryoku-pkg-add "${all[@]}"
    return $?
  fi

  if (( ${#repo[@]} )); then
    sudo pacman -S --needed --noconfirm "${repo[@]}"
  fi

  if (( ${#aur[@]} )); then
    helper="$(ensure_aur_helper)"
    "$helper" -S --needed --noconfirm "${aur[@]}"
  fi
}

install_flatpak() {
  if ! setup_cmd_present flatpak; then
    setup_fail "flatpak is not installed; cannot continue on this distro"
    return 1
  fi

  flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  flatpak install -y --user flathub "$@"
}

setup_finish_pause() {
  printf '\nPress Enter to close this window... '
  read -r _ || true
}

_setup_load_distro
