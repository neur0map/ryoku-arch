-- Cassette: the flat YoRHa motion, loaded as the active Ryoku theme. The sharp,
-- blurless, shadowless finish comes from the look block; here we set one gentle
-- curve and a slide-led feel so windows arrive deliberately rather than springing.
hl.curve("ryokuTheme", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "ryokuTheme" })
