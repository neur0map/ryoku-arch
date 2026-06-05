echo "Repair invalid bare multimedia keysyms in HyprMod's Hyprland config"

# HyprMod (the AUR Hyprland settings GUI) can write a multimedia key by its bare
# name (e.g. "Tools") into ~/.config/hypr/hyprland-gui.{lua,conf}. Hyprland only
# accepts the XF86-prefixed keysym ("XF86Tools"), so one bare name fails the whole
# config load and the session falls back to defaults: dead keybinds and an unscaled
# monitor. Rewrite the known bare keynames to their XF86 keysyms so existing installs
# that already hit this come up correctly. Idempotent; only touches HyprMod-owned
# files. ryoku-doctor runs the same check/repair on demand for recurrences.

fixer="$RYOKU_PATH/bin/ryoku-hypr-fix-keysyms"
if [[ -x $fixer ]]; then
  "$fixer" || true
fi
