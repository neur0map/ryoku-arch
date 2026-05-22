#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $ROOT_DIR/config/hypr/hyprland.conf ]] || \
  fail "missing Hyprland entry config"
[[ -f $ROOT_DIR/config/hypr/colors.conf ]] || \
  fail "missing Hyprland color fallback"
[[ -f $ROOT_DIR/config/hypr/hypridle-rebirth.conf ]] || \
  fail "missing rebirth hypridle config"
[[ ! -e $ROOT_DIR/bin/ryoku-rebirth-shell ]] || \
  fail "rebirth shell wrapper should be removed"
[[ ! -d $ROOT_DIR/shell-rebirth ]] || \
  fail "rebirth shell source should be removed"

if rg -n 'ryoku-rebirth-shell|ryoku-vroomies-shell|shell-rebirth|QS_CONFIG_NAME,ryoku-|launcherWindow|clipboardManager|powerMenu toggle|systemPanel toggle' \
    "$ROOT_DIR/config/hypr" "$ROOT_DIR/bin" | grep -v 'bin/ryoku-rebirth-purge-niri-live' >/tmp/rebirth-shell-free.$$; then
  cat /tmp/rebirth-shell-free.$$
  rm -f /tmp/rebirth-shell-free.$$
  fail "rebirth Hyprland should not depend on experimental Quickshell runtimes"
fi
rm -f /tmp/rebirth-shell-free.$$

rg -q 'source = ~/.config/hypr/colors.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should source a local color fallback"
rg -q 'monitor = eDP-1, preferred, 0x0, 1.25' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should use a smaller explicit laptop scale"
rg -q "[$]menu = sh -lc '\\\$HOME/.local/bin/ryoku-shell launcher'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route launcher through Ryoku shell"
rg -q "[$]clipboard = sh -lc 'cliphist list \\| fuzzel --dmenu" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep clipboard history fallback"
rg -q "[$]systemPanel = sh -lc '\\\$HOME/.local/bin/ryoku-shell settings'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route system bind through Ryoku shell"
rg -q "[$]powerMenu = sh -lc '\\\$HOME/.local/bin/ryoku-shell session'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route power bind through Ryoku shell"
rg -q "exec-once = sh -lc '\\\$HOME/.local/bin/ryoku-shell run --session'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should start Ryoku shell"
rg -q 'exec-once = hypridle -c ~/.config/hypr/hypridle-rebirth.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should use the rebirth hypridle config"
rg -q 'bind = SUPER SHIFT, R, exec, hyprctl reload' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland reload bind should not restart a shell"
rg -q 'bind = SUPER, Space, exec, [$]menu' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the launcher bind"
rg -q 'bind = SUPER, V, exec, [$]clipboard' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the clipboard bind"
rg -q 'bind = SUPER, S, exec, [$]systemPanel' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the system bind"
rg -q 'bind = SUPER, P, exec, [$]powerMenu' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the power bind"
rg -q 'bind = SUPER, Q, killactive,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the close-window bind"
rg -q 'bind = ALT, F4, killactive,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should support the common close-window bind"
rg -q 'bind = SUPER, A, togglefloating,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the floating toggle bind"
rg -q 'bind = SUPER, H, movefocus, l' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep HJKL focus navigation"
rg -q 'bind = SUPER SHIFT, H, movewindow, l' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep HJKL move navigation"
rg -q 'bind = SUPER CTRL, 1, movetoworkspace, 1' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep Niri-style workspace move binds"

echo "PASS: rebirth Hyprland uses the Ryoku shell seed and keeps core binds"
