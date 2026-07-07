-- optional(mod): load a drop-in only when its file exists. most of these are
-- never shipped (user overrides, hub and theme output), and hyprland reports
-- even a pcall'd require() of a missing module in the config-error overlay,
-- so a fresh home flashed "Your config has errors" on first boot. probe the
-- path first; a file that exists but is torn or corrupt still degrades via
-- pcall instead of emergency mode, and ryoku doctor repairs it.
local function optional(mod)
    if package.searchpath == nil or package.searchpath(mod, package.path) then
        pcall(require, mod)
    end
end

require("modules.env")
require("keyboard")
-- hardware drop-ins, written at runtime: ryoku-gpu emits gpu.lua, ryoku-monitor
-- emits monitors.lua, both rewritten on a hotplug or GPU reset. ryoku doctor
-- repairs a corrupt one, autoscale regenerates it next login.
optional("gpu")
optional("monitors")
-- hand-written overrides: ~/.config/hypr/monitors_user.lua, never shipped,
-- never touched by ryoku-monitor. loaded after the generated monitors.lua so a
-- pinned panel (fake-EDID needing a forced mode or modeline, a pinned layout)
-- wins. see monitors_user.lua.example.
optional("monitors_user")
require("modules.displays")
require("modules.input")
require("modules.misc")
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
optional("theme")

-- machine-state written by the hub (ryoku-hub), never shipped. after the base
-- modules so the GUI's tweaks override the defaults, before user.lua so a
-- hand-written user file still wins.
optional("settings")

optional("modules.private")

-- GhostType hotkey (the app owns it)
optional("ghosttype")

-- last word: ~/.config/hypr/user.lua. never shipped, never touched by updates.
optional("user")
