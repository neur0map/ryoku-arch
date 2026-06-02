echo "Add user-owned hypr/custom.conf and refresh Ryoku keybinds on existing installs"

# Existing installs were seeded copy-if-missing, so ~/.config/hypr/hyprland.conf
# is never refreshed on update and silently lags the repo (this is why shipped
# binds and shell features fail to reach already-installed machines). Fix it:
#   1. Seed the user-owned overrides file (sourced last by hyprland.conf) so
#      custom binds survive this and future refreshes. copy-if-missing.
#   2. Refresh the Ryoku-owned hyprland.conf so the current keybinds/exec-once
#      land. ryoku-refresh-config backs up the existing file first.

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"

if [[ ! -e $hypr_dir/custom.conf ]]; then
  mkdir -p "$hypr_dir"
  if [[ -f $RYOKU_PATH/config/hypr/custom.conf ]]; then
    cp -a "$RYOKU_PATH/config/hypr/custom.conf" "$hypr_dir/custom.conf"
  else
    : >"$hypr_dir/custom.conf"
  fi
  echo "Seeded $hypr_dir/custom.conf (your personal overrides; never overwritten)"
fi

if [[ -f $hypr_dir/hyprland.conf ]] && command -v ryoku-refresh-config >/dev/null 2>&1; then
  ryoku-refresh-config hypr/hyprland.conf
fi

# Apply immediately when a Hyprland session is live; harmless otherwise.
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
