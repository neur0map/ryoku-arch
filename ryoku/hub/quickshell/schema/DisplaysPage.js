.pragma library

// DisplaysPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "<selected monitor name> (SettingSection title is dynamic: page.sel.name; literal fallback \"DISPLAY\")",
        "key": "position (Set as main re-bases the layout so this display sits at the 0,0 origin; not a per-display disk key)",
        "label": "Main display",
        "desc": "Make this the primary display: puts it at the global origin, Hyprland's cursor-home / reference corner",
        "ctl": "action",
        "src": "<name>.json (Save) / monitors-applied.json (Apply)"
    },
    {
        "tab": "",
        "group": "<selected monitor name> (SettingSection title is dynamic: page.sel.name; literal fallback \"DISPLAY\" when no selection)",
        "key": "disabled",
        "label": "Enabled",
        "desc": "Off turns the display dark; takes effect only when you Apply",
        "ctl": "sw",
        "src": "<name>.json (RYOKU_MONITORS_DIR) on Save"
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "mode",
        "label": "Resolution",
        "desc": "Pixel size and refresh rate together; one choice sets both",
        "ctl": "chips",
        "src": "<name>.json (Save)",
        "opts": [
            "DYNAMIC",
            "Option",
            "Option",
            "Parsed",
            "De-duplicated",
            "Sorted:",
            "Fallback",
            "Related"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "scale",
        "label": "Scale",
        "desc": "Higher values render everything larger, leaving less desktop space",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 0.5,
        "hi": 3.0
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "transform",
        "label": "Rotation",
        "desc": "Turns the picture; 90\u00b0 and 270\u00b0 swap the display's width and height",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "0",
            "1",
            "2",
            "3"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "vrr",
        "label": "Adaptive sync",
        "desc": "Refresh rate follows the frame rate; Fullscreen enables it only there",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "0",
            "1",
            "2"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "cm",
        "label": "Colour",
        "desc": "sRGB is standard, Wide is wide-gamut, HDR needs a display that supports it (falls back to sRGB otherwise)",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "sRGB",
            "Wide",
            "HDR"
        ]
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "sdrbrightness",
        "label": "SDR brightness",
        "desc": "How bright non-HDR content looks in HDR mode; shown only when Color is HDR",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 1.0,
        "hi": 2.0
    },
    {
        "tab": "",
        "group": "<selected monitor name> (dynamic; fallback \"DISPLAY\")",
        "key": "mirror",
        "label": "Mirror of",
        "desc": "Shows a copy of the chosen display here; disabled screens aren't listed",
        "ctl": "seg",
        "src": "<name>.json (Save)",
        "opts": [
            "\"\"",
            "DYNAMIC:",
            "Excluded"
        ]
    },
    {
        "tab": "",
        "group": "POSITION",
        "key": "position (serialised jointly as \"<x>x<y>\", e.g. \"2560x0\" \u2014 X and Y are NOT separate disk keys)",
        "label": "X",
        "desc": "Distance from the layout's left edge; dragging the tile sets it too",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 0.0,
        "hi": 20000.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "POSITION",
        "key": "position (serialised jointly as \"<x>x<y>\" \u2014 X and Y are NOT separate disk keys)",
        "label": "Y",
        "desc": "Distance from the layout's top edge; dragging the tile sets it too",
        "ctl": "step",
        "src": "<name>.json (Save)",
        "lo": 0.0,
        "hi": 20000.0,
        "unit": "px"
    },
    {
        "tab": "",
        "group": "PROFILES",
        "key": "filename \u2014 becomes ~/.config/ryoku/monitors/<name>.json",
        "label": "Profile name",
        "desc": "Name for the new profile; Enter saves it, blank names are ignored",
        "ctl": "text",
        "src": "<name>.json (RYOKU_MONITORS_DIR)"
    },
    {
        "tab": "",
        "group": "PROFILES",
        "key": "",
        "label": "Save (profile)",
        "desc": "",
        "ctl": "action",
        "src": "monitors.lua"
    },
    {
        "tab": "",
        "group": "(header quick-actions Row \u2014 outside any SettingSection, top-right, aligned to the \"N displays detected\" text)",
        "key": "",
        "label": "Mirror (quick action)",
        "desc": "",
        "ctl": "action",
        "src": "monitors.lua (via cmd_mirror \u2192 cmd_persist)"
    },
    {
        "tab": "",
        "group": "(header quick-actions Row \u2014 outside any SettingSection)",
        "key": "",
        "label": "Extend (quick action)",
        "desc": "",
        "ctl": "action",
        "src": "monitors-applied.json"
    },
    {
        "tab": "",
        "group": "(header quick-actions Row \u2014 outside any SettingSection)",
        "key": "",
        "label": "DPI auto-scale (quick action)",
        "desc": "",
        "ctl": "action",
        "src": "monitors-applied.json"
    },
    {
        "tab": "",
        "group": "(bottom action bar \u2014 outside any SettingSection)",
        "key": "",
        "label": "Apply (action bar)",
        "desc": "",
        "ctl": "action",
        "src": "monitors-applied.json"
    },
    {
        "tab": "",
        "group": "(bottom action bar \u2014 outside any SettingSection)",
        "key": "",
        "label": "Revert (action bar)",
        "desc": "",
        "ctl": "action",
        "src": "shell"
    }
];
