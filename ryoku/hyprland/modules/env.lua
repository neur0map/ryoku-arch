hl.env("XCURSOR_THEME",     "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE",      "24")
hl.env("HYPRCURSOR_THEME",  "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE",   "24")

-- VA-API/GLX vendor hints: nvidia only. mesa (AMD/Intel) auto-detects, and
-- forcing them there breaks video decode + Xwayland GL. gate on the driver.
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME",         "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("__GL_GSYNC_ALLOWED",        "0")
    hl.env("__GL_VRR_ALLOWED",          "0")
end

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- GTK4 apps (nautilus, the file manager) hang at startup on wlroots compositors:
-- the default renderer opens its display through org.gnome.Mutter.ServiceChannel,
-- which only exists under GNOME's Mutter, so on Hyprland it never connects. The
-- GL renderer takes a direct Wayland path instead, so pin it: a GTK stack upgrade
-- must never leave the file manager unable to open.
hl.env("GSK_RENDERER", "gl")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")


hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")