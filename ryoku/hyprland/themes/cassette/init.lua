-- cassette: the flat yorha motion. active ryoku theme. sharp, blurless,
-- shadowless finish comes from the look block; this file = one gentle curve
-- and a slide-led feel so windows arrive instead of springing.
hl.curve("ryokuTheme", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "ryokuTheme" })
