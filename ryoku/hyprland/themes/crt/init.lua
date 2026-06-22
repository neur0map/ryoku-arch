-- CRT: a cyan phosphor finish, loaded as the active Ryoku theme. A wide cyan
-- shadow stands in for the tube glow, and a quick, almost-linear curve keeps the
-- motion crisp like a refresh sweep; the palette carries the rest.
hl.config({
  decoration = {
    rounding_power = 2,
    blur = { vibrancy = 0.2, noise = 0.05 },
  },
})

hl.curve("ryokuTheme", { type = "bezier", points = { { 0.15, 0.0 }, { 0.1, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "ryokuTheme" })
