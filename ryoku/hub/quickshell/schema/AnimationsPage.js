.pragma library

// AnimationsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "GLOBAL",
        "key": "appearance.animations",
        "label": "Animations",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "FOCUS FLASH",
        "key": "plugins.hyprfocus.enabled",
        "label": "Animate the focused window",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "FOCUS FLASH",
        "key": "plugins.hyprfocus.mode",
        "label": "Style",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua",
        "opts": [
            "flash",
            "bounce",
            "slide"
        ]
    },
    {
        "tab": "",
        "group": "FOCUS FLASH",
        "key": "plugins.hyprfocus.opacity",
        "label": "Flash opacity",
        "desc": "",
        "ctl": "slid",
        "src": "settings.lua",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "",
        "group": "FOCUS FLASH",
        "key": "plugins.hyprfocus.bounce",
        "label": "Bounce strength",
        "desc": "",
        "ctl": "slid",
        "src": "settings.lua",
        "lo": 0.5,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "",
        "group": "FOCUS FLASH",
        "key": "plugins.hyprfocus.slide",
        "label": "Slide height",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua",
        "lo": 0.0,
        "hi": 150.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "",
        "label": "Curve (selector)",
        "desc": "",
        "ctl": "pick",
        "src": "(none \u2014 transient page state: page.selectedCurve)",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves[name=<selected>].x0",
        "label": "Bezier curve P1 x (first control point, X)",
        "desc": "",
        "ctl": "slid",
        "src": "settings.lua",
        "lo": 0.0,
        "hi": 1.0
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves[name=<selected>].y0",
        "label": "Bezier curve P1 y (first control point, Y)",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua",
        "lo": -1.0,
        "hi": 2.0
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves[name=<selected>].x1",
        "label": "Bezier curve P2 x (second control point, X)",
        "desc": "",
        "ctl": "slid",
        "src": "settings.lua",
        "lo": 0.0,
        "hi": 1.0
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves[name=<selected>].y1",
        "label": "Bezier curve P2 y (second control point, Y)",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua",
        "lo": -1.0,
        "hi": 2.0
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves",
        "label": "User bezier curves (the whole list)",
        "desc": "",
        "ctl": "list",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves (append)",
        "label": "New (add curve)",
        "desc": "",
        "ctl": "action",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "CURVES",
        "key": "anim.curves (remove by name)",
        "label": "Delete / Reset (curve)",
        "desc": "",
        "ctl": "action",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "(action bar)",
        "key": "anim.items = [] ; anim.curves = []",
        "label": "Reset to defaults",
        "desc": "",
        "ctl": "action",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=borderangle].enabled",
        "label": "borderangle  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=borderangle].speed",
        "label": "borderangle  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=borderangle].bezier",
        "label": "borderangle  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsIn].enabled",
        "label": "windowsIn  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsIn].speed",
        "label": "windowsIn  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsIn].bezier",
        "label": "windowsIn  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsIn].style",
        "label": "windowsIn  \u00b7  style",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "popin",
            "gnomed"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeOut].enabled",
        "label": "fadeOut  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeOut].speed",
        "label": "fadeOut  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeOut].bezier",
        "label": "fadeOut  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fade].enabled",
        "label": "fade  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fade].speed",
        "label": "fade  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fade].bezier",
        "label": "fade  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=border].enabled",
        "label": "border  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=border].speed",
        "label": "border  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=border].bezier",
        "label": "border  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=workspaces].enabled",
        "label": "workspaces  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=workspaces].speed",
        "label": "workspaces  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=workspaces].bezier",
        "label": "workspaces  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=workspaces].style",
        "label": "workspaces  \u00b7  style",
        "desc": "",
        "ctl": "chips",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "slidevert",
            "fade",
            "slidefade",
            "slidefadevert"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=global].enabled",
        "label": "global  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=global].speed",
        "label": "global  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=global].bezier",
        "label": "global  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsOut].enabled",
        "label": "windowsOut  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsOut].speed",
        "label": "windowsOut  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsOut].bezier",
        "label": "windowsOut  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsOut].style",
        "label": "windowsOut  \u00b7  style",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "popin",
            "gnomed"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=layers].enabled",
        "label": "layers  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=layers].speed",
        "label": "layers  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=layers].bezier",
        "label": "layers  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=layers].style",
        "label": "layers  \u00b7  style",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "popin",
            "fade"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeIn].enabled",
        "label": "fadeIn  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeIn].speed",
        "label": "fadeIn  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeIn].bezier",
        "label": "fadeIn  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=specialWorkspace].enabled",
        "label": "specialWorkspace  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=specialWorkspace].speed",
        "label": "specialWorkspace  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=specialWorkspace].bezier",
        "label": "specialWorkspace  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=specialWorkspace].style",
        "label": "specialWorkspace  \u00b7  style",
        "desc": "",
        "ctl": "chips",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "slidevert",
            "fade",
            "slidefade",
            "slidefadevert"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windows].enabled",
        "label": "windows  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windows].speed",
        "label": "windows  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windows].bezier",
        "label": "windows  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windows].style",
        "label": "windows  \u00b7  style",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "popin",
            "gnomed"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeLayersIn].enabled",
        "label": "fadeLayersIn  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeLayersIn].speed",
        "label": "fadeLayersIn  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeLayersIn].bezier",
        "label": "fadeLayersIn  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeLayersOut].enabled",
        "label": "fadeLayersOut  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeLayersOut].speed",
        "label": "fadeLayersOut  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=fadeLayersOut].bezier",
        "label": "fadeLayersOut  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsMove].enabled",
        "label": "windowsMove  \u00b7  enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsMove].speed",
        "label": "windowsMove  \u00b7  speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 10.0
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsMove].bezier",
        "label": "windowsMove  \u00b7  bezier curve",
        "desc": "",
        "ctl": "pick",
        "src": "hypr.json",
        "opts": [
            "ryokuWobble",
            "dynamic-cursors-magnification",
            "ryokuTheme",
            "ryokuBloom",
            "almostLinear",
            "ryokuSettle",
            "quick",
            "easeOutQuint",
            "linear",
            "default"
        ]
    },
    {
        "tab": "",
        "group": "ANIMATIONS",
        "key": "anim.items[leaf=windowsMove].style",
        "label": "windowsMove  \u00b7  style",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "",
            "slide",
            "popin",
            "gnomed"
        ]
    }
];
