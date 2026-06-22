-- Soft Color: a dreamy pastel finish, loaded as the active Ryoku theme. High
-- blur vibrancy and a gentle, slightly slow curve give it a soft, floaty feel;
-- the palette and the heavy blur in the look block do the rest.
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
