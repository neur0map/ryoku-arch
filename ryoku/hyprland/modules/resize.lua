-- Resize mode: SUPER+R (in binds.lua) enters this submap and shows a toast, since
-- entering a submap is otherwise silent. Arrow keys or hjkl grow and shrink the
-- active window; Escape, Return, or SUPER+R again hand control back to the normal
-- keymap. The submap is exclusive, so the bare keys resize here without colliding
-- with the global SUPER+arrow focus. SUPER+CTRL+arrows (in binds.lua) resize the
-- same way without entering a mode.
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
