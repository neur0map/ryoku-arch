#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $ROOT_DIR/config/hypr/hyprland.lua ]] || \
  fail "missing Hyprland entry config"
[[ -f $ROOT_DIR/config/hypr/colors.lua ]] || \
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

rg -q 'require\("colors"\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should source a local color fallback"
! rg -q 'ryoku-user-binds|Ryoku Keybinds|SUPER \+ slash' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should not ship the removed Super+/ keybind menu"
! rg -q 'output = "eDP-1"' "$ROOT_DIR/config/hypr/monitors.lua" || \
  fail "monitors.lua must not ship a hardcoded per-output line; baking a fractional scale blurs XWayland apps on panels that don't want it"
rg -q 'mode = "highrr"' "$ROOT_DIR/config/hypr/monitors.lua" || \
  fail "monitors.lua should keep the high-refresh, auto-scale catch-all"
rg -q 'force_zero_scaling = true' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should force_zero_scaling so XWayland (Helium/web-apps) stay crisp under fractional scaling"
rg -q 'local var_fileManager = "nautilus"' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should launch the shipped Files app"
rg -q 'local var_menu = .*ryoku-launch-app' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should route the launcher through ryoku-launch-app"
rg -q 'local var_clipboard = .*ryoku-shell ipc clipboard open' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should route clipboard through the Ryoku shell"
rg -q 'local var_systemPanel = .*ryoku-shell settings' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should route system bind through Ryoku shell"
rg -q 'local var_hyprlandSettings = "ryoku-launch-hyprmod"' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should launch HyprMod through Ryoku geometry wrapper"
rg -q 'local var_powerMenu = .*ryoku-shell session' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should route power bind through Ryoku shell"
rg -q 'local var_heliumBrowser = .*\.local/bin/helium' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should launch Helium through an absolute user-bin path"
rg -q 'local var_toggleFloat = .*ryoku-toggle-floating-center' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should route floating toggle through the Ryoku centering helper"
rg -q 'local var_yaziFileManager = .*ryoku-launch-tui yazi' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should launch Yazi through the Ryoku TUI helper"
rg -q 'local var_neovimEditor = .*ryoku-launch-tui nvim' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should launch Neovim through the Ryoku TUI helper"
rg -q 'local var_obsidianNotes = "obsidian"' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should define Obsidian as the notes app"
rg -q 'systemctl --user reset-failed ryoku-shell.service' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should start ryoku-shell.service"
! rg -q 'hl.exec_cmd\("hypridle' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should leave hypridle lifecycle to hypridle.service"
rg -q 'systemctl --user enable --now hypridle.service' "$ROOT_DIR/install/config/ryoku-hypridle.sh" || \
  fail "Hypridle setup should enable the systemd user service"
! rg -q 'XCURSOR_THEME|HYPRCURSOR_THEME' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should leave cursor theme to HyprMod, not hardcode XCURSOR/HYPRCURSOR env"
rg -q 'hl.env\("XCURSOR_THEME", "Bibata-Modern-Classic"\)' "$ROOT_DIR/config/hypr/hyprland-gui.lua" || \
  fail "Ryoku should ship the Bibata Xcursor theme via the HyprMod seed (hyprland-gui.lua)"
rg -q 'hl.curve\("smoothOpen", \{ type = "bezier", points = \{ \{0.12, 0\}, \{0.2, 1\} \} \}' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should ship a gentler opening animation curve"
rg -q 'leaf = "windowsIn".*popin 85%' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should smooth out opening windows"
rg -q 'leaf = "fadeIn".*bezier = "smoothOpen"' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should smooth out opening fades"
rg -q 'set_smooth_opening_animations' "$ROOT_DIR/migrations/1779504291.sh" || \
  fail "Migration should converge existing Hyprland configs to the shipped smooth opening animation"
rg -q 'set_high_refresh_monitor_fallback' "$ROOT_DIR/migrations/1779585854.sh" || \
  fail "Migration should converge existing Hyprland monitor fallback to high refresh"
rg -q 'SUPER \+ SHIFT \+ R", hl.dsp.exec_cmd\("hyprctl reload"\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland reload bind should not restart a shell"
rg -q 'pass_mouse_when_bound = false' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should consume mouse events when mouse binds trigger"
rg -q 'scroll_event_delay = 0' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should handle every Super+scroll tick as a bind"
rg -q 'SUPER \+ Space", hl.dsp.exec_cmd\(var_menu\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep the launcher bind"
rg -q 'SUPER \+ V", hl.dsp.exec_cmd\(var_clipboard\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep the clipboard bind"
rg -q 'SUPER \+ comma", hl.dsp.exec_cmd\(var_systemPanel\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should move system bind to Super+comma"
rg -q 'SUPER \+ SHIFT \+ comma", hl.dsp.exec_cmd\(var_hyprlandSettings\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+Shift+comma to HyprMod"
rg -q 'SUPER \+ P", hl.dsp.exec_cmd\(var_powerMenu\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep the power bind"
rg -q 'SUPER \+ B", hl.dsp.exec_cmd\(var_heliumBrowser\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+B to Helium"
rg -q 'SUPER \+ E", hl.dsp.exec_cmd\(var_fileManager\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+E to the files app"
rg -q 'SUPER \+ ALT \+ E", hl.dsp.exec_cmd\(var_yaziFileManager\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+Alt+E to Yazi"
rg -q 'SUPER \+ N", hl.dsp.exec_cmd\(var_neovimEditor\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+N to Neovim"
rg -q 'SUPER \+ ALT \+ O", hl.dsp.exec_cmd\(var_obsidianNotes\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+Alt+O to Obsidian"
! rg -q 'SUPER \+ O", hl.dsp.exec_cmd\(var_obsidianNotes\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should not bind Obsidian to Super+O"
rg -q 'SUPER ALT, O' "$ROOT_DIR/migrations/1779758051.sh" || \
  fail "Migration should move Obsidian away from Super+O"
rg -q 'SUPER \+ Q", hl.dsp.window.close\(\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep the close-window bind"
rg -q 'ALT \+ F4", hl.dsp.window.close\(\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should support the common close-window bind"
rg -q 'SUPER \+ A", hl.dsp.exec_cmd\(var_toggleFloat\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep the centered floating toggle bind"
rg -q 'SUPER \+ mouse:272", hl.dsp.window.drag\(\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should allow Super+left-drag to move windows"
rg -q 'SUPER \+ mouse:273", hl.dsp.window.resize\(\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should allow Super+right-drag to resize windows"
rg -q 'SUPER \+ H", hl.dsp.focus\(\{ direction = "left" \}\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep HJKL focus navigation"
rg -q 'SUPER \+ SHIFT \+ H", hl.dsp.window.move\(\{ direction = "left" \}\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep HJKL move navigation"
rg -q 'SUPER \+ CTRL \+ 1", hl.dsp.window.move\(\{ workspace = 1 \}\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should keep direct workspace move binds"
rg -q 'var_workspaceScrollNext = .*ryoku-cmd-hypr-workspace-scroll.* next' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should define the non-wrapping next workspace scroll helper"
rg -q 'var_workspaceScrollPrev = .*ryoku-cmd-hypr-workspace-scroll.* prev' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should define the non-wrapping previous workspace scroll helper"
rg -q 'SUPER \+ mouse_down", hl.dsp.exec_cmd\(var_workspaceScrollPrev\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
  fail "Hyprland config should bind Super+scroll down to the previous open workspace"
rg -q 'SUPER \+ mouse_up", hl.dsp.exec_cmd\(var_workspaceScrollNext\)' "$ROOT_DIR/config/hypr/hyprland.lua" || \
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
