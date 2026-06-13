-- Ryoku Hyprland config (Lua, Hyprland 0.55+). Hyprland loads hyprland.lua instead
-- of hyprland.conf when present. hypr* tools (hyprlock, hypridle) keep their .conf.

local var_terminal = "kitty"
local var_fileManager = "nautilus"
local var_yaziFileManager = "sh -lc '$HOME/.local/share/ryoku/bin/ryoku-launch-tui yazi'"
local var_heliumBrowser = "sh -lc '$HOME/.local/bin/helium'"
local var_neovimEditor = "sh -lc '$HOME/.local/share/ryoku/bin/ryoku-launch-tui nvim'"
local var_obsidianNotes = "obsidian"
local var_menu = "sh -lc '$HOME/.local/share/ryoku/bin/ryoku-launch-app'"
local var_clipboard = "sh -lc '$HOME/.local/bin/ryoku-shell ipc clipboard open'"
local var_gameBar = "sh -lc '$HOME/.local/bin/ryoku-shell ipc gaming toggle'"
local var_systemPanel = "sh -lc '$HOME/.local/bin/ryoku-shell settings'"
local var_wallpaperSwitcher = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-wallpaper-switcher\"'"
local var_hyprlandSettings = "ryoku-launch-hyprmod"
local var_lockscreen = "sh -lc 'exec env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST \"$HOME/.local/share/quickshell-lockscreen/lock.sh\"'"
local var_powerMenu = "sh -lc '$HOME/.local/bin/ryoku-shell session'"
local var_toggleFloat = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-toggle-floating-center\"'"
local var_screenshot = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" screen'"
local var_regionScreenshot = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" region'"
local var_screenshotChooser = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" choose'"
local var_workspaceScrollPrev = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-hypr-workspace-scroll\" prev'"
local var_workspaceScrollNext = "sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-hypr-workspace-scroll\" next'"

-- Theme palette (var_primary, var_tertiary, …). Regenerated on theme switch.
require("colors")

-- Monitor layout is managed by Ryoku Display settings (Settings > Display).
require("monitors")

-- Keyboard layout lives in a user-owned file so updates don't reset it.
require("keyboard")

-- GPU render-device selection is managed by ryoku-gpu (pins the strongest GPU on
-- multi-GPU machines so the desktop renders on the discrete GPU, not a weak iGPU).
require("gpu")

-- DPI-aware monitor scaling: size each panel by its real pixel density (resolution /
-- physical size) so low-DPI external monitors stay 1x and high-DPI laptop panels get
-- bumped, instead of a hardcoded scale. Skips monitors with explicit Display settings.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -lc '$HOME/.local/share/ryoku/bin/ryoku-monitor autoscale'")
    hl.exec_cmd("sh -lc 'systemctl --user reset-failed ryoku-shell.service >/dev/null 2>&1 || true; exec systemctl --user start ryoku-shell.service'")
end)

-- App launcher backend. ryoku-launch-app reads Settings > Launcher (default Vicinae)
-- and, in apply mode, starts the Vicinae server when selected or stops it otherwise.
-- The $menu keybind dispatches to the chosen launcher's window.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -lc '$HOME/.local/share/ryoku/bin/ryoku-launch-app apply'")
end)

-- Authentication agent for privileged GUI actions (pkexec): without it, no password
-- prompt appears for system changes (qylock greeter, mounts, etc.).
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("kdeconnect-indicator")
end)

-- RYOKU: clipboard history now captured by the image-capable ClipboardService
-- (started by the shell); Super+V opens it. cliphist auto-start disabled.
--
-- Cursor theme/size are managed by HyprMod (required below as hyprland-gui); do not
-- hardcode XCURSOR/HYPRCURSOR env here. Border/shadow colors come from colors.lua.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 16,
        border_size = 2,
        col = {
            active_border = {
                colors = {var_primary, var_tertiary},
                angle = 45,
            },
            inactive_border = {
                colors = {var_surface_container, var_outline},
                angle = 45,
            },
        },
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 12,
        active_opacity = 0.98,
        inactive_opacity = 0.92,
        shadow = {
            enabled = true,
            range = 12,
            render_power = 4,
            color = var_shadow,
        },
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
        },
    },
    animations = {
        enabled = true,
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
    },
})

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1")

-- Electron apps (Discord/Vesktop, VS Code, Obsidian, ...) only use the PipeWire
-- screencast portal when they run on Wayland, so screen sharing works. "auto" picks
-- Wayland on Hyprland and falls back to X11 elsewhere; apps that need X11 (Helium)
-- opt in via their own launcher flag, so this is safe as a global default.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.curve("easeOut", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("smoothOpen", { type = "bezier", points = { {0.12, 0}, {0.2, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "easeOut" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "smoothOpen", style = "popin 85%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "easeOut" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 5, bezier = "smoothOpen" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOut" })

-- Let Vicinae (and other launchers) grab focus when they request activation.
hl.config({
    misc = {
        focus_on_activate = true,
    },
})

-- Vicinae launcher: blur the wlr-layer-shell surface so it reads as frosted glass
-- over the desktop (namespace matches the launcher's layer surface).
hl.layer_rule({
    match = {
        namespace = "^(vicinae)$",
    },
    blur = true,
})
hl.layer_rule({
    match = {
        namespace = "^(vicinae)$",
    },
    ignore_alpha = 0.3,
})

-- Render XWayland (X11) clients at native pixel density and let Hyprland scale the
-- surface, instead of letting XWayland bitmap-upscale itself at fractional monitor
-- scales. Without this, Chromium/Electron apps on XWayland (Helium, web-apps) look
-- blurry/pixelated on HiDPI/fractional displays. Matches omarchy's default.
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
    binds = {
        pass_mouse_when_bound = false,
        scroll_event_delay = 0,
    },
})

hl.bind("SUPER + Return", hl.dsp.exec_cmd(var_terminal))
hl.bind("SUPER + T", hl.dsp.exec_cmd(var_terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd(var_fileManager))
hl.bind("SUPER + ALT + E", hl.dsp.exec_cmd(var_yaziFileManager))
hl.bind("SUPER + B", hl.dsp.exec_cmd(var_heliumBrowser))
hl.bind("SUPER + N", hl.dsp.exec_cmd(var_neovimEditor))
hl.bind("SUPER + ALT + O", hl.dsp.exec_cmd(var_obsidianNotes))
hl.bind("SUPER + R", hl.dsp.exec_cmd(var_menu))
hl.bind("SUPER + Space", hl.dsp.exec_cmd(var_menu))
hl.bind("SUPER + V", hl.dsp.exec_cmd(var_clipboard))
hl.bind("SUPER + G", hl.dsp.exec_cmd(var_gameBar))
hl.bind("SUPER + comma", hl.dsp.exec_cmd(var_systemPanel))
hl.bind("SUPER + X", hl.dsp.exec_cmd("sh -lc '$HOME/.local/bin/ryoku-shell ipc plugins toggle'"))
hl.bind("SUPER + W", hl.dsp.exec_cmd(var_wallpaperSwitcher))
hl.bind("SUPER + SHIFT + comma", hl.dsp.exec_cmd(var_hyprlandSettings))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd(var_lockscreen))
hl.bind("SUPER + P", hl.dsp.exec_cmd(var_powerMenu))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + A", hl.dsp.exec_cmd(var_toggleFloat))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {
    mouse = true,
    description = "Move window",
})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {
    mouse = true,
    description = "Resize window",
})
hl.bind("Print", hl.dsp.exec_cmd(var_screenshot))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(var_regionScreenshot))
hl.bind("SUPER + S", hl.dsp.exec_cmd(var_screenshotChooser))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), {
    repeating = true,
    locked = true,
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), {
    repeating = true,
    locked = true,
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
    repeating = true,
    locked = true,
})
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), {
    repeating = true,
    locked = true,
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), {
    repeating = true,
    locked = true,
})
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), {
    locked = true,
})
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true,
})
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true,
})
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), {
    locked = true,
})
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind("SUPER + CTRL + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind("SUPER + CTRL + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind("SUPER + CTRL + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind("SUPER + CTRL + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind("SUPER + CTRL + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind("SUPER + CTRL + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind("SUPER + CTRL + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind("SUPER + CTRL + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind("SUPER + CTRL + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind("SUPER + CTRL + 0", hl.dsp.window.move({ workspace = 10 }))
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd(var_workspaceScrollPrev))
hl.bind("SUPER + mouse_up", hl.dsp.exec_cmd(var_workspaceScrollNext))
hl.bind("SUPER + Left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + Up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + Down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

hl.window_rule({
    match = {
        class = "^(org.kde.polkit-kde-authentication-agent-1)$",
    },
    float = true,
})
hl.window_rule({
    match = {
        title = "^(Picture-in-Picture)$",
    },
    float = true,
})
hl.window_rule({
    match = {
        class = "^(io.github.bluemancz.hyprmod)$",
    },
    float = true,
})
hl.window_rule({
    match = {
        class = "^(io.github.bluemancz.hyprmod)$",
    },
    center = true,
})
hl.window_rule({
    match = {
        class = "^(org.ryoku.screensaver)$",
    },
    fullscreen = true,
})
hl.window_rule({
    match = {
        class = "^(ryoku-control)$",
    },
    float = true,
})
hl.window_rule({
    match = {
        class = "^(ryoku-control)$",
    },
    size = "1280 720",
})
hl.window_rule({
    match = {
        class = "^(ryoku-control)$",
    },
    center = true,
})
hl.window_rule({
    match = {
        class = "^(ryoku-update)$",
    },
    float = true,
})
hl.window_rule({
    match = {
        class = "^(ryoku-update)$",
    },
    size = "900 560",
})
hl.window_rule({
    match = {
        class = "^(ryoku-update)$",
    },
    center = true,
})

-- HyprMod managed settings (transparency, blur, cursor, rounding, bezier).
require("hyprland-gui")

-- Keep web apps and games fully opaque while preserving HyprMod transparency for normal windows.
hl.window_rule({
    match = {
        class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        initial_class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        class = "^(helium|Helium)$",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        initial_class = "^(helium|Helium)$",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        content = "game",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        class = "^(steam_app_[0-9]+|gamescope)$",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        initial_class = "^(steam_app_[0-9]+|gamescope)$",
    },
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
    match = {
        class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        initial_class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        class = "^(helium|Helium)$",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        initial_class = "^(helium|Helium)$",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        content = "game",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        class = "^(steam_app_[0-9]+|gamescope)$",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        initial_class = "^(steam_app_[0-9]+|gamescope)$",
    },
    opaque = true,
})
hl.window_rule({
    match = {
        class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",
    },
    force_rgbx = true,
})
hl.window_rule({
    match = {
        initial_class = "^(chrome|chromium|google-chrome|brave|brave-browser|microsoft-edge|opera|vivaldi)-.+-Default$",
    },
    force_rgbx = true,
})
hl.window_rule({
    match = {
        class = "^(helium|Helium)$",
    },
    force_rgbx = true,
})
hl.window_rule({
    match = {
        initial_class = "^(helium|Helium)$",
    },
    force_rgbx = true,
})
hl.window_rule({
    match = {
        content = "game",
    },
    force_rgbx = true,
})
hl.window_rule({
    match = {
        class = "^(steam_app_[0-9]+|gamescope)$",
    },
    force_rgbx = true,
})
hl.window_rule({
    match = {
        initial_class = "^(steam_app_[0-9]+|gamescope)$",
    },
    force_rgbx = true,
})

-- User-owned overrides. Ryoku never overwrites this file, and it is required LAST so
-- your binds and settings take precedence over the shipped defaults above.
require("custom")
