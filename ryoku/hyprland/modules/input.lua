-- follow_mouse = 2 detaches keyboard focus from the pointer: a newly opened
-- window keeps keyboard focus instead of losing it to whatever the cursor
-- happens to sit over (the follow_mouse = 1 default), and a click moves focus.
-- Fixes "the terminal I just opened isn't active until I move the mouse onto it".
hl.config({
    input = {
        follow_mouse = 2,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    -- focus_on_activate = true honours an app's xdg-activation focus request, so a
    -- window that maps (or an already-running instance brought forward) on a
    -- non-focused workspace/monitor actually receives keyboard focus instead of
    -- coming up un-typeable. Without it Hyprland's default (false) ignores the
    -- request and keystrokes keep going to the previously focused window until you
    -- move the window to another monitor or reopen the app -- the exact symptom
    -- hit with Discord (Electron) and Vivaldi (Chromium). It rode in the misc block
    -- of the old monolithic config and was dropped in the modular refactor
    -- (ca28de6c); follow_mouse = 2 then removed the pointer fallback that had been
    -- masking it. Verified live: with this false the activation request is ignored,
    -- with it true keyboard focus moves to the activated window.
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        focus_on_activate = true,
    },
    -- Render XWayland clients at native density so Chromium/Electron stay crisp on
    -- HiDPI / fractional displays instead of blurry-upscaled. Same block as misc
    -- above; both were lost in the modular refactor (ca28de6c).
    xwayland = {
        force_zero_scaling = true,
    },
})
