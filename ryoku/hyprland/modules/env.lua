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

-- Shared QML modules (Ryoku.Ui, Ryoku.PluginKit, Ryoku.Blobs) live in
-- /usr/lib/qt6/qml on an installed system, which Qt finds on its own. A
-- deploy.sh checkout puts them under ~/.local instead, and only the daemon
-- injects that path (ipc/daemon.go setupQmlImportPath) -- so the configs it
-- supervises resolve the imports while `qs -c hub` from a keybind does not.
-- Set it for the session so both paths behave the same.
hl.env("QML_IMPORT_PATH",  os.getenv("HOME") .. "/.local/lib/qt6/qml")
hl.env("QML2_IMPORT_PATH", os.getenv("HOME") .. "/.local/lib/qt6/qml")

-- The ryoku-* binaries split the same way: the package ships /usr/bin, a
-- deploy.sh checkout builds them into ~/.local/bin. Put ~/.local/bin first for
-- the session so the Hub, keybind commands, and the shell daemon all run the
-- deployed build, not a stale packaged one (an old ryoku-hub parsing new
-- binds.lua is what showed keybinds as raw K(...)). Harmless on a package
-- install: nothing ryoku sits in ~/.local/bin, so /usr/bin still wins.
hl.env("PATH", (os.getenv("HOME") or "") .. "/.local/bin:" .. (os.getenv("PATH") or ""))


hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")