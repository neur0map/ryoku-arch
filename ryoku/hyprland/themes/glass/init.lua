-- glass: frosted, translucent finish. active ryoku theme. heavy blur and
-- window alpha come from the look block; this file bumps blur vibrancy and
-- gives windows a small overshoot so they pop into place.
hl.config({
  decoration = {
    rounding_power = 2,
    blur = { vibrancy = 0.4, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "ryokuTheme" })
