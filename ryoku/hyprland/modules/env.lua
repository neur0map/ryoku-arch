hl.env("XCURSOR_THEME",     "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE",      "24")
hl.env("HYPRCURSOR_THEME",  "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE",   "24")

-- VA-API/GLX hints are nvidia-only: mesa auto-detects, and forcing them breaks
-- video decode + Xwayland GL. AQ_NO_MODIFIERS is the opposite, a mesa-only fix.
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME",         "nvidia")
    -- NVD_BACKEND=direct: nvidia VA-API direct backend (Turing+), omarchy's GSP default.
    hl.env("NVD_BACKEND",               "direct")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("__GL_GSYNC_ALLOWED",        "0")
    hl.env("__GL_VRR_ALLOWED",          "0")
else
    -- dodges Hyprland's post-capture black screen (#11315). Not on nvidia: it
    -- can't import the modifier-less buffer and SIGABRTs the first multi-GPU commit.
    hl.env("AQ_NO_MODIFIERS", "1")
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

-- The shell daemon registers as the PolicyKit1 authentication agent, so an
-- administrator password is asked for on a Ryoku island instead of the stock
-- agent's grey dialog. The daemon reads it at startup; without it the daemon
-- leaves the slot alone.
hl.env("RYOKU_POLKIT_AGENT", "1")
hl.env("QML2_IMPORT_PATH", os.getenv("HOME") .. "/.local/lib/qt6/qml")

-- deploy.sh builds the ryoku-* binaries into ~/.local/bin; put it first so the
-- session runs them, not the package's /usr/bin copies. Inert on a package
-- install, where ~/.local/bin holds no ryoku binaries.
hl.env("PATH", (os.getenv("HOME") or "") .. "/.local/bin:" .. (os.getenv("PATH") or ""))


hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")