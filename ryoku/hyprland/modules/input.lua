-- follow_mouse = 2 detaches keyboard focus from the pointer: a newly opened
-- window keeps keyboard focus instead of losing it to whatever the cursor
-- happens to sit over (the follow_mouse = 1 default), and a click moves focus.
-- Fixes "the terminal I just opened isn't active until I move the mouse onto it".
hl.config({
    input = {
        follow_mouse = 2,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})
