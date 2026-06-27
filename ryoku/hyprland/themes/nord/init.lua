-- nord: motion + finish. active ryoku theme.
hl.config({
  decoration = {
    rounding_power = 4,
    blur = { vibrancy = 0.15, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.3, 0.9 }, { 0.3, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "ryokuTheme" })
