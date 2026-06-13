echo "Enable Hyprland popup blur so tray/context menus match the frosted-glass surfaces"

# [global] native-feel change: xdg-popups (tray menus, context menus, dropdowns) of the
# already-blurred ryoku-drawers layer now inherit the compositor blur, so they read as
# frosted glass instead of flat opaque rectangles. New installs get this from the default
# decoration.blur block in config/hypr/hyprland.lua; existing users get it via this
# idempotent append (hyprland.lua is never wholesale-refreshed, only migrated).
hyprlua="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
[[ -f $hyprlua ]] || exit 0

if ! grep -q "ryoku: blur popups" "$hyprlua"; then
  cat >>"$hyprlua" <<'EOF'

-- ryoku: blur popups (tray menus, context menus inherit the frosted-glass look)
hl.config({
    decoration = {
        blur = {
            popups = true,
            popups_ignorealpha = 0.2,
        },
    },
})
EOF
fi

if ryoku-cmd-present hyprctl; then
  hyprctl reload >/dev/null 2>&1 || true
fi
