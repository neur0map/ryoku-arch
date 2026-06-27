-- drift: airy, breathing motion. slow curve at low speed lets windows and
-- workspaces ease in unhurried (calm, ambient feel). wide gaps + soft blur
-- live in the look block.
hl.config({
  decoration = {
    rounding_power = 4,
    blur = { vibrancy = 0.3, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.45, 0.0 }, { 0.25, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "ryokuTheme" })
