-- Voxtype output-suppression submap. Ryoku triggers dictation with Super+`, so
-- when Voxtype types the transcription its injected keys can collide with a
-- still-held modifier and get eaten as a shortcut instead of inserted at the
-- cursor. Voxtype's config enters this submap right before typing
-- (pre_output_command) and leaves it right after (post_output_command); the
-- modifier keys are bound to no-ops here so the text lands as plain characters.
-- F12 escapes if output ever hangs. Do not bind Escape: it drops wtype's first
-- character (Hyprland issue 3165).
hl.define_submap("voxtype_suppress", function()
    hl.bind("SUPER_L",   hl.dsp.exec_cmd("true"))
    hl.bind("SUPER_R",   hl.dsp.exec_cmd("true"))
    hl.bind("Control_L", hl.dsp.exec_cmd("true"))
    hl.bind("Control_R", hl.dsp.exec_cmd("true"))
    hl.bind("Alt_L",     hl.dsp.exec_cmd("true"))
    hl.bind("Alt_R",     hl.dsp.exec_cmd("true"))
    hl.bind("Shift_L",   hl.dsp.exec_cmd("true"))
    hl.bind("Shift_R",   hl.dsp.exec_cmd("true"))
    hl.bind("F12",       hl.dsp.submap("reset"))
end)
