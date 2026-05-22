#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -d $ROOT_DIR/shell-rebirth/quickshell ]] || \
  fail "missing rebirth quickshell runtime"
[[ -f $ROOT_DIR/shell-rebirth/quickshell/shell.qml ]] || \
  fail "missing rebirth shell.qml"
[[ -x $ROOT_DIR/bin/ryoku-rebirth-shell ]] || \
  fail "missing executable ryoku-rebirth-shell wrapper"
[[ -f $ROOT_DIR/config/hypr/hyprland.conf ]] || \
  fail "missing Hyprland entry config"
[[ -f $ROOT_DIR/config/hypr/colors.conf ]] || \
  fail "missing Hyprland color fallback"
[[ -f $ROOT_DIR/config/hypr/hypridle-rebirth.conf ]] || \
  fail "missing rebirth hypridle config"

if find "$ROOT_DIR/shell-rebirth/quickshell" \( -path '*/.idea/*' -o -path '*/__pycache__/*' -o -name '*.pyc' \) | grep -q .; then
  fail "rebirth shell should not vendor IDE files or Python bytecode caches"
fi

home_prefix="/h""ome/"
bad_user_pattern="${home_prefix}igris|igris|${home_prefix}dhrruv|dhrruvsharma"
if rg -n "$bad_user_pattern" "$ROOT_DIR/shell-rebirth/quickshell" "$ROOT_DIR/config/hypr" >/tmp/rebirth-hardcoded-paths.$$; then
  cat /tmp/rebirth-hardcoded-paths.$$
  rm -f /tmp/rebirth-hardcoded-paths.$$
  fail "rebirth shell should not contain upstream user or branding paths"
fi
rm -f /tmp/rebirth-hardcoded-paths.$$

! rg -n 'niri msg|NIRI_SOCKET|niri.service.wants|service enable niri' "$ROOT_DIR/config/hypr" "$ROOT_DIR/shell-rebirth/quickshell" || \
  fail "rebirth runtime should not wire Niri behavior"

rg -q 'RYOKU_REBIRTH_SHELL_DIR' "$ROOT_DIR/bin/ryoku-rebirth-shell" || \
  fail "wrapper should export the rebirth shell runtime directory"
rg -q 'qs.*-p.*RYOKU_REBIRTH_SHELL_DIR' "$ROOT_DIR/bin/ryoku-rebirth-shell" || \
  fail "wrapper should launch Quickshell from the rebirth runtime directory"
rg -q 'exec-once = ryoku-rebirth-shell' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should start the rebirth shell"
rg -q 'exec-once = hypridle -c ~/.config/hypr/hypridle-rebirth.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should use the rebirth hypridle config"
rg -q 'source = ~/.config/hypr/colors.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should source a local color fallback"
rg -q 'bind = SUPER, Return, exec' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep a terminal bind"
rg -q 'bind = SUPER, R, exec, qs ipc call launcherWindow toggle' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the upstream launcher IPC bind"
rg -q 'bind = SUPER SHIFT, R, exec, ryoku-rebirth-shell restart' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should support shell restart"

echo "PASS: rebirth shell runtime is self-contained and Hyprland-first"
