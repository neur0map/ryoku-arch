hl.config({
    misc = {
        -- keyboard focus follows an app's activation request, else a window mapping
        -- off the focused monitor comes up un-typeable (Discord, Vivaldi)
        focus_on_activate = true,
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        -- a locker that crashes while locked (GPU glitch on resume) otherwise
        -- wedges the session on a black screen that eats every key. with this,
        -- Hyprland accepts a fresh locker instead of stranding the session.
        allow_session_lock_restore = true,
    },
    xwayland = {
        force_zero_scaling = true, -- XWayland (Chromium/Electron) crisp on HiDPI
    },
})
