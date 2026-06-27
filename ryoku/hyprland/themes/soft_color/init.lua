-- soft color: dreamy pastel finish. active ryoku theme. high blur vibrancy +
-- a gentle, slightly slow curve = soft, floaty feel. palette and the heavier
-- blur live in the look block.
hl.config({
  decoration = {
    rounding_power = 4,
    blur = { vibrancy = 0.35, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.25, 0.9 }, { 0.25, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "ryokuTheme" })
