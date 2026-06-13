echo "Install Chromium, switch the default browser from Helium, and rebind SUPER+B"

# Helium runs under XWayland to dodge a Chromium-on-Wayland rendering bug, but XWayland
# clients cannot capture native Wayland windows, so screen sharing (Discord/Meet/OBS)
# shows a black screen. Chromium on Wayland drives the PipeWire screencast portal and
# shares correctly. Install Chromium and switch installs that still default to Helium;
# a browser the user deliberately chose is left untouched. Helium is NOT removed, so its
# bookmarks/passwords can still be exported. New installs get Chromium from
# install/ryoku-base.packages + install/config/mimetypes.sh.
ryoku-default-app-migrate browser chromium yes
status=$?

# Rebind SUPER+B to the new default. The keybind execs the var_heliumBrowser value in
# the live hyprland.lua (migrated, never wholesale-refreshed). Only rewrite it once
# Chromium is actually the default browser, so the bind never points at a browser that
# failed to install, and only while it still holds the Ryoku Helium default; a value the
# user customized is left alone.
if [[ $(xdg-settings get default-web-browser 2>/dev/null || true) == "chromium.desktop" ]]; then
  hyprlua="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
  if [[ -f $hyprlua ]] && grep -qE '^local var_heliumBrowser = .*helium' "$hyprlua"; then
    sed -i -E 's|^local var_heliumBrowser = .*helium.*|local var_heliumBrowser = "chromium"|' "$hyprlua"
    if ryoku-cmd-present hyprctl; then
      hyprctl reload >/dev/null 2>&1 || true
    fi
  fi
fi

# Propagate ryoku-default-app-migrate's status so a deferred install (exit 75) is retried.
exit "$status"
