require("modules.env")
require("keyboard")
require("gpu")
require("monitors")
require("modules.displays")
require("modules.input")
require("modules.decoration")
require("modules.animations")
require("modules.binds")
require("modules.ryoshot")
require("modules.window_rules")
require("modules.fullscreen")
require("modules.autostart")

pcall(require, "modules.private")

-- GhostType hotkey (managed by the app)
pcall(require, "ghosttype")

-- User overrides: ~/.config/hypr/user.lua is never shipped or touched by updates
-- and loads last, so your settings win over the base config.
pcall(require, "user")
