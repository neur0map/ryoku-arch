-- The keybind recorder's capture submap. Ryoku Settings enters it (via
-- `hyprctl dispatch submap record`) while the user presses a shortcut to record,
-- then leaves it (`submap reset`) once the chord is captured or cancelled.
--
-- In a submap only its own binds fire, so every chord -- even a live one like
-- SUPER + Q -- passes straight through to the focused Hub window to be read,
-- instead of triggering its normal action mid-record (which would, say, close
-- the Hub). Escape is the one binding: a guaranteed hatch back to the normal
-- keymap even if the Hub goes away while the submap is active, so the keyboard
-- is never stranded in record mode.
hl.define_submap("record", function()
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
