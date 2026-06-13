echo "Repair Wayland screen sharing for existing installs (portal + indicator placement)"

# xdg-desktop-portal >= 1.20 ships Requisite=graphical-session.target, which a bare
# (non-uwsm) Hyprland session never brings up -- so the portal frontend stayed dead and
# every Wayland screen-share / file-picker silently failed. Ship + activate a session
# wrapper target, then append the session bringup + the Chromium screen-share indicator
# window rule to the live hyprland.lua (which is migrated, never wholesale-refreshed) so
# both survive re-login. New installs get all of this from config/hypr/hyprland.lua and
# config/systemd/user/hyprland-session.target.

ryoku-refresh-config systemd/user/hyprland-session.target

if ryoku-cmd-present systemctl; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  # graphical-session.target has RefuseManualStart, so it is pulled in via the wrapper.
  env_vars="WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY XAUTHORITY"
  # shellcheck disable=SC2086
  systemctl --user import-environment $env_vars >/dev/null 2>&1 || true
  if ryoku-cmd-present dbus-update-activation-environment; then
    # shellcheck disable=SC2086
    dbus-update-activation-environment --systemd $env_vars >/dev/null 2>&1 || true
  fi
  systemctl --user start hyprland-session.target >/dev/null 2>&1 || true
fi

hyprlua="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
if [[ -f $hyprlua ]]; then
  if ! grep -q "ryoku: portal session bringup" "$hyprlua"; then
    cat >>"$hyprlua" <<'EOF'

-- ryoku: portal session bringup (graphical-session.target for xdg-desktop-portal)
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -lc 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY XAUTHORITY 2>/dev/null; command -v dbus-update-activation-environment >/dev/null 2>&1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY XAUTHORITY 2>/dev/null; systemctl --user start hyprland-session.target'")
end)
EOF
  fi
  if ! grep -q "ryoku: screen-share indicator" "$hyprlua"; then
    cat >>"$hyprlua" <<'EOF'

-- ryoku: screen-share indicator (float + pin + park bottom; Chromium Hide is a Wayland no-op)
hl.window_rule({ match = { title = ".*is sharing (a window|your screen).*" }, float = true })
hl.window_rule({ match = { title = ".*is sharing (a window|your screen).*" }, pin = true })
hl.window_rule({ match = { title = ".*is sharing (a window|your screen).*" }, move = { "(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)" } })
EOF
  fi
  if ryoku-cmd-present hyprctl; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
fi
