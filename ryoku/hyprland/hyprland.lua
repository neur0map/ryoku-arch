require("modules.env")
require("keyboard")
-- hardware drop-ins, written at runtime: ryoku-gpu emits gpu.lua, ryoku-monitor
-- emits monitors.lua, both rewritten on a hotplug or GPU reset. pcall = a
-- half-written or corrupt one falls back to Hyprland defaults instead of
-- dropping the whole config into emergency mode. ryoku doctor repairs the file,
-- autoscale regenerates it next login.
pcall(require, "gpu")
pcall(require, "monitors")
-- hand-written overrides: ~/.config/hypr/monitors_user.lua, never shipped,
-- never touched by ryoku-monitor. loaded after the generated monitors.lua so a
-- pinned panel (fake-EDID needing a forced mode or modeline, a pinned layout)
-- wins. see monitors_user.lua.example.
pcall(require, "monitors_user")
require("modules.displays")
require("modules.input")
require("modules.decoration")
require("modules.animations")
require("modules.binds")
require("modules.resize")
require("modules.ryoshot")
require("modules.window_rules")
require("modules.fullscreen")
require("modules.autostart")

-- selected theme's real Lua (motion, decoration nuances). after the base
-- modules but before settings.lua, so a Look-tab tweak still wins over the
-- theme.
pcall(require, "theme")

-- machine-state written by the hub (ryoku-hub), never shipped. after the base
-- modules so the GUI's tweaks override the defaults, before user.lua so a
-- hand-written user file still wins.
pcall(require, "settings")

pcall(require, "modules.private")

-- GhostType hotkey (the app owns it)
pcall(require, "ghosttype")

-- last word: ~/.config/hypr/user.lua. never shipped, never touched by updates.
pcall(require, "user")
