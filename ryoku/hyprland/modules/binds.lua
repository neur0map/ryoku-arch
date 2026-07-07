local mod = "SUPER"

-- Windows
hl.bind(mod .. " + Q",         hl.dsp.window.close())                           -- close active window
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())                      -- fullscreen
hl.bind(mod .. " + A",         function() hl.dispatch(hl.dsp.window.float({ action = "toggle" })); hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 660, exact = true })); hl.dispatch(hl.dsp.window.center()) end) -- float at 1000x660, centred (press again to tile back)
hl.bind(mod .. " + R",         function() hl.dispatch(hl.dsp.submap("resize")); hl.dispatch(hl.dsp.exec_cmd("hyprctl notify -1 2200 0 'Resize mode: arrows or hjkl resize, Esc exits'")) end) -- resize mode (arrows/hjkl resize, Esc exits)
hl.bind(mod .. " + P",         hl.dsp.exec_cmd("ryoku-monitor toggle"))         -- mirror <-> extend displays

-- Focus and move windows
hl.bind(mod .. " + Left",          hl.dsp.focus({ direction = "left" }))        -- focus left
hl.bind(mod .. " + Right",         hl.dsp.focus({ direction = "right" }))       -- focus right
hl.bind(mod .. " + Up",            hl.dsp.focus({ direction = "up" }))          -- focus up
hl.bind(mod .. " + Down",          hl.dsp.focus({ direction = "down" }))        -- focus down
hl.bind(mod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "left" }))  -- move window left
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" })) -- move window right
hl.bind(mod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "up" }))    -- move window up
hl.bind(mod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "down" }))  -- move window down
hl.bind(mod .. " + CTRL + Left",   hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true }) -- resize window narrower
hl.bind(mod .. " + CTRL + Right",  hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true }) -- resize window wider
hl.bind(mod .. " + CTRL + Up",     hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true }) -- resize window shorter
hl.bind(mod .. " + CTRL + Down",   hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true }) -- resize window taller

-- Apps
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E",         hl.dsp.exec_cmd("nautilus"))
hl.bind(mod .. " + B",         hl.dsp.exec_cmd("chromium"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("kitty -e nvim"))                -- neovim
hl.bind(mod .. " + ALT + E",   hl.dsp.exec_cmd("kitty -e yazi"))               -- yazi file manager

-- Shell surfaces and tools
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd("ryoku-shell launcher"))
hl.bind(mod .. " + V",         hl.dsp.exec_cmd("ryoku-shell clipboard"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("ryoku-shell lock"))
hl.bind(mod .. " + W",         hl.dsp.exec_cmd("ryoku-shell wallpaper"))         -- next wallpaper
hl.bind(mod .. " + C",         hl.dsp.exec_cmd("flock -n -o /tmp/ryoku-wallpaper.lock qs -c wallpaper")) -- wallpaper switcher (unified images + live, colour-sorted)
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("ryoku-summon ryowalls flock -n -o /tmp/ryowalls.lock qs -c ryowalls")) -- ryowalls: summon to current workspace
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("ryoku-summon ryovm flock -n -o /tmp/ryovm.lock qs -c ryovm")) -- ryovm: summon to current workspace
hl.bind(mod .. " + D",         hl.dsp.exec_cmd("ryoku-shell toolkit"))           -- control deck (stash, tools, utilities)
hl.bind(mod .. " + Tab",       hl.dsp.exec_cmd("flock -n -o /tmp/ryoku-overview.lock qs -c overview")) -- workspace overview (expo: live previews, drag windows between workspaces, cycle)
hl.bind(mod .. " + ALT + Tab", hl.dsp.exec_cmd("flock -n -o /tmp/ryoku-overview.lock qs -c overview")) -- workspace overview, stepping desktops (Alt+Tab again inside cycles desktops)
hl.bind(mod .. " + M",         hl.dsp.exec_cmd("ryoku-shell visualizer"))        -- toggle the desktop audio visualiser
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("ryoku-shell visualizer-overlay")) -- raise the visualiser over windows (flip back to desktop)
hl.bind(mod .. " + grave",     hl.dsp.exec_cmd("ryoku-shell voice"))             -- tap: Voxtype speech-to-text + mic wave (tap again to stop)
hl.bind(mod .. " + comma",     hl.dsp.exec_cmd("flock -n -o /tmp/ryoku-hub.lock qs -c hub"))     -- ryoku settings
hl.bind(mod .. " + K",         hl.dsp.exec_cmd("ryoku-hub config set section keybinds; flock -n -o /tmp/ryoku-hub.lock qs -c hub")) -- keybind reference (the live shortcut legend)
hl.bind(mod .. " + S",         hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock qs -c ryoshot"))  -- screenshot
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))                 -- pick a color

-- Move/resize with the mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspaces. Super+N focuses the Nth workspace OF THE CURRENT DESKTOP (a
-- desktop is a block of 10 workspace ids; see scripts/ryoku-workspace and the
-- overview). On desktop 2, Super+3 -> ws13, never ws3, so each desktop keeps its
-- own 1..10 and windows never jump desktops. The helper also pulls the target to
-- the monitor under the cursor, so the keys drive whichever screen the mouse is
-- on. Super+Alt+N sends the active window to that slot, staying on this desktop.
local ws_helper = (os.getenv("HOME") or "") .. "/.config/hypr/scripts/ryoku-workspace"

hl.bind(mod .. " + H",          hl.dsp.workspace.toggle_special("scratch"))     -- toggle the scratchpad (special workspace)
hl.bind(mod .. " + SHIFT + H",  function() hl.dispatch(hl.dsp.window.float({ action = "enable" })); hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 800, exact = true })); hl.dispatch(hl.dsp.window.center()); hl.dispatch(hl.dsp.window.move({ workspace = "special:scratch", silent = true })) end) -- stash the active window in the scratchpad
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))            -- previous workspace
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))            -- next workspace
for i = 1, 10 do
    local key = i % 10 -- 10 maps to the 0 key
    hl.bind(mod .. " + " .. key,          hl.dsp.exec_cmd(ws_helper .. " focus " .. i)) -- focus slot i of the current desktop
    hl.bind(mod .. " + ALT + " .. key,    hl.dsp.exec_cmd(ws_helper .. " move " .. i))  -- send active window to slot i of the current desktop
end

-- Media and volume keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
