echo "Install skwd-wall as the default wallpaper switcher (SUPER+W)"

# Picker + its prebuilt daemon backend. skwd-wall runs in pickOnlyMode and routes
# the chosen wallpaper back through `ryoku wallpaper -f`, so ryoku stays
# authoritative for the wallpaper layer and scheme.json.
ryoku-pkg-add skwd-daemon-bin skwd-wall >/dev/null 2>&1 || true

# Seed the integration config only if the user does not already have one, so a
# customised config.json is never clobbered.
skwd_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/skwd-wall/config.json"
if [[ ! -e $skwd_cfg && -f $RYOKU_PATH/config/skwd-wall/config.json ]]; then
  mkdir -p "$(dirname "$skwd_cfg")"
  cp -a "$RYOKU_PATH/config/skwd-wall/config.json" "$skwd_cfg"
fi

# The picker is inert without its daemon; enable the user service.
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user enable --now skwd-daemon.service >/dev/null 2>&1 || true
fi

# Seeded configs are never overwritten on existing installs, so the SUPER+W
# binding has to be injected into the live hyprland.conf here. Strip any prior
# identical lines first to stay idempotent, then append the var + bind (the var
# precedes the bind so Hyprland resolves it).
hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
switcher_var="\$wallpaperSwitcher = sh -lc 'exec \"\$HOME/.local/share/ryoku/bin/ryoku-cmd-wallpaper-switcher\"'"
switcher_bind="bind = SUPER, W, exec, \$wallpaperSwitcher"

if [[ -f $hypr_conf ]]; then
  tmp_conf=$(mktemp)
  cp "$hypr_conf" "$tmp_conf"

  for line in "$switcher_var" "$switcher_bind"; do
    next_conf=$(mktemp)
    grep -Fxv "$line" "$tmp_conf" >"$next_conf" || true
    mv "$next_conf" "$tmp_conf"
  done

  mv "$tmp_conf" "$hypr_conf"

  printf '\n%s\n%s\n' "$switcher_var" "$switcher_bind" >>"$hypr_conf"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
