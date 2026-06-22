-- Drift: an airy, breathing motion, loaded as the active Ryoku theme. A slow
-- curve at a low speed lets windows and workspaces ease in unhurriedly, for a
-- calm, ambient feel; the wide gaps and soft blur come from the look block.
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
