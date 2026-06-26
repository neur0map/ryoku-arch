hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "float-system-dialogs",
    match = { class = "(pavucontrol|nm-connection-editor|blueman-manager|org.kde.polkit-kde-authentication-agent-1|xdg-desktop-portal-gtk)" },
    float = true,
})

hl.window_rule({
    name   = "float-polkit-agent",
    match  = { class = "hyprpolkitagent" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "float-file-pickers",
    match = { title = "(Open File|Save File|Save As|Choose Files|Open Folder)" },
    float = true,
})

hl.window_rule({
    name  = "float-ghosttype",
    match = { class = "Ghosttype-app" },
    float = true,
})

hl.window_rule({
    name  = "float-spotify",
    match = { class = "[Ss]potify" },
    float = true,
})

hl.window_rule({
    name   = "float-nautilus",
    match  = { class = "org.gnome.Nautilus" },
    float  = true,
    size   = { 1500, 850 },
    center = true,
})

hl.window_rule({
    name  = "float-webcam-mirror",
    match = { title = "ryoku-mirror" },
    float = true,
    size  = { 360, 270 },
})

hl.window_rule({
	name   = "float-ryoku-settings",
	match  = { title = "^(Ryoku Settings)$" },
	float  = true,
	size   = { 1360, 880 },
	center = true,
})

hl.window_rule({
    name   = "float-ryoku-extras",
    match  = { class = "ryoku-extras" },
    float  = true,
    size   = { 900, 600 },
    center = true,
})
