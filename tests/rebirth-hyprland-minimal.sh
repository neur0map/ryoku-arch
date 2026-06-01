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
[[ -f $ROOT_DIR/config/hypr/hypridle.conf ]] || \
  fail "missing canonical Hyprland hypridle config"
[[ ! -e $ROOT_DIR/config/hypr/hypridle-rebirth.conf ]] || \
  fail "rebirth hypridle config should not be shipped after hypridle.service became canonical"
[[ ! -e $ROOT_DIR/bin/ryoku-rebirth-shell ]] || \
  fail "rebirth shell wrapper should be removed"
[[ ! -d $ROOT_DIR/shell-rebirth ]] || \
  fail "rebirth shell source should be removed"
[[ -x $ROOT_DIR/bin/ryoku-toggle-floating-center ]] || \
  fail "missing executable floating center helper"
[[ -f $ROOT_DIR/shell/services/Hypr.qml ]] || \
  fail "missing Hyprland shell service"

if rg -n 'ryoku-rebirth-shell|ryoku-vroomies-shell|shell-rebirth|QS_CONFIG_NAME,ryoku-|launcherWindow|clipboardManager|powerMenu toggle|systemPanel toggle' \
    "$ROOT_DIR/config/hypr" "$ROOT_DIR/bin" | grep -v 'bin/ryoku-rebirth-purge-niri-live' >/tmp/rebirth-shell-free.$$; then
  cat /tmp/rebirth-shell-free.$$
  rm -f /tmp/rebirth-shell-free.$$
  fail "rebirth Hyprland should not depend on experimental Quickshell runtimes"
fi
rm -f /tmp/rebirth-shell-free.$$

rg -q 'source = ~/.config/hypr/colors.conf' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should source a local color fallback"
! rg -q 'ryoku-user-binds|[$]keybinds|Ryoku Keybinds|SUPER,[[:space:]]*slash' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should not ship the removed Super+/ keybind menu"
! rg -q 'monitor = eDP-1' "$ROOT_DIR/config/hypr/monitors.conf" || \
  fail "monitors.conf must not ship a hardcoded per-output line; baking a fractional scale blurs XWayland apps on panels that don't want it"
rg -q 'monitor = , highrr, auto, auto' "$ROOT_DIR/config/hypr/monitors.conf" || \
  fail "monitors.conf should keep the high-refresh, auto-scale catch-all"
rg -q 'force_zero_scaling = true' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should force_zero_scaling so XWayland (Helium/web-apps) stay crisp under fractional scaling"
rg -q "[$]fileManager = nautilus" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should launch the shipped Files app"
rg -q "[$]menu = sh -lc '\\\$HOME/.local/bin/ryoku-shell launcher'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route launcher through Ryoku shell"
rg -q "[$]clipboard = sh -lc 'cliphist list \\| fuzzel --dmenu" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep clipboard history fallback"
rg -q "[$]systemPanel = sh -lc '\\\$HOME/.local/bin/ryoku-shell settings'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route system bind through Ryoku shell"
rg -q "[$]hyprlandSettings = ryoku-launch-hyprmod" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should launch HyprMod through Ryoku geometry wrapper"
rg -q "[$]powerMenu = sh -lc '\\\$HOME/.local/bin/ryoku-shell session'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route power bind through Ryoku shell"
rg -q "[$]heliumBrowser = sh -lc '\\\$HOME/.local/bin/helium'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should launch Helium through an absolute user-bin path"
rg -q "[$]toggleFloat = sh -lc 'exec \"\\\$HOME/.local/share/ryoku/bin/ryoku-toggle-floating-center\"'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route floating toggle through the Ryoku centering helper"
rg -q "[$]yaziFileManager = .*ryoku-launch-tui yazi" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should launch Yazi through the Ryoku TUI helper"
rg -q "[$]neovimEditor = .*ryoku-launch-tui nvim" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should launch Neovim through the Ryoku TUI helper"
rg -q "[$]obsidianNotes = obsidian" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should define Obsidian as the notes app"
rg -q "exec-once = sh -lc 'systemctl --user reset-failed ryoku-shell.service" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should start ryoku-shell.service"
! rg -q '^exec-once = hypridle' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should leave hypridle lifecycle to hypridle.service"
rg -q 'systemctl --user enable --now hypridle.service' "$ROOT_DIR/install/config/ryoku-hypridle.sh" || \
  fail "Hypridle setup should enable the systemd user service"
rg -q 'env = XCURSOR_THEME,Bibata-Modern-Classic' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should set the Ryoku Xcursor theme for Xwayland apps"
rg -q 'env = HYPRCURSOR_THEME,Bibata-Modern-Classic' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should set the Ryoku Hyprcursor theme"
rg -q 'bezier = smoothOpen,0\.12,0,0\.20,1' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should ship a gentler opening animation curve"
rg -q 'animation = windowsIn, 1, 5, smoothOpen, popin 85%' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should smooth out opening windows"
rg -q 'animation = fadeIn, 1, 5, smoothOpen' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should smooth out opening fades"
rg -q 'set_smooth_opening_animations' "$ROOT_DIR/migrations/1779504291.sh" || \
  fail "Migration should converge existing Hyprland configs to the shipped smooth opening animation"
rg -q 'set_high_refresh_monitor_fallback' "$ROOT_DIR/migrations/1779585854.sh" || \
  fail "Migration should converge existing Hyprland monitor fallback to high refresh"
rg -q 'bind = SUPER SHIFT, R, exec, hyprctl reload' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland reload bind should not restart a shell"
rg -q 'pass_mouse_when_bound = false' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should consume mouse events when mouse binds trigger"
rg -q 'scroll_event_delay = 0' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should handle every Super+scroll tick as a bind"
rg -q 'bind = SUPER, Space, exec, [$]menu' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the launcher bind"
rg -q 'bind = SUPER, V, exec, [$]clipboard' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the clipboard bind"
rg -q 'bind = SUPER, comma, exec, [$]systemPanel' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should move system bind to Super+comma"
rg -q 'bind = SUPER SHIFT, comma, exec, [$]hyprlandSettings' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+Shift+comma to HyprMod"
rg -q 'bind = SUPER, P, exec, [$]powerMenu' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the power bind"
rg -q 'bind = SUPER, B, exec, [$]heliumBrowser' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+B to Helium"
rg -q 'bind = SUPER, E, exec, [$]fileManager' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+E to the files app"
rg -q 'bind = SUPER ALT, E, exec, [$]yaziFileManager' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+Alt+E to Yazi"
rg -q 'bind = SUPER, N, exec, [$]neovimEditor' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+N to Neovim"
rg -q 'bind = SUPER ALT, O, exec, [$]obsidianNotes' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+Alt+O to Obsidian"
! rg -q 'bind = SUPER, O, exec, [$]obsidianNotes' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should not bind Obsidian to Super+O"
rg -q 'SUPER ALT, O' "$ROOT_DIR/migrations/1779758051.sh" || \
  fail "Migration should move Obsidian away from Super+O"
rg -q 'bind = SUPER, Q, killactive,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the close-window bind"
rg -q 'bind = ALT, F4, killactive,' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should support the common close-window bind"
rg -q 'bind = SUPER, A, exec, [$]toggleFloat' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep the centered floating toggle bind"
rg -q 'bindmd = SUPER, mouse:272, Move window, movewindow' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should allow Super+left-drag to move windows"
rg -q 'bindmd = SUPER, mouse:273, Resize window, resizewindow' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should allow Super+right-drag to resize windows"
rg -q 'bind = SUPER, H, movefocus, l' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep HJKL focus navigation"
rg -q 'bind = SUPER SHIFT, H, movewindow, l' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep HJKL move navigation"
rg -q 'bind = SUPER CTRL, 1, movetoworkspace, 1' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should keep direct workspace move binds"
rg -q '[$]workspaceScrollNext = sh -lc .*ryoku-cmd-hypr-workspace-scroll" next' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should define the non-wrapping next workspace scroll helper"
rg -q '[$]workspaceScrollPrev = sh -lc .*ryoku-cmd-hypr-workspace-scroll" prev' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should define the non-wrapping previous workspace scroll helper"
rg -q 'bind = SUPER, mouse_down, exec, [$]workspaceScrollPrev' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+scroll down to the previous open workspace"
rg -q 'bind = SUPER, mouse_up, exec, [$]workspaceScrollNext' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should bind Super+scroll up to the next open workspace"
rg -q 'function queueRefresh' "$ROOT_DIR/shell/services/Hypr.qml" || \
  fail "Hyprland shell service should debounce compositor model refreshes"
rg -q 'root\.queueRefresh\(true, true, false\)' "$ROOT_DIR/shell/services/Hypr.qml" || \
  fail "Window open/close/move events should coalesce toplevel/workspace refreshes"
rg -q '\["activewindow", "windowtitle"\]\.includes\(n\)' "$ROOT_DIR/shell/services/Hypr.qml" || \
  fail "Focus and title churn should not force full toplevel refreshes"
rg -q 'interval: 25' "$ROOT_DIR/shell/services/Hypr.qml" || \
  fail "Hyprland refresh debounce should stay short enough for responsive UI"

echo "PASS: rebirth Hyprland uses the Ryoku shell seed and keeps core binds"
