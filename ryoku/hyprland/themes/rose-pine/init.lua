-- rose-pine: motion + finish (active theme).
hl.config({
  decoration = {
    rounding_power = 5,
    blur = { vibrancy = 0.22, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.4, 1.0 }, { 0.3, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "ryokuTheme" })
