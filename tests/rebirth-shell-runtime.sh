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
grep -Fq 'qs_config_name="ryoku-rebirth-shell"' "$ROOT_DIR/bin/ryoku-rebirth-shell" || \
  fail "wrapper should select the rebirth Quickshell config name for child IPC calls"
grep -Fq "qs_args=(-c \"\$QS_CONFIG_NAME\")" "$ROOT_DIR/bin/ryoku-rebirth-shell" || \
  fail "wrapper should launch the named rebirth Quickshell config"
grep -Fq "exec \"\$qs_bin\" \"\${qs_args[@]}\" ipc \"\$@\"" "$ROOT_DIR/bin/ryoku-rebirth-shell" || \
  fail "wrapper should route IPC to the selected rebirth shell"
rg -q 'exec-once = hypridle -c ~/.config/hypr/hypridle-rebirth.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should use the rebirth hypridle config"
rg -q 'source = ~/.config/hypr/colors.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should source a local color fallback"
rg -q 'monitor = eDP-1, preferred, 0x0, 1.25' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should use a smaller explicit laptop scale"
rg -q 'bind = SUPER, Return, exec' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep a terminal bind"
rg -q 'bind = SUPER, T, exec, [$]terminal' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri terminal bind"
rg -q 'bind = SUPER, R, exec, [$]menu' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the upstream launcher bind"
rg -q 'bind = SUPER, Space, exec, [$]menu' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri launcher bind"
rg -q 'bind = SUPER, V, exec, [$]clipboard' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri clipboard bind"
rg -q 'bind = SUPER, S, exec, [$]systemPanel' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri toolkit bind"
rg -q 'bind = SUPER, Q, killactive,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri close-window bind"
rg -q 'bind = ALT, F4, killactive,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should support the common close-window bind"
rg -q 'bind = SUPER, A, togglefloating,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri floating toggle bind"
rg -q 'bind = SUPER SHIFT, R, exec, [$]shellRestart' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should support shell restart through the active shell wrapper"
rg -q 'bind = SUPER SHIFT, S, exec, [$]regionScreenshot' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the Niri region screenshot bind"
rg -q 'bind = SUPER, H, movefocus, l' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep HJKL focus navigation"
rg -q 'bind = SUPER SHIFT, H, movewindow, l' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep HJKL move navigation"
rg -q 'bind = SUPER CTRL, 1, movetoworkspace, 1' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep Niri-style workspace move binds"
rg -q 'WlrLayershell\.keyboardFocus: launcherWindow\.isOpen \? WlrKeyboardFocus\.Exclusive : WlrKeyboardFocus\.None' "$ROOT_DIR/shell-rebirth/quickshell/shell.qml" || \
  fail "launcher should request layer keyboard focus while open"
rg -q 'Qt\.callLater\(function\(\) \{ searchField\.forceActiveFocus\(\) \}\)' "$ROOT_DIR/shell-rebirth/quickshell/modules/launcher/LauncherWindow.qml" || \
  fail "launcher should focus the search field after the layer accepts keyboard focus"

echo "PASS: rebirth shell runtime is self-contained and Hyprland-first"
