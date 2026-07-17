.pragma library

// AppearancePage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "Look",
        "group": "SHAPE",
        "key": "appearance.rounding",
        "label": "Corner radius",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua)",
        "lo": 0.0,
        "hi": 30.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "SHAPE",
        "key": "appearance.roundingPower",
        "label": "Corner softness",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 2.0,
        "hi": 8.0
    },
    {
        "tab": "Look",
        "group": "SHAPE",
        "key": "appearance.borderSize",
        "label": "Border thickness",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 12.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "SHAPE",
        "key": "appearance.layout",
        "label": "Tiling layout",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "dwindle",
            "master",
            "scrolling"
        ]
    },
    {
        "tab": "Look",
        "group": "SHAPE",
        "key": "plugins.hyprscrolling.columnWidth",
        "label": "Column width",
        "desc": "",
        "ctl": "slid",
        "src": "hypr.json",
        "lo": 0.1,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "Look",
        "group": "SHAPE",
        "key": "plugins.hyprscrolling.followFocus",
        "label": "Scroll to follow focus",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GAPS",
        "key": "appearance.gapsIn",
        "label": "Inner (between windows)",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "GAPS",
        "key": "appearance.gapsOut",
        "label": "Outer (screen edge)",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "BEHAVIOUR",
        "key": "appearance.resizeOnBorder",
        "label": "Drag to resize at window edges",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "BEHAVIOUR",
        "key": "appearance.snapEnabled",
        "label": "Snap floating windows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.enabled",
        "label": "Window title bars",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.height",
        "label": "Bar height",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 12.0,
        "hi": 48.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.textSize",
        "label": "Title text size",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 8.0,
        "hi": 20.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.blur",
        "label": "Blur the bar",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.buttons",
        "label": "Close and maximise buttons",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "OPACITY",
        "key": "appearance.activeOpacity",
        "label": "Active",
        "desc": "",
        "ctl": "slid",
        "src": "hypr.json",
        "lo": 0.4,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "Look",
        "group": "OPACITY",
        "key": "appearance.inactiveOpacity",
        "label": "Inactive",
        "desc": "",
        "ctl": "slid",
        "src": "hypr.json",
        "lo": 0.4,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "Look",
        "group": "OPACITY",
        "key": "appearance.dimInactive",
        "label": "Dim inactive windows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "OPACITY",
        "key": "appearance.dimStrength",
        "label": "Dim strength",
        "desc": "",
        "ctl": "slid",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurEnabled",
        "label": "Enabled",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurSize",
        "label": "Size",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 20.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurPasses",
        "label": "Passes",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 1.0,
        "hi": 6.0
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurXray",
        "label": "X-ray (blur shows the wallpaper)",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurVibrancy",
        "label": "Vibrancy",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 0.5
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurNoise",
        "label": "Noise",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 0.1
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.shadowEnabled",
        "label": "Window shadows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.shadowRange",
        "label": "Shadow range",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.shadowPower",
        "label": "Shadow sharpness",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 1.0,
        "hi": 4.0
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.animations",
        "label": "Animations",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.wobblyWindows",
        "label": "Wobbly windows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.windowStyle",
        "label": "Open / close",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "pop",
            "slide",
            "gnomed"
        ]
    },
    {
        "tab": "Look",
        "group": "GLOW",
        "key": "appearance.glowEnabled",
        "label": "Glow behind windows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GLOW",
        "key": "appearance.glowRange",
        "label": "Range",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 4.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "Look",
        "group": "GLOW",
        "key": "appearance.glowColor",
        "label": "Colour",
        "desc": "",
        "ctl": "color",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GLASS",
        "key": "plugins.hyprglass.enabled",
        "label": "Liquid glass windows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GLASS",
        "key": "plugins.hyprglass.preset",
        "label": "Preset",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "clear",
            "subtle",
            "high_contrast",
            "glass"
        ]
    },
    {
        "tab": "Look",
        "group": "GLASS",
        "key": "plugins.hyprglass.blurStrength",
        "label": "Blur strength",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 5.0
    },
    {
        "tab": "Look",
        "group": "GLASS",
        "key": "plugins.hyprglass.opacity",
        "label": "Glass opacity",
        "desc": "",
        "ctl": "slid",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "Borders",
        "group": "FIXED COLOURS",
        "key": "appearance.activeBorder",
        "label": "Active window",
        "desc": "",
        "ctl": "color",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "FIXED COLOURS",
        "key": "appearance.inactiveBorder",
        "label": "Inactive window",
        "desc": "",
        "ctl": "color",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "ANIMATED BORDER",
        "key": "appearance.animatedBorder",
        "label": "Rotating gradient border",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "ANIMATED BORDER",
        "key": "appearance.borderAngleSpeed",
        "label": "Rotation speed",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 1.0,
        "hi": 10.0
    },
    {
        "tab": "Borders",
        "group": "IMAGE BORDER",
        "key": "plugins.imgborders.enabled",
        "label": "Image border around windows",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "IMAGE BORDER",
        "key": "plugins.imgborders.image",
        "label": "Choose image (path readout + button)",
        "desc": "",
        "ctl": "text",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "IMAGE BORDER",
        "key": "plugins.imgborders.scale",
        "label": "Border scale",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.5,
        "hi": 3.0
    },
    {
        "tab": "Borders",
        "group": "IMAGE BORDER",
        "key": "plugins.imgborders.smooth",
        "label": "Smooth scaling",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Cursor",
        "group": "CURSOR",
        "key": "cursor.theme",
        "label": "Theme",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "DYNAMIC"
        ]
    },
    {
        "tab": "Cursor",
        "group": "CURSOR",
        "key": "cursor.size",
        "label": "Size",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 12.0,
        "hi": 64.0,
        "unit": "px"
    },
    {
        "tab": "Cursor",
        "group": "CURSOR",
        "key": "cursor.inactiveTimeout",
        "label": "Hide after idle",
        "desc": "",
        "ctl": "step",
        "src": "hypr.json",
        "lo": 0.0,
        "hi": 30.0,
        "unit": "s"
    },
    {
        "tab": "Cursor",
        "group": "CURSOR",
        "key": "cursor.hideOnKeyPress",
        "label": "Hide while typing",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Cursor",
        "group": "MOTION",
        "key": "plugins.dynamicCursors.enabled",
        "label": "Realistic cursor motion",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Cursor",
        "group": "MOTION",
        "key": "plugins.dynamicCursors.mode",
        "label": "Style",
        "desc": "",
        "ctl": "seg",
        "src": "hypr.json",
        "opts": [
            "rotate",
            "tilt",
            "stretch"
        ]
    },
    {
        "tab": "Cursor",
        "group": "MOTION",
        "key": "plugins.dynamicCursors.shake",
        "label": "Shake to find (magnify)",
        "desc": "",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Wallpaper",
        "group": "THEME PALETTE",
        "key": "scheme (+ followWallpaper)",
        "label": "Colours",
        "desc": "",
        "ctl": "seg",
        "src": "current-theme.conf, regen of settings.lua, hyprctl reload, pkill -USR1 kitty",
        "opts": [
            "follow",
            "light",
            "dark",
            "custom"
        ]
    },
    {
        "tab": "Wallpaper",
        "group": "WALLPAPER",
        "key": "(no key \u2014 a path in a state file)",
        "label": "Wallpaper (image grid selection)",
        "desc": "",
        "ctl": "text",
        "src": "ryoku-wallpaper (read); written via `ryoku-shell wallpaper set <path>`"
    },
    {
        "tab": "Comfort",
        "group": "BACKLIGHT",
        "key": "(no key \u2014 hardware)",
        "label": "Brightness",
        "desc": "",
        "ctl": "slid",
        "src": "none \u2014 `brightnessctl set <N>%`; read back via `brightnessctl -m` (field 4)",
        "lo": 0.05,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "Comfort",
        "group": "NIGHT LIGHT",
        "key": "(no key \u2014 process presence)",
        "label": "Warm the screen",
        "desc": "",
        "ctl": "sw",
        "src": " `off`; state read via `... status` (\"on <temp>\" | \"off\"), which is really `pgrep -x hyprsunset`"
    },
    {
        "tab": "Comfort",
        "group": "NIGHT LIGHT",
        "key": "(no key \u2014 a bare number in a state file)",
        "label": "Temperature",
        "desc": "",
        "ctl": "step",
        "src": "ryoku-nightlight \u2014 written only as a side effect of the script's `start`, i.e. only when the light is turned on",
        "lo": 2500.0,
        "hi": 6500.0,
        "unit": "K"
    }
];
