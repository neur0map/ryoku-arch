-- mountains: calm, neutral earth-tone. steady curve at moderate speed = motion
-- stays grounded and unhurried. desaturated palette + modest blur come from
-- the look block.
hl.config({
  decoration = {
    rounding_power = 2,
    blur = { vibrancy = 0.1, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.2, 1.0 }, { 0.3, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "ryokuTheme" })
