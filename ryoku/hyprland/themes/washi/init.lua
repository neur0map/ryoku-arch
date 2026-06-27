-- washi: warm vermilion, clinical snap. single easeOutQuint = quick no-bounce
-- settle. warmth + finish come from the palette and the look block.
hl.config({
  decoration = {
    rounding_power = 3,
    blur = { vibrancy = 0.15, noise = 0.0 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.23, 1.0 }, { 0.32, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "ryokuTheme" })
