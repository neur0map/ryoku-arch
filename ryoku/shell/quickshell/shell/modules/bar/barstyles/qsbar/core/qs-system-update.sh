#!/usr/bin/env bash
# Side-effect-free backend discovery and terminal launch adapter for the
# ArchUpdater panel. This file ships inside the QML generation, so the panel
# never has to probe an older privileged apply helper with an unknown option.
set -euo pipefail

RYOKU_SYSTEM_ROOT="${QS_ARCH_RYOKU_SYSTEM_ROOT:-/usr/share/ryoku}"
RYOKU_USER_ROOT="${QS_ARCH_RYOKU_USER_ROOT:-$HOME/.local/share/ryoku}"

resolve_command() {
  local override_name="$1" command_name="$2"
  shift 2
  local candidate

  if [[ -v $override_name ]]; then
    candidate="${!override_name}"
    [ -x "$candidate" ] && readlink -f "$candidate"
    return 0
  fi

  candidate="$(type -P "$command_name" 2>/dev/null || true)"
  for candidate in "$candidate" "$@"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      readlink -f "$candidate"
      return 0
    fi
  done
  return 0
}

resolve_pacman() {
  local candidate
  if [[ -v QS_ARCH_PACMAN_PROBE_COMMAND ]]; then
    candidate="$QS_ARCH_PACMAN_PROBE_COMMAND"
    if [[ "$candidate" == */* ]]; then
      [ -x "$candidate" ] && readlink -f "$candidate"
    else
      type -P "$candidate" 2>/dev/null || true
    fi
  else
    type -P pacman 2>/dev/null || true
  fi
  return 0
}

probe_backend() {
  local helper="$1" updater cli pacman protocol="missing"

  if [ -x "$helper" ]; then
    if grep -Fqx '# QS_ARCH_APPLY_PROTOCOL=2' "$helper"; then
      protocol="2"
    else
      protocol="legacy"
    fi
  fi

  updater="$(resolve_command QS_ARCH_RYOKU_UPDATE_COMMAND ryoku update \
    "$RYOKU_USER_ROOT/bin/ryoku update" \
    "$RYOKU_SYSTEM_ROOT/bin/ryoku update")"
  cli="$(resolve_command QS_ARCH_RYOKU_CLI_COMMAND omarchy \
    "$RYOKU_USER_ROOT/bin/omarchy" \
    "$RYOKU_SYSTEM_ROOT/bin/omarchy")"

  if [ -n "$updater" ]; then
    printf 'omarchy\tupdate\t%s\t%s\n' "$updater" "$protocol"
  elif [ -n "$cli" ]; then
    printf 'omarchy\tcli\t%s\t%s\n' "$cli" "$protocol"
  elif [ -d "$RYOKU_SYSTEM_ROOT" ] || [ -d "$RYOKU_USER_ROOT" ]; then
    printf 'ryoku-broken\tnone\t\t%s\n' "$protocol"
  else
    pacman="$(resolve_pacman)"
    if [ -n "$pacman" ]; then
      printf 'arch\tapply\t%s\t%s\n' "$helper" "$protocol"
    else
      printf 'unsupported\tnone\t\t%s\n' "$protocol"
    fi
  fi
}

launch_terminal() {
  local terminal presentation
  [ "$#" -gt 0 ] || {
    printf 'qs-system-update: update command is missing\n' >&2
    exit 64
  }

  # Hermetic argv-preserving seam for the regression suite; it deliberately has
  # no ambiguous one-string terminal API.
  if [[ -v QS_TEST_SYSTEM_UPDATE_ARGV_TERMINAL ]]; then
    terminal="$QS_TEST_SYSTEM_UPDATE_ARGV_TERMINAL"
    [ -x "$terminal" ] || {
      printf 'qs-system-update: test terminal is unavailable\n' >&2
      exit 69
    }
    exec "$terminal" "$@"
  fi

  presentation="$(resolve_command QS_TEST_SYSTEM_UPDATE_PRESENTATION_LAUNCHER \
    kitty \
    "$RYOKU_USER_ROOT/bin/kitty" \
    "$RYOKU_SYSTEM_ROOT/bin/kitty")"
  if [ -n "$presentation" ]; then
    exec "$presentation" --hold "$@"
  elif terminal="$(type -P xdg-terminal-exec 2>/dev/null)"; then
    exec "$terminal" --hold -- "$@"
  elif terminal="$(type -P footclient 2>/dev/null)"; then
    exec "$terminal" --hold "$@"
  elif terminal="$(type -P foot 2>/dev/null)"; then
    exec "$terminal" --hold "$@"
  elif terminal="$(type -P kitty 2>/dev/null)"; then
    exec "$terminal" --hold "$@"
  elif terminal="$(type -P alacritty 2>/dev/null)"; then
    exec "$terminal" --hold -e "$@"
  elif terminal="$(type -P wezterm 2>/dev/null)"; then
    exec "$terminal" start --always-new-process -- "$@"
  elif terminal="$(type -P konsole 2>/dev/null)"; then
    exec "$terminal" --hold -e "$@"
  elif terminal="$(type -P ghostty 2>/dev/null)"; then
    exec "$terminal" --wait-after-command=true -e "$@"
  elif terminal="$(type -P xterm 2>/dev/null)"; then
    exec "$terminal" -hold -e "$@"
  fi

  type -P notify-send >/dev/null 2>&1 \
    && notify-send -a "QS-Shell" -u critical "System update unavailable" \
      "No supported terminal launcher was found." 2>/dev/null \
    || true
  printf 'qs-system-update: no supported terminal launcher was found\n' >&2
  exit 69
}

case "${1:-}" in
  --probe)
    [ -n "${2:-}" ] || {
      printf 'qs-system-update: apply helper path is missing\n' >&2
      exit 64
    }
    probe_backend "$2"
    ;;
  --launch)
    shift
    launch_terminal "$@"
    ;;
  *)
    printf 'qs-system-update: expected --probe or --launch\n' >&2
    exit 64
    ;;
esac
