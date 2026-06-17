local mod = "SUPER"

hl.bind(mod .. " + W",         hl.dsp.window.kill())
hl.bind("CTRL + SHIFT + W",    hl.dsp.window.close())
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + E",         hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + M",         hl.dsp.window.move({ workspace = "special:minimized", follow = false }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Left",       hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + Right",      hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mod .. " + SHIFT + C",  hl.dsp.exec_cmd("hyprpicker -a"))

hl.bind(mod .. " + Space",      hl.dsp.exec_cmd("ryoku-shell launcher"))
hl.bind(mod .. " + V",          hl.dsp.exec_cmd("ryoku-shell clipboard"))

hl.bind(mod .. " + SUPER_L",    hl.dsp.exec_cmd("ryoku-shell link"), { release = true })

hl.bind(mod .. " + L",          hl.dsp.exec_cmd("ryoku-shell lock"))

hl.bind(mod .. " + B",          hl.dsp.exec_cmd("ryoku-shell wallpaper"))
hl.bind(mod .. " + C",          hl.dsp.exec_cmd("ryoku-shell wallpaper-picker"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
