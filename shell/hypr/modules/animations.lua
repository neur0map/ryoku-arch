hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })

hl.animation({ leaf = "global",     enabled = true, speed = 3,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3,   bezier = "easeOutQuint", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.6, bezier = "easeOutQuint", style = "popin 92%" })
hl.animation({ leaf = "border",     enabled = true, speed = 3,   bezier = "quick" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2.5, bezier = "almostLinear" })
hl.animation({ leaf = "layers",        enabled = true, speed = 7, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 7, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 7, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "slide" })
