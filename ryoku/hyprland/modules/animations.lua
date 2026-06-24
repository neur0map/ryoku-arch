hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("ryokuBloom",     { type = "bezier", points = { { 0.16, 1.12 }, { 0.24, 1 } } })
hl.curve("ryokuSettle",    { type = "bezier", points = { { 0.18, 0.86 }, { 0.24, 1 } } })

hl.animation({ leaf = "global",     enabled = true, speed = 3.2, bezier = "ryokuSettle" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3.2, bezier = "ryokuSettle" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.8, bezier = "ryokuBloom",  style = "popin 78%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.4, bezier = "ryokuSettle", style = "popin 86%" })
hl.animation({ leaf = "border",     enabled = true, speed = 3.5, bezier = "quick" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3.2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2.2, bezier = "almostLinear" })
hl.animation({ leaf = "layers",        enabled = true, speed = 7, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 7, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 7, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6,   bezier = "easeOutQuint", style = "slidefadevert 20%" })
