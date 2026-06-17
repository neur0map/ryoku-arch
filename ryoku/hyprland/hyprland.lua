-- Ryoku Hyprland config (Lua, native hl API). Hyprland 0.55+ loads this file from
-- ~/.config/hypr/hyprland.lua. This is the plain pass: a standard tiling desktop,
-- no Ryoku shell, no widgets, no bars.
--
-- Order matters. colors first (the look-and-feel below reads its palette), then
-- the shipped defaults, then the machine-managed and user modules so their values
-- win: keyboard, gpu (cursor + GPU pin), monitors (scale + GDK_SCALE), keybinds,
-- and finally custom for personal overrides.

require("colors")

-- Look and feel.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border = { colors = { var_primary, var_tertiary }, angle = 45 },
            inactive_border = { colors = { var_surface_container, var_outline }, angle = 45 },
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = var_shadow,
        },
        blur = {
            enabled = true,
            size = 6,
            passes = 2,
            new_optimizations = true,
            popups = true,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    input = {
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        focus_on_activate = true,
    },
    -- Render XWayland clients at native density so Chromium/Electron stay crisp
    -- on HiDPI and fractional displays.
    xwayland = {
        force_zero_scaling = true,
    },
})

-- Animation curves and timing.
hl.curve("easeOut", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("smoothOpen", { type = "bezier", points = { {0.12, 0}, {0.2, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "easeOut", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeOut", style = "popin 90%" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "easeOut" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "easeOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOut" })

-- Environment defaults. Machine-managed modules below may override these.
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

-- Keyboard layout (user-owned).
require("keyboard")

-- GPU pin and reverse-PRIME cursor, then per-output scaling. Required after the
-- env defaults so the hardware-managed values win.
require("gpu")
require("monitors")

-- Keybinds.
require("keybinds")

-- Startup. Hand the Wayland session to systemd and D-Bus so xdg-desktop-portal
-- (screen share, file pickers) activates under plain Hyprland, then a polkit agent,
-- the XDG user dirs, and a best-effort hardware autoscale and GPU pin.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE 2>/dev/null; command -v dbus-update-activation-environment >/dev/null 2>&1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE 2>/dev/null; systemctl --user start hyprland-session.target 2>/dev/null")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("xdg-user-dirs-update")
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
    hl.exec_cmd("command -v ryoku-gpu >/dev/null 2>&1 && ryoku-gpu persist")
end)

-- User overrides, required LAST so they win over everything above.
require("custom")
