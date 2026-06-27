-- gruvbox: motion + finish (active theme).
hl.config({
  decoration = {
    rounding_power = 3,
    blur = { vibrancy = 0.1, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.2, 1.0 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "ryokuTheme" })
