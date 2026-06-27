-- compact: dense + soft pop. tight gaps, light rounding and low shadow come
-- from the look block. curve below has a whisper of overshoot so windows
-- spring into place as they settle.
hl.curve("ryokuTheme", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "ryokuTheme" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "ryokuTheme" })
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "ryokuTheme" })
