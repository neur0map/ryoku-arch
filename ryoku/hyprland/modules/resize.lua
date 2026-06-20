-- Resize mode: SUPER+R (in binds.lua) enters this submap, where the arrow keys
-- grow and shrink the active window and Escape or Return hands control back to
-- the normal keymap. The submap is exclusive, so the bare arrows resize here
-- without colliding with SUPER+arrow focus on the global map.
local step = 40

hl.define_submap("resize", function()
    hl.bind("Left",   hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), { repeating = true })
    hl.bind("Right",  hl.dsp.window.resize({ x = step,  y = 0,     relative = true }), { repeating = true })
    hl.bind("Up",     hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), { repeating = true })
    hl.bind("Down",   hl.dsp.window.resize({ x = 0,     y = step,  relative = true }), { repeating = true })
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)
