-- resize mode. SUPER+R (binds.lua) enters this submap and pops a toast;
-- submap entry is otherwise silent. arrows or hjkl grow/shrink the active
-- window. escape, return, or SUPER+R again hand control back to the normal
-- keymap. exclusive submap, so bare arrows resize here without fighting the
-- global SUPER+arrow focus. SUPER+CTRL+arrows (binds.lua) do the same without
-- entering a mode.
local step = 40

hl.define_submap("resize", function()
    hl.bind("Left",   hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), { repeating = true })
    hl.bind("Right",  hl.dsp.window.resize({ x = step,  y = 0,     relative = true }), { repeating = true })
    hl.bind("Up",     hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), { repeating = true })
    hl.bind("Down",   hl.dsp.window.resize({ x = 0,     y = step,  relative = true }), { repeating = true })
    hl.bind("h",      hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), { repeating = true })
    hl.bind("l",      hl.dsp.window.resize({ x = step,  y = 0,     relative = true }), { repeating = true })
    hl.bind("k",      hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), { repeating = true })
    hl.bind("j",      hl.dsp.window.resize({ x = 0,     y = step,  relative = true }), { repeating = true })
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("SUPER + R", hl.dsp.submap("reset"))
end)
