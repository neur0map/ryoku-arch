local mod = "SUPER"

-- Windows
hl.bind(mod .. " + Q",         hl.dsp.window.close())                           -- close active window
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())                      -- fullscreen
hl.bind(mod .. " + A",         hl.dsp.window.float({ action = "enable" }))      -- compact: pop the window out as floating
hl.bind(mod .. " + SHIFT + A", hl.dsp.window.float({ action = "disable" }))     -- restore: tile it back to normal

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
hl.bind(mod .. " + C",         hl.dsp.exec_cmd("ryoku-shell wallpaper-picker"))  -- wallpaper picker
hl.bind(mod .. " + D",         hl.dsp.exec_cmd("ryoku-shell toolkit"))           -- screen toolkit (lens, color, ocr, mirror, caffeine)
hl.bind(mod .. " + Z",         hl.dsp.exec_cmd("ryoku-shell stash"))             -- file stash
hl.bind(mod .. " + U",         hl.dsp.exec_cmd("ryoku-shell utilities"))         -- utilities (keep-awake, record, toggles, recordings)
hl.bind(mod .. " + comma",     hl.dsp.exec_cmd("flock -n -o /tmp/ryoku-hub.lock qs -c hub"))     -- ryoku hub
hl.bind(mod .. " + S",         hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock qs -c ryoshot"))  -- screenshot
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))                 -- pick a color

-- Move/resize with the mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Switch workspaces
hl.bind(mod .. " + Left",       hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + Right",      hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))
for i = 1, 10 do
    local key = i % 10 -- 10 maps to the 0 key
    hl.bind(mod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
end

-- Media and volume keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
