-- crt: cyan phosphor finish. active ryoku theme. the wide cyan shadow (look
-- block) fakes the tube glow; the near-linear curve here keeps motion crisp,
-- like a refresh sweep. palette does the rest.
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
