-- Keyboard layout. User-owned: seeded once on install, then never overwritten by
-- a Ryoku update or redeploy, so edits here persist. For several layouts,
-- comma-separate them and add a switch key, for example:
--     kb_layout  = "us,ru,de,fr"
--     kb_options = "grp:alt_shift_toggle"
-- List codes with `localectl list-x11-keymap-layouts`; variants and options are
-- in the Hyprland wiki (input settings). Setting a layout in Ryoku Settings
-- (Input) writes a single layout that overrides this file, so for multiple
-- layouts edit here and leave the Settings keyboard layout at its default.
hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_options = "",
    },
})
