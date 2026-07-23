.pragma library

// AppearancePage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [{
        "tab": "Theme",
        "group": "THEME PALETTE",
        "key": "scheme (+ followWallpaper)",
        "label": "Colours",
        "desc": "Mono is the Ryoku default; Follow retints per wallpaper, Light or Dark lock a palette",
        "ctl": "seg",
        "src": "current-theme.conf, regen of settings.lua, hyprctl reload, pkill -USR1 kitty",
        "opts": [
            "follow",
            "mono",
            "light",
            "dark",
            "custom"
        ]
    },{
        "tab": "Theme",
        "group": "WALLPAPER",
        "key": "(no key \u2014 a path in a state file)",
        "label": "Wallpaper",
        "desc": "Images from ~/Pictures/Wallpapers, picking one rethemes the desktop",
        "ctl": "text",
        "src": "ryoku-wallpaper (read); written via `ryoku-shell wallpaper set <path>`"
    },{
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
    },{
        "tab": "Comfort",
        "group": "NIGHT LIGHT",
        "key": "(no key \u2014 process presence)",
        "label": "Warm the screen",
        "desc": "Cuts blue light for the evening, stays on across sessions",
        "ctl": "sw",
        "src": " `off`; state read via `... status` (\"on <temp>\" | \"off\"), which is really `pgrep -x hyprsunset`"
    },{
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
    },{
        "tab": "Theme",
        "group": "BORDER COLOURS",
        "key": "appearance.activeBorder",
        "label": "Active window",
        "desc": "Frame colour of the focused window, only with a fixed palette",
        "ctl": "color",
        "src": "hypr.json"
    },{
        "tab": "Theme",
        "group": "BORDER COLOURS",
        "key": "appearance.inactiveBorder",
        "label": "Inactive window",
        "desc": "Frame colour of unfocused windows, only with a fixed palette",
        "ctl": "color",
        "src": "hypr.json"
    }
];
