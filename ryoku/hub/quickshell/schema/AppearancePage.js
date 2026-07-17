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
        "desc": "How rounded window corners are, 0 keeps them square",
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
        "desc": "Corner curve shape: 2 is a circle, higher flattens toward square",
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
        "desc": "Width of the frame around every window, 0 removes it",
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
        "desc": "How tiles arrange: binary splits, master and stack, or a strip",
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
        "desc": "Share of the screen each column takes, scrolling layout only",
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
        "desc": "The strip scrolls to keep focus in view, scrolling layout only",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GAPS",
        "key": "appearance.gapsIn",
        "label": "Inner (between windows)",
        "desc": "Space between neighbouring tiled windows",
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
        "desc": "Space between windows and the screen edge",
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
        "desc": "Grab a window's edge with the mouse to resize it",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "BEHAVIOUR",
        "key": "appearance.snapEnabled",
        "label": "Snap floating windows",
        "desc": "Dragged floating windows stick to screen edges and other windows",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.enabled",
        "label": "Window title bars",
        "desc": "Adds a bar with the window's title above it, applies on Save",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.height",
        "label": "Bar height",
        "desc": "Vertical space the title bar takes on each window",
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
        "desc": "How big the window's name renders in the bar",
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
        "desc": "The bar goes translucent and blurs whatever sits behind it",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "TITLE BARS",
        "key": "plugins.hyprbars.buttons",
        "label": "Close and maximise buttons",
        "desc": "Coloured dots on the bar: red closes, green goes fullscreen",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "OPACITY",
        "key": "appearance.activeOpacity",
        "label": "Active",
        "desc": "How solid the focused window is drawn, below 100% shows through",
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
        "desc": "How solid unfocused windows are drawn",
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
        "desc": "Darkens every window except the focused one",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "OPACITY",
        "key": "appearance.dimStrength",
        "label": "Dim strength",
        "desc": "How dark unfocused windows get while dimming is on",
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
        "desc": "Frosted-glass blur behind translucent windows and the shell",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurSize",
        "label": "Size",
        "desc": "How far each pass spreads, pair with passes for overall strength",
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
        "desc": "Times the blur repeats, more is stronger but costs GPU time",
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
        "desc": "Ignores windows beneath when blurring, lighter on the GPU",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "BLUR",
        "key": "appearance.blurVibrancy",
        "label": "Vibrancy",
        "desc": "Boosts colour saturation seen through the blur",
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
        "desc": "Grain over blurred areas, hides gradient banding",
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
        "desc": "A soft drop shadow under every window",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.shadowRange",
        "label": "Shadow range",
        "desc": "How far the shadow spreads from the window",
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
        "desc": "Higher pulls the shadow in tight, lower leaves a wide haze",
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
        "desc": "Motion for opening, closing, moving, workspaces; off snaps instantly",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.wobblyWindows",
        "label": "Wobbly windows",
        "desc": "Dragged windows overshoot and spring back, needs animations on",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "DEPTH & MOTION",
        "key": "appearance.windowStyle",
        "label": "Open / close",
        "desc": "Entrance and exit motion: scale from centre, slide, or GNOME style",
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
        "desc": "A coloured halo cast behind every window",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GLOW",
        "key": "appearance.glowRange",
        "label": "Range",
        "desc": "How far the halo reaches past the window edge",
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
        "desc": "The halo's tint, picked here, not taken from the theme",
        "ctl": "color",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GLASS",
        "key": "plugins.hyprglass.enabled",
        "label": "Liquid glass windows",
        "desc": "Blur with glass-like refraction on windows, applies on Save",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Look",
        "group": "GLASS",
        "key": "plugins.hyprglass.preset",
        "label": "Preset",
        "desc": "Starting glass character, from nearly clear to heavy frosting",
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
        "desc": "How heavily the glass frosts what is behind the window",
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
        "desc": "How visible the glass pane is over the window",
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
        "desc": "Frame colour of the focused window, only with a fixed palette",
        "ctl": "color",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "FIXED COLOURS",
        "key": "appearance.inactiveBorder",
        "label": "Inactive window",
        "desc": "Frame colour of unfocused windows, only with a fixed palette",
        "ctl": "color",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "ANIMATED BORDER",
        "key": "appearance.animatedBorder",
        "label": "Rotating gradient border",
        "desc": "Sweeps your accent colours around the frame, needs thickness above 0",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "ANIMATED BORDER",
        "key": "appearance.borderAngleSpeed",
        "label": "Rotation speed",
        "desc": "How fast the gradient circles the window",
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
        "desc": "Tiles a picture around each window as its frame, applies on Save",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "IMAGE BORDER",
        "key": "plugins.imgborders.image",
        "label": "Border image",
        "desc": "The picture tiled around windows, takes effect on Save",
        "ctl": "text",
        "src": "hypr.json"
    },
    {
        "tab": "Borders",
        "group": "IMAGE BORDER",
        "key": "plugins.imgborders.scale",
        "label": "Border scale",
        "desc": "Grows or shrinks the tiled picture around each window",
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
        "desc": "Filters the picture when scaled, off keeps hard pixel edges",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Cursor",
        "group": "CURSOR",
        "key": "cursor.theme",
        "label": "Theme",
        "desc": "From installed icon sets, applies now and to newly opened apps",
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
        "desc": "How large the pointer is drawn",
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
        "desc": "Seconds of stillness before the pointer hides, 0 never hides",
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
        "desc": "The pointer vanishes on a keypress and returns when moved",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Cursor",
        "group": "MOTION",
        "key": "plugins.dynamicCursors.enabled",
        "label": "Realistic cursor motion",
        "desc": "The pointer tilts, turns, or stretches as it moves, applies on Save",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Cursor",
        "group": "MOTION",
        "key": "plugins.dynamicCursors.mode",
        "label": "Style",
        "desc": "Which deformation the motion uses",
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
        "desc": "Shaking the mouse briefly grows the pointer so you can find it",
        "ctl": "sw",
        "src": "hypr.json"
    },
    {
        "tab": "Wallpaper",
        "group": "THEME PALETTE",
        "key": "scheme (+ followWallpaper)",
        "label": "Colours",
        "desc": "Follow retints from each wallpaper, Light or Dark locks a palette",
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
        "label": "Wallpaper",
        "desc": "Images from ~/Pictures/Wallpapers, picking one rethemes the desktop",
        "ctl": "text",
        "src": "ryoku-wallpaper (read); written via `ryoku-shell wallpaper set <path>`"
    },
    {
        "tab": "Comfort",
        "group": "BACKLIGHT",
        "key": "(no key \u2014 hardware)",
        "label": "Brightness",
        "desc": "Hardware backlight, applied at once, floors at 5% to stay visible",
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
        "desc": "Cuts blue light for the evening, stays on across sessions",
        "ctl": "sw",
        "src": " `off`; state read via `... status` (\"on <temp>\" | \"off\"), which is really `pgrep -x hyprsunset`"
    },
    {
        "tab": "Comfort",
        "group": "NIGHT LIGHT",
        "key": "(no key \u2014 a bare number in a state file)",
        "label": "Temperature",
        "desc": "Lower Kelvin is warmer, saved only while the light is on",
        "ctl": "step",
        "src": "ryoku-nightlight \u2014 written only as a side effect of the script's `start`, i.e. only when the light is turned on",
        "lo": 2500.0,
        "hi": 6500.0,
        "unit": "K"
    }
];
